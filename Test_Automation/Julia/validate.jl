using Plots
using WAV
include("turntable.jl")
include("heartbeat.jl")
include("device.jl")
include("soundcard_api.jl")
include("libaudio.jl")
include("kwsasr.jl")












function session_open(n)
    # preparation of workers
    for i in workers()
        i != 1 && rmprocs(i)      
    end
    addprocs(n)
    for wpid in workers()
        remotecall_fetch(include, wpid, "turntable.jl")
        remotecall_fetch(include, wpid, "heartbeat.jl")
        remotecall_fetch(include, wpid, "device.jl")
        remotecall_fetch(include, wpid, "soundcard_api.jl")
        remotecall_fetch(include, wpid, "kwsasr.jl")        
    end
    nothing
end


function session_close()
    for i in workers()
        i != 1 && rmprocs(i)      
    end
    nothing
end




# const sndcard_n_out = 8
# const sndcard_n_in = 8
# const mic_n = 1
# mixplay = zeros(Float32, size(essd,2), sndcard_n_out)
# mixplay[1,2] = 1.0f0
# mixrec = zeros(Float32, sndcard_n_in, mic_n)
# mixrec[2,1] = 1.0f0
#
# note: adjust atten for the level of the ess signal
# note: adjust syncatten for the level of the sync symbol, if too high mixer would prompt with mic clipping error!
# note: use long t_ess when possible, for the build-up of the stimulus energy
# note: use long t_decay if room or system dunamics are reverberant
# note: eq = [(b,a),(b,a)...] is prepending transfer function for filter verification, must be designed according to fs or fsd based on mode
# note: mode[1] is the physical device for playback, mode[2] is the physical device for recording
function impulse_response(mixspk::Matrix{Float64}, mixmic::Matrix{Float64};
    fs = 48000,
    fd = 47999.513810916986,
    f0 = 22, 
    f1 = 22000, 
    t_ess = 10, 
    t_decay = 3,
    eq = [([1.0],[1.0])],
    atten = -6,
    syncatten = -18,
    mode = (:asio, :asio))


    # parallel environment
    assert(nprocs() > 1)
    wpid = workers()

    # frequency range limitation
    assert(f0 < f1)
    f0 < 1.0 && (f0 = 1.0)
    f1 > fs/2 && (f1 = fs/2)

    

    if all(x->x==:asio, mode)

        ess = LibAudio.sinesweep_exp(f0, f1, t_ess, fs)
        m = length(ess)
        n = round(Int64, t_decay * fs)
        essd = zeros(m+n, 1)
        essd[1:m,1] = ess
        for i in eq
            essd = LibAudio.tf_filter(i[1], i[2], essd)  # the mixer will do clipping check
        end
        essd = 10^(atten/20) * essd
        mic = SoundcardAPI.playrecord(essd, mixspk, mixmic, fs)
        return LibAudio.impresp(ess, n, f0, f1, fs, mic)


    elseif all(x->x==:simulation, mode)

        ess = LibAudio.sinesweep_exp(f0, f1, t_ess, fs)
        m = length(ess)
        n = round(Int64, t_decay * fs)
        essd = zeros(m+n, 1)
        essd[1:m,1] = ess
        for i in eq
            essd = LibAudio.tf_filter(i[1], i[2], essd)  
        end

        ellip_b = [0.165069005881145, 0.064728220211450, 0.237771476924023, 0.237771476924022, 0.064728220211450, 0.165069005881146]
        ellip_a = [1.0, -1.544070855644442, 2.377072040756431, -1.638501402700271, 0.950992608325718, -0.210354984704200]
        mic = LibAudio.tf_filter(ellip_b, ellip_a, essd)
        ym = median(abs.(mic))
        mic[mic.>ym] = ym
        return LibAudio.impresp(ess, n, f0, f1, fs, mic)


    elseif all(x->x==:fileio, mode)

        ess = LibAudio.sinesweep_exp(f0, f1, t_ess, fd)
        m = length(ess)
        n = round(Int64, t_decay * fd)
        essd = zeros(m+n, 1)
        essd[1:m,1] = ess
        for i in eq
            essd = LibAudio.tf_filter(i[1], i[2], essd)  
        end
        essd = 10^(atten/20) * essd
        t_essd = length(essd) / fd
        contextswitch = 5
        syncdecay = 3
        essda = LibAudio.syncsymbol_encode(essd, contextswitch, LibAudio.syncsymbol, syncatten, syncdecay, fd)

        capture = ["mic_8ch_16k_s16_le"]
        playback = "dutplaybackexpsinesweep.wav"
        wavwrite(Device.mixer(essda, mixspk), playback, Fs=fs, nbits=32)

        Device.luxinit()
        Device.luxplayrecord(playback, ceil(size(essda,1)/fd), capture)
        Device.luxplayrecord(capture)

                ## todo: retrieve the 48000 raw mic signal
                Device.raw2wav_16bit("$(capture[1]).raw", size(mixmic,1), 16000, "$(capture[1]).wav")
                raw_fileio, fs_fileio = wavread("$(capture[1]).wav")
                r = LibAudio.resample_vhq(Device.mixer(raw_fileio, mixmic), fs_fileio, fs)

        # decode async signal
        p = size(essd,1)
        c = size(r,2)
        loc = LibAudio.syncsymbol_decode(r, LibAudio.syncsymbol, syncdecay, t_essd, fd)

        hyperthetical_tolerance = 2048
        mic = zeros(p, c)
        for i = 1:c
            l = loc[i] - hyperthetical_tolerance
            mic[:,i] = r[l:l+p-1, i]
        end
        return LibAudio.impresp(ess, n, f0, f1, fd, mic)


    elseif mode[1] == :asio && mode[2] == :fileio

        ess = LibAudio.sinesweep_exp(f0, f1, t_ess, fs)
        m = length(ess)
        n = round(Int64, t_decay * fs)
        essd = zeros(m+n, 1)
        essd[1:m,1] = ess
        for i in eq
            essd = LibAudio.tf_filter(i[1], i[2], essd)  
        end
        essd = 10^(atten/20) * essd
        t_essd = length(essd) / fs
        contextswitch = 5
        syncdecay = 3
        essda = LibAudio.syncsymbol_encode(essd, contextswitch, LibAudio.syncsymbol, syncatten, syncdecay, fs)

            # prepare device side
            capture = ["mic_8ch_16k_s16_le"]
            Device.luxrecord(ceil(size(essda,1)/fs), capture)

            # prepare souncard side
            dat = SoundcardAPI.mixer(Float32.(essda), Float32.(mixspk))
            pcm = SharedArray{Float32,1}(SoundcardAPI.to_interleave(dat))
            
            # playdone = remotecall(SoundcardAPI.play, wpid[1], essdfa, mixspk, fs) # latency is high
            playdone = remotecall(SoundcardAPI.play, wpid[1], size(dat), pcm, fs)  # latency is low
            Device.luxrecord(capture)
            fetch(playdone)

            # post processing
            Device.raw2wav_16bit("$(capture[1]).raw", size(mixmic,1), 16000, "$(capture[1]).wav")
            raw_fileio, fs_fileio = wavread("$(capture[1]).wav")
            r = LibAudio.resample_vhq(Device.mixer(raw_fileio, mixmic), fs_fileio, fs)

        # decode async signal
        ess_mt = LibAudio.sinesweep_exp(f0, f1, t_ess, fd)
        n_mt = round(Int64, t_decay * fd)  

        p = round(Int64, t_essd * fd)           
        c = size(r,2)
        loc = LibAudio.syncsymbol_decode(r, LibAudio.syncsymbol, syncdecay, t_essd, fd)
        hyperthetical_tolerance = 2048
        mic = zeros(p, c)
        for i = 1:c
            l = loc[i] - hyperthetical_tolerance
            mic[:,i] = r[l:l+p-1,i]
        end
        return LibAudio.impresp(ess_mt, n_mt, f0, f1, fd, mic)


    elseif mode[1] == :fileio && mode[2] == :asio

        ess = LibAudio.sinesweep_exp(f0, f1, t_ess, fd)
        m = length(ess)
        n = round(Int64, t_decay * fd)
        essd = zeros(m+n, 1)
        essd[1:m,1] = ess
        for i in eq
            essd = LibAudio.tf_filter(i[1], i[2], essd)  
        end
        essd = 10^(atten/20) * essd
        t_essd = length(essd) / fd  
        contextswitch = 5
        syncdecay = 3
        essda = LibAudio.syncsymbol_encode(essd, contextswitch, LibAudio.syncsymbol, syncatten, syncdecay, fd)

        playback = "dutplaybackexpsinesweep.wav"
        wavwrite(Device.mixer(essda, mixspk), playback, Fs=fs, nbits=32)
        Device.luxplay(playback)

                playdone = remotecall(Device.luxplay, wpid[1])
                r = SoundcardAPI.record(size(essda,1), mixmic, fs)
                fetch(playdone)

        # decode async signal
        ess_mt = LibAudio.sinesweep_exp(f0, f1, t_ess, fs)
        n_mt = round(Int64, t_decay * fs)  

        p = round(Int64, t_essd * fs)           
        c = size(r,2)
        loc = LibAudio.syncsymbol_decode(r, LibAudio.syncsymbol, syncdecay, t_essd, fs)
        hyperthetical_tolerance = 2048
        mic = zeros(p, c)
        for i = 1:c
            l = loc[i] - hyperthetical_tolerance
            mic[:,i] = r[l:l+p-1,i]
        end
        return LibAudio.impresp(ess_mt, n_mt, f0, f1, fs, mic)
        
    else
        error("mode: (:asio,:asio) | (:asio,:fileio) | (:fileio,:asio) | (:fileio,:fileio) | (:simulation,:simulation)")
    end



    
end 








hwinfo2string(hw::Dict{Symbol,String}) = hw[:calibrator] * "_" * hw[:db] * "_" * hw[:dba] * "_" * hw[:mic] * "_" * hw[:preamp] * "_" * hw[:gain] * "_" * hw[:soundcard]

# example:
#   mixmic = zeros(8,1)
#   micmic[2,1] = 1.0
#   hwspec = Dict(:calibrator=>"42AA", :db=>"114.0", :dba=>"105.4", :mic=>"26AM", :preamp=>"12AA", :gain=>"0dB", :soundcard=>"UFX")
#   levelcalibrate_updateref(mixmic, 60.0, 48000, "D:\\AATT\\Data\\Calib\\Level", hwinfo=hwspec)
function levelcalibrate_updateref(mixmic::Matrix{Float64}, seconds, fs, folderpath;
    hwinfo = Dict(:calibrator=>"42AA", :db=>"114.0", :dba=>"105.4", :mic=>"26XX", :preamp=>"12AA", :gain=>"0dB", :soundcard=>"UFX"))
    
    r = SoundcardAPI.record(round(Int64, seconds * fs), mixmic, fs)
    t = replace(string(now()), [':','.'], '-')
    wavwrite(r, joinpath(folderpath, t * "+" * hwinfo2string(hwinfo) * ".wav"), Fs=fs, nbits=32)
    r[1:192,:]
end


# note: time diff in millseconds, use Dates.Millisecond(24*3600*1000) for conditions
function levelcalibrate_retrievelatest(folderpath;
    hwinfo = Dict(:calibrator=>"42AA", :db=>"114.0", :dba=>"105.4", :mic=>"26XX", :preamp=>"12AA", :gain=>"0dB", :soundcard=>"UFX"))

    fileloc = ""
    timespan = Vector{DateTime}([now(), now()])
    archive = [(DateTime(String(split(basename(i),"+")[1]), DateFormat("y-m-dTH-M-S-s")), i) for i in LibAudio.list(folderpath, t=".wav")]
    sort!(archive, by=x->x[1], rev=true)
    
    for i in archive
        if String(split(basename(i[2]),"+")[2]) == hwinfo2string(hwinfo) * ".wav"
            timespan[1] = i[1]
            fileloc = i[2]
            break
        end
    end
    fileloc, diff(timespan)[1]
end



# note: symbol is the segment of signal for level measurement
# note: repeat if for multiple trial --- t_context + (symbol + decay) x repeat
# note: folderpath is the path for reference mic recordings of the calibrators (piston and piezo etc...)
# note: validation method 1: compare against the spl meter
#       validation method 2: 200hz -> 10dB lower than dBSPL, 1kHz-> the same, 6kHz-> almost the same, 7kHz-> 0.8 dB lower than dBSPL
function levelcalibrate_dba(symbol::Vector{Float64}, repeat::Int, symbol_gain_init, mixspk::Matrix{Float64}, mixmic::Matrix{Float64}, fs, dba_target, folderpath;
    barometer_correction = 0.0,
    mode = :asio,
    t_context = 3.0,
    t_decay = 2.0,
    piston = Dict(:calibrator=>"42AA", :db=>"114.0", :dba=>"105.4", :mic=>"26XX", :preamp=>"12AA", :gain=>"0dB", :soundcard=>"UFX"),
    piezo = Dict(:calibrator=>"42AB", :db=>"114.0", :dba=>"", :mic=>"26XX", :preamp=>"12AA", :gain=>"0dB", :soundcard=>"UFX"))
    

    # parallel environment
    assert(nprocs() > 1)
    wpid = workers()
    assert(size(mixspk, 1) == 1)
    assert(size(mixmic, 2) == 1)


    function recording_with_gain(g)
        m = length(symbol)
        n = round(Int64, t_decay*fs)
        
        symbold = zeros(m+n,1)
        symbold[1:m,1] = symbol * 10^(g/20)
        symboldt = [zeros(round(Int64, t_context*fs), 1); repmat(symbold,repeat,1)]
    
        if mode == :asio
            r = SoundcardAPI.playrecord(symboldt, mixspk, mixmic, fs)
    
        elseif mode == :fileio
            # prepare the device
            Device.luxinit()
            playback = "dutplayback.wav"
            wavwrite(Device.mixer(symboldt, mixspk), playback, Fs=fs, nbits=32)
            Device.luxplay(playback)
    
            playdone = remotecall(Device.luxplay, wpid[1])
            r = SoundcardAPI.record(size(symboldt,1), mixmic, fs)
            fetch(playdone)
        else
            error("mode must be either :asio or :fileio")
        end
        return r
    end


    # load the latest calibrator recordings: 42AA and 42AB
    fileloc_piston, millidelta_piston = levelcalibrate_retrievelatest(folderpath, hwinfo=piston)
    fileloc_piezo, millidelta_piezo = levelcalibrate_retrievelatest(folderpath, hwinfo=piezo)
    info("use latest calibration files:")
    info(fileloc_piston)
    info(fileloc_piezo)
    assert(millidelta_piston <= Dates.Millisecond(Dates.Day(1)))
    assert(millidelta_piezo <= Dates.Millisecond(Dates.Day(1)))

    # do recording
    y = recording_with_gain(symbol_gain_init) 

    # dbspl of piston and piezo would give similar results: for example < 0.5dB
    dbspl_piston = LibAudio.spl(fileloc_piston, y, symbol, repeat, fs, calibrator_reading=parse(Float64,piston[:db])+barometer_correction)
    dbspl_piezo = LibAudio.spl(fileloc_piezo, y, symbol, repeat, fs, calibrator_reading=parse(Float64,piezo[:db]))
    if abs(dbspl_piston[1] - dbspl_piezo[1]) > 0.5
        error("calibration deviation > 0.5 dB(A), please re-calibrate! Abort")
    else
        info("calibration deviation: $(abs(dbspl_piston[1] - dbspl_piezo[1]))")
    end

    # if cross validation ok, use piston(42AA) for dBA measurement
    dba_piston = LibAudio.spl(fileloc_piston, y, symbol, repeat, fs, calibrator_reading=parse(Float64,piston[:dba]), weighting="a")
    symbol_gain = symbol_gain_init + (dba_target - dba_piston[1])
    
    # apply the delta and remeasure
    y = recording_with_gain(symbol_gain) 
    dba_piston = LibAudio.spl(fileloc_piston, y, symbol, repeat, fs, calibrator_reading=parse(Float64,piston[:dba]), weighting="a")

    return symbol_gain, dba_piston[1]
end





# note: source is multichannel sound tracks for spl measurement, it is based on async method, therefore no need for parameter repeat
function levelcalibrate_dba(source::Matrix{Float64}, source_gain_init, mixspk::Matrix{Float64}, mixmic::Matrix{Float64}, fs, dba_target, folderpath;
    barometer_correction = 0.0,
    mode = :asio,
    t_context = 3.0,
    t_decay = 2.0,
    gain_sync = -12,
    piston = Dict(:calibrator=>"42AA", :db=>"114.0", :dba=>"105.4", :mic=>"26XX", :preamp=>"12AA", :gain=>"0dB", :soundcard=>"UFX"),
    piezo = Dict(:calibrator=>"42AB", :db=>"114.0", :dba=>"", :mic=>"26XX", :preamp=>"12AA", :gain=>"0dB", :soundcard=>"UFX"))
    

    # parallel environment
    assert(nprocs() > 1)
    wpid = workers()
    assert(size(mixmic, 2) == 1)


    function recording_with_gain(g)
      
        syncsym = LibAudio.syncsymbol(220,8000,1,fs)
        source_async = LibAudio.syncsymbol_encode(source * 10^(g/20), t_context, 10^(gain_sync/20)*syncsym, t_decay, fs)

        if mode == :asio
            r = SoundcardAPI.playrecord(source_async, mixspk, mixmic, fs)
    
        elseif mode == :fileio
            # prepare the device
            Device.luxinit()
            playback = "dutplayback.wav"
            wavwrite(Device.mixer(source_async, mixspk), playback, Fs=fs, nbits=32)
            Device.luxplay(playback)
    
            playdone = remotecall(Device.luxplay, wpid[1])
            r = SoundcardAPI.record(size(source_async,1), mixmic, fs)
            fetch(playdone)
        else
            error("mode must be either :asio or :fileio")
        end
        return r, syncsym
    end


    # load the latest calibrator recordings: 42AA and 42AB
    fileloc_piston, millidelta_piston = levelcalibrate_retrievelatest(folderpath, hwinfo=piston)
    fileloc_piezo, millidelta_piezo = levelcalibrate_retrievelatest(folderpath, hwinfo=piezo)
    info("use latest calibration files:")
    info(fileloc_piston)
    info(fileloc_piezo)
    assert(millidelta_piston <= Dates.Millisecond(Dates.Day(1)))
    assert(millidelta_piezo <= Dates.Millisecond(Dates.Day(1)))

    # do recording
    ya, syn = recording_with_gain(source_gain_init) 
    loc = LibAudio.syncsymbol_decode(ya, size(source,1), syn, t_decay, fs)
    lb = loc[1,1] + length(syn) + round(Int64, t_decay * fs)
    rb = loc[2,1] - 1

    # dbspl of piston and piezo would give similar results: for example < 0.5dB
    dbspl_piston = LibAudio.spl(fileloc_piston, ya[lb:rb,:], ya[lb:rb,1], 1, fs, calibrator_reading=parse(Float64,piston[:db])+barometer_correction)
    dbspl_piezo = LibAudio.spl(fileloc_piezo, ya[lb:rb,:], ya[lb:rb,1], 1, fs, calibrator_reading=parse(Float64,piezo[:db]))
    if abs(dbspl_piston[1] - dbspl_piezo[1]) > 0.5
        error("calibration deviation > 0.5 dB(A), please re-calibrate! Abort")
    else
        info("calibration deviation: $(abs(dbspl_piston[1] - dbspl_piezo[1]))")
    end

    # if cross validation ok, use piston(42AA) for dBA measurement
    dba_piston = LibAudio.spl(fileloc_piston, ya[lb:rb,:], ya[lb:rb,1], 1, fs, calibrator_reading=parse(Float64,piston[:dba]), weighting="a")
    source_gain = source_gain_init + (dba_target - dba_piston[1])
    
    # apply the delta and remeasure
    ya, syn = recording_with_gain(source_gain) 
    loc = LibAudio.syncsymbol_decode(ya, size(source,1), syn, t_decay, fs)
    lb = loc[1,1] + length(syn) + round(Int64, t_decay * fs)
    rb = loc[2,1] - 1
    dba_piston = LibAudio.spl(fileloc_piston, ya[lb:rb,:], ya[lb:rb,1], 1, fs, calibrator_reading=parse(Float64,piston[:dba]), weighting="a")

    return source_gain, dba_piston[1]
end



# mixspk = zeros(1,2)
# mixspk[1,1] = 1.0
# mixmic = zeros(9,1)
# mixmic[9,1] = 1.0
function clockdrift_measure(devmix_spk::Matrix{Float64}, sndmix_mic::Matrix{Float64}; repeat = 3, fs = 48000)

    # 
    #   +--------+--------+--------+--------+--------+ => 5 samples in digital domain played via dut's speaker, whose sample interval is Td.
    #   +-----+-----+-----+-----+-----+-----+-----+--- => 7 samples captured by the standard sampler of the soundcard,
    #  
    #   5 x Td ≈ 7 x Tr
    #   or formly, N/Fd ≈ Nm / Fr
    #   Fd ≈ N / Nm x Fr
    #   Fd/Fr ≈ N/Nm = 5/7  
    #
    assert(nprocs() > 1)
    wpid = workers()
    info("start measure clock drift:")

    # fileio -> asio
    sync = 10^(-6/20) * LibAudio.syncsymbol(800, 2000, 0.5, fs)
    info("  sync samples: $(length(sync))")
    period = [zeros(round(Int64,100fs),1); sync]
    signal = [zeros(round(Int64,3fs),1); sync; repmat(period,repeat,1); zeros(round(Int64,3fs),1)]
    info("  signal train formed")

    Device.luxinit()
    playback = "dutplayback.wav"
    wavwrite(Device.mixer(signal, devmix_spk), playback, Fs=fs, nbits=32)
    info("  filesize: $(filesize("dutplayback.wav")/1024/1024) MiB")
    Device.luxplay(playback)
    info("  singal pushed to device")

    playdone = remotecall(Device.luxplay, wpid[1])
    r = SoundcardAPI.record(size(signal,1), sndmix_mic, fs)
    fetch(playdone)
    wavwrite(r, "clockdrift.wav", Fs=fs, nbits=32)
    info("  recording written to clockdrift.wav")

    # syncs = 10^(-6/20) * LibAudio.syncsymbol(800, 2000, 1, fss)
    # info("  syncs samples: $(length(syncs))")
    # note: sync is approximately invariant due to its short length
    lbs,pk,pkf,y = LibAudio.extract_symbol_and_merge(r[:,1], sync, repeat+1, dither=-180)

    pkfd = diff(pkf)
    chrodrift_100sec = ((pkfd[end] - pkfd[1]) / (repeat-1))/fs
    freqdrift_100sec = (size(period,1) - median(pkfd))/fs
    
    (fs * size(period,1)/median(pkfd), freqdrift_100sec, chrodrift_100sec)
end