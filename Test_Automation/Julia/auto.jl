#  [1.0]  soundcard ok? dut ok? turntable ok?
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

include("heartbeat.jl")
include("soundcard_api.jl")
include("turntable.jl")




function auto(configure)

    # preparation of workers
    for i = 2:nprocs()
        rmprocs(i)      
    end
    addprocs(3)
    wpid = workers()
    proc = Dict(:soundcard=>wpid[1], :device=>wpid[2], :heartbeat=>wpid[3])
    remotecall_fetch(include, proc[:heartbeat], "heartbeat.jl")
    info("heartbeat module loaded to process [$(proc[:heartbeat])]")
    remotecall_fetch(include, proc[:soundcard], "soundcard_api.jl")
    info("soundcard_api module loaded to process [$(proc[:soundcard])]")


    # check device and soundcard availability
    digest = remotecall_fetch(Heartbeat.lux_isalive, proc[:heartbeat])
    digest == false && error("device is not available!")
    digest = remotecall_fetch(SoundcardAPI.device, proc[:soundcard])
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


    ####################
    degree = 11.3
    Turntable.rotate(rs232, degree, direction="CCW")

    
    digest = remotecall_fetch(Heartbeat.powreset, proc[:heartbeat], 6000)
    info(digest)

    
    ####################

    rmprocs(workers())
    nothing
end





















