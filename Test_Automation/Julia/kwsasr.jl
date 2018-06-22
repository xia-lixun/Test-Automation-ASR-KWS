module KwsAsr


    function score_kws(server_ip, wavfile, reportpath)
        try
            # make sure we are only scoring the correct file by removing historical
            ssh = "C:\\Program Files\\Git\\usr\\bin\\ssh.exe"
            run(`$(ssh) coc@$(server_ip) "rm -f /home/coc/WakeupScoring_Tool_2.4/wav/*.wav"`)
            run(`$(ssh) coc@$(server_ip) "rm -f /home/coc/WakeupScoring_Tool_2.4/wav/*.txt"`)
            
            # push to the server
            run(`pscp -pw Audio123 -scp $(wavfile) coc@$(server_ip):/home/coc/WakeupScoring_Tool_2.4/wav/`)
            run(`$(ssh) coc@$(server_ip) lux-score.sh`)
            
            # pull results back and render
            run(`pscp -unsafe -pw Audio123 -scp coc@$(server_ip):"/home/coc/WakeupScoring_Tool_2.4/wav/*.txt" $(reportpath)`)
            return true
        catch
            warn("kws/asr score failure, redo the scoring manually")
            return false
        end
    end


end