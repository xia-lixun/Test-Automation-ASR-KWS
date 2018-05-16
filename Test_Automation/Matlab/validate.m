close all;
clear all;
clc;


% spk: 3,4,5,6
% mouth: 7
% mic: 9

%% test of [impulse response and distortion measurement]
mix_spk = zeros(1,8); mix_spk(1,7) = 1.0;
mix_mic = zeros(12,1); mix_mic(9,1) = 1.0;
[fundamental, harmonics, response, dirac] = impulse_response_exponential_sine_sweep(mix_spk, mix_mic, 100, 12000, 10, 5, 'asio', [1], [1], -12); % fireface -> fireface
figure; plot(fundamental); grid on;
figure; plot(harmonics); grid on;
figure; hold on; plot(response); plot(dirac); grid on;
freqz(fundamental,1);
%% test of [simulation]
mix_spk = zeros(1,8); mix_spk(1,2) = 1.0;
mix_mic = zeros(8,1); mix_mic(2,1) = 1.0;
[fundamental, harmonics, response, dirac] = impulse_response_exponential_sine_sweep(mix_spk, mix_mic, 100, 12000, 10, 5, 'simulation', [1], [1], -3); % simulation
figure; plot(fundamental); grid on;
figure; plot(harmonics); grid on;
figure; hold on; plot(response); plot(dirac); grid on;
%%
mix_spk = zeros(1,2); mix_spk(1,2) = 1.0;
mix_mic = eye(8); 
[fundamental, harmonics, response, dirac] = impulse_response_exponential_sine_sweep(mix_spk, mix_mic, 100, 12000, 10, 5, 'fileio', [1], [1], -20); % DUT -> DUT
figure; plot(fundamental); grid on;
figure; plot(harmonics); grid on;
figure; hold on; plot(response); plot(dirac); grid on;
%%
mix_spk = zeros(1,8); mix_spk(1,3) = 1.0;
mix_mic = eye(8); 
[fundamental, harmonics, response, dirac] = impulse_response_exponential_sine_sweep(mix_spk, mix_mic, 100, 12000, 10, 5, 'asio_fileio', [1], [1], -6); % fireface -> DUT
figure; plot(fundamental); grid on;
figure; plot(harmonics); grid on;
figure; hold on; plot(response); plot(dirac); grid on;
%%
mix_spk = zeros(1,2); mix_spk(1,2) = 1.0;
mix_mic = zeros(12,1); mix_mic(9,1) = 1.0;
[fundamental, harmonics, response, dirac] = impulse_response_exponential_sine_sweep(mix_spk, mix_mic, 100, 12000, 10, 5, 'fileio_asio', [1], [1], -6); % DUT -> fireface
figure; plot(fundamental); grid on;
figure; plot(harmonics); grid on;
figure; hold on; plot(response); plot(dirac); grid on;








%% test of [update calibrator recordings]
add_calibrator_recordings(9, 120, '26AM', '42AA');
%%
add_calibrator_recordings(9, 120, '26AM', '42AB');


%% test of single-source [SPL calibrated to specified dBA] on noise loudspeakers
[symbol,fs] = audioread('Data/Symbol/pink_noise_peak_0dbfs.wav');
assert(fs == 48000);
[g, dba_42aa] = spl_calibrate(symbol, -10, [0,0,0,0,1,0,0,0], [0,0,0,0,0,0,0,0,1].', '26AM', fs, 51, 0.0, 'asio'); % coarse adjustment
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
[g, dba_42aa] = spl_calibrate_multi_source(source, -10, mix_spk, [0,0,0,0,0,0,0,0,1].', '26AM', fs, 57, 0.0, 'asio');

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
clear all
clc
%         IMPORTANT: equalization must be done in the anechoic room!
%                    so change the routing matrix accordingly!
%%
f_anchor = 100; %Hz
h = eq_calibration([0,0,1,0,0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0,1].', f_anchor, -24);
add_equalization_filters(h, 'LoudSPK-1');
%%
f_anchor = 100; %Hz
h = eq_calibration([0,0,0,1,0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0,1].', f_anchor, -24);
add_equalization_filters(h, 'LoudSPK-2');
%%
f_anchor = 100; %Hz
h = eq_calibration([0,0,0,0,1,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0,1].', f_anchor, -24);
add_equalization_filters(h, 'LoudSPK-3');
%%
f_anchor = 100; %Hz
h = eq_calibration([0,0,0,0,0,1,0,0,0,0,0,0], [0,0,0,0,0,0,0,0,1].', f_anchor, -24);
add_equalization_filters(h, 'LoudSPK-4');
%%
f_anchor = 70; %Hz
h = eq_calibration([0,0,0,0,0,0,1,0,0,0,0,0], [0,0,0,0,0,0,0,0,1].', f_anchor, -30);
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
turntable_rotate(serial_port, 11.7, 'CCW');

%% test of power cycle of the dut
system(['julia ', fullfile(pwd(), 'Julia', 'power_reset.jl')]);