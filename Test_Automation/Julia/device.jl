using WAV


module Device

    function luxinit()
        run(`sdb root on`)
        run(`sdb shell "mount -o remount,rw /"`)
        run(`sdb shell "chmod -R 777 /opt/usr/media"`)
    end


    function luxplay(wavfile)
        run(`sdb push $wavfile /home/owner/test.wav`)
    end
    function luxplay()
        run('sdb shell "paplay /home/owner/test.wav"')
    end


    function luxrecord(duration, streams)
        open("device_test.sh","w") do fid
            write(fid, "parecord --channels=2 --rate=16000 --file-format=wav /home/owner/record.wav &\n")
            for i = 1 : max(size(streams))
                write(fid, "MicDspClient save $(streams[i]) 1\n")
            end
            write(fid, "sleep $duration\n")
            for i = 1 : max(size(streams))
                write(fid, "MicDspClient save $(streams[i]) 0\n")
            end
            write(fid, "killall -9 parecord\n")
            write(fid, "\n")
        end
        run(`sdb push device_test.sh /home/owner/`)
    end
    function luxrecord(streams)
        run(`sdb shell ". /home/owner/device_test.sh"`)
        run(`sdb pull /home/owner/record.wav .`)
        for i = 1 : max(size(streams))
            run(`sdb pull /opt/usr/media/dump/capture/$(streams[i]).raw .`)
        end
    end



    function luxplayrecord(wavfile, duration, streams)
        open("device_test.sh","w") do fid
            write(fid, "paplay /home/owner/test.wav &\n")
            write(fid, "parecord --channels=2 --rate=16000 --file-format=wav /home/owner/record.wav &\n")
            for i = 1 : max(size(streams))
                write(fid, "MicDspClient save $(streams[i]) 1\n")
            end
            write(fid, "sleep $duration\n")
            for i = 1 : max(size(streams))
                write(fid, "MicDspClient save $(streams[i]) 0\n")
            end
            write(fid, "killall -9 parecord\n")
            write(fid, "killall -9 paplay\n")
            write(fid, "\n")
        end
        run(`sdb push $wavfile /home/owner/test.wav`)
        run(`sdb push device_test.sh /home/owner/`)
    end
    function luxplayrecord(streams)
        run(`sdb shell ". /home/owner/device_test.sh"`)
        run(`sdb pull /home/owner/record.wav .`)
        for i = 1 : max(size(streams))
            run(`sdb pull /opt/usr/media/dump/capture/$(streams[i]).raw .`)
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
            wavwrite(x.', wavfile, Fs=fs, nbits=16)
        end
    end
        
end