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
            # run(`sdb shell "vconftool set -t bool memory/private/bixby_wakeup_service/wakeup_mute 1 -f"`)
            return true
        catch
            warn("lux init failed")
            return false
        end
    end




    #  Reference is 119 -> 0dB
    #  Info: one step equal 0.5dB
    #  Example: -4dB equals step 111
    function luxpowericvol(;twt_vol=111, wf_vol=119)
        try
            run(`sdb root on`)
            # twitter
            run(`sdb shell amixer cset name="AMP1 Left Speaker Volume" $(twt_vol)`)
            run(`sdb shell amixer cset name="AMP2 Left Speaker Volume" $(twt_vol)`)
            run(`sdb shell amixer cset name="AMP3 Left Speaker Volume" $(twt_vol)`)
            run(`sdb shell amixer cset name="AMP1 Right Speaker Volume" $(twt_vol)`)
            run(`sdb shell amixer cset name="AMP2 Right Speaker Volume" $(twt_vol)`)
            run(`sdb shell amixer cset name="AMP3 Right Speaker Volume" $(twt_vol)`)
            # woofer
            run(`sdb shell amixer cset name="AMP4 Left Speaker Volume" $(wf_vol)`)
            run(`sdb shell amixer cset name="AMP4 Right Speaker Volume" $(wf_vol)`)
        catch
            warn("lux power ic gain failed")
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




    
    function luxrecord(duration; fetchall = false)
        try
            open("device_test.sh","w") do fid
                if fetchall
                    write(fid, "MicDspClient save all 1\n")
                    write(fid, "sleep 1\n")
                end

                write(fid, "parecord --channels=2 --rate=16000 --file-format=wav /home/owner/record.wav &\n")
                fetchall && write(fid, "pactl set-pcm-dump hw_record 1\n")
                write(fid, "sleep $duration\n")
                fetchall && write(fid, "pactl set-pcm-dump hw_record 0\n")
                fetchall && write(fid, "MicDspClient save all 0\n")
                
                write(fid, "killall -15 parecord\n")
                fetchall && write(fid, "mv /opt/usr/home/owner/media/*mic_pcm_before_resample_8ch_48000.raw /opt/usr/home/owner/media/mic_pcm_before_resample_8ch_48000.raw\n")
                write(fid, "\n")
            end
            run(`sdb push device_test.sh /home/owner/`)
            run(`sdb shell "rm -f /home/owner/record.wav"`)
            run(`sdb shell "rm -f /opt/usr/home/owner/media/*.raw"`)
            run(`sdb shell "rm -f /opt/usr/home/owner/media/dump/capture/*.raw"`)
            return true
        catch
            warn("lux record init failed")
            return false
        end
    end

    function luxrecord(;fetchall = false)
        try
            run(`sdb shell ". /home/owner/device_test.sh"`)
            run(`sdb pull /home/owner/record.wav .`)
            if fetchall
                run(`sdb pull /opt/usr/home/owner/media/dump/capture ./capture`)
                run(`sdb pull /opt/usr/home/owner/media/mic_pcm_before_resample_8ch_48000.raw ./capture/mic_pcm_before_resample_8ch_48000.raw`)
            end
            return true
        catch
            warn("lux record failed")
            return false
        end
    end




    function luxplayrecord(wavfile, duration; fetchall = false)
        try
            open("device_test.sh","w") do fid
                if fetchall
                    write(fid, "MicDspClient save all 1\n")
                    write(fid, "sleep 1\n")
                end
                write(fid, "paplay /home/owner/test.wav &\n")
                write(fid, "parecord --channels=2 --rate=16000 --file-format=wav /home/owner/record.wav &\n")
                fetchall && write(fid, "pactl set-pcm-dump hw_record 1\n")
                write(fid, "sleep $duration\n")
                fetchall && write(fid, "pactl set-pcm-dump hw_record 0\n")
                fetchall && write(fid, "MicDspClient save all 0\n")
                
                write(fid, "killall -15 parecord\n")
                write(fid, "killall -15 paplay\n")
                fetchall && write(fid, "mv /opt/usr/home/owner/media/*mic_pcm_before_resample_8ch_48000.raw /opt/usr/home/owner/media/mic_pcm_before_resample_8ch_48000.raw\n")
                write(fid, "\n")
            end
            run(`sdb push device_test.sh /home/owner/`)
            run(`sdb push $wavfile /home/owner/test.wav`)
            run(`sdb shell "rm -f /home/owner/record.wav"`)
            run(`sdb shell "rm -f /opt/usr/home/owner/media/*.raw"`)
            run(`sdb shell "rm -f /opt/usr/home/owner/media/dump/capture/*.raw"`)
            return true
        catch
            warn("lux playrecord init failed")
            return false
        end
    end

    function luxplayrecord(;fetchall = false)
        try
            run(`sdb shell ". /home/owner/device_test.sh"`)
            run(`sdb pull /home/owner/record.wav .`)
            if fetchall
                run(`sdb pull /opt/usr/home/owner/media/dump/capture ./capture`)
                run(`sdb pull /opt/usr/home/owner/media/mic_pcm_before_resample_8ch_48000.raw ./capture/mic_pcm_before_resample_8ch_48000.raw`)
            end
            return true
        catch
            warn("lux playrecord failed")
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