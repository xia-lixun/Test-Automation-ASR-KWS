
using WAV
include("device.jl")
include("soundcard_api.jl")
include("libaudio.jl")






function soundcard_api()
    fs = 48000
    data = SoundcardAPI.record((3fs,8), fs)
    wavwrite(data, "record.wav", Fs=fs, nbits=32)

    SoundcardAPI.play(data, fs)

    loopback = SoundcardAPI.playrecord(data, 8, fs)
    wavwrite(loopback, "loopback.wav", Fs=fs, nbits=32)
end






function impulse_response_open()
    # preparation of workers
    for i in workers()
        i != 1 && rmprocs(i)      
    end
    addprocs(1)
    wpid = workers()
    remotecall_fetch(include, wpid[1], "device.jl")
    remotecall_fetch(include, wpid[1], "soundcard_api.jl")        
end

function impulse_response_close()
    for i in workers()
        i != 1 && rmprocs(i)      
    end
end
# const sndcard_n_out = 8
# const sndcard_n_in = 8
# const mic_n = 1
# mixplay = zeros(Float32, size(essd,2), sndcard_n_out)
# mixplay[1,2] = 1.0f0
# mixrec = zeros(Float32, sndcard_n_in, mic_n)
# mixrec[2,1] = 1.0f0
function impulse_response(mixspk::Matrix{Float64}, mixmic::Matrix{Float64};
    fs = 48000,
    f0 = 22, 
    f1 = 22000, 
    t_ess = 10, 
    t_decay = 3,
    b = [1.0],
    a = [1.0],
    atten = -20,
    syncatten = -18,
    mode = (:asio, :asio))


    # parallel environment
    assert(nprocs() > 1)
    wpid = workers()

    # frequency range limitation
    assert(f0 < f1)
    f0 < 1.0 && (f0 = 1.0)
    f1 > fs/2 && (f1 = fs/2)

    # generate ess
    ess = LibAudio.expsinesweep(f0, f1, t_ess, fs)
    m = size(ess,1)
    n = round(Int64, t_decay * fs)
    essd = zeros(m+n, 1)
    essd[1:m,:] = ess

    # eq filter and attenuate, we do not do clipping check as it is duty of the mixer
    essdf = 10^(atten/20) * LibAudio.tf_filter(b, a, essd)


    if all(x->x==:asio, mode)
        mics = SoundcardAPI.playrecord(essdf, mixspk, mixmic, fs)
    
    else
        sync = 10^(syncatten/20) * LibAudio.syncsymbol(220, 8000, 1, fs)
        contextswitch = 5
        syncdecay = 3
        essdfa = LibAudio.add_syncsymbol(essdf, contextswitch, sync, syncdecay, fs)
        Device.luxinit()

        if all(x->x==:fileio, mode)

            playback = "dutplayback.wav"
            wavwrite(Device.mixer(essdfa, mixspk), playback, Fs=fs, nbits=32)

            capture = ["mic_8ch_16k_s16_le"]
            Device.luxplayrecord(playback, size(essdfa,1)/fs, capture)
            Device.luxplayrecord(capture)

            Device.raw2wav_16bit("$(capture[1]).raw", size(mixmic,1), 16000, "$(capture[1]).wav")
            raw_fileio, fs_fileio = wavread("$(capture[1]).wav")
            r = LibAudio.resample_vhq(Device.mixer(raw_fileio, mixmic), fs_fileio, fs)

            #run(`sox $(capture[1]).wav -r $(fs) mic_8ch_48k_s16_le.wav`)
            #r = Device.mixer(wavread("mic_8ch_48k_s16_le.wav")[1], mixmic)

        elseif mode[1] == :asio && mode[2] == :fileio

            # prepare device side
            capture = ["mic_8ch_16k_s16_le"]
            Device.luxrecord(size(essdfa,1)/fs, capture)

            # prepare souncard side
            dat = SoundcardAPI.mixer(Float32.(essdfa), Float32.(mixspk))
            pcm = SharedArray{Float32,1}(SoundcardAPI.to_interleave(dat))
            
            # playdone = remotecall(SoundcardAPI.play, wpid[1], essdfa, mixspk, fs) # latency is high
            playdone = remotecall(SoundcardAPI.play, wpid[1], size(dat), pcm, fs)  # latency is low
            Device.luxrecord(capture)
            fetch(playdone)

            # post processing
            Device.raw2wav_16bit("$(capture[1]).raw", size(mixmic,1), 16000, "$(capture[1]).wav")
            raw_fileio, fs_fileio = wavread("$(capture[1]).wav")
            r = LibAudio.resample_vhq(Device.mixer(raw_fileio, mixmic), fs_fileio, fs)

            # run(`sox $(capture[1]).wav -r $(fs) mic_8ch_48k_s16_le.wav`)
            # r = Device.mixer(wavread("mic_8ch_48k_s16_le.wav")[1], mixmic)                

        elseif mode[1] == :fileio && mode[2] == :asio

            # prepare the device
            playback = "dutplayback.wav"
            wavwrite(Device.mixer(essdfa, mixspk), playback, Fs=fs, nbits=32)
            Device.luxplay(playback)

            playdone = remotecall(Device.luxplay, wpid[1])
            r = SoundcardAPI.record(size(essdfa,1), mixmic, fs)
            fetch(playdone)

        else
            error("please choose valid mode: (:asio, :asio)|(:fileio, :fileio)|(:asio, :fileio)|(:fileio, :asio)")
        end


        # decode async signal
        nmic = size(mixmic,2)
        symloc = zeros(Int64,2,nmic)
        for i = 1:nmic
            lbs,pks,pksf,y = LibAudio.extract_symbol_and_merge(r[:,i], sync[:,1], 2)
            symloc[:,i] = lbs
        end
        delta_measure = symloc[2,:] - symloc[1,:]
        delta_theory = size(sync,1) + round(Int64, syncdecay * fs) + size(essdf,1)
        relat = symloc[1,:] - minimum(symloc[1,:])
        info(delta_measure)
        info(delta_theory)
        info(relat)

        mics = zeros(size(essdf,1), nmic)
        hyperthetical_tolerance = 2048
        for i = 1:nmic
            loc = symloc[1,i] + size(sync,1) + round(Int64, syncdecay * fs) - hyperthetical_tolerance
            mics[:,i] = r[loc:loc+size(essdf,1)-1, i]
        end
    end

    fund, harm, dirac, total = LibAudio.impresp(ess, n, f0, f1, fs, mics)
end 




function levelcalibrate_updateref(mixmic::Matrix{Float64}, seconds, fs, folderpath;
    hwinfo = Dict(:calibrator=>"42AA", :db=>"114.0", :dba=>"105.4", :mic=>"26AM", :preamp=>"12AA", :gain=>"0dB", :soundcard=>"UFX"))
    
    r = SoundcardAPI.record(round(Int64, seconds * fs), mixmic, fs)
    t = replace(string(now()), [':','.'], '-')
    name = hwinfo[:calibrator] * "_" * hwinfo[:db] * "_" * hwinfo[:dba] * "_" * hwinfo[:mic] * "_" * hwinfo[:preamp] * "_" * hwinfo[:gain] * "_" * hwinfo[:soundcard]
    wavwrite(r, joinpath(folderpath, t * "_" * name * ".wav"), Fs=fs, nbits=32)
end

function levelcalibrate_dba(symbol, symbol_gain_init, mixspk, mixmic, fs, dba_target, barometer_correction;
    mode = :asio,
    hwinfo = Dict(:calibrator=>"42AA", :db=>"114.0", :dba=>"105.4", :mic=>"26AM", :preamp=>"12AA", :gain=>"0dB", :soundcard=>"UFX"))
    
    
end