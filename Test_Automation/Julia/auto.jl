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
import Tk
include("validate.jl")







function tune(taskjsonfile)

    conf = JSON.parsefile(taskjsonfile)
    assert(VersionNumber(conf["Version"]) == v"0.0.1-rc+b1")
    
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
    while !Device.luxisalive()
        warn("device is not available? reboot the dut")
        Heartbeat.dutreset_client()
        sleep(10)    
    end
    info("dut reboot ok")
    

    dgt = SoundcardAPI.device()
    dgt[1] < 1 && error("soundcard is not available?")
    info("device and soundcard found.")

    # read parameters from the soundcard
    m = match(Regex("[0-9]+"), dgt[2][6])
    sndin_max = min(10, parse(Int64, m.match))
    m = match(Regex("[0-9]+"), dgt[2][6], m.offset+length(m.match))
    sndout_max = min(10, parse(Int64, m.match))
    info("soundcard i/o max: $(sndin_max)/$(sndout_max)")


    # check if the time validity of calibrations
    sndmix_mic = zeros(sndin_max, 1)
    sndmix_mic[conf["Task"][1]["Reference Mic"]["Port"], 1] = 1.0

    piston = Dict(:calibrator=>"42AA", :db=>"114.0", :dba=>"105.4", :mic=>"26XX", :preamp=>"12AA", :gain=>"0dB", :soundcard=>"UFX")
    piezo = Dict(:calibrator=>"42AB", :db=>"114.0", :dba=>"", :mic=>"26XX", :preamp=>"12AA", :gain=>"0dB", :soundcard=>"UFX")

    dontcare, milli_piston = levelcalibrate_retrievelatest(conf["Level Calibration"], hwinfo = piston)
    dontcare, milli_piezo = levelcalibrate_retrievelatest(conf["Level Calibration"], hwinfo = piezo)

    # if time check fails do level calibration update
    if milli_piston >= Dates.Millisecond(Dates.Day(1)) || milli_piezo >= Dates.Millisecond(Dates.Day(1))

        Tk.Messagebox(title="Action", message="Please tether 42AA to reference mic, when ready press ok")
        snap = levelcalibrate_updateref(sndmix_mic, 60, fs, conf["Level Calibration"], hwinfo=piston)
        display(plot(snap))

        Tk.Messagebox(title="Action", message="Please tether 42AB to reference mic, when ready press ok")
        snap = levelcalibrate_updateref(sndmix_mic, 60, fs, conf["Level Calibration"], hwinfo=piezo)
        display(plot(snap))

        Tk.Messagebox(title="Info", message="Level calibration data updated, please restore mic back to position, then press ok")
    end

    

    # make unique measurement folder, after all sanity checks ok
    eq = matread(conf["Equalization Filters"])
    datpath = replace(string(now()), [':','.'], '-')
    mkdir(datpath)
    score_future = Array{Bool}(length(conf["Task"]))


    for (seq,i) in enumerate(conf["Task"])

        status = false
        dutalive = false
        while !dutalive

            # ----[2.0]----
            info("start task $(i["Topic"])")
            mkdir(joinpath(datpath, i["Topic"]))

            while !Device.luxisalive()
                Heartbeat.dutreset_client()
                sleep(10)
            end
            Device.luxinit()
            info("dut reboot, init and clear ok")

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
            speech_eq = LibAudio.tf_filter(eqload(eq["mouth_$(mouhot_p)_b"]), eqload(eq["mouth_$(mouhot_p)_a"]), speech)   
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
                    noise_eq[:,j] = LibAudio.tf_filter(eqload(eq["ldspk_$(port)_b"]), eqload(eq["ldspk_$(port)_a"]), noise[:, min(j, n_noise)])
                    noise_eq[:,j] = noise_eq[:,j] ./ maximum(noise_eq[:,j])
                end
                info("noise source detected: eq applied and peak normalized")
            else
                info("noise source not present, skip eq")
            end


            # ----[2.4]----
            # level calibration of mouth and noise speakers
            t0 = round(Int64, i["Mouth"][mouhot]["Calibration Start(sec)"] * fs)
            t1 = round(Int64, i["Mouth"][mouhot]["Calibration Stop(sec)"] * fs)
            speech_eq_calib = [speech_eq[t0:t1,1]; speech_eq[t0:t1,1]; speech_eq[t0:t1,1]]

            sndmix_spk = zeros(1, sndout_max)
            sndmix_spk[1, mouhot_p] = 1.0
            speech_gain, dba_measure = levelcalibrate_dba(speech_eq_calib, 3, -6, sndmix_spk, sndmix_mic, fs, i["Mouth"][mouhot]["Level(dBA)"], conf["Level Calibration"])
            speech_eq .= 10^(speech_gain/20) .* speech_eq
            info("speech_eq level calibrated")

            if !isempty(i["Noise"]["Source"])
                t0 = round(Int64, i["Noise"]["Calibration Start(sec)"] * fs)
                t1 = round(Int64, i["Noise"]["Calibration Stop(sec)"] * fs)
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

                t0 = round(Int64, i["Echo"]["Calibration Start(sec)"] * fs)
                t1 = round(Int64, i["Echo"]["Calibration Stop(sec)"] * fs)
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
            
            # recording time duration
            t_record = ceil(size(sndplay,1)/fs) + 3.0

            dutalive = true
            if !isempty(i["Echo"]["Source"])
                status = Device.luxplayrecord("echocalibrated.wav", t_record, fetchall=conf["Internal Signals"])
            else
                status = Device.luxrecord(t_record, fetchall=conf["Internal Signals"])
            end
            dutalive = dutalive && status
            info("main recording ready for go: dut status - $(status)")    
            
            # bang!
            dat = SoundcardAPI.mixer(Float32.(sndplay), Float32.(sndmix_spk))
            pcmo = SharedArray{Float32,1}(SoundcardAPI.to_interleave(dat))
            pcmi = SharedArray{Float32,1}(zeros(Float32, size(sndmix_mic,1) * size(dat)[1]))
            
            complete = false
            expback = 2

            while !complete
                sndone = remotecall(SoundcardAPI.playrecord, wid[1], size(dat), pcmo, pcmi, size(sndmix_mic), fs)  # low-latency api
                if !isempty(i["Echo"]["Source"])            
                    status = Device.luxplayrecord(fetchall=conf["Internal Signals"])
                else
                    status = Device.luxrecord(fetchall=conf["Internal Signals"])
                end
                fetch(sndone)
                dutalive = dutalive && status
                info("main recording finished: dut status - $(status)")

                finalout, rate = wavread("record.wav")
                dutalive = dutalive && Device.luxisalive()

                if dutalive && size(finalout,1) > floor(Int64, (t_record-3.0) * rate) 
                    info("recording seems to be ok for file length")
                    refmic = Float64.(SoundcardAPI.mixer(Matrix{Float32}(transpose(reshape(pcmi, size(sndmix_mic,1), size(dat)[1]))), Float32.(sndmix_mic)))
                    mv("record.wav", joinpath(datpath, i["Topic"], "record_$(i["Topic"]).wav"), remove_destination=true)
                    wavwrite(refmic, joinpath(datpath, i["Topic"], "record_refmic.wav"), Fs=fs, nbits=32)
                    conf["Internal Signals"] && mv("./capture", joinpath(datpath, i["Topic"], "capture"))
                    info("results written to /$(datpath)/$(i["Topic"])")            
                    complete = true

                elseif dutalive && size(finalout,1) < floor(Int64, (t_record-3.0) * rate)
                    warn("possibly parecord/paplay process not found, redo the main recording")
                    sleep(expback)
                    expback = 2expback
                    if expback >= 64
                        complete = true
                        dutalive = false
                    end
                else    
                    warn("device seems dead, redo the task")
                    complete = true
                end
            end # while !complete
        end # while !dutalive


        # [2.7]
        # push results to scoring server, retrieve the individual report
        score_future[seq] = KwsAsr.score_kws(conf["Score Server IP"], joinpath(datpath, i["Topic"], "record_$(i["Topic"]).wav"), joinpath(datpath, i["Topic"]))
    end
    
    # [2.8]
    # form the final report based on individual reports
    finalpath = joinpath(datpath,"report-final.txt")
    open(finalpath,"w") do ffid
        write(ffid, "$(now())\n\n")
        write(ffid, "Samsung Firmware Version: $(conf["Samsung Firmware Version"])\n")
        write(ffid, "Harman Solution Version: $(conf["Harman Solution Version"])\n")
        write(ffid, "Capture Tuning Version: $(conf["Capture Tuning Version"])\n")
        write(ffid, "Speaker Tuning Version: $(conf["Speaker Tuning Version"])\n\n")
        write(ffid, "====\n")
        for seq = 1:length(conf["Task"])
            info(score_future[seq])
            s = open(joinpath(datpath, conf["Task"][seq]["Topic"], "record_$(conf["Task"][seq]["Topic"]).txt"), "r") do fid
                readlines(fid)
            end
            for k in s
                write(ffid, k * "\n")
            end
            write(ffid, "====\n")
        end
    end
    info("final report written to $(finalpath)")

    
    session_close()
    nothing
end






# level = "[info] int"
#         "[warn] int"
#         "[erro] int"
# "[info] 3:2018-06-30 11-03-29:something happened"
function logt(level, message)
    t = replace("$(now())",[':','.'],'-')
    open("at.log","a") do fid
        write(fid, level * ":" * t * ":" * message * "\n")
    end
    message
end






function auto(config)
    
    info(logt("[info] 0", "== test started =="))

    # reading parameters
    cf = JSON.parsefile(config)
    assert(VersionNumber(cf["Version"]) == v"0.0.1-release+b1")
    fs = cf["Sample Rate"]
    p_mouth = cf["Artificial Mouth"]["Port"]
    p_ldspk = cf["Noise Loudspeaker"]["Port"]
    n_mouth = length(p_mouth)
    n_ldspk = length(p_ldspk)
    info(logt("[info] 1", "artificial mouth ports = $(p_mouth)"))
    info(logt("[info] 1", "noise loudspeaker ports = $(p_ldspk)"))


    # preparation of workers
    session_open(2)
    wid = workers()
    info("parallel sessions loaded.")
    


    # [0.9]
    # check device and soundcard availability
    Heartbeat.dutreset_client()
    sleep(10)
    while !Device.luxisalive()
        warn("device is not available? reboot the dut")
        Heartbeat.dutreset_client()
        sleep(10)    
    end
    info("dut reboot ok")
    

    dgt = SoundcardAPI.device()
    dgt[1] < 1 && error("soundcard is not available?")
    info("device and soundcard found.")

    # read parameters from the soundcard
    m = match(Regex("[0-9]+"), dgt[2][6])
    sndin_max = min(10, parse(Int64, m.match))
    m = match(Regex("[0-9]+"), dgt[2][6], m.offset+length(m.match))
    sndout_max = min(10, parse(Int64, m.match))
    info("soundcard i/o max: $(sndin_max)/$(sndout_max)")

    # check serial port for turntable
    rs232 = comportsel_radiobutton(Turntable.device())
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

        Tk.Messagebox(title="Action", message="Please tether 42AA to reference mic, when ready press ok")
        snap = levelcalibrate_updateref(sndmix_mic, 60, fs, conf["Level Calibration"], hwinfo=piston)
        display(plot(snap))

        Tk.Messagebox(title="Action", message="Please tether 42AB to reference mic, when ready press ok")
        snap = levelcalibrate_updateref(sndmix_mic, 60, fs, conf["Level Calibration"], hwinfo=piezo)
        display(plot(snap))

        Tk.Messagebox(title="Info", message="Level calibration data updated, please restore mic back to position, then press ok")
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
    tf = Dict{String, Matrix{Float64}}()

    for i = 1:n_ldspk
        port = conf["Task"][1]["Noise"]["Port"][i]
        sndmix_spk = zeros(1, sndout_max)
        sndmix_spk[1, port] = 1.0

        fu0, ha0, di0, tt0 = impulse_response(sndmix_spk, sndmix_mic, fs=fs, t_ess=3, t_decay=1, atten = -20, mode=(:asio,:asio))
        eqB = eqload(eq["ldspk_$(port)_b"])
        eqA = eqload(eq["ldspk_$(port)_a"])
        fu1, ha1, di1, tt1 = impulse_response(sndmix_spk, sndmix_mic, fs=fs, t_ess=3, t_decay=1, atten = -20, mode=(:asio,:asio), eq=[(eqB,eqA)])
        
        fu01 = abs.(fft([fu0[1:65536,:] fu1[1:65536,:]],1)) / 65536
        display(plot( 20log10.(fu01[1:32768,:].+eps()) ))
        sleep(3)
        ha01 = abs.(fft([ha0 ha1],1)) / size(ha0,1)
        display(plot( 20log10.(ha01[1:div(size(ha01,1),2),:].+eps()) ))

        # save to archive
        tf["ldspk_$(port)_fun0"] = fu0
        tf["ldspk_$(port)_fun1"] = fu1
        tf["ldspk_$(port)_har0"] = ha0
        tf["ldspk_$(port)_har1"] = ha1
        tf["ldspk_$(port)_drc0"] = di0
        tf["ldspk_$(port)_drc1"] = di1
        tf["ldspk_$(port)_tot0"] = tt0
        tf["ldspk_$(port)_tot1"] = tt1
        
        # placeholder: conditions to proceed
    end
    for i = 1:n_mouth
        port = conf["Task"][1]["Mouth"][i]["Port"]
        sndmix_spk = zeros(1, sndout_max)
        sndmix_spk[1, port] = 1.0

        fu0, ha0, di0, tt0 = impulse_response(sndmix_spk, sndmix_mic, fs = fs, t_ess = 3, t_decay = 1, atten = -20, mode = (:asio, :asio))
        eqB = eqload(eq["mouth_$(port)_b"])
        eqA = eqload(eq["mouth_$(port)_a"])
        fu1, ha1, di1, tt1 = impulse_response(sndmix_spk, sndmix_mic, fs = fs, t_ess = 3, t_decay = 1, atten = -20, mode = (:asio, :asio), eq=[(eqB,eqA)])

        fu01 = abs.(fft([fu0[1:65536,:] fu1[1:65536,:]],1)) / 65536
        display(plot( 20log10.(fu01[1:32768,:].+eps()) ))
        sleep(3)
        ha01 = abs.(fft([ha0 ha1],1)) / size(ha0,1)
        display(plot( 20log10.(ha01[1:div(size(ha01,1),2),:].+eps()) ))
        
        # save to archive
        tf["mouth_$(port)_fun0"] = fu0
        tf["mouth_$(port)_fun1"] = fu1
        tf["mouth_$(port)_har0"] = ha0
        tf["mouth_$(port)_har1"] = ha1
        tf["mouth_$(port)_drc0"] = di0
        tf["mouth_$(port)_drc1"] = di1
        tf["mouth_$(port)_tot0"] = tt0
        tf["mouth_$(port)_tot1"] = tt1

        # placeholder: conditions to proceed
    end
    

    # [1.3.1]
    # check clock drift of the device under test
    fsd = 48000.0
    if conf["Clock Drift Compensation"]
        info("measure device sample rate in precision:")
        devmix_spk = zeros(1,2)
        devmix_spk[1,1] = 1.0
        fsd, freqdrift, chrodrift = clockdrift_measure(devmix_spk, sndmix_mic, repeat=1)
        info("time drift of dut: $(freqdrift)/100 sec")
        info("chronic drift of dut: $(chrodrift)/100 sec")
        info("dut freqency: $(fsd) samples per second")
    end

    # [1.3]
    # check dut transfer function from dut speakers to reference mic
    devmix_spk = ones(1,2)
    fu2, ha2, di2, tt2 = impulse_response(devmix_spk, sndmix_mic, fs=fs, fd=fsd, t_ess=10, t_decay=3, atten = -15, syncatten = -7, mode=(:fileio,:asio))

    fu2v = abs.(fft(fu2[1:65536,:],1)) / 65536
    display(plot( 20log10.(fu2v[1:32768,:].+eps()) ))
    sleep(3)
    ha2v = abs.(fft(ha2,1)) / size(ha2,1)
    display(plot( 20log10.(ha2v[1:div(size(ha2v,1),2),:].+eps()) ))

    tf["dut_refmic_fun"] = fu2
    tf["dut_refmic_har"] = ha2
    tf["dut_refmic_drc"] = di2
    tf["dut_refmic_tot"] = tt2


    # [1.4]
    # check artificial mouth to dut raw mics
    sndmix_spk = zeros(1, sndout_max)
    sndmix_spk[1, conf["Task"][1]["Mouth"][1]["Port"]] = 1.0
    devmix_mic = eye(8)

    fu3, ha3, di3, tt3 = impulse_response(sndmix_spk, devmix_mic, fs=fs, fd=fsd, t_ess=10, t_decay=3, atten = -15, syncatten = -7, mode=(:asio,:fileio))

    # display(plot(fu3[1:65536,:]))
    fu3v = abs.(fft(fu3[1:65536,:],1)) / 65536
    display(plot( 20log10.(fu3v[1:32768,:].+eps()) ))
    sleep(3)
    ha3v = abs.(fft(ha3,1)) / size(ha3,1)
    display(plot( 20log10.(ha3v[1:div(size(ha3v,1),2),:].+eps()) ))

    tf["mouth_dutrawmic_fun"] = fu3
    tf["mouth_dutrawmic_har"] = ha3
    tf["mouth_dutrawmic_drc"] = di3
    tf["mouth_dutrawmic_tot"] = tt3






    #
    # make unique measurement folder, after all sanity checks ok
    datpath = replace(string(now()), [':','.'], '-')
    mkdir(datpath)
    matwrite(joinpath(datpath,"impulse_responses.mat"), tf)
    score_future = Array{Future}(length(conf["Task"]))
    cache_speech_cal = Dict{Any,Float64}()
    cache_noise_cal = Dict{Any,Float64}()
    cache_echo_cal = Dict{Any,Float64}()


    for (seq,i) in enumerate(conf["Task"])

        status = false
        dutalive = false
        while !dutalive

            # ----[2.0]----
            info("start task $(i["Topic"])")
            mkdir(joinpath(datpath, i["Topic"]))

            # ----[2.1]----
            # set the orientation of the dut
            Turntable.rotate(rs232, i["Orientation(deg)"], direction="CCW")
            info("turntable operated")

            # ----[2.2]----
            # power cycle the dut
            Heartbeat.dutreset_client()
            sleep(10)
            while !Device.luxisalive()
                Heartbeat.dutreset_client()
                sleep(10)
            end
            Device.luxinit()
            info("dut reboot, init and clear ok")

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
            speech_eq = LibAudio.tf_filter(eqload(eq["mouth_$(mouhot_p)_b"]), eqload(eq["mouth_$(mouhot_p)_a"]), speech)   
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
                    noise_eq[:,j] = LibAudio.tf_filter(eqload(eq["ldspk_$(port)_b"]), eqload(eq["ldspk_$(port)_a"]), noise[:, min(j, n_noise)])
                    noise_eq[:,j] = noise_eq[:,j] ./ maximum(noise_eq[:,j])
                end
                info("noise source detected: eq applied and peak normalized")
            else
                info("noise source not present, skip eq")
            end


            # ----[2.4]----
            # level calibration of mouth and noise speakers
            if in(i["Mouth"][mouhot], keys(cache_speech_cal))

                speech_gain = cache_speech_cal[i["Mouth"][mouhot]]
                speech_eq .= 10^(speech_gain/20) .* speech_eq
                info("speech_eq level calibrated before, retrieve from history: $(speech_gain)")
            else
                t0 = round(Int64, i["Mouth"][mouhot]["Calibration Start(sec)"] * fs)
                t1 = round(Int64, i["Mouth"][mouhot]["Calibration Stop(sec)"] * fs)
                speech_eq_calib = [speech_eq[t0:t1,1]; speech_eq[t0:t1,1]; speech_eq[t0:t1,1]]

                sndmix_spk = zeros(1, sndout_max)
                sndmix_spk[1, mouhot_p] = 1.0
                speech_gain, dba_measure = levelcalibrate_dba(speech_eq_calib, 3, -6, sndmix_spk, sndmix_mic, fs, i["Mouth"][mouhot]["Level(dBA)"], conf["Level Calibration"])

                speech_eq .= 10^(speech_gain/20) .* speech_eq
                cache_speech_cal[i["Mouth"][mouhot]] = speech_gain
                info("speech_eq level newly calibrated and cached: $(speech_gain)")
            end

            
            if !isempty(i["Noise"]["Source"])

                if in(i["Noise"], keys(cache_noise_cal))

                    noise_gain = cache_noise_cal[i["Noise"]]
                    noise_eq .= 10^(noise_gain/20) .* noise_eq
                    info("noise_eq level calibrated before, retrieve from history: $(noise_gain)")
                else
                    t0 = round(Int64, i["Noise"]["Calibration Start(sec)"] * fs)
                    t1 = round(Int64, i["Noise"]["Calibration Stop(sec)"] * fs)
                    noise_eq_calib = noise_eq[t0:t1, :]

                    sndmix_spk = zeros(n_ldspk, sndout_max)
                    for j = 1:n_ldspk
                        sndmix_spk[j, i["Noise"]["Port"][j]] = 1.0
                    end
                    noise_gain, dba_measure = levelcalibrate_dba(noise_eq_calib, -6, sndmix_spk, sndmix_mic, fs, i["Noise"]["Level(dBA)"], conf["Level Calibration"])

                    noise_eq .= 10^(noise_gain/20) .* noise_eq
                    cache_noise_cal[i["Noise"]] = noise_gain
                    info("noise_eq level newly calibrated and cached: $(noise_gain)")
                end
            else
                info("skip noise level calibration")
            end


            # ----[2.5]----
            # dut echo level calibration if there is a requirement
            if !isempty(i["Echo"]["Source"])

                echo, rate = wavread(i["Echo"]["Source"])
                assert(size(echo,2) == 2)
                assert(Int64(rate) == fs)

                if in(i["Echo"], keys(cache_echo_cal))

                    echo_gain = cache_echo_cal[i["Echo"]]
                    echo .= 10^(echo_gain/20) .* echo
                    wavwrite(echo, "echocalibrated.wav", Fs=fs, nbits=32)
                    info("echo_eq level calibrated before, retrieve from history: $(echo_gain)")
                else
                    t0 = round(Int64, i["Echo"]["Calibration Start(sec)"] * fs)
                    t1 = round(Int64, i["Echo"]["Calibration Stop(sec)"] * fs)
                    echo_calib = echo[t0:t1, :]
                    devmix_spk = eye(2)
                    echo_gain, dba_measure = levelcalibrate_dba(echo_calib, -6, devmix_spk, sndmix_mic, fs, i["Echo"]["Level(dBA)"], conf["Level Calibration"], mode=:fileio)

                    echo .= 10^(echo_gain/20) .* echo
                    wavwrite(echo, "echocalibrated.wav", Fs=fs, nbits=32)
                    cache_echo_cal[i["Echo"]] = echo_gain
                    info("echo source detected: level newly calibrated and cached: $(echo_gain)")
                end
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
            
            # recording time duration
            t_record = ceil(size(sndplay,1)/fs) + 3.0

            dutalive = true
            if !isempty(i["Echo"]["Source"])
                status = Device.luxplayrecord("echocalibrated.wav", t_record, fetchall=conf["Internal Signals"])
            else
                status = Device.luxrecord(t_record, fetchall=conf["Internal Signals"])
            end
            dutalive = dutalive && status
            info("main recording ready for go: dut status - $(status)")    
            
            #
            # bang!
            dat = SoundcardAPI.mixer(Float32.(sndplay), Float32.(sndmix_spk))
            pcmo = SharedArray{Float32,1}(SoundcardAPI.to_interleave(dat))
            pcmi = SharedArray{Float32,1}(zeros(Float32, size(sndmix_mic,1) * size(dat)[1]))
            
            complete = false
            expback = 2

            while !complete
                sndone = remotecall(SoundcardAPI.playrecord, wid[1], size(dat), pcmo, pcmi, size(sndmix_mic), fs)  # low-latency api
                if !isempty(i["Echo"]["Source"])            
                    status = Device.luxplayrecord(fetchall=conf["Internal Signals"])
                else
                    status = Device.luxrecord(fetchall=conf["Internal Signals"])
                end
                fetch(sndone)
                dutalive = dutalive && status
                info("main recording finished: dut status - $(status)")

                finalout, rate = wavread("record.wav")
                dutalive = dutalive && Device.luxisalive()

                if dutalive && size(finalout,1) > floor(Int64, (t_record-3.0) * rate) 
                    info("recording seems to be ok for file length")
                    refmic = Float64.(SoundcardAPI.mixer(Matrix{Float32}(transpose(reshape(pcmi, size(sndmix_mic,1), size(dat)[1]))), Float32.(sndmix_mic)))
                    mv("record.wav", joinpath(datpath, i["Topic"], "record_$(i["Topic"]).wav"), remove_destination=true)
                    wavwrite(refmic, joinpath(datpath, i["Topic"], "record_refmic.wav"), Fs=fs, nbits=32)
                    conf["Internal Signals"] && mv("./capture", joinpath(datpath, i["Topic"], "capture"))
                    info("results written to /$(datpath)/$(i["Topic"])")            
                    complete = true

                elseif dutalive && size(finalout,1) < floor(Int64, (t_record-3.0) * rate)
                    warn("possibly parecord/paplay process not found, redo the main recording")
                    sleep(expback)
                    expback = 2expback
                    if expback >= 64
                        complete = true
                        dutalive = false
                    end
                else    
                    warn("device seems dead, redo the task")
                    complete = true
                end
            end # while !complete
        end # while !dutalive


        # [2.7]
        # push results to scoring server, retrieve the individual report
        score_future[seq] = remotecall(KwsAsr.score_kws, 
                                       wid[2], 
                                       conf["Score Server IP"], 
                                       joinpath(datpath, i["Topic"], "record_$(i["Topic"]).wav"), 
                                       joinpath(datpath, i["Topic"]))
    end
    
    # [2.8]
    # form the final report based on individual reports
    finalpath = joinpath(datpath,"report-final.txt")
    open(finalpath,"w") do ffid
        write(ffid, "$(now())\n\n")
        write(ffid, "Samsung Firmware Version: $(conf["Samsung Firmware Version"])\n")
        write(ffid, "Harman Solution Version: $(conf["Harman Solution Version"])\n")
        write(ffid, "Capture Tuning Version: $(conf["Capture Tuning Version"])\n")
        write(ffid, "Speaker Tuning Version: $(conf["Speaker Tuning Version"])\n\n")
        write(ffid, "====\n")
        for seq = 1:length(conf["Task"])
            info(fetch(score_future[seq]))
            s = open(joinpath(datpath, conf["Task"][seq]["Topic"], "record_$(conf["Task"][seq]["Topic"]).txt"), "r") do fid
                readlines(fid)
            end
            for k in s
                write(ffid, k * "\n")
            end
            write(ffid, "====\n")
        end
    end
    open(joinpath(datpath,"gain-specification.json"),"w") do jid
        write(jid, JSON.json([cache_speech_cal, cache_noise_cal, cache_echo_cal]))
    end
    info("final report written to $(finalpath)")

    
    session_close()
    nothing
end






function eqload(x)
    if ndims(x) == 0
        y = [x]
    elseif ndims(x) == 1
        y = x
    elseif ndims(x) == 2
        y = x[:,1]
    else
        error("eq load dim error")
    end
end



function comportsel_radiobutton(list)
    
    w = Tk.Toplevel("Serial Port Configuration")
    f = Tk.Frame(w)
    Tk.pack(f, expand=true, fill="both")

    l  = Tk.Label(f, "Serial ports found on this machine:")
    rb = Tk.Radio(f, list)
    map(u -> Tk.pack(u, anchor="w"), (l, rb)) 

    Tk.Messagebox(title="Action", message="Please select COM for turntable!")
    tick = Tk.get_value(rb)
    Tk.destroy(w)
    tick
end












