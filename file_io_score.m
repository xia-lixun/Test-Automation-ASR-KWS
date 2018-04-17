% Test Automation For ASR and KWS
% Harman Suzhou
% lixun.xia2@harman.com
% 2018
%
% Module: File IO DUT
%
% Client(Win) dependency: ssh.exe (or just install git for windows)
%                         winscp
%                         putty
%
% Server(Linux) dependency: WakeupScoring_Tool_2.2
%                           [optional: ffmpeg|sox|julialang]
%                           see \Test-Automation-ASR-KWS\WakeupScoring_Tool_2.2\
%
function file_io_score(wav_to_be_scored, server_ip)
    
    % make sure we are only scoring the correct file by removing historical
    ssh = 'C:\Users\LiXia\AppData\Local\Programs\Git\usr\bin\ssh.exe';
    system([ssh, ' coc@', server_ip, ' rm /home/coc/WakeupScoring_Tool_2.2/wav/*.wav'])
    system([ssh, ' coc@', server_ip, ' rm /home/coc/WakeupScoring_Tool_2.2/wav/*.txt'])
    
    % push to the server
    system(['pscp -pw Audio123 -scp ', wav_to_be_scored, ' coc@', server_ip, ':/home/coc/WakeupScoring_Tool_2.2/wav/'])
    system([ssh, ' coc@', server_ip, ' lux-score.sh'])
    
    % pull results back and render
    system(['pscp -unsafe -pw Audio123 -scp coc@', server_ip, ':/home/coc/WakeupScoring_Tool_2.2/wav/*.txt ./'])
    system('notepad report.txt')
end