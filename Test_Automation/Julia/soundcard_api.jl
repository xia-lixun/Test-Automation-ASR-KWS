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


    # ch = size(mixmic,1)
    function playrecord(dat::Matrix{Float32}, ch::Int64, fs::Int64)    # -> Matrix{Float32}
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

    
    function mixer(x::Matrix{T}, mix::Matrix{T}) where T <: AbstractFloat   # -> Matrix{T}
        y = x * mix
        maximum(abs.(y)) >= one(T) && error("soundcard mixer: sample clipping!")
        return y
    end





                                        ## --------------------------
                                        ##    API for ease of use
                                        ## --------------------------

    function playrecord(playing::Matrix{T}, mixspk::Matrix{T}, mixmic::Matrix{T}, fs) where T <: AbstractFloat
        recording = T.(mixer(playrecord(mixer(Float32.(playing), Float32.(mixspk)), size(mixmic,1), Int64(fs)), Float32.(mixmic)))
    end
    
    function play(playing::Matrix{T}, mixspk::Matrix{T}, fs) where T <: AbstractFloat
        play(mixer(Float32.(playing), Float32.(mixspk)), Int64(fs))
    end

    function record(samples, mixmic::Matrix{T}, fs) where T <: AbstractFloat
        recording = T.(mixer(record((Int64(samples),size(mixmic,1)), Int64(fs)), Float32.(mixmic)))
    end



                                        ## --------------------------
                                        ##  API for ultralow latency
                                        ## --------------------------

    #dat = SoundcardAPI.mixer(Float32.(playing), Float32.(mixspk))
    #pcm = SharedArray{Float32,1}(SoundcardAPI.to_interleave(dat))
    play(size_dat::Tuple{Int64,Int64}, pcm::SharedArray{Float32,1}, fs) = 
        ccall((:play, "soundcard_api"), Int32, (Ptr{Float32}, Int64, Int64, Int64), pcm, size_dat[2], size_dat[1], fs)  # remotecall
    # async tasks
    # fetch(done)
    

    # pcm = SharedArray{Float32,1}(zeros(Float32, size(mixmic,1) * samples))
    record(pcm::SharedArray{Float32,1}, size_mixmic::Tuple{Int64,Int64}, samples, fs) =
        ccall((:record, "soundcard_api"), Int32, (Ptr{Float32}, Int64, Int64, Int64), pcm, size_mixmic[1], samples, fs)  # remotecall
    # async tasks...
    # fetch(done)
    # recording = Float64.(SoundcardAPI.mixer(Matrix{Float32}(transpose(reshape(pcm, size(mixmic,1), samples))), Float32.(mixmic)))


    # dat = SoundcardAPI.mixer(Float32.(playing), Float32.(mixspk))
    # pcmo = SharedArray{Float32,1}(SoundcardAPI.to_interleave(dat))
    # pcmi = SharedArray{Float32,1}(zeros(Float32, size(mixmic,1) * size(dat)[1]))
    playrecord(size_dat::Tuple{Int64,Int64}, pcmo::SharedArray{Float32,1}, pcmi::SharedArray{Float32,1}, size_mixmic::Tuple{Int64,Int64}, fs) =
        ccall((:playrecord, "soundcard_api"), Int32, (Ptr{Float32}, Int64, Ptr{Float32}, Int64, Int64, Int64), pcmo, size_dat[2], pcmi, size_mixmic[1], size_dat[1], fs)
    # async tasks
    # fetch(done)
    # recording = Float64.(SoundcardAPI.mixer(Matrix{Float32}(transpose(reshape(pcmi, size(mixmic,1), size(dat)[1]))), Float32.(mixmic)))



# function soundcard_api()
#     fs = 48000
#     data = SoundcardAPI.record((3fs,8), fs)
#     wavwrite(data, "record.wav", Fs=fs, nbits=32)

#     SoundcardAPI.play(data, fs)

#     loopback = SoundcardAPI.playrecord(data, 8, fs)
#     wavwrite(loopback, "loopback.wav", Fs=fs, nbits=32)
# end

end