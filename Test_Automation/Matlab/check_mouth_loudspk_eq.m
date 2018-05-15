function param = check_mouth_loudspk_eq(soundcard_out_channels, ...
                                        soundcard_in_channels, ...
                                        soundcard_mth_port, ...
                                        soundcard_spk_port, ...
                                        soundcard_mic_port)

        % load the latest eq for mouths and loudspeakers
        [latest_m05, dt_m05] = latest_timestamp('Data/Equalization/Mouth-05');
        [latest_m10, dt_m10] = latest_timestamp('Data/Equalization/Mouth-10');
        [latest_m35, dt_m35] = latest_timestamp('Data/Equalization/Mouth-35');

        [latest_s1, dt_s1] = latest_timestamp('Data/Equalization/LoudSPK-1');
        [latest_s2, dt_s2] = latest_timestamp('Data/Equalization/LoudSPK-2');
        [latest_s3, dt_s3] = latest_timestamp('Data/Equalization/LoudSPK-3');
        [latest_s4, dt_s4] = latest_timestamp('Data/Equalization/LoudSPK-4');

        disp('Use latest calibration files:')
        disp(latest_m05);
        disp(latest_m10);
        disp(latest_m35);
        disp(latest_s1);
        disp(latest_s2);
        disp(latest_s3);
        disp(latest_s4);
        
        % time assurance for valid calibration of reference mic
        dt_now = datetime();
        elapse = zeros(7,1);
        elapse(1) = hours(dt_now - dt_m05);
        elapse(2) = hours(dt_now - dt_m10);
        elapse(3) = hours(dt_now - dt_m35);
        elapse(4) = hours(dt_now - dt_s1);
        elapse(5) = hours(dt_now - dt_s2);
        elapse(6) = hours(dt_now - dt_s3);
        elapse(7) = hours(dt_now - dt_s4);
        if elapse > 24*7
            error('Over one week passed since last eq calibration, please update the EQ! Abort.')
        else
            disp('All EQ calibrations are done within a week, ok to proceed...')
        end
        
        % load the latest eq filters
        param.eq.mouth05 = load('Data/Equalization/Mouth-05/', latest_m05 ,'/fir_min_phase.mat');
        param.eq.mouth10 = load('Data/Equalization/Mouth-10/', latest_m10 ,'/fir_min_phase.mat');
        param.eq.mouth35 = load('Data/Equalization/Mouth-35/', latest_m35 ,'/fir_min_phase.mat');

        param.eq.loudspk1 = load('Data/Equalization/LoudSPK-1/', latest_s1 ,'/fir_min_phase.mat');
        param.eq.loudspk2 = load('Data/Equalization/LoudSPK-2/', latest_s2 ,'/fir_min_phase.mat');
        param.eq.loudspk3 = load('Data/Equalization/LoudSPK-3/', latest_s3 ,'/fir_min_phase.mat');
        param.eq.loudspk4 = load('Data/Equalization/LoudSPK-4/', latest_s4 ,'/fir_min_phase.mat');
        
        % measure impulse response with eq in the loop
        mix_mic = zeros(soundcard_in_channels, 1); 
        mix_mic(soundcard_mic_port, 1) = 1.0;
        
        mix_spk = zeros(1, soundcard_out_channels); 
        mix_spk(1, soundcard_spk_port(1)) = 1.0;
        [fundspk1, harmspk1, respspk1, diracspk1] = impulse_response_exponential_sine_sweep(mix_spk, mix_mic, 100, 22000, 10, 5, 'asio', param.eq.loudspk1.eqFilter, 1, -30); % fireface -> fireface
        mix_spk = zeros(1, soundcard_out_channels); 
        mix_spk(1, soundcard_spk_port(2)) = 1.0;
        [fundspk2, harmspk2, respspk2, diracspk2] = impulse_response_exponential_sine_sweep(mix_spk, mix_mic, 100, 22000, 10, 5, 'asio', param.eq.loudspk2.eqFilter, 1, -30);
        mix_spk = zeros(1, soundcard_out_channels); 
        mix_spk(1, soundcard_spk_port(3)) = 1.0;
        [fundspk3, harmspk3, respspk3, diracspk3] = impulse_response_exponential_sine_sweep(mix_spk, mix_mic, 100, 22000, 10, 5, 'asio', param.eq.loudspk3.eqFilter, 1, -30);
        mix_spk = zeros(1, soundcard_out_channels); 
        mix_spk(1, soundcard_spk_port(4)) = 1.0;
        [fundspk4, harmspk4, respspk4, diracspk4] = impulse_response_exponential_sine_sweep(mix_spk, mix_mic, 100, 22000, 10, 5, 'asio', param.eq.loudspk4.eqFilter, 1, -30);
        
        mix_mth = zeros(1, soundcard_out_channels); 
        mix_mth(1, soundcard_mth_port(1)) = 1.0;
        [fundmou05, harmmou05, respmou05, diracmou05] = impulse_response_exponential_sine_sweep(mix_mth, mix_mic, 100, 22000, 10, 5, 'asio', param.eq.mouth05.eqFilter, 1, -30);
        mix_mth = zeros(1, soundcard_out_channels); 
        mix_mth(1, soundcard_mth_port(2)) = 1.0;
        [fundmou10, harmmou10, respmou10, diracmou10] = impulse_response_exponential_sine_sweep(mix_mth, mix_mic, 100, 22000, 10, 5, 'asio', param.eq.mouth10.eqFilter, 1, -30);
        mix_mth = zeros(1, soundcard_out_channels); 
        mix_mth(1, soundcard_mth_port(3)) = 1.0;
        [fundmou35, harmmou35, respmou35, diracmou35] = impulse_response_exponential_sine_sweep(mix_mth, mix_mic, 100, 22000, 10, 5, 'asio', param.eq.mouth35.eqFilter, 1, -30);

        figure; hold on; plot(diracspk1, 'b'); plot(respspk1, 'r');  grid on;
        figure; hold on; plot(diracspk2, 'b'); plot(respspk2, 'r');  grid on;
        figure; hold on; plot(diracspk3, 'b'); plot(respspk3, 'r');  grid on;
        figure; hold on; plot(diracspk4, 'b'); plot(respspk4, 'r');  grid on;

        figure; hold on; plot(diracmou05, 'b'); plot(respmou05, 'r');  grid on;
        figure; hold on; plot(diracmou10, 'b'); plot(respmou10, 'r');  grid on;
        figure; hold on; plot(diracmou35, 'b'); plot(respmou35, 'r');  grid on;

        freqz(fundspk1,1);
        freqz(fundspk2,1);
        freqz(fundspk3,1);
        freqz(fundspk4,1);
        
        freqz(fundmou05,1);
        freqz(fundmou10,1);
        freqz(fundmou35,1);
        
        freqz(harmspk1,1);
        freqz(harmspk2,1);
        freqz(harmspk3,1);
        freqz(harmspk4,1);
        
        freqz(harmmou05,1);
        freqz(harmmou10,1);
        freqz(harmmou35,1);
        
        %[place holder] need to add method for impulse response validation,
        %               for example ripple fluctuation of the response...
        %               at this point, if eq looks ok, proceed with eq
end