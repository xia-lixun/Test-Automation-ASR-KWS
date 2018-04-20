close all;
clear all;
clc;

[fundamental, harmonic_2nd, response_t] = impulse_response_exponential_sine_sweep(1, 2, 1, 22, 16000/2, 10, 5, true, 'fileio');
figure; plot(fundamental); grid on;
figure; plot(harmonic_2nd); grid on


%% test blocking and non-blocking operation of asio application
system(['PaDynamic.exe --record response.wav --rate 48000 --channels 8 --duration 10 --bits 32 &'])
magic(9)

