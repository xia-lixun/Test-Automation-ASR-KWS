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
        param.eq.mouth(1) = load('Data/Equalization/Mouth-05/', latest_m05 ,'/fir_min_phase.mat');
        param.eq.mouth(2) = load('Data/Equalization/Mouth-10/', latest_m10 ,'/fir_min_phase.mat');
        param.eq.mouth(3) = load('Data/Equalization/Mouth-35/', latest_m35 ,'/fir_min_phase.mat');

        param.eq.spk(1) = load('Data/Equalization/LoudSPK-1/', latest_s1 ,'/fir_min_phase.mat');
        param.eq.spk(2) = load('Data/Equalization/LoudSPK-2/', latest_s2 ,'/fir_min_phase.mat');
        param.eq.spk(3) = load('Data/Equalization/LoudSPK-3/', latest_s3 ,'/fir_min_phase.mat');
        param.eq.spk(4) = load('Data/Equalization/LoudSPK-4/', latest_s4 ,'/fir_min_phase.mat');
        
        % measure impulse response with eq in the loop
        mix_mic = zeros(soundcard_in_channels, 1); 
        mix_mic(soundcard_mic_port, 1) = 1.0;
        
        
        figure; hold on; grid on;
        for i = 1:4
            mix_spk = zeros(1, soundcard_out_channels); 
            mix_spk(1, soundcard_spk_port(i)) = 1.0;
            [fund, harm, resp, ideal] = impulse_response_exponential_sine_sweep(mix_spk, mix_mic, 100, 22000, 10, 5, 'asio', param.eq.spk(i).eqFilter, 1, -30); % fireface -> fireface
            [h,w] = freqz(fund, 1);
            plot(w/pi, 20*log10(abs(h)));
        end
        title('speaker impulse response with eq')
        

        figure; hold on; grid on;
        for i = 1:3
            mix_mth = zeros(1, soundcard_out_channels); 
            mix_mth(1, soundcard_mth_port(i)) = 1.0;
            [fund, harm, resp, ideal] = impulse_response_exponential_sine_sweep(mix_mth, mix_mic, 100, 22000, 10, 5, 'asio', param.eq.mouth(i).eqFilter, 1, -30);
            [h,w] = freqz(fund, 1);
            plot(w/pi, 20*log10(abs(h)));
        end
        title('mouth impulse response with eq')

        
        %[place holder] need to add method for impulse response validation,
        %               for example ripple fluctuation of the response...
        %               at this point, if eq looks ok, proceed with eq
end