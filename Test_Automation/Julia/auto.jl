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

include("validate.jl")




function auto(task)

    # reading parameters
    fs = 48000
    levelcalpath = "D:\\Git\\TestAutomation\\LevelCalRefRecordings"
    sndmixspk = zeros(7,16)
    sndmixmic = zeros(16,1)
    sndmixmic[9,1] = 1.0
    #dutmixspk = zeros(2,2)
    #dutmixmic = eye(8)

    # preparation of workers
    session_open(2)
    wid = workers()
    
    
    # [0.9]
    # check device and soundcard availability
    digest = remotecall_fetch(Heartbeat.lux_isalive, wid[1])
    digest == false && error("device is not available!")
    digest = remotecall_fetch(SoundcardAPI.device, wid[2])
    digest[1] < 1 && error("soundcard is not available!")
    info("device and soundcard are visible")

    # read parameters from the soundcard
    m = match(Regex("[1-9]+"), digest[2][6])
    soundcard_max_in = parse(Int64, m.match)
    m = match(Regex("[1-9]+"), digest[2][6], m.offset+length(m.match))
    soundcard_max_out = parse(Int64, m.match)
    
    # check serial port for turntable
    info("serial ports available: $(list_serialports())")
    info("please select:")
    rs232 = readline()
    Turntable.set_origin(rs232)

    # [1.0]
    # level calibration update
    piston = Dict(:calibrator=>"42AA", :db=>"114.0", :dba=>"105.4", :mic=>"26XX", :preamp=>"12AA", :gain=>"0dB", :soundcard=>"UFX")
    piezo = Dict(:calibrator=>"42AB", :db=>"114.0", :dba=>"", :mic=>"26XX", :preamp=>"12AA", :gain=>"0dB", :soundcard=>"UFX")
    info("please tether 42AA to reference mic: hit any key to proceed...")
    readline()
    levelcalibrate_updateref(sndmixmic, 60, fs, levelcalpath, hwinfo=piston)
    info("please tether 42AB to reference mic: hit any key to proceed...")
    readline()
    levelcalibrate_updateref(sndmixmic, 60, fs, levelcalpath, hwinfo=piezo)
    info("level calibration data updated.")

    # [1.1]
    # measure room default dba
    dontcare, noisefloor = levelcalibrate_dba(zeros(10fs,7), 0, sndmixspk, sndmixmic, fs, 35, levelcalpath)
    noisefloor > 35 && error("room is too noisy? abort")

    # [1.2]
    # mouth loudspeaker eq check


    # [1.3]
    # parse the test specification


    
    for i in task

        # [2.1]
        # set the orientation of the dut
        degree = 11.3
        Turntable.rotate(rs232, degree, direction="CCW")

        # [2.2]
        # power cycle the dut
        digest = remotecall_fetch(Heartbeat.powreset, wid[1], 6000)
        info(digest)

        # [2.3]
        # apply eq to speech and noise files, peak normalize to avoid clipping

        # [2.4]
        # level calibration of mouth and noise speakers

        # [2.5]
        # dut echo level calibration if there is a requirement

        # [2.6]
        # start playback and recording using signals after the eq and calibrated gains

        # [2.7]
        # push results to scoring server

        # [2.8]
        # fetch results and generate report
    end
    

    session_close()
    nothing
end





















