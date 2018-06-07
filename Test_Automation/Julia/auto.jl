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
using Plots
using WAV
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
    info("artificial mouth ports: $(mouth_ports)")
    info("noise loudspeaker ports: $(Int64.(conf["Task"][1]["Noise"]["Port"]))")


    # preparation of workers
    session_open(1)
    wid = workers()
    info("parallel sessions loaded.")
    


    # [0.9]
    # check device and soundcard availability
    Heartbeat.dutreset_client()
    sleep(10)

    !Heartbeat.luxisalive() && error("device is not available?")
    digest = SoundcardAPI.device()
    digest[1] < 1 && error("soundcard is not available?")
    info("device and soundcard found.")

    # read parameters from the soundcard
    m = match(Regex("[0-9]+"), digest[2][6])
    sndin_max = min(10, parse(Int64, m.match))
    m = match(Regex("[0-9]+"), digest[2][6], m.offset+length(m.match))
    sndout_max = min(10, parse(Int64, m.match))
    info("soundcard i/o max: $(sndin_max)/$(sndout_max)")

    # check serial port for turntable
    info("serial ports available: $(Turntable.device())")
    info("please select:")
    rs232 = readline()
    Turntable.set_origin(rs232)


    # [1.0]
    # check if the time validity of calibrations
    sndmix_mic = zeros(sndin_max, 1)
    sndmix_mic[conf["Task"][1]["Reference Mic"]["Port"], 1] = 1.0

    piston = Dict(:calibrator=>"42AA", :db=>"114.0", :dba=>"105.4", :mic=>"26XX", :preamp=>"12AA", :gain=>"0dB", :soundcard=>"UFX")
    piezo = Dict(:calibrator=>"42AB", :db=>"114.0", :dba=>"", :mic=>"26XX", :preamp=>"12AA", :gain=>"0dB", :soundcard=>"UFX")

    dontcare, milli_piston = levelcalibrate_retrievelatest(conf["Level Calibration"], hwinfo = piston)
    dontcare, milli_piezo = levelcalibrate_retrievelatest(conf["Level Calibration"], hwinfo = piezo)

    # if time check fails do level calibration update
    if milli_piston >= Dates.Millisecond(Dates.Day(1)) || milli_piezo >= Dates.Millisecond(Dates.Day(1))

        info("please tether 42AA to reference mic, when ready hit any key to proceed...")
        readline()
        levelcalibrate_updateref(sndmix_mic, 60, fs, conf["Level Calibration"], hwinfo=piston)
        info("please tether 42AB to reference mic, when ready hit any key to proceed...")
        readline()
        levelcalibrate_updateref(sndmix_mic, 60, fs, conf["Level Calibration"], hwinfo=piezo)
        info("level calibration data updated, please restore mic back to position, when ready hit any key to proceed...")
        readline()
    end

    # [1.1]
    # measure room default dba
    # note: our measurement precision lower bound is depdendent on the sensitivity of the reference mic
    sndmix_spk = zeros(n_ldspk+n_mouth, sndout_max)
    for i = 1:n_ldspk
        sndmix_spk[i, conf["Task"][1]["Noise"]["Port"][i]] = 1.0
    end
    for i = 1:n_mouth
        sndmix_spk[n_ldspk+i, mouth_ports[i]] = 1.0
    end
    dontcare, noisefloor = levelcalibrate_dba(zeros(5fs,n_ldspk+n_mouth), 0, sndmix_spk, sndmix_mic, fs, 40, conf["Level Calibration"])
    noisefloor > 40 && error("room is too noisy? abort")


    
    # [1.2]
    # mouth loudspeaker eq check
    eq = matread(conf["Equalization Filters"])
    # eq["ldspk_3_b"]
    # eq["ldpsk_3_a"]
    # eq["mouth_7_b"]
    # eq["mouth_7_a"]
    eqchk = Dict{String, Matrix{Float64}}()
    for i = 1:n_ldspk
        port = conf["Task"][1]["Noise"]["Port"][i]
        sndmix_spk = zeros(1, sndout_max)
        sndmix_spk[1, port] = 1.0

        fund0, harm0, dirac0, resp0 = impulse_response(sndmix_spk, sndmix_mic, fs = fs, t_ess = 3, t_decay = 1, atten = -20, mode = (:asio, :asio))
        fund1, harm1, dirac1, resp1 = impulse_response(sndmix_spk, sndmix_mic, fs = fs, t_ess = 3, t_decay = 1, atten = -20, mode = (:asio, :asio), 
                                                        b=eq["ldspk_$(port)_b"][:,1], a = [1.0])
                                
        # plot(20log10.(abs.(fft([fund0 fund1],1)).+eps()))
        # plot(20log10.(abs.(fft([harm0 harm1],1)).+eps()))
        
        # save to archive
        eqchk["ldspk_$(port)_fund0"] = fund0
        eqchk["ldspk_$(port)_fund1"] = fund1
        eqchk["ldspk_$(port)_harm0"] = harm0
        eqchk["ldspk_$(port)_harm1"] = harm1
        eqchk["ldspk_$(port)_dirac0"] = dirac0
        eqchk["ldspk_$(port)_dirac1"] = dirac1
        eqchk["ldspk_$(port)_resp0"] = resp0
        eqchk["ldspk_$(port)_resp1"] = resp1
        
        # conditions to proceed
    end
    for i = 1:n_mouth
        port = conf["Task"][1]["Mouth"][i]["Port"]
        sndmix_spk = zeros(1, sndout_max)
        sndmix_spk[1, port] = 1.0

        fund0, harm0, dirac0, resp0 = impulse_response(sndmix_spk, sndmix_mic, fs = fs, t_ess = 3, t_decay = 1, atten = -20, mode = (:asio, :asio))
        fund1, harm1, dirac1, resp1 = impulse_response(sndmix_spk, sndmix_mic, fs = fs, t_ess = 3, t_decay = 1, atten = -20, mode = (:asio, :asio), 
                                                        b=eq["mouth_$(port)_b"][:,1], a = [1.0])

        #plot(20log10.(abs.(fft([fund0 fund1],1)).+eps()))
        #plot(20log10.(abs.(fft([harm0 harm1],1)).+eps()))
        
        # save to archive
        eqchk["mouth_$(port)_fund0"] = fund0
        eqchk["mouth_$(port)_fund1"] = fund1
        eqchk["mouth_$(port)_harm0"] = harm0
        eqchk["mouth_$(port)_harm1"] = harm1
        eqchk["mouth_$(port)_dirac0"] = dirac0
        eqchk["mouth_$(port)_dirac1"] = dirac1
        eqchk["mouth_$(port)_resp0"] = resp0
        eqchk["mouth_$(port)_resp1"] = resp1

        # conditions to proceed
    end
    matwrite("eqchk.mat", eqchk)






    
    for i in conf["Task"]

        info("start task $(i["Topic"])")

        # ----[2.0]----
        rm(i["Topic"], force=true, recursive=true)
        mkdir(i["Topic"])

        # ----[2.1]----
        # set the orientation of the dut
        Turntable.rotate(rs232, i["Orientation(deg)"], direction="CCW")
        info("turntable operated")

        # ----[2.2]----
        # power cycle the dut
        digest = Heartbeat.dutreset_client()
        info(digest)
        sleep(10)

        # ----[2.3]----
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
        speech_eq = LibAudio.tf_filter([1.0], [1.0], speech)   #eq["mouth_$(mouhot_p)_b"][:,1]
        speech_eq = speech_eq ./ maximum(speech_eq)
        info("speech eq applied and peak normalized")

        if !isempty(i["Noise"]["Source"])
            noise, rate = wavread(i["Noise"]["Source"])
            n_noise = size(noise,2)
            assert(in(n_noise, [1, n_ldspk]))       # noise file is either mono-channel, or n-channel that fits the noise loudspeakers
            assert(Int64(rate) == fs)

            noise_eq = zeros(size(noise,1), n_ldspk)
            for j = 1:n_ldspk
                port = i["Noise"]["Port"][j]
                noise_eq[:,j] = LibAudio.tf_filter([1.0], [1.0], noise[:, min(j, n_noise)])  #eq["ldpsk_$(port)_b"][:,1]
                noise_eq[:,j] = noise_eq[:,j] ./ maximum(noise_eq[:,j])
            end
            info("noise source detected: eq applied and peak normalized")
        else
            info("noise source not present, skip eq")
        end


        # ----[2.4]----
        # level calibration of mouth and noise speakers
        t0 = round(Int64, 5.5fs)
        t1 = round(Int64, 6.611fs)
        speech_eq_calib = [speech_eq[t0:t1,1]; speech_eq[t0:t1,1]; speech_eq[t0:t1,1]]

        sndmix_spk = zeros(1, sndout_max)
        sndmix_spk[1, mouhot_p] = 1.0
        speech_gain, dba_measure = levelcalibrate_dba(speech_eq_calib, 3, -6, sndmix_spk, sndmix_mic, fs, i["Mouth"][mouhot]["Level(dBA)"], conf["Level Calibration"])
        speech_eq .= 10^(speech_gain/20) .* speech_eq
        info("speech_eq level calibrated")

        if !isempty(i["Noise"]["Source"])
            t0 = round(Int64, 60fs)
            t1 = round(Int64, 120fs)
            noise_eq_calib = noise_eq[t0:t1, :]

            sndmix_spk = zeros(n_ldspk, sndout_max)
            for j = 1:n_ldspk
                sndmix_spk[j, i["Noise"]["Port"][j]] = 1.0
            end
            noise_gain, dba_measure = levelcalibrate_dba(noise_eq_calib, -6, sndmix_spk, sndmix_mic, fs, i["Noise"]["Level(dBA)"], conf["Level Calibration"])
            noise_eq .= 10^(noise_gain/20) .* noise_eq
            info("noise_eq level calibrated")
        else
            info("skip noise level calibration")
        end


        # ----[2.5]----
        # dut echo level calibration if there is a requirement
        if !isempty(i["Echo"]["Source"])
            echo, rate = wavread(i["Echo"]["Source"])
            assert(size(echo,2) == 2)
            assert(Int64(rate) == fs)

            t0 = round(Int64, 60fs)
            t1 = round(Int64, 120fs)
            echo_calib = echo[t0:t1, :]
            
            devmix_spk = eye(2)
            echo_gain, dba_measure = levelcalibrate_dba(echo_calib, -6, devmix_spk, sndmix_mic, fs, i["Echo"]["Level(dBA)"], conf["Level Calibration"], mode=:fileio)
            echo .= 10^(echo_gain/20) .* echo
            wavwrite(echo, "echocalibrated.wav", Fs=fs, nbits=32)
            info("echo source detected: level calibrated")
        else
            info("echo source not present, skip level calibration")
        end


        # ----[2.6]----
        # start playback and recording using signals after the eq and calibrated gains
        sndplay = zeros(size(speech_eq,1), n_ldspk+1)
        if !isempty(i["Noise"]["Source"])
            sndplay[:, 1:n_ldspk] = noise_eq[1:min(size(speech_eq,1),size(noise_eq,1)),:]
        end
        sndplay[:, n_ldspk+1] = speech_eq[:,:]
        
        # generate mix
        sndmix_spk = zeros(n_ldspk+1, sndout_max)
        for j = 1:n_ldspk
            sndmix_spk[j, i["Noise"]["Port"][j]] = 1.0
        end
        sndmix_spk[n_ldspk+1, mouhot_p] = 1.0

        t_record = ceil(size(sndplay,1)/fs) + 3.0
        if !isempty(i["Echo"]["Source"])
            Device.luxplayrecord("echocalibrated.wav", t_record, [])
        else
            Device.luxrecord(t_record, [])
        end
        info("main recording ready for go")    
        
        # bang!
        dat = SoundcardAPI.mixer(Float32.(sndplay), Float32.(sndmix_spk))
        pcmo = SharedArray{Float32,1}(SoundcardAPI.to_interleave(dat))
        pcmi = SharedArray{Float32,1}(zeros(Float32, size(sndmix_mic,1) * size(dat)[1]))
        sndone = remotecall(SoundcardAPI.playrecord, wid[1], size(dat), pcmo, pcmi, size(sndmix_mic), fs)  # latency is low
        if !isempty(i["Echo"]["Source"])            
            Device.luxplayrecord([])
        else
            Device.luxrecord([])
        end
        fetch(sndone)
        refmic = Float64.(SoundcardAPI.mixer(Matrix{Float32}(transpose(reshape(pcmi, size(sndmix_mic,1), size(dat)[1]))), Float32.(sndmix_mic)))
        info("main recording finished")

        # process recording
        mv("record.wav", joinpath(i["Topic"], "record.wav"), remove_destination=true)
        wavwrite(refmic, joinpath(i["Topic"], "record_refmic.wav"), Fs=fs, nbits=32)
        info("results written to /$(i["Topic"])")

        # [2.7]
        # push results to scoring server

        # [2.8]
        # fetch results and generate report
    end
    

    session_close()
    nothing
end





















