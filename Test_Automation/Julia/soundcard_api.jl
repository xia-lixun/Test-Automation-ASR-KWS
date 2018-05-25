module SoundcardAPI
    #
    #                        -------------------------------------
    #                        -- interface for soundcard_api.dll --
    #                        -------------------------------------
    #
    # int record(float * pcm_record, int64_t record_channels, int64_t record_frames, int64_t samplerate);
    # int play(const float * pcm_play, int64_t play_channels, int64_t play_frames, int64_t samplerate);
    # int playrecord(const float * pcm_play, int64_t play_channels, float * pcm_record, int64_t record_channels, int64_t common_frames, int64_t samplerate);
    function device()
        buffer = zeros(Int8, 8192)
        numdev = ccall((:list_devices, "soundcard_api"), Int32, (Ptr{Int8},), buffer)
        digest = ""
        for i in buffer
            digest = digest * string(Char(i))
        end
        report = split(digest,'\n')
        numdev, report[1:end-1]
    end


    function record(dim::Tuple{Int64, Int64}, fs::Int64)    # -> Matrix{Float32}
        pcm = zeros(Float32, dim[2] * dim[1])
        ccall((:record, "soundcard_api"), Int32, (Ptr{Float32}, Int64, Int64, Int64), pcm, dim[2], dim[1], fs)
        return transpose(reshape(pcm, dim[2], dim[1]))
    end


    function play(dat::Matrix{Float32}, fs::Int64)
        pcm = to_interleave(dat)
        ccall((:play, "soundcard_api"), Int32, (Ptr{Float32}, Int64, Int64, Int64), pcm, size(dat)[2], size(dat)[1], fs)
        return nothing
    end


    function play_record(dat::Matrix{Float32}, ch::Int64, fs::Int64)    # -> Matrix{Float32}
        pcmo = to_interleave(dat)
        pcmi = zeros(Float32, size(dat)[1] * ch)
        ccall((:playrecord, "soundcard_api"), Int32, (Ptr{Float32}, Int64, Ptr{Float32}, Int64, Int64, Int64), pcmo, size(dat)[2], pcmi, ch, size(dat)[1], fs)
        return transpose(reshape(pcmi, ch, size(dat)[1]))
    end


    function to_interleave(x::Matrix{T}) where T <: Number
        fr,ch = size(x)
        interleave = zeros(T, ch * fr)        
        k::Int64 = 0
        for i = 1:fr 
            interleave[k+1:k+ch] = x[i,:]
            k += ch
        end
        return interleave
    end

    
    function mixer(x::Matrix{Float32}, mix::Matrix{Float32})    # -> Matrix{Float32}
        y = x * mix
        maximum(abs.(y)) >= 1.0f0 && error("mixer: sample clipping!")
        return y
    end

end