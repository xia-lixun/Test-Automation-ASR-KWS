% Test Automation For ASR and KWS
% Harman Suzhou
% lixun.xia2@harman.com
% 2018
%
% Module: File IO DUT
%
% Dependency: Jungle's file io scripts
%
function file_io_dut_sdb(fn)

    if strcmp(fn, 'setup')
        system('setup.bat');
        
    elseif strcmp(fn, 'record_blocking')
        system('start_record_specific_time.bat'); % Note! change the time within the .sh file
        
    elseif strcmp(fn, 'play_nonblocking')
        system('start_play.bat');
    
    elseif strcmp(fn, 'play+record_blocking')
        system('start_record_specific_time_with_playback.bat');
        
    else
        error('unsupported file IO operation!');
    end
    
    % add keep-alive mechanism?
    % transaction guarantee? if recordings pull is corrupted...
    % hot spot for reliable transfer and control here!
end