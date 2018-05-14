module SoundcardAPI
    #
    #                        -------------------------------------
    #                        -- interface for soundcard_api.dll --
    #                        -------------------------------------
    #
    # int record(float * pcm_record, int64_t record_channels, int64_t record_frames, int64_t samplerate);
    # int play(const float * pcm_play, int64_t play_channels, int64_t play_frames, int64_t samplerate);
    # int playrecord(const float * pcm_play, int64_t play_channels, float * pcm_record, int64_t record_channels, int64_t common_frames, int64_t samplerate);


    function record(dim::Tuple{Int64, Int64}, fs::Int64)
        pcm = zeros(Float32, dim[2] * dim[1])
        ccall((:record, "soundcard_api"), Int32, (Ptr{Float32}, Int64, Int64, Int64), pcm, dim[2], dim[1], fs)
        return transpose(reshape(pcm, dim[2], dim[1]))
    end


    function play(dat::Array{Float32,2}, fs::Int64)
        pcm = to_interleave(dat)
        ccall((:play, "soundcard_api"), Int32, (Ptr{Float32}, Int64, Int64, Int64), pcm, size(dat)[2], size(dat)[1], fs)
        return nothing
    end


    function play_record(dat::Array{Float32,2}, ch::Int64, fs::Int64)
        pcmo = to_interleave(dat)
        pcmi = zeros(Float32, size(dat)[1] * ch)
        ccall((:playrecord, "soundcard_api"), Int32, (Ptr{Float32}, Int64, Ptr{Float32}, Int64, Int64, Int64), pcmo, size(dat)[2], pcmi, ch, size(dat)[1], fs)
        return transpose(reshape(pcmi, ch, size(dat)[1]))
    end


    function to_interleave(x::Array{T,2}) where T <: Number
        fr,ch = size(x)
        interleave = zeros(T, ch * fr)        
        k::Int64 = 0
        for i = 1:fr 
            interleave[k+1:k+ch] = x[i,:]
            k += ch
        end
        return interleave
    end


    function mixer(x, mix::Array{Float32,2})
        y = x * mix
        maximum(abs.(y)) >= 1.0f0 && error("mixer: sample clipping!")
        y
    end

end