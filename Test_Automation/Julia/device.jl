module Device
    #
    #
    #                        -------------------------------------
    #                        --  interface for dut fileio api   --
    #                        -------------------------------------
using WAV



    function luxinit()
        try
            run(`sdb root on`)
            run(`sdb shell "mount -o remount,rw /"`)
            run(`sdb shell "chmod -R 777 /opt/usr/media"`)
            return true
        catch
            warn("lux init failed")
            return false
        end
    end




    function luxplay(wavfile)
        try
            run(`sdb push $wavfile /home/owner/test.wav`)
            return true
        catch
            warn("lux play init failed")
            return false
        end
    end

    function luxplay()
        try
            run(`sdb shell "paplay /home/owner/test.wav"`)
            return true
        catch
            warn("lux play failed")
            return false
        end
    end




    # streams = ["mic_8ch_16k_s16_le"]
    function luxrecord(duration, streams)
        try
            open("device_test.sh","w") do fid
                write(fid, "parecord --channels=2 --rate=16000 --file-format=wav /home/owner/record.wav &\n")
                for i = 1 : maximum(size(streams))
                    write(fid, "MicDspClient save $(streams[i]) 1\n")
                end
                write(fid, "sleep $duration\n")
                for i = 1 : maximum(size(streams))
                    write(fid, "MicDspClient save $(streams[i]) 0\n")
                end
                write(fid, "killall -9 parecord\n")
                write(fid, "\n")
            end
            run(`sdb push device_test.sh /home/owner/`)
            return true
        catch
            warn("lux record init failed")
            return false
        end
    end

    function luxrecord(streams)
        try
            run(`sdb shell ". /home/owner/device_test.sh"`)
            run(`sdb pull /home/owner/record.wav .`)
            for i = 1 : maximum(size(streams))
                run(`sdb pull /opt/usr/media/dump/capture/$(streams[i]).raw .`)
            end
            return true
        catch
            warn("lux record failed")
            return false
        end
    end




    function luxplayrecord(wavfile, duration, streams)
        try
            open("device_test.sh","w") do fid
                write(fid, "paplay /home/owner/test.wav &\n")
                write(fid, "parecord --channels=2 --rate=16000 --file-format=wav /home/owner/record.wav &\n")
                for i = 1 : maximum(size(streams))
                    write(fid, "MicDspClient save $(streams[i]) 1\n")
                end
                write(fid, "sleep $duration\n")
                for i = 1 : maximum(size(streams))
                    write(fid, "MicDspClient save $(streams[i]) 0\n")
                end
                write(fid, "killall -9 parecord\n")
                write(fid, "killall -9 paplay\n")
                write(fid, "\n")
            end
            run(`sdb push $wavfile /home/owner/test.wav`)
            run(`sdb push device_test.sh /home/owner/`)
            return true
        catch
            warn("lux play+record init failed")
            return false
        end
    end

    function luxplayrecord(streams)
        try
            run(`sdb shell ". /home/owner/device_test.sh"`)
            run(`sdb pull /home/owner/record.wav .`)
            for i = 1 : maximum(size(streams))
                run(`sdb pull /opt/usr/media/dump/capture/$(streams[i]).raw .`)
            end
            return true
        catch
            warn("lux play+record failed")
            return false
        end
    end



    function luxclear()
        try
            run(`sdb shell "rm -f /home/owner/record.wav"`)
            return true
        catch
            warn("lux clear failed")
            return false
        end
    end
    

    function raw2wav_16bit(rawfile, channels, fs, wavfile)
        x = Array{Int16,1}()
        open(rawfile, "r") do fid
            while !eof(fid)
                push!(x, read(fid, Int16))
            end
            n = length(x)
            x = reshape(x, channels, div(n,channels))
        end
        wavwrite(x.', wavfile, Fs=fs, nbits=16)
    end


    # note: x must be dimensionally raised to matrix!
    function mixer(x::Matrix{T}, mix::Matrix{T}) where T <: AbstractFloat
        y = x * mix
        maximum(abs.(y)) >= one(T) && error("device mixer: sample clipping!")
        return y
    end

    




    function luxisalive()
        try
            readstring(`sdb root off`)
        catch
            warn("sdb process failure")
            return false
        end
        x = chomp(readstring(`sdb root on`))
        x == "Switched to 'root' account mode" && (return true)
        return false
    end


end