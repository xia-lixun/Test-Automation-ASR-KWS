function [g, dba_42aa] = spl_calibrate(symbol, symbol_gain_init, mix_spk, mix_mic, mic_type, fs, target_dba, barometer_correction, device)
% symbol:               single channel linear PCM to be calibrated for SPL, for example, 'Data/Symbol/pink_noise_peak_0dbfs.wav'
% symbol_gain_init:     init dB value for error and trial, for example -6
% mix_spk:              routing matrix for loudspeakers
% mix_mic:              routing matrix for mics
% mic_type:             '46AN', '26AI' or '26AM'
% fs:                   sample rate
% target_dba:           the dbA level we would like to have
% barometer_correction: for 42AA which is based on mechanic piston, barometer-correction must be applid to its standard reading.
% device:               'asio'   - source playback is from fireface, for example artificial mouths, noise loud speakers
%                       'fileio' - source playback is from DUT, for example, musics
%
% g:                    value of dB applies to symbol for tartget_dba
% dba_42aa:             measured dbA when g applied

    g = symbol_gain_init;  
    assert(size(symbol, 2) == 1);
    assert(size(mix_spk, 1) == 1);
    assert(size(mix_mic, 2) == 1);
    
    y = [zeros(0.5*fs,1); (10^(g/20))*symbol; zeros(0.5*fs,1)];
    y = [zeros(3*fs,1); y;y;y; zeros(3*fs,1)];
    
    
    if strcmp(device, 'asio')
        r = soundcard_api_playrecord(y, mix_spk, mix_mic, fs);
        
    elseif strcmp(device, 'fileio')
        playback = '_dut_playback.wav';
        audiowrite(playback, mixer(y, mix_spk), fs, 'BitsPerSample', 32);
        
        luxInit()
        system(sprintf('sdb push %s /home/owner/test.wav', playback));
        time_recording = ceil(size(y,1)/fs) + 5;
        system('sdb shell "paplay /home/owner/test.wav" &');
        r = soundcard_api_record(mix_mic, time_recording, fs);
        
    else
        error('specify device type for source playback! Abort.');
    end
    
    
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
                               r, ...
                               symbol, ...
                               3, ...
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
                               r, ...
                               symbol, ...
                               3, ...
                               0, ...
                               0, ...
                               100, ...
                               12000, ...
                               114, ...
                               48000, ...
                               16384, ...
                               16384/4, ...
                               ' ');
    if abs(dbspl_42aa - dbspl_42ab) > 0.5
        error('calibration deviation > 0.5 dB(A), please re-calibrate! Abort');
    else
        disp('calibration deviation: dB');
        disp(abs(dbspl_42aa - dbspl_42ab));
    end
    
    % 4. if cross validation ok, use 42AA for dBA measurement
    dba_42aa = sound_pressure_level(['Data/Calibration/42AA/',latest_42aa,'/cal-250hz-114dB(105.4dBA)_',mic_type,'_12AA(0dB)_UFX.wav'], ...
                               r, ...
                               symbol, ...
                               3, ...
                               0, ...
                               0, ...
                               100, ...
                               12000, ...
                               105.4, ...
                               48000, ...
                               16384, ...
                               16384/4, ...
                               'a-weight');    
    disp('dBA of g initial:');
    disp(dba_42aa);
    
    % 5. find the delta between dBA measurement and target dBA
    g = g + (target_dba - dba_42aa);
    
    % 6. apply the delta and re-measure
    y = [zeros(0.5*fs,1); (10^(g/20))*symbol; zeros(0.5*fs,1)];
    y = [zeros(3*fs,1); y;y;y; zeros(3*fs,1)];
    
    
    if strcmp(device, 'asio')
        r = soundcard_api_playrecord(y, mix_spk, mix_mic, fs);
        
    elseif strcmp(device, 'fileio')
        playback = '_dut_playback.wav';
        audiowrite(playback, mixer(y, mix_spk), fs, 'BitsPerSample', 32);
        
        luxInit()
        system(sprintf('sdb push %s /home/owner/test.wav', playback));
        time_recording = ceil(size(y,1)/fs) + 5;
        system('sdb shell "paplay /home/owner/test.wav" &');
        
        r = soundcard_api_record(mix_mic, time_recording, fs);
    else
        error('specify device type for source playback! Abort.');
    end

    dba_42aa = sound_pressure_level(['Data/Calibration/42AA/',latest_42aa,'/cal-250hz-114dB(105.4dBA)_',mic_type,'_12AA(0dB)_UFX.wav'], ...
                               r, ...
                               symbol, ...
                               3, ...
                               0, ...
                               0, ...
                               100, ...
                               12000, ...
                               105.4, ...
                               48000, ...
                               16384, ...
                               16384/4, ...
                               'a-weight');     
    
    disp('dBA of g adjusted:');
    disp(dba_42aa);
end






