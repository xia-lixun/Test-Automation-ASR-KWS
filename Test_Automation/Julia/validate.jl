
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


function validate_impulse_response_asio()
    fs = 48000
    f0 = 22
    f1 = 12000
    tess = 3.0
    ndecay = 1fs
    sndcard_n_out = 8
    sndcard_n_in = 8
    mic_n = 1

    ess = LibAudio.expsinesweep(f0, f1, tess, fs) .* 10^(-3/20)
    m = length(ess)
    sti = zeros(Float32, m+ndecay, 1)
    sti[1:m,:] = Float32.(ess)

    mixplay = zeros(Float32, size(sti,2), sndcard_n_out)
    mixplay[1,2] = 1.0f0
    mixrec = zeros(Float32, sndcard_n_in, mic_n)
    mixrec[2,1] = 1.0f0
    rsp = SoundcardAPI.mixer(SoundcardAPI.play_record(SoundcardAPI.mixer(sti, mixplay), sndcard_n_in, fs), mixrec)
    fund, harm, dirac = LibAudio.impresp(ess, ndecay, f0, f1, fs, Float64.(rsp))
end