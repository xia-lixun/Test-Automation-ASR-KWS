% Test Automation For ASR and KWS
% Harman Suzhou
% lixun.xia2@harman.com
% 2018
%
% Module: impulse response estimate, exponential sine sweep
%
% Reference: Farina, "Simultaneous measurement of impulse response and
% distortion with a swept-sine technique"
%
% Dependency: sound-card tool for simultaneous play and recording
%
function [data,response] = impulse_response_exponential_sine_sweep(spk_active, n_spk, n_mic, time_ess, time_pause, save_raw, asio)
%
% 1. The sample rate is always fixed at 48000 sps.
% 2. MIMO case: [1] -> [1,2,3] pause  [2] -> [1,2,3] pause  and repeat...
%    [1]    [1]
%    
%    [2]    [2]
%
%           [3]
%
FS = 48000;
F_START = 5;
F_STOP = FS/2;

ess = exponential_sine_sweep(F_START, F_STOP, time_ess, FS);
essinv = inverse_exponential_sine_sweep(ess, F_START, F_STOP);

m = length(ess);
n = round(time_pause * FS);

stimulus = zeros(m + n, n_spk);
stimulus(1:m, spk_active) = ess * 10^(-3/20);


%@ do the electricoacoustic task
if asio
    audiowrite('ess-stimulus-minus-3db.wav', stimulus, FS, 'BitsPerSample', 32);
    system(['PaDynamic.exe --play ess-stimulus-minus-3db.wav --record response.wav --rate 48000 --channels ', num2str(n_mic) ,' --bits 32'])
else
    %only do simulation
    [b,a] = ellip(5,0.5,20,0.4);
    freqz(b,a);
    n_mic = 1; %force response to be mono
    
    y = filter(b,a,stimulus(:,spk_active));
    audiowrite('response.wav', y, FS, 'BitsPerSample', 32);
end

% retrieve the response
[mics, fs_] = audioread('response.wav');
assert(fs_ == FS);
if save_raw
    path = replace(datestr(datetime()), ':', '-');
    mkdir(path);
    copyfile('ess-stimulus-minus-3db.wav', fullfile(path, 'ess-stimulus-minus-3db.wav'))
    copyfile('response.wav', fullfile(path, 'response.wav'))
end


%@calculate impulse response
%@convolve with the gain-compensated inverse filter
period = m + n;
nfft = 2^(nextpow2(m + period - 1));
essinvfft = fft(essinv,nfft);
data = zeros(nfft - m, n_mic);

for channel = 1:n_mic
    
    mic_ichannel = mics(:, channel);            
    impulse = real(ifft(fft(ess,nfft).* essinvfft, nfft))/nfft;
    response = real(ifft(fft(mic_ichannel,nfft).* essinvfft, nfft))/nfft;    
   
    figure; hold on; plot(impulse); plot(response); grid on;
    data(:,channel) = response(m+1:end);
end






end