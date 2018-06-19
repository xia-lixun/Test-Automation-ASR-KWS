close all;
clear all;
clc;


% spk: 3,4,5,6
% mouth: 7
% mic: 9

%% test of [impulse response and distortion measurement]
mix_spk = zeros(1,8); mix_spk(1,3) = 1.0;
mix_mic = zeros(12,1); mix_mic(9,1) = 1.0;
[fundamental, harmonics, response, dirac] = impulse_response_exponential_sine_sweep(mix_spk, mix_mic, 100, 12000, 30, 5, 'asio', [1], [1], -12); % fireface -> fireface

figure; plot(20*log10(abs(fundamental))); grid on;
figure; hold on; plot(dirac,'b'); plot(response,'r');  grid on;
[h1,w1] = freqz(fundamental,1);
[h2,w2] = freqz(harmonics,1);
figure; semilogx(w1/pi*24000, 20*log10(abs(h1)), 'b'); hold on; semilogx(w2/pi*24000, 20*log10(abs(h2)), 'r'); grid on;

%% test of [simulation]
mix_spk = zeros(1,8); mix_spk(1,2) = 1.0;
mix_mic = zeros(8,1); mix_mic(2,1) = 1.0;
[fundamental, harmonics, response, dirac] = impulse_response_exponential_sine_sweep(mix_spk, mix_mic, 100, 12000, 10, 5, 'simulation', [1], [1], -3); % simulation

figure; plot(20*log10(abs(fundamental))); grid on;
figure; hold on; plot(dirac,'b'); plot(response,'r');  grid on;
[h1,w1] = freqz(fundamental,1);
[h2,w2] = freqz(harmonics,1);
figure; semilogx(w1/pi*24000, 20*log10(abs(h1)), 'b'); hold on; semilogx(w2/pi*24000, 20*log10(abs(h2)), 'r'); grid on;

%%
mix_spk = zeros(1,2); mix_spk(1,2) = 1.0;
mix_mic = eye(8); 
[fundamental, harmonics, response, dirac] = impulse_response_exponential_sine_sweep(mix_spk, mix_mic, 100, 12000, 10, 5, 'fileio', [1], [1], -20); % DUT -> DUT

figure; plot(20*log10(abs(fundamental))); grid on;
figure; hold on; plot(dirac,'b'); plot(response,'r');  grid on;
[h1,w1] = freqz(fundamental,1);
[h2,w2] = freqz(harmonics,1);
figure; semilogx(w1/pi*24000, 20*log10(abs(h1)), 'b'); hold on; semilogx(w2/pi*24000, 20*log10(abs(h2)), 'r'); grid on;

%%
mix_spk = zeros(1,8); mix_spk(1,3) = 1.0;
mix_mic = eye(8); 
[fundamental, harmonics, response, dirac] = impulse_response_exponential_sine_sweep(mix_spk, mix_mic, 100, 12000, 10, 5, 'asio_fileio', [1], [1], -6); % fireface -> DUT

figure; plot(20*log10(abs(fundamental))); grid on;
figure; hold on; plot(dirac,'b'); plot(response,'r');  grid on;
[h1,w1] = freqz(fundamental,1);
[h2,w2] = freqz(harmonics,1);
figure; semilogx(w1/pi*24000, 20*log10(abs(h1)), 'b'); hold on; semilogx(w2/pi*24000, 20*log10(abs(h2)), 'r'); grid on;

%%
mix_spk = zeros(1,2); mix_spk(1,2) = 1.0;
mix_mic = zeros(12,1); mix_mic(9,1) = 1.0;
[fundamental, harmonics, response, dirac] = impulse_response_exponential_sine_sweep(mix_spk, mix_mic, 100, 12000, 10, 5, 'fileio_asio', [1], [1], -6); % DUT -> fireface

figure; plot(20*log10(abs(fundamental))); grid on;
figure; hold on; plot(dirac,'b'); plot(response,'r');  grid on;
[h1,w1] = freqz(fundamental,1);
[h2,w2] = freqz(harmonics,1);
figure; semilogx(w1/pi*24000, 20*log10(abs(h1)), 'b'); hold on; semilogx(w2/pi*24000, 20*log10(abs(h2)), 'r'); grid on;








%% test of [update calibrator recordings]
add_calibrator_recordings(9, 120, '26AM', '42AA');
%%
add_calibrator_recordings(9, 120, '26AM', '42AB');


%% + measure WuW levels +
close all; clear all; clc;


fs = 48000;
[x44,rate] = audioread('D:\P4\ATG_Projects\Projects\20171127_Samsung_LUX\Trunk\Tools\Test_Automation\Data\Lux_Test_HQ_Harman_180515\WakeupWord\WuW_HiBixby_40_bmt_03m25s.wav');
x48 = resample(x44, fs, rate);
t = [5.5 6.611; 10.4908 11.5836; 15.5136 16.5847; 20.4906 21.4488; 25.5038 26.4877; 30.5187 31.2152; 35.5087 36.2787; 40.5058 41.223; 45.5122 46.2569; 50.5011 51.2413; 55.508 56.3717; 60.4593 61.3614; 65.4895 66.37; 70.4671 71.2992; 75.4948 76.3752; 80.5146 81.3628; 85.5032 86.4594; 90.4976 91.4198; 95.5115 96.4203; 100.502 101.37; 105.502 106.401; 110.505 111.381; 115.512 116.441; 120.508 121.391; 125.519 126.378; 130.47 131.276; 135.474 136.338; 140.472 141.23; 145.47 146.275; 150.488 151.305; 155.495 156.116; 160.506 161.154; 165.515 166.244; 170.488 171.24; 175.501 176.243; 180.562 181.266; 185.538 186.294; 190.521 191.263; 195.524 196.253; 200.518 201.263];
%t = [5.5 6.611; 10.4693 11.6223; 15.5165 16.6198; 20.4906 21.5293; 25.5222 26.546; 30.5048 31.2701; 35.5236 36.3486; 40.4998 41.2652; 45.5122 46.3124; 50.4884 51.2978; 55.508 56.4523; 60.4593 61.4533; 65.4895 66.4338; 70.4614 71.3511; 75.415 76.4288; 80.5083 81.4327; 85.4909 86.5097; 90.4976 91.4916; 95.5115 96.4806; 100.502 101.451; 105.502 106.481; 110.505 111.455; 115.512 116.506; 120.508 121.477; 125.519 126.448; 130.47 131.32; 135.467 136.398; 140.472 141.292; 145.438 146.328; 150.488 151.367; 155.484 156.205; 160.495 161.226; 165.504 166.309; 170.474 171.289; 175.49 176.3; 180.541 181.326; 185.528 186.353; 190.497 191.322; 195.514 196.284; 200.506 201.301];
s = round(t*fs);

r = [];
for i = 1:max(size(t))
    r = [r; zeros(fs,1); x48(s(i,1):s(i,2)); x48(s(i,1):s(i,2)); x48(s(i,1):s(i,2)); zeros(fs,1)];
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



mic_type = '26AM';
result = zeros(max(size(t)),1);
for i = 1:max(size(t))
    
    result(i) = sound_pressure_level(['Data/Calibration/42AA/',latest_42aa,'/cal-250hz-114dB(105.4dBA)_',mic_type,'_12AA(0dB)_UFX.wav'], ...
    r, ...
    [x48(s(i,1):s(i,2)); x48(s(i,1):s(i,2)); x48(s(i,1):s(i,2))], ...
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
end

%% test of single-source [SPL calibrated to specified dBA] on noise loudspeakers
[symbol,fs] = audioread('Data/Symbol/pink_noise_peak_0dbfs.wav');
assert(fs == 48000);
[g, dba_42aa] = spl_calibrate(symbol, -10, [0,0,0,1,0,0,0,0], [0,0,0,0,0,0,0,0,1].', '26AM', fs, 51, 0.0, 'asio'); % coarse adjustment
%[g, dba_42aa] = spl_calibrate(symbol, g, [0,0,0,0,1,0,0,0], [0,0,0,0,0,0,0,0,1].', '26AM', fs, 51, 0.0, 'asio'); % fine adjustment

%% test of single-source [SPL calibrated to specified dBA] on DUT playback
[symbol,fs] = audioread('Data/Symbol/pink_noise_peak_0dbfs.wav');
assert(fs == 48000);
[g, dba_42aa] = spl_calibrate(symbol, -10, [1,1], [0,0,0,0,0,0,0,0,1].', '26AM', fs, 60, 0.0, 'fileio'); % coarse adjustment
%[g, dba_42aa] = spl_calibrate(symbol, g, [1,1], [0,0,0,0,0,0,0,0,1].', '26AM', fs, 60, 0.0, 'fileio'); % fine adjustment

%% test of multi-source [SPL calibrated to specified dBA] on noise loudspeakers
[source,fs] = audioread('Data/Symbol/LevelCalibration4ch.wav');
assert(fs == 48000);
mix_spk = zeros(4,8);
mix_spk(1,3) = 1;
mix_spk(2,4) = 1;
mix_spk(3,5) = 1;
mix_spk(4,6) = 1;
[g, dba_42aa] = spl_calibrate_multi_source(source, -20, mix_spk, [0,0,0,0,0,0,0,0,1].', '26AM', fs, 57, 0.0, 'asio');

%% test of multi-source [SPL calibrated to specified dBA] on DUT playback
[source, fs] = audioread('Data\Symbol\acqua_ieee_male_250ms_10450ms.wav');
assert(fs == 48000);
[g, dba_42aa] = spl_calibrate_multi_source(source, -10, eye(2), [0,0,0,0,0,0,0,0,1].', '26AM', fs, 60, 0.0, 'fileio');


%% test of [lux file IO]
luxAlive()
luxInit()
luxPlay('Data\Symbol\pink_noise_peak_0dbfs.wav')              % shows that lux can play mono channel
luxPlay('Data\Symbol\acqua_ieee_male_250ms_10450ms.wav')
luxRecord(3, cellstr('mic_8ch_16k_s16_le'))
luxRecord(3, cellstr('ref_1ch_16k_s16_le'))
raw2wav_16bit('mic_8ch_16k_s16_le.raw', 8, 16000, 'mic_8ch_16k_s16_le.wav');
raw2wav_16bit('ref_1ch_16k_s16_le.raw', 1, 16000, 'ref_1ch_16k_s16_le.wav');
luxPlayAndRecord('Data\Symbol\acqua_ieee_male_250ms_10450ms.wav', 20, cellstr('mic_8ch_16k_s16_le'))
raw2wav_16bit('mic_8ch_16k_s16_le.raw', 8, 16000, 'mic_8ch_16k_s16_le.wav');







%%
close all
clear all;
clc
%         IMPORTANT: equalization must be done in the anechoic room!
%                    so change the routing matrix accordingly!
%%
f_anchor = 36; %Hz
h = eq_calibration([0,0,1,0,0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0,1].', f_anchor, 16000, -26);
add_equalization_filters(h, 'LoudSPK-1');
%%
f_anchor = 32; %Hz
h = eq_calibration([0,0,0,1,0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0,1].', f_anchor, 14100, -26);
add_equalization_filters(h, 'LoudSPK-2');
%%
f_anchor = 33; %Hz
h = eq_calibration([0,0,0,0,1,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0,1].', f_anchor, 16000, -26);
add_equalization_filters(h, 'LoudSPK-3');
%%
f_anchor = 33; %Hz
h = eq_calibration([0,0,0,0,0,1,0,0,0,0,0,0], [0,0,0,0,0,0,0,0,1].', f_anchor, 16000, -26);
add_equalization_filters(h, 'LoudSPK-4');
%%
f_anchor = 200; %Hz
h = eq_calibration([0,0,0,0,0,0,1,0,0,0,0,0], [0,0,0,0,0,0,0,0,1].', f_anchor, 100, 22000, -30);
add_equalization_filters(h, 'Mouth-05');
%%
f_anchor = 70; %Hz
h = eq_calibration([0,0,0,0,0,0,0,1,0,0,0,0], [0,0,0,0,0,0,0,0,1].', f_anchor, -30);
add_equalization_filters(h, 'Mouth-10');
%%
f_anchor = 70; %Hz
h = eq_calibration([0,0,0,0,0,0,0,0,1,0,0,0], [0,0,0,0,0,0,0,0,1].', f_anchor, -30);
add_equalization_filters(h, 'Mouth-35');





%% test of turn table
serial_port = 1;
turntable_set_origin(serial_port);
turntable_rotate(serial_port, 360-13.3, 'CW');

%% test of power cycle of the dut
system(['julia ', fullfile(pwd(), 'Julia', 'power_reset.jl')]);