function main(ini_file)

    config = ini2struct(ini_file);
    tasks = fieldnames(config);
    
    for eachtask = 1:length(tasks)
        
        topic = tasks{eachtask}
        room = ini_decomment(config.(tasks{eachtask}).room)
        testtype = ini_decomment(config.(tasks{eachtask}).testtype)
        dutorient = str2num(ini_decomment(config.(tasks{eachtask}).dutorientation))
        report = ini_decomment(config.(tasks{eachtask}).report);
        report = report(2:end-1)
        
        mouth50cm = ini_decomment(config.(tasks{eachtask}).mouth50cm);
        mouth50cm = mouth50cm(2:end-1)
        mouth1m = ini_decomment(config.(tasks{eachtask}).mouth1m);
        mouth1m = mouth1m(2:end-1)
        mouth3m = ini_decomment(config.(tasks{eachtask}).mouth3m);
        mouth3m = mouth3m(2:end-1)
        mouth5m = ini_decomment(config.(tasks{eachtask}).mouth5m);
        mouth5m = mouth5m(2:end-1) 
        mouthlevel = str2num(ini_decomment(config.(tasks{eachtask}).mouthlevel))
        
        noise = ini_decomment(config.(tasks{eachtask}).noise);
        noise = noise(2:end-1)
        noiselevel = str2num(ini_decomment(config.(tasks{eachtask}).noiselevel))
        
        echo = ini_decomment(config.(tasks{eachtask}).echo);
        echo = echo(2:end-1)
        echolevel = str2num(ini_decomment(config.(tasks{eachtask}).echolevel))
        
        
        
        refmic = ini_decomment(config.(tasks{eachtask}).refmic);
        refmic = refmic(2:end-1)
        micin = ini_decomment(config.(tasks{eachtask}).micin);
        micin = micin(2:end-1)
        micref = ini_decomment(config.(tasks{eachtask}).micref);
        micref = micref(2:end-1)
        micinput = ini_decomment(config.(tasks{eachtask}).micinput);
        micinput = micinput(2:end-1)
        dcblock = ini_decomment(config.(tasks{eachtask}).dcblock);
        dcblock = dcblock(2:end-1)
        aec = ini_decomment(config.(tasks{eachtask}).aec);
        aec = aec(2:end-1)
        fixedbeamformer = ini_decomment(config.(tasks{eachtask}).fixedbeamformer);
        fixedbeamformer = fixedbeamformer(2:end-1)
        globaleq = ini_decomment(config.(tasks{eachtask}).globaleq);
        globaleq = globaleq(2:end-1)
        spectralbeamsteering = ini_decomment(config.(tasks{eachtask}).spectralbeamsteering);
        spectralbeamsteering = spectralbeamsteering(2:end-1)
        adaptivebeamformer = ini_decomment(config.(tasks{eachtask}).adaptivebeamformer);
        adaptivebeamformer = adaptivebeamformer(2:end-1)
        noisereduction = ini_decomment(config.(tasks{eachtask}).noisereduction);
        noisereduction = noisereduction(2:end-1)
        asrleveler = ini_decomment(config.(tasks{eachtask}).asrleveler);
        asrleveler = asrleveler(2:end-1)
        asrlimiter = ini_decomment(config.(tasks{eachtask}).asrlimiter);
        asrlimiter = asrlimiter(2:end-1)
        callleveler = ini_decomment(config.(tasks{eachtask}).callleveler);
        callleveler = callleveler(2:end-1)
        expander = ini_decomment(config.(tasks{eachtask}).expander);
        expander = expander(2:end-1)
        calleq = ini_decomment(config.(tasks{eachtask}).calleq);
        calleq = calleq(2:end-1)
        calllimiter = ini_decomment(config.(tasks{eachtask}).calllimiter);
        calllimiter = calllimiter(2:end-1)
        micout = ini_decomment(config.(tasks{eachtask}).micout);
        micout = micout(2:end-1)
        
        
        fs = 48000;
        soundcard_mic_channels = 12;
        soundcard_spk_channels = 12;
        barometer_correction = 0.0;
        serial_port = 11;
        
        %======================================
        % I. Measure room default SPL in dB(A)
        %======================================
        mic_route = zeros(1,soundcard_mic_channels);
        mic_route(1,9) = 1.0;
        room_noise_floor = soundcard_api_record(mic_route, 30, fs);
        
        % 1. load the latest calibrator recordings: 42AA and 42AB
        [latest_42aa, dt_42aa] = latest_timestamp('Data/Calibration/42AA');
        [latest_42ab, dt_42ab] = latest_timestamp('Data/Calibration/42AB');
        disp('Use latest calibration files:')
        disp(latest_42aa);
        disp(latest_42ab);
        
        % 2. time assurance for valid calibration of reference mic
        dt_now = datetime();
        if hours(dt_now - dt_42aa) > 24
            error('Over 24 hours passed since last calibration of the reference mic, please re-claibrate with 42AA! Abort.')
        elseif hours(dt_now - dt_42ab) > 24
            error('Over 24 hours passed since last calibration of the reference mic, please re-claibrate with 42AB! Abort.')
        else
            disp('Both latest reference mic calibrations are done within 24 hours, ok to proceed...')
        end
        
        
        % 3. spl (no weighting) shall give similar values for cross validation:
        %    termiate the measurement if difference > 0.1
        dbspl_42aa = sound_pressure_level(['Data/Calibration/42AA/',latest_42aa,'/cal-250hz-114dB(105.4dBA)_',mic_type,'_12AA(0dB)_UFX.wav'], ...
            room_noise_floor, ...
            room_noise_floor, ...
            1, ...
            0, ...
            0, ...
            100, ...
            12000, ...
            114+barometer_correction, ...
            48000, ...
            16384, ...
            16384/4, ...
            ' ');
        dbspl_42ab = sound_pressure_level(['Data/Calibration/42AB/',latest_42ab,'/cal-1khz-114dB_',mic_type,'_12AA(0dB)_UFX.wav'], ...
            room_noise_floor, ...
            room_noise_floor, ...
            1, ...
            0, ...
            0, ...
            100, ...
            12000, ...
            114, ...
            48000, ...
            16384, ...
            16384/4, ...
            ' ');
        if abs(dbspl_42aa - dbspl_42ab) > 0.1
            error('calibration deviation > 0.1, please re-calibrate! Abort');
        else
            disp('calibration deviation: dB');
            disp(abs(dbspl_42aa - dbspl_42ab));
        end
        
        % 4. if cross validation ok, use 42AA for dBA measurement
        dba_42aa = sound_pressure_level(['Data/Calibration/42AA/',latest_42aa,'/cal-250hz-114dB(105.4dBA)_',mic_type,'_12AA(0dB)_UFX.wav'], ...
            room_noise_floor, ...
            room_noise_floor, ...
            1, ...
            0, ...
            0, ...
            100, ...
            12000, ...
            105.4, ...
            48000, ...
            16384, ...
            16384/4, ...
            'a-weight');
        disp('dBA of room noise floor:');
        disp(dba_42aa);
        if dba_42aa > 30
            error('room is too noisy for automatic measurement? abort.');
        end
        
        %===================================
        % II. Set the orientation of the DUT
        %===================================
        % always put the DUT 0 degree to the mouth, 
        % the turntable will set the correct orientation!
        turntable_set_origin(serial_port);
        turntable_rotate(serial_port, dutorient, 'CCW');
        
        
        %===================================
        % III. Power cycle the DUT
        %===================================
        pwrst_script = fullfile(pwd(), 'Julia', 'power_reset.jl');
        system(['julia ', pwrst_script]);
        
        
        %===================================
        % IV. Speech/Noise SPL calibration
        %===================================
        [symbol, rate] = audioread('Data/Symbol/LevelCalibration.wav');
        assert(rate == fs);
        spk_route = zeros(size(symbol,2), soundcard_spk_channels);
        if mouth50cm ~= '""'
            spk_route(1,7) = 1.0;
        end
        if mouth1m ~= '""'
            spk_route(1,8) = 1.0;
        end
        if mouth3m ~= '""'
            spk_route(1,9) = 1.0;
        end
        if mouth5m ~= '""'
            spk_route(1,9) = 1.0;
        end
        [g_mouth, dba_42aa] = spl_calibrate(symbol, -30, spk_route.', mic_route, '26AM', fs, mouthlevel, 0.0, 'asio');
        
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
        
        %(5) echo spl calibration
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