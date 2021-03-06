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
tool_ver = v"0.1.1-release+b1"





# "[info/warn/erro] int:2018-06-30 11-03-29:something happened"
function logt(level, message)
    t = replace("$(now())",[':','.'],'-')
    open("at.log","a") do fid
        write(fid, level * ":" * t * ":" * message * "\n")
    end
    message
end


function delay(x)
    for i = 1:x
        print(".")
        sleep(1)
    end
    print(".\n")
end





function auto(config)
    
    trace_report = Dict{String, String}()
    timezero = now()
    datpath = replace(string(timezero), [':','.'], '-')
    mkdir(datpath)
    info(logt("[info] 0", "\n\n== test started =="))
    

    cf = JSON.parsefile(config)
    fs = cf["Sample Rate"]
    crd = cf["Calibrator Refresh Day"]
    p_rfmic = cf["Reference Mic"]["Port"]
    p_mouth = cf["Artificial Mouth"]["Port"]
    p_ldspk = cf["Noise Loudspeaker"]["Port"]
    n_rfmic = length(p_rfmic)
    n_mouth = length(p_mouth)
    n_ldspk = length(p_ldspk)
    
    assert(VersionNumber(cf["Version"]) == tool_ver)
    info(logt("[info] 1", "reference microphone ports = $(p_rfmic)"))
    info(logt("[info] 1", "artificial mouth ports = $(p_mouth)"))
    info(logt("[info] 1", "noise loudspeaker ports = $(p_ldspk)"))
    trace_report["ref. microphone port(s)"] = "$(Int.(p_rfmic))"
    trace_report["artificial mouth port(s)"] = "$(Int.(p_mouth))"
    trace_report["noise loudspeaker port(s)"] = "$(Int.(p_ldspk))"

    
    # preparation of workers
    session_open(2)
    wid = workers()
    info(logt("[info] 1", "parallel sessions loaded"))
    

    # [0.9]
    # check device-under-test availability
    Heartbeat.dutreset_client()
    delay(cf["Start Up Music/Speech Duration(sec)"])
    while !Device.luxisalive()
        warn(logt("[warn] 0", "device is not available? reboot the dut"))
        Heartbeat.dutreset_client()
        delay(cf["Start Up Music/Speech Duration(sec)"])
    end
    info(logt("[info] 2", "dut reboot ok"))
    
    
    # check soundcard availability, then
    # read parameters from the soundcard
    digest = SoundcardAPI.device()
    digest[1] < 1 && error(logt("[erro] 0", "soundcard is not available?"))
    info(logt("[info] 2", "asio soundcard found"))

    m = match(Regex("[0-9]+"), digest[2][6])
    sndin_max = min(10, parse(Int64, m.match))
    m = match(Regex("[0-9]+"), digest[2][6], m.offset+length(m.match))
    sndout_max = min(10, parse(Int64, m.match))
    info(logt("[info] 2", "soundcard i/o max = $(sndin_max)/$(sndout_max)"))


    # check serial port for turntable
    if cf["Use Turntable"]
        rs232 = comportsel_radiobutton(Turntable.device())
        Turntable.set_origin(rs232)
    end

    # [1.0]
    # check the time validity of all reference mic calibrations
    piston = Dict(:calibrator=>"42AA", :db=>"114.0", :dba=>"105.4", :mic=>"26XX", :preamp=>"12AA", :gain=>"0dB", :soundcard=>"UFX")
    piezo = Dict(:calibrator=>"42AB", :db=>"114.0", :dba=>"", :mic=>"26XX", :preamp=>"12AA", :gain=>"0dB", :soundcard=>"UFX")
    barometer_correction = 0.0

    for p in p_rfmic
        sndmix_mic = zeros(sndin_max, 1)
        sndmix_mic[p, 1] = 1.0

        # dummy files used to trigger data update
        path = joinpath(cf["Reference Mic"]["Level Calibration"], "$p")
        mkpath(path)
        open(joinpath(path, "2018-06-25T11-22-46-356+42AA_114.0_105.4_26XX_12AA_0dB_UFX.wav"), "w") do fid
            write(fid, " \n")
        end
        open(joinpath(path, "2018-06-25T11-24-13-988+42AB_114.0__26XX_12AA_0dB_UFX.wav"), "w") do fid
            write(fid, " \n")
        end

        dont_care, millisec_elapse_piston = levelcalibrate_retrievelatest(path, hwinfo = piston)
        dont_care, millisec_elapse_piezo = levelcalibrate_retrievelatest(path, hwinfo = piezo)

        # if time check fails do level calibration update
        function refmic_calibration_check(snap)
            assert(size(snap,2) == 1)
            period_sps = diff(find(x->x==1.0, LibAudio.zero_crossing_rate(snap[:,1])))
            info(logt("[info] 11", "calibrate ref. mic samples/half-period distribution $(Set(period_sps))"))
            info(logt("[info] 11", "calibrate ref. mic frequency $(fs/median(period_sps)/2)"))
            display(plot(snap[1:192,:]))
            nothing
        end
        
        if millisec_elapse_piston >= Dates.Millisecond(Dates.Day(crd)) || millisec_elapse_piezo >= Dates.Millisecond(Dates.Day(crd))
            Tk.Messagebox(title="Action", message="Please tether 42AA to reference mic port $p, press OK to start recording [请用42AA校准标麦$p, 连接好后点击OK开始录音]")
            refmic_calibration_check(levelcalibrate_updateref(sndmix_mic, 30, fs, path, hwinfo=piston))
            # barometer_correction = barrometer_entry()

            Tk.Messagebox(title="Action", message="Please tether 42AB to reference mic port $p, press OK to start recording [请用42AB校准标麦$p, 连接好后点击OK开始录音]")
            refmic_calibration_check(levelcalibrate_updateref(sndmix_mic, 30, fs, path, hwinfo=piezo))
            
            Tk.Messagebox(title="Information", message="Reference mic calibrated, please put mic back to position, then press OK [标麦校准成功，请把标麦放回录音位置，点击OK继续]")
        end
    end


    # [1.1]
    # measure room default dba
    # note: our measurement precision lower bound is depdendent on the sensitivity of the reference mic
    sndmix_mic = zeros(sndin_max, n_rfmic)
    for i = 1:n_rfmic
        sndmix_mic[p_rfmic[i], i] = 1.0
    end


    if cf["Measure Room default SPL"]
        sndmix_spk = zeros(n_ldspk+n_mouth, sndout_max)
        for i = 1:n_ldspk
            sndmix_spk[i, p_ldspk[i]] = 1.0
        end
        for i = 1:n_mouth
            sndmix_spk[n_ldspk+i, p_mouth[i]] = 1.0
        end
        r = SoundcardAPI.playrecord(zeros(5fs, n_ldspk+n_mouth), sndmix_spk, sndmix_mic, fs)

        for i = 1:n_rfmic
            path = joinpath(cf["Reference Mic"]["Level Calibration"], "$(p_rfmic[i])")
            file_piston, millisec_elapse_piston = levelcalibrate_retrievelatest(path, hwinfo=piston)
            file_piezo, millisec_elapse_piezo = levelcalibrate_retrievelatest(path, hwinfo=piezo)
            info(logt("[info] 3", "use latest calibration files..."))
            info(logt("[info] 3", file_piston))
            info(logt("[info] 3", file_piezo))
            assert(millisec_elapse_piston <= Dates.Millisecond(Dates.Day(crd)))
            assert(millisec_elapse_piezo <= Dates.Millisecond(Dates.Day(crd)))
        
            dbspl_piston = LibAudio.spl(file_piston, r[:,i:i], r[:,i], 1, fs, calibrator_reading=parse(Float64,piston[:db])+barometer_correction)
            dbspl_piezo = LibAudio.spl(file_piezo, r[:,i:i], r[:,i], 1, fs, calibrator_reading=parse(Float64,piezo[:db]))
            if abs(dbspl_piston[1] - dbspl_piezo[1]) > 0.5
                error(logt("[erro] 1", "spl deviation > 0.5 dB, please re-calibrate! halt"))
            else
                info(logt("[info] 3", "spl deviation = $(abs(dbspl_piston[1] - dbspl_piezo[1]))"))
            end
            dba_piston = LibAudio.spl(file_piston, r[:,i:i], r[:,i], 1, fs, calibrator_reading=parse(Float64,piston[:dba]), weighting="a")
            if dba_piston[1] < 40
                info(logt("[info] 3", "room default $(dba_piston) dB(A) at mic $(p_rfmic[i])"))
                trace_report["Room default level"] = "\\textless $(dba_piston) dB(A) at mic $(p_rfmic[i])"
            else
                error(logt("[erro] 3", "room too noisy $(dba_piston) dB(A) at mic $(p_rfmic[i])? halt"))
            end
        end
    end


    # [1.2]
    # noise loudspeaker eq check
    tf = Dict{String, Matrix{Float64}}()    
    eqnl = matread(cf["Noise Loudspeaker"]["Equalization"])
    eqam = matread(cf["Artificial Mouth"]["Equalization"])


    if cf["Noise Loudspeaker EQ check"]
        for p in p_ldspk
            sndmix_spk = zeros(1, sndout_max)
            sndmix_spk[1, p] = 1.0

            f0, h0, d0, t0 = impulse_response(sndmix_spk, sndmix_mic, fs=fs, t_ess=3, t_decay=1, atten = -20, mode=(:asio,:asio))
            f1, h1, d1, t1 = impulse_response(sndmix_spk, sndmix_mic, fs=fs, t_ess=3, t_decay=1, atten = -20, mode=(:asio,:asio), 
                                            eq=[(eqload(eqnl["ldspk_$(p)_b"]), eqload(eqnl["ldspk_$(p)_a"]))])
            
            f01 = abs.(fft([f0[1:32768,:] f1[1:32768,:]],1)) / 32768
            fig = plot(((2:16384)-1)/32768*fs, 20log10.(f01[2:16384,:].+eps()), xscale = :log10, xlabel="Hz", ylabel="dB", title="Noise loudspeakers EQ check")
            png(fig, "ldspk$(p)eq")
            display(fig)
            mv("ldspk$(p)eq.png", joinpath(datpath,"ldspk$(p)eq.png"), remove_destination=true)
            # h01 = abs.(fft([h0 h1],1)) / size(h0,1)
            # display(plot( 20log10.(h01[1:div(size(h01,1),2),:].+eps()) ))

            tf["ldspk$(p)_f0"] = f0
            tf["ldspk$(p)_f1"] = f1
            tf["ldspk$(p)_h0"] = h0
            tf["ldspk$(p)_h1"] = h1
            tf["ldspk$(p)_d0"] = d0
            tf["ldspk$(p)_d1"] = d1
            tf["ldspk$(p)_t0"] = t0
            tf["ldspk$(p)_t1"] = t1
        end
        info(logt("[info] 4", "noise loudspeaker eq checked"))
    end


    if cf["Artificial Mouth EQ check"]
        for p in p_mouth
            sndmix_spk = zeros(1, sndout_max)
            sndmix_spk[1, p] = 1.0

            f0, h0, d0, t0 = impulse_response(sndmix_spk, sndmix_mic, fs = fs, t_ess = 3, t_decay = 1, atten = -20, mode = (:asio, :asio))
            f1, h1, d1, t1 = impulse_response(sndmix_spk, sndmix_mic, fs = fs, t_ess = 3, t_decay = 1, atten = -20, mode = (:asio, :asio), 
                                            eq=[(eqload(eqam["mouth_$(p)_b"]), eqload(eqam["mouth_$(p)_a"]))])

            f01 = abs.(fft([f0[1:32768,:] f1[1:32768,:]],1)) / 32768
            fig = plot(((2:16384)-1)/32768*fs, 20log10.(f01[2:16384,:].+eps()), xscale = :log10, xlabel="Hz", ylabel="dB", title="Artificial mouth EQ check")
            png(fig, "mouth$(p)eq")
            display(fig)
            mv("mouth$(p)eq.png", joinpath(datpath,"mouth$(p)eq.png"), remove_destination=true)
            # h01 = abs.(fft([h0 h1],1)) / size(h0,1)
            # display(plot( 20log10.(h01[1:div(size(h01,1),2),:].+eps()) ))
            
            tf["mouth$(p)_f0"] = f0
            tf["mouth$(p)_f1"] = f1
            tf["mouth$(p)_h0"] = h0
            tf["mouth$(p)_h1"] = h1
            tf["mouth$(p)_d0"] = d0
            tf["mouth$(p)_d1"] = d1
            tf["mouth$(p)_t0"] = t0
            tf["mouth$(p)_t1"] = t1
        end
        info(logt("[info] 4", "artificial mouth eq checked"))
    end

    
    # [1.3.1]
    # check clock drift of the device under test
    fsd = Float64(fs)

    if cf["Clock Drift Compensation"]
        info(logt("[info] 5", "measure device sample rate in precision..."))
        devmix_spk = zeros(1,2)
        devmix_spk[1,1] = 1.0
        drift = clockdrift_measure(devmix_spk, sndmix_mic)  # (fsd, freqdrift, tempdrift)
        for (ik,k) in enumerate(drift)
            info(logt("[info] 5", "time drift of dut: $(k[2])/100 sec"))
            info(logt("[info] 5", "temp drift of dut: $(k[3])/100 sec"))
            info(logt("[info] 5", "dut freqency: $(k[1]) samples per second"))
            trace_report["DUT clock drift estimate - $(ik)"] = "$(k[2])/100 seconds"
            trace_report["DUT clock temp. drift estimate - $(ik)"] = "$(k[3])/100 seconds"
            trace_report["DUT sample rate estimate - $(ik)"] = "$(k[1]) samples/second"
        end
        fsd = median([x[1] for x in drift])
    end


    # [1.3]
    # check dut transfer function from dut speakers to reference mic
    if cf["Measure Impulse Response - DUT to Ref. Mic"]
        devmix_spk = ones(1,2)
        f2, h2, d2, t2 = impulse_response(devmix_spk, sndmix_mic, fs=fs, fd=fsd, t_ess=10, t_decay=3, atten = -15, syncatten = -7, mode=(:fileio,:asio))

        f2v = abs.(fft(f2[1:32768,:],1)) / 32768
        fig = plot(((2:16384)-1)/32768*fs, 20log10.(f2v[2:16384,:].+eps()), xscale = :log10, xlabel="Hz", ylabel="dB", title="Impulse response: DUT loudspeakers to ref. mic(s)")
        png(fig, "dutrefmic")
        display(fig)
        mv("dutrefmic.png", joinpath(datpath, "dutrefmic.png"), remove_destination=true)
        # h2v = abs.(fft(h2,1)) / size(h2,1)
        # display(plot( 20log10.(h2v[1:div(size(h2v,1),2),:].+eps()) ))

        tf["dut_refmic_f"] = f2
        tf["dut_refmic_h"] = h2
        tf["dut_refmic_d"] = d2
        tf["dut_refmic_t"] = t2
        info(logt("[info] 6", "dut speaker to ref mic transfer function checked"))
    end


    # [1.4]
    # check artificial mouth to dut raw mics
    if cf["Measure Impulse Response - Mouth to DUT Raw Mic"]
        for p in p_mouth
            sndmix_spk = zeros(1, sndout_max)
            sndmix_spk[1, p] = 1.0
            devmix_mic = eye(8)

            f3, h3, d3, t3 = impulse_response(sndmix_spk, devmix_mic, fs=fs, fd=fsd, t_ess=10, t_decay=3, atten = -15, syncatten = -7, mode=(:asio,:fileio))

            # display(plot(f3[1:65536,:]))
            f3v = abs.(fft(f3[1:32768,:],1)) / 32768
            fig = plot(((2:16384)-1)/32768*fsd, 20log10.(f3v[2:16384,:].+eps()), xscale = :log10, xscale = :log10, xlabel="Hz", ylabel="dB", title="Impulse response: mouth(s) to DUT mic(s)")
            png(fig, "mouth$(p)dutrawmic")
            display(fig)
            mv("mouth$(p)dutrawmic.png", joinpath(datpath,"mouth$(p)dutrawmic.png"), remove_destination=true)
            # h3v = abs.(fft(h3,1)) / size(h3,1)
            # display(plot( 20log10.(h3v[1:div(size(h3v,1),2),:].+eps()) ))

            tf["mouth$(p)_dutrawmic_f"] = f3
            tf["mouth$(p)_dutrawmic_h"] = h3
            tf["mouth$(p)_dutrawmic_d"] = d3
            tf["mouth$(p)_dutrawmic_t"] = t3
        end
        info(logt("[info] 6", "art. mouth to dut raw mics transfer function checked"))
    end
    matwrite(joinpath(datpath,"impulse_responses.mat"), tf)

    


    score_future = Array{Future,1}(length(cf["Task"]))
    cache_speech_cal = Dict{Any,Float64}()
    cache_noise_cal = Dict{Any,Float64}()
    cache_echo_cal = Dict{Any,Float64}()
    orient_mat = zeros(Float64, 4, 4)




    for (seq,i) in enumerate(cf["Task"])

        update_orient_matrix!(orient_mat, i["Topic"], i["Orientation(deg)"])
        status = false
        dutalive = false
        while !dutalive

            info(logt("[info] 7", "start task $(i["Topic"])"))
            mkdir(joinpath(datpath, i["Topic"]))

            # set the orientation of the dut
            if cf["Use Turntable"]
                Turntable.rotate(rs232, i["Orientation(deg)"], direction="CCW")
                info(logt("[info] 7", "turntable operated"))
            end

            # power cycle the dut
            Heartbeat.dutreset_client()
            delay(cf["Start Up Music/Speech Duration(sec)"])
            while !Device.luxisalive()
                Heartbeat.dutreset_client()
                delay(cf["Start Up Music/Speech Duration(sec)"])
            end
            Device.luxinit()
            info(logt("[info] 7", "dut reboot and initialized"))


            # apply eq to speech source, peak normalize to avoid clipping
            speech, rate = wavread(i["Mouth"]["Source"])
            assert(size(speech,2) == 1)
            assert(typeof(fs)(rate) == fs)

            speech_eq = LibAudio.tf_filter(eqload(eqam["mouth_$(i["Mouth"]["Port"])_b"]), eqload(eqam["mouth_$(i["Mouth"]["Port"])_a"]), speech)   
            speech_eq = speech_eq ./ maximum(speech_eq)
            info(logt("[info] 8", "speech eq applied and peak normalized"))


            # apply eq to noise source
            if !isempty(i["Noise"]["Source"])
                noise, rate = wavread(i["Noise"]["Source"])
                n_noise = size(noise,2)
                assert(in(n_noise, [1, n_ldspk]))       # noise file is either mono-channel, or n-channel that fits the noise loudspeakers
                assert(typeof(fs)(rate) == fs)

                noise_eq = zeros(size(noise,1), n_ldspk)
                for j = 1:n_ldspk
                    noise_eq[:,j] = LibAudio.tf_filter(eqload(eqnl["ldspk_$(p_ldspk[j])_b"]), eqload(eqnl["ldspk_$(p_ldspk[j])_a"]), noise[:, min(j, n_noise)])
                    noise_eq[:,j] = noise_eq[:,j] ./ maximum(noise_eq[:,j])
                end
                info(logt("[info] 8", "noise source detected: eq applied and peak normalized"))
            else
                info(logt("[info] 8", "noise source not present, skip eq"))
            end


            # level calibration of mouth
            if in(i["Mouth"], keys(cache_speech_cal))

                speech_gain = cache_speech_cal[i["Mouth"]]
                speech_eq .= 10^(speech_gain/20) .* speech_eq
                info(logt("[info] 9", "speech_eq level calibrated before, retrieve from history... $(speech_gain)"))
            else
                t0 = round(Int64, i["Mouth"]["Calibration Start(sec)"] * fs)
                t1 = round(Int64, i["Mouth"]["Calibration Stop(sec)"] * fs)

                sndmix_spk = zeros(1, sndout_max)
                sndmix_spk[1, i["Mouth"]["Port"]] = 1.0
                sndmix_mic = zeros(sndin_max, 1)
                sndmix_mic[i["Mouth"]["Measure Port"], 1] = 1.0

                speech_gain, dba_measure = levelcalibrate_dba(speech_eq[t0:t1, 1], 3, -6, sndmix_spk, sndmix_mic, fs, 
                                                              i["Mouth"]["Level(dBA)"], 
                                                              joinpath(cf["Reference Mic"]["Level Calibration"], "$(i["Mouth"]["Measure Port"])"),
                                                              update_interval_days = crd)

                speech_eq .= 10^(speech_gain/20) .* speech_eq
                cache_speech_cal[i["Mouth"]] = speech_gain
                trace_report["Mouth level calibrated - $(seq)"] = "$(speech_gain) dB \\textrightarrow $(dba_measure) dB(A)"
                info(logt("[info] 9", "speech_eq level newly calibrated and cached... $(speech_gain) -> $(dba_measure) dB(A)"))
            end

            
            if !isempty(i["Noise"]["Source"])
                if in(i["Noise"], keys(cache_noise_cal))

                    noise_gain = cache_noise_cal[i["Noise"]]
                    noise_eq .= 10^(noise_gain/20) .* noise_eq
                    info(logt("[info] 9", "noise_eq level calibrated before, retrieve from history... $(noise_gain)"))
                else
                    t0 = round(Int64, i["Noise"]["Calibration Start(sec)"] * fs)
                    t1 = round(Int64, i["Noise"]["Calibration Stop(sec)"] * fs)

                    sndmix_spk = zeros(n_ldspk, sndout_max)
                    for j = 1:n_ldspk
                        sndmix_spk[j, p_ldspk[j]] = 1.0
                    end
                    sndmix_mic = zeros(sndin_max, 1)
                    sndmix_mic[i["Noise"]["Measure Port"], 1] = 1.0

                    noise_gain, dba_measure = levelcalibrate_dba(noise_eq[t0:t1, :], -6, sndmix_spk, sndmix_mic, fs, 
                                                                 i["Noise"]["Level(dBA)"], 
                                                                 joinpath(cf["Reference Mic"]["Level Calibration"], "$(i["Noise"]["Measure Port"])"),
                                                                 update_interval_days = crd)

                    noise_eq .= 10^(noise_gain/20) .* noise_eq
                    cache_noise_cal[i["Noise"]] = noise_gain
                    trace_report["Noise level calibrated - $(seq)"] = "$(noise_gain) dB \\textrightarrow $(dba_measure) dB(A)"
                    info(logt("[info] 9", "noise_eq level newly calibrated and cached... $(noise_gain) -> $(dba_measure) dB(A)"))
                end
            else
                info(logt("[info] 9", "skip noise level calibration"))
            end


            # ----[2.5]----
            # dut echo level calibration if there is a requirement
            if !isempty(i["Echo"]["Source"])

                echo, rate = wavread(i["Echo"]["Source"])
                assert(size(echo,2) == 2)
                assert(typeof(fs)(rate) == fs)

                if in(i["Echo"], keys(cache_echo_cal))

                    echo_gain = cache_echo_cal[i["Echo"]]
                    echo .= 10^(echo_gain/20) .* echo
                    wavwrite(echo, "echocalibrated.wav", Fs=fs, nbits=32)
                    info(logt("[info] 9", "echo_eq level calibrated before, retrieve from history... $(echo_gain)"))
                else
                    t0 = round(Int64, i["Echo"]["Calibration Start(sec)"] * fs)
                    t1 = round(Int64, i["Echo"]["Calibration Stop(sec)"] * fs)
                    devmix_spk = eye(2)
                    sndmix_mic = zeros(sndin_max, 1)
                    sndmix_mic[i["Echo"]["Measure Port"], 1] = 1.0
                    echo_gain, dba_measure = levelcalibrate_dba(echo[t0:t1, :], -6, devmix_spk, sndmix_mic, fs, 
                                                                i["Echo"]["Level(dBA)"], 
                                                                joinpath(cf["Reference Mic"]["Level Calibration"], "$(i["Echo"]["Measure Port"])"), 
                                                                mode=:fileio,
                                                                update_interval_days = crd)

                    echo .= 10^(echo_gain/20) .* echo
                    wavwrite(echo, "echocalibrated.wav", Fs=fs, nbits=32)
                    cache_echo_cal[i["Echo"]] = echo_gain
                    trace_report["Echo level calibrated - $(seq)"] = "$(echo_gain) dB \\textrightarrow $(dba_measure) dB(A)"
                    info(logt("[info] 9", "echo source detected, level newly calibrated and cached... $(echo_gain) -> $(dba_measure) dB(A)"))
                end
            else
                info(logt("[info] 9", "echo source not present, skip level calibration"))
            end


            #
            # start playback and recording using signals after the eq and calibrated gains
            sndplay = zeros(size(speech_eq,1), n_ldspk+1)
            if !isempty(i["Noise"]["Source"])
                sndplay[:, 1:n_ldspk] = noise_eq[1:min(size(speech_eq,1),size(noise_eq,1)),:]
            end
            sndplay[:, n_ldspk+1] = speech_eq[:,:]
            
            # generate mix
            sndmix_spk = zeros(n_ldspk+1, sndout_max)
            for j = 1:n_ldspk
                sndmix_spk[j, p_ldspk[j]] = 1.0
            end
            sndmix_spk[n_ldspk+1, i["Mouth"]["Port"]] = 1.0
            sndmix_mic = zeros(sndin_max, n_rfmic)
            for j = 1:n_rfmic
                sndmix_mic[p_rfmic[j], j] = 1.0
            end

            # recording time duration
            t_record = ceil(size(sndplay,1)/fs) + 3.0

            dutalive = true
            if !isempty(i["Echo"]["Source"])
                status = Device.luxplayrecord("echocalibrated.wav", t_record, fetchall=cf["Internal Signals"])
            else
                status = Device.luxrecord(t_record, fetchall=cf["Internal Signals"])
            end
            dutalive = dutalive && status
            info(logt("[info] 10", "main recording ready for go, dut status - $(dutalive)"))
            
            
            # bang!
            dat = SoundcardAPI.mixer(Float32.(sndplay), Float32.(sndmix_spk))
            pcmo = SharedArray{Float32,1}(SoundcardAPI.to_interleave(dat))
            pcmi = SharedArray{Float32,1}(zeros(Float32, size(sndmix_mic,1) * size(dat)[1]))
            
            complete = false
            expback = 2

            while !complete
                sndone = remotecall(SoundcardAPI.playrecord, wid[1], size(dat), pcmo, pcmi, size(sndmix_mic), fs)  # low-latency api
                if !isempty(i["Echo"]["Source"])            
                    status = Device.luxplayrecord(fetchall=cf["Internal Signals"])
                else
                    status = Device.luxrecord(fetchall=cf["Internal Signals"])
                end
                fetch(sndone)
                dutalive = dutalive && status
                dutalive = dutalive && Device.luxisalive()
                info(logt("[info] 10", "main recording finished, dut status - $(dutalive)"))

                if dutalive 
                    if isfile("record.wav")
                        finalout, rate = wavread("record.wav")
                        if size(finalout,1) > floor(Int64, (t_record-3.0) * rate)
                            info(logt("[info] 10", "recording seems to be ok for file length"))
                            refmic = Float64.(SoundcardAPI.mixer(Matrix{Float32}(transpose(reshape(pcmi, size(sndmix_mic,1), size(dat)[1]))), Float32.(sndmix_mic)))
                            mv("record.wav", joinpath(datpath, i["Topic"], "record_$(i["Topic"]).wav"), remove_destination=true)
                            wavwrite(refmic, joinpath(datpath, i["Topic"], "record_refmic.wav"), Fs=fs, nbits=32)
                            cf["Internal Signals"] && mv("./capture", joinpath(datpath, i["Topic"], "capture"))
                            info(logt("[info] 10", "results written to /$(datpath)/$(i["Topic"])"))
                            complete = true
                        else
                            warn(logt("[warn] 1", "possibly parecord/paplay process not found, redo the main recording"))
                            sleep(expback)
                            expback = 2expback
                            if expback >= 64
                                complete = true
                                dutalive = false
                            end
                        end
                    else
                        warn(logt("[warn] 4", "device seems alive, but no record.wav found, redo the task"))
                        dutalive = false
                        complete = true
                    end
                else    
                    warn(logt("[warn] 2", "device seems dead, redo the task"))
                    complete = true
                end
            end # while !complete
        end # while !dutalive


        # [2.7]
        # push results to scoring server, retrieve the individual report
        score_future[seq] = remotecall(KwsAsr.score_kws, wid[2], cf["Score Server IP"], joinpath(datpath, i["Topic"], "record_$(i["Topic"]).wav"), joinpath(datpath, i["Topic"]))
    end
    

    # [2.8]
    # form the final report based on individual reports
    score_mat = zeros(Int, 4, 4)
    finalpath = joinpath(datpath,"report-final.txt")
    open(finalpath,"w") do ffid
        write(ffid, "$(timezero)\n\n")
        write(ffid, "Samsung Firmware Version: $(cf["Samsung Firmware Version"])\n")
        write(ffid, "Harman Solution Version: $(cf["Harman Solution Version"])\n")
        write(ffid, "Capture Tuning Version: $(cf["Capture Tuning Version"])\n")
        write(ffid, "Speaker Tuning Version: $(cf["Speaker Tuning Version"])\n\n")
        write(ffid, "====\n")
        for seq = 1:length(cf["Task"])
            info(fetch(score_future[seq]))
            s = open(joinpath(datpath, cf["Task"][seq]["Topic"], "record_$(cf["Task"][seq]["Topic"]).txt"), "r") do fid
                readlines(fid)
            end
            for k in s
                write(ffid, k * "\n")
            end
            write(ffid, "====\n")
            update_score_matrix!(score_mat, s[1])
        end
    end
    open(joinpath(datpath,"gain-specification.json"),"w") do jid
        write(jid, JSON.json([cache_speech_cal, cache_noise_cal, cache_echo_cal]))
    end
    info(logt("[info] 11", "final report written to $(finalpath)"))
    
    
    # add pdf report
    # note the MikTeX support: try to build the /MikTeX/report_template.tex to make sure
    # third-party packages are installed
    if KwsAsr.report_pdf(score_mat, orient_mat, cf, timezero, trace_report, replace.(LibAudio.list(datpath, t=".png"),"\\", "/"))
        info(logt("[info] 12", "pdf report generated"))
    else
        warn(logt("[warn] 3", "pdf report generation failed, please use the text version"))
    end
    mv("report.pdf", joinpath(datpath, "report.pdf"), remove_destination=true)


    
    mv("at.log", joinpath(datpath, "at.log"), remove_destination=true)
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


function barrometer_entry()

    w = Tk.Toplevel("Enter Barrometer Correction For 42AA")
    f = Tk.Frame(w)
    Tk.pack(f, expand=true, fill="both")
    
    e = Tk.Entry(f)
    Tk.formlayout(e, "42AA Barometer Correction:")
    Tk.focus(e)			## put keyboard focus on widget

    Tk.Messagebox(title="Action", message="Please enter the reading!")
    val = Tk.get_value(e)
    Tk.destroy(w)

    isempty(val) && (val = "0")
    parse(Float64, val)
end



# 4x4 score matrix:
#
#             0.5m   1m   3m   5m
# Quiet
# Noise
# Echo
# Echo+Noise
function update_score_matrix!(sm::Matrix{Int}, s::String)
    
    # get the value
    # col = match(Regex(":"), s)
    # score = parse(Int, match(Regex("[0-9]+"), s, col.offset))
    score = parse(Int, basename(s))

    # gestimate the position in score matrix
    x = 0
    y = 0
    ls = lowercase(s)
    if ismatch(Regex("0.5m"),ls) || ismatch(Regex("50cm"),ls) || ismatch(Regex("500mm"),ls)
        y = 1
    elseif ismatch(Regex("1m"),ls) || ismatch(Regex("100cm"),ls) || ismatch(Regex("1000mm"),ls)
        y = 2
    elseif ismatch(Regex("3m"),ls) || ismatch(Regex("300cm"),ls) || ismatch(Regex("3000mm"),ls)
        y = 3
    elseif ismatch(Regex("5m"),ls) || ismatch(Regex("500cm"),ls) || ismatch(Regex("5000mm"),ls)
        y = 4
    end

    if ismatch(Regex("quiet"),ls)
        x = 1
    elseif ismatch(Regex("noise"),ls) && !ismatch(Regex("echo"),ls)
        x = 2
    elseif ismatch(Regex("echo"),ls) && !ismatch(Regex("noise"),ls)
        x = 3
    elseif ismatch(Regex("echo"),ls) && ismatch(Regex("noise"),ls)
        x = 4
    end

    if x > 0 && y > 0
        sm[x,y] = score
    end
    nothing
end


function update_orient_matrix!(dm::Matrix{Float64}, s::String, degree)
    
    # gestimate the position in matrix
    x = 0
    y = 0
    ls = lowercase(s)
    if ismatch(Regex("0.5m"),ls) || ismatch(Regex("50cm"),ls) || ismatch(Regex("500mm"),ls)
        y = 1
    elseif ismatch(Regex("1m"),ls) || ismatch(Regex("100cm"),ls) || ismatch(Regex("1000mm"),ls)
        y = 2
    elseif ismatch(Regex("3m"),ls) || ismatch(Regex("300cm"),ls) || ismatch(Regex("3000mm"),ls)
        y = 3
    elseif ismatch(Regex("5m"),ls) || ismatch(Regex("500cm"),ls) || ismatch(Regex("5000mm"),ls)
        y = 4
    end

    if ismatch(Regex("quiet"),ls)
        x = 1
    elseif ismatch(Regex("noise"),ls) && !ismatch(Regex("echo"),ls)
        x = 2
    elseif ismatch(Regex("echo"),ls) && !ismatch(Regex("noise"),ls)
        x = 3
    elseif ismatch(Regex("echo"),ls) && ismatch(Regex("noise"),ls)
        x = 4
    end

    if x > 0 && y > 0
        dm[x,y] = degree
    end
    nothing
end

