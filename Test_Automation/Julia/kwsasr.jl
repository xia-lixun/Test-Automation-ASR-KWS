module KwsAsr


    function score_kws(server_ip, wavfile, reportpath)
        try
            # make sure we are only scoring the correct file by removing historical
            ssh = "C:\\Program Files\\Git\\usr\\bin\\ssh.exe"
            run(`$(ssh) coc@$(server_ip) "rm -f /home/coc/WakeupScoring_Tool_2.4/wav/*.wav"`)
            run(`$(ssh) coc@$(server_ip) "rm -f /home/coc/WakeupScoring_Tool_2.4/wav/*.txt"`)
            
            # push to the server
            scp = "C:\\Program Files\\Git\\usr\\bin\\scp.exe"
            run(`$(scp) $(wavfile) coc@$(server_ip):/home/coc/WakeupScoring_Tool_2.4/wav/$(basename(wavfile))`)
            run(`$(ssh) coc@$(server_ip) lux-score.sh`)
            
            # pull results back and render
            run(`$(scp) coc@$(server_ip):"/home/coc/WakeupScoring_Tool_2.4/wav/*.txt" $(reportpath)`)
            return true
        catch
            warn("kws/asr score failure, redo the scoring manually")
            return false
        end
    end







    # time_alpha:  the begining time of the test 
    # conf:        configuration tuple parsed from JSON
    # sm:          score matrix
    # cal_history: level calibration history
    function report_pdf(sm::Matrix{Int}, conf, time_alpha, cal_history)
        try
            # this is the portable MikTeX installation
            # additional packages must also be installed
            tex = "C:/MikTeX/texmfs/install/miktex/bin/pdflatex.exe"
            open("report.tex", "w") do fid
                write(fid, "\\documentclass{article}\n")
                write(fid, "\\usepackage[table]{xcolor}\n")
                write(fid, "\\usepackage{booktabs}\n")
                write(fid, "\\usepackage{fancybox}\n")
                write(fid, "\\usepackage[a4paper, vmargin={20mm, 20mm}, hmargin={20mm, 20mm}]{geometry}\n")
                write(fid, "\\begin{document}\n")
                write(fid, "\\fancypage{\\setlength{\\fboxsep}{0pt}\\doublebox}{}\n")
                write(fid, "  \n")
                write(fid, "  \n")

                write(fid, "\\noindent \\\\\n")
                write(fid, "Project = $(conf["Project"])\\\\\n")
                write(fid, "Sample Rate = $(conf["Sample Rate"]) samples/sec\\\\\n")
                write(fid, "Score Srever IP = $(conf["Score Server IP"])\\\\\n")
                write(fid, "Time Start = $(string(time_alpha))\\\\\n")
                time_omega = now()
                delta = div(convert(Int64, Dates.value(time_omega - time_alpha)), 1000)  # num of seconds
                hours = div(delta, 3600)
                minutes = div(rem(delta, 3600), 60)
                seconds = rem(rem(delta, 3600), 60)
                write(fid, "Time Elapse = $(hours) hour(s), $(minutes) min(s), $(seconds) sec(s)\\\\\n")
                write(fid, "Test Tool Version = $(conf["Version"])\\\\\n") 
                write(fid, "\\vspace{10mm}\n")
                write(fid, "  \n")
                write(fid, "  \n")

                write(fid, "\\begin{table}[!ht]\n")
                write(fid, "\\centering\n")
                write(fid, "\\begin{tabular}{ *5l }    \\toprule\n")
                write(fid, "\\rowcolor{black!5} Samsung Firmware Version   & $(conf["Samsung Firmware Version"])  \\\\\n") 
                write(fid, "\\rowcolor{black!10} Harman Solution Version & $(conf["Harman Solution Version"]) \\\\\n")
                write(fid, "\\rowcolor{black!5} Capture Tuning Version &  $(conf["Capture Tuning Version"])\\\\\n")
                write(fid, "\\rowcolor{black!10} Speaker Tuning Version & $(conf["Speaker Tuning Version"])\\\\\\bottomrule\n")
                write(fid, "\\hline\n")
                write(fid, "\\end{tabular}\n")
                write(fid, "\\caption{Versions Under Test} \\label{tab:fulltest0}\n")
                write(fid, "\\end{table}\n")
                write(fid, "  \n")
                write(fid, "  \n")
                write(fid, "\\vspace{20mm}\n")
                write(fid, "  \n")

                write(fid, "%\\rowcolors{3}{green!25}{yellow!25}\n")
                write(fid, "\\begin{table}[!ht]\n")
                write(fid, "\\centering\n")
                write(fid, "\\begin{tabular}{ *5l }    \\toprule\n")
                write(fid, "& \\emph{0.5m} & \\emph{1.0m} & \\emph{3.0m} & \\emph{5.0m} \\\\ \\midrule\n")
                write(fid, "\\rowcolor{black!5} Quiet    & $(sm[1,1])  & $(sm[1,2])  & $(sm[1,3])  & $(sm[1,4])\\\\ \n")
                write(fid, "\\rowcolor{black!10} TV Noise & $(sm[2,1]) & $(sm[2,2]) & $(sm[2,3]) & $(sm[2,4])\\\\ \n")
                write(fid, "\\rowcolor{black!5} Echo & $(sm[3,1]) & $(sm[3,2]) & $(sm[3,3]) & $(sm[3,4])\\\\ \n")
                write(fid, "\\rowcolor{black!10} Echo+TV Noise & $(sm[4,1]) & $(sm[4,2]) & $(sm[4,3]) & $(sm[4,4])\\\\ \\bottomrule\n")
                write(fid, "\\hline\n")
                write(fid, "\\end{tabular}\n")
                write(fid, "\\caption{KWS Score Result} \\label{tab:fulltest1}\n")
                write(fid, "\\end{table}\n")
                write(fid, "  \n")
                write(fid, "  \n")

                write(fid, "\\vspace{20mm}\n")
                write(fid, "  \n")

                write(fid, "\\noindent \n")
                for i in cal_history
                    write(fid, "$i\\\\\n")
                end

                write(fid, "\\end{document}\n")
            end
            run(`$(tex) report.tex`)
            return true
        catch
            warn("failed to generate pdf report, please check final-report.txt for result")
            return false
        end
    end



end