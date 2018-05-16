function main(ini_file)

% [1.1]  measure room default SPL in dB(A), if too noisy -> halt the process
% [1.2]  mouth/loudspeaker EQ check, if EQ out-of-date, or shaped impulse response not flat enough -> halt the process
% [1.3]  parse the test specification
% [2.1]  set the orientation of the DUT
% [2.2]  power cycle the DUT
% [2.3]  apply EQ to speech and noise files, peak normalized avoid clipping
% [2.4]  mouth/loudspeaker SPL calibration (use signals after EQ)
% [2.5]  DUT echo SPL calibration
% [2.6]  start playback/recordings (use signals after EQ)
% [2.7]  push recordings to ASR/KWS scoring server
% [2.8]  fetch the scoring results and generate the report

    fs = 48000;
    soundcard_in_channels = 12;
    soundcard_out_channels = 12;
    soundcard_mic_port = 9;
    soundcard_mic_type = '26AM';
    soundcard_spk_port = [3,4,5,6];
    soundcard_mth_port = [7,8,9];
    barometer_correction = 0.0;
    serial_port = 11;

    
    room_default_dba(soundcard_in_channels, soundcard_mic_port, soundcard_mic_type, fs, barometer_correction);                                   % [1.1]
    param = check_mouth_loudspk_eq(soundcard_out_channels, soundcard_in_channels, soundcard_mth_port, soundcard_spk_port, soundcard_mic_port);   % [1.2]
    param = parse_task_specification(ini_file, param);                                                                                           % [1.3]
    
    for i = 1:length(param.task)
        
        % [2.1]
        % always put the DUT 0 degree to the mouth, 
        % the turntable will set the correct orientation!
        turntable_set_origin(serial_port);
        turntable_rotate(serial_port, param.task(i).dutorient, 'CCW');
        
        % [2.2]
        system(['julia ', fullfile(pwd(), 'Julia', 'power_reset.jl')]);
        
        % [2.3]
        
        
        
        [temp_x, rate] = audioread(param.task(i).noise);
        assert(rate == fs);
        assert(size(temp_x,2) == 4);
        
       
        %===================================
        % V. Mouth/loudspeaker SPL calibration
        %===================================

        
        %(4) noise spl calibration
        g_noise_spk = zeros(1,4);
        
        if noiselevel ~= 0
            spk_route = zeros(size(symbol,2), soundcard_spk_channels);
            spk_route(3,3) = 1.0;
            [g_noise_spk(1), dba_42aa] = spl_calibrate(symbol, -30, spk_route.', mic_route, '26AM', fs, noiselevel-6, 0.0, 'asio');
            
            spk_route = zeros(size(symbol,2), soundcard_spk_channels);
            spk_route(4,4) = 1.0;
            [g_noise_spk(2), dba_42aa] = spl_calibrate(symbol, -30, spk_route.', mic_route, '26AM', fs, noiselevel-6, 0.0, 'asio');
            
            spk_route = zeros(size(symbol,2), soundcard_spk_channels);
            spk_route(5,5) = 1.0;
            [g_noise_spk(3), dba_42aa] = spl_calibrate(symbol, -30, spk_route.', mic_route, '26AM', fs, noiselevel-6, 0.0, 'asio');
            
            spk_route = zeros(size(symbol,2), soundcard_spk_channels);
            spk_route(6,6) = 1.0;
            [g_noise_spk(4), dba_42aa] = spl_calibrate(symbol, -30, spk_route.', mic_route, '26AM', fs, noiselevel-6, 0.0, 'asio');
        end
        
        symbol(:,1) = symbol(:,1) * g_mouth;
        symbol(:,3:6) = symbol(:,3:6) .* g_noise_spk;
        
        if noiselevel ~= 0
            spk_route = zeros(size(symbol,2), soundcard_spk_channels);
            spk_route(3,3) = 1.0;
            spk_route(4,4) = 1.0;
            spk_route(5,5) = 1.0;
            spk_route(6,6) = 1.0;
            [g_noise_spk_together, dba_42aa] = spl_calibrate_multi_source(symbol, 0.0, spk_route.', mic_route, '26AM', fs, noiselevel, 0.0, 'asio');
        end
        
        %(5) DUT echo spl calibration
        g_echo = 0;
        if echolevel ~= 0
            [source, rate] = audioread('Data\Symbol\EchoCalibration.wav');
            assert(rate == fs);
            [g_echo, dba_42aa] = spl_calibrate_multi_source(source, -30, eye(2), mic_route, '26AM', fs, echolevel, 0.0, 'fileio');
        end
        if ~isempty(echo)
            [source, rate] = audioread(echo);
            assert(rate == fs);
            source = source * g_echo;
        end
        %(6) start the playback/recording
        %(7) push result to asr/kws scoring server
        %(8) fetch the scoring results and generate the report
    end    
    
end