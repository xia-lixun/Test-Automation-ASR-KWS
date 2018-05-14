
using WAV
include("soundcard_api.jl")
include("libaudio.jl")


function validate_soundcard_api()
    fs = 48000
    data = SoundcardAPI.record((3fs,8), fs)
    wavwrite(data, "record.wav", Fs=fs, nbits=32)

    SoundcardAPI.play(data, fs)
    loopback = SoundcardAPI.play_record(data, 8, fs)
    wavwrite(loopback, "loopback.wav", Fs=fs, nbits=32)
end


function impulse_response_asio()
    fs = 48000
    f0 = 22
    f1 = 12000
    tess = 3.0
    ndecay = 1fs

    ess = LibAudio.expsinesweep(f0, f1, tess, fs) .* 10^(-3/20)
    m = length(ess)
    sti = zeros(Float32, m+ndecay)
    sti[1:m] = convert.(Float32,ess)
    rsp = SoundcardAPI.play_record(SoundcardAPI.mixer(sti,[0.0f0 1.0f0]), 2, fs)

    info("ok here 1")
    rsp = SoundcardAPI.mixer(rsp, transpose([0.0f0 1.0f0]))
    info("ok here 2")
    fund, harm, total = LibAudio.impresp(ess, ndecay, f0, f1, fs, convert.(Float64,rsp))
end