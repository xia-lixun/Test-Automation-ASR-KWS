function add_calibrator_recordings(mic_port, duration, mic_type, calibrator_type)
% mic_port: port number on the FireFace soundcard
% duration: number of seconds to be recorded
% mic_type: '46AN' or '26AI'
% calibrator_type: which exactly calibrator is using, '250hz' or '1khz'

    root = 'Data/Calibration/';
    
    system(['soundcard_api.exe --record response.wav --rate 48000 --channels ', num2str(mic_port), ' --duration ', num2str(duration), ' --bits 32']);
    [x, fs] = audioread('response.wav');
    
    timestamp = datestr(datetime());
    timestamp = replace(timestamp, ' ', '_');
    timestamp = replace(timestamp, ':', '-');
    
    mkdir(fullfile(root, calibrator_type));
    folder = fullfile(root, calibrator_type, timestamp);
    mkdir(folder);
    
    if strcmp(calibrator_type, '42AA')
        file = ['cal-250hz-114dB(105.4dBA)_', mic_type, '_12AA(0dB)_UFX.wav'];
    elseif strcmp(calibrator_type, '42AB')
        file = ['cal-1khz-114dB_', mic_type, '_12AA(0dB)_UFX.wav'];
    else
        error('please specify either 42AA (250Hz) or 42AB (1khz)!');
    end
    
    path = fullfile(folder, file);
    audiowrite(path, x(:,size(x,2)), fs, 'BitsPerSample', 32);
    
    delete('response.wav');
end