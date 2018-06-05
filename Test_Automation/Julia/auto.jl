#  [0.9]  soundcard ok? dut ok? turntable ok?
#  [1.0]  update level calibration recordings (42AA and 42AB)
#  [1.1]  measure room default SPL in dB(A), if too noisy -> halt the process
#  [1.2]  mouth/loudspeaker EQ check, if EQ out-of-date, or shaped impulse response not flat enough -> halt the process
#  [1.3]  parse the test specification
#  [2.1]  set the orientation of the DUT
#  [2.2]  power cycle the DUT
#  [2.3]  apply EQ to speech and noise files, peak normalized avoid clipping
#  [2.4]  mouth/loudspeaker SPL calibration (use signals after EQ)
#  [2.5]  DUT echo SPL calibration
#  [2.6]  start playback/recordings (use signals after EQ)
#  [2.7]  push recordings to ASR/KWS scoring server
#  [2.8]  fetch the scoring results and generate the report
using JSON
using MAT
include("validate.jl")




function auto(taskjsonfile)

    # reading parameters
    conf = JSON.parsefile(taskjsonfile)
    fs = conf["Sample Rate"]

    function populate_mouth()
        mth = Set{Int64}()
        for i in conf["Task"][1]["Mouth"]
            push!(mth, i["Port"])
        end
        sort([i for i in mth])
    end
    mouth_ports = populate_mouth()
    n_mouth = length(mouth_ports)
    n_ldspk = length(conf["Task"][1]["Noise"]["Port"])

    # preparation of workers
    session_open(1)
    wid = workers()
    
    
    # [0.9]
    # check device and soundcard availability
    digest = remotecall_fetch(Heartbeat.lux_isalive, wid[1])
    digest == false && error("device is not available!")
    digest = remotecall_fetch(SoundcardAPI.device, wid[1])
    digest[1] < 1 && error("soundcard is not available!")
    info("device and soundcard are visible")

    # read parameters from the soundcard
    m = match(Regex("[1-9]+"), digest[2][6])
    sndin_max = parse(Int64, m.match)
    m = match(Regex("[1-9]+"), digest[2][6], m.offset+length(m.match))
    sndout_max = parse(Int64, m.match)
    
    # check serial port for turntable
    info("serial ports available: $(list_serialports())")
    info("please select:")
    rs232 = readline()
    Turntable.set_origin(rs232)

    # [1.0]
    # level calibration update
    sndmix_mic = zeros(sndin_max, 1)
    sndmix_mic[conf["Reference Mic"]["Port"], 1] = 1.0
    #dutmixspk = zeros(2,2)
    #dutmixmic = eye(8)

    piston = Dict(:calibrator=>"42AA", :db=>"114.0", :dba=>"105.4", :mic=>"26XX", :preamp=>"12AA", :gain=>"0dB", :soundcard=>"UFX")
    piezo = Dict(:calibrator=>"42AB", :db=>"114.0", :dba=>"", :mic=>"26XX", :preamp=>"12AA", :gain=>"0dB", :soundcard=>"UFX")
    info("please tether 42AA to reference mic: hit any key to proceed...")
    readline()
    levelcalibrate_updateref(sndmix_mic, 60, fs, conf["Level Calibration"], hwinfo=piston)
    info("please tether 42AB to reference mic: hit any key to proceed...")
    readline()
    levelcalibrate_updateref(sndmix_mic, 60, fs, conf["Level Calibration"], hwinfo=piezo)
    info("level calibration data updated.")

    # [1.1]
    # measure room default dba
    sndmix_spk = zeros(n_ldspk+n_mouth, sndout_max)
    for i = 1:n_ldspk
        sndmix_spk[i, conf["Task"][1]["Noise"]["Port"][i]] = 1.0
    end
    for i = 1:n_mouth
        sndmix_spk[i+n_ldspk, mouth_ports[i]] = 1.0
    end

    dontcare, noisefloor = levelcalibrate_dba(zeros(10fs,n_mouth+n_ldspk), 0, sndmix_spk, sndmix_mic, fs, 35, conf["Level Calibration"])
    noisefloor > 35 && error("room is too noisy? abort")

    # [1.2]
    # mouth loudspeaker eq check
    eq = matread(conf["Equalization Filters"])
    # eq["ldspk_3_b"]
    # eq["ldpsk_3_a"]
    # eq["mouth_7_b"]
    # eq["mouth_7_a"]
    for i = 1:n_ldspk
        port = conf["Task"][1]["Noise"]["Port"][i]
        sndmix_spk = zeros(1, sndout_max)
        sndmix_spk[1, port] = 1.0

        fund0, harm0, dirac0, resp0 = impulse_response(sndmix_spk, sndmix_mic, fs = fs, atten = -10, mode = (:asio, :asio))
        fund1, harm1, dirac1, resp1 = impulse_response(sndmix_spk, sndmix_mic, fs = fs, atten = -10, mode = (:asio, :asio), 
                                                        b=eq["ldspk_$(port)_b"][:,1], a = eq["ldspk_$(port)_a"][:,1])
        # plot(fund0, fund1)
        # plot(harm0, harm1)
        # save to archive
        # conditions to proceed
    end
    for i = 1:n_mouth
        port = conf["Task"][1]["Mouth"][i]["Port"]
        sndmix_spk = zeros(1, sndout_max)
        sndmix_spk[1, port] = 1.0

        fund0, harm0, dirac0, resp0 = impulse_response(sndmix_spk, sndmix_mic, fs = fs, atten = -10, mode = (:asio, :asio))
        fund1, harm1, dirac1, resp1 = impulse_response(sndmix_spk, sndmix_mic, fs = fs, atten = -10, mode = (:asio, :asio), 
                                                        b=eq["mouth_$(port)_b"][:,1], a = eq["mouth_$(port)_a"][:,1])
        # plot(fund0, fund1)
        # plot(harm0, harm1)
        # save to archive
        # conditions to proceed
    end







    
    for i in conf["Task"]

        # [2.1]
        # set the orientation of the dut
        Turntable.rotate(rs232, i["Orientaton(deg)"], direction="CCW")

        # [2.2]
        # power cycle the dut
        digest = remotecall_fetch(Heartbeat.powreset, wid[2], 6000)
        info(digest)

        # [2.3]
        # apply eq to speech and noise files, peak normalize to avoid clipping
        mouhot = 0
        for (k,j) in enumerate(i["Mouth"])
            if !isempty(j["Source"])
                mouhot = k
                break
            end
        end
        speech, rate = wavread(i["Mouth"][mouhot]["Source"])
        assert(size(speech,2) == 1)
        assert(Int64(rate) == fs)

        mouhot_p = i["Mouth"][mouhot]["Port"]
        speech_eq = LibAudio.tf_filter(eq["mouth_$(mouhot_p)_b"][:,1], eq["mouth_$(mouhot_p)_a"][:,1], speech)
        speech_eq = speech_eq ./ maximum(speech_eq)


        if !isempty(i["Noise"]["Source"])
            noise, rate = wavread(i["Noise"]["Source"])
            assert(size(noise,2) == n_ldspk)
            assert(Int64(rate) == fs)

            noise_eq = similar(noise)
            for j = 1:n_ldspk
                port = i["Noise"]["Port"][j]
                noise_eq[:,j] = LibAudio.tf_filter(eq["ldpsk_$(port)_b"][:,1], eq["ldspk_$(port)_a"][:,1], noise[:,j])
                noise_eq[:,j] = noise_eq[:,j] ./ maximum(noise_eq[:,j])
            end
        end


        # [2.4]
        # level calibration of mouth and noise speakers
        t0 = round(Int64, 5.5fs)
        t1 = round(Int64, 6.5fs)
        speech_eq_calib = [speech_eq[t0:t1,1]; speech_eq[t0:t1,1]; speech_eq[t0:t1,1]]

        sndmix_spk = zeros(1, sndout_max)
        sndmix_spk[1, mouhot_p] = 1.0

        speech_gain, dba_measure = levelcalibrate_dba(speech_eq_calib, 3, -6, sndmix_spk, sndmix_mic, fs, i["Mouth"][mouhot]["Level(dBA)"], conf["Level Calibration"])
        speech_eq .= 10^(speech_gain/20) .* speech_eq
        
        if !isempty(i["Noise"]["Source"])
            sndmix_spk = zeros(n_ldspk, sndout_max)
            for j = 1:n_ldspk
                sndmix_spk[j, i["Noise"]["Port"][j]] = 1.0
            end
            noise_gain, dba_measure = levelcalibrate_dba(noise_eq, -6, sndmix_spk, sndmix_mic, fs, i["Noise"]["Level(dBA)"], conf["Level Calibration"])
            noise_eq .= 10^(noise_gain/20) .* noise_eq
        end

        # [2.5]
        # dut echo level calibration if there is a requirement
        if !isempty(i["Echo"]["Source"])
            echo, rate = wavread(i["Echo"]["Source"])
            assert(size(echo,2) == 2)
            assert(Int64(rate) == fs)
            
            devmix_spk = eye(2)
            echo_gain, dba_measure = levelcalibrate_dba(echo, -6, devmix_spk, sndmix_mic, fs, i["Noise"]["Level(dBA)"], conf["Level Calibration"], mode=:fileio)
            echo .= 10^(echo_gain/20) .* echo
            wavwrite(echo, "echocalibrated.wav", Fs=fs, nbits=32)
        end

        # [2.6]
        # start playback and recording using signals after the eq and calibrated gains
        if !isempty(i["Noise"]["Source"])
            sndplay = zeros(max(size(speech_eq,1), size(noise_eq,1)), n_ldspk+1)
            sndplay[1:size(noise_eq,1), 1:n_ldspk] = noise_eq[:,:]
            sndplay[1:size(speech_eq,1), n_ldspk+1] = speech_eq[:,:]
            # generate mix
        else
            sndplay = speech_eq
            # generate mix
        end
        sndone = remotecall(SoundcardAPI.playrecord, wid[1])

        if !isempty(i["Echo"]["Source"])
            dut = Device.playrecord()
        else
            dut = Device.record()
        end
        refmic = fetch(sndone)


        # [2.7]
        # push results to scoring server

        # [2.8]
        # fetch results and generate report
    end
    

    session_close()
    nothing
end





















