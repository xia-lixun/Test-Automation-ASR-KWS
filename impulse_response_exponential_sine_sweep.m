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
%             only works for ASIO driver
%             asio = true must be enabled
function [fundamental, harmonic_2nd, response_t] = impulse_response_exponential_sine_sweep(spk_active, n_spk, n_mic, f0, f1, time_ess, time_pause, save_raw, device)
%
% 1. The sample rate is always fixed at 48000 sps.
% 2. MIMO: multiple loud speakers, multiple microphones
%
%      /|         |
%   [1] |         |[1] 
%      \|         |
%
%                 |
%                 |[2]
%                 |
%
%      /|         |         
%   [2] |         |[3]
%      \|         |
%
%    n_spk = 2
%    n_mic = 3
%    to measure all impulse responses, iterate over spk_active = 1,2
%
assert(spk_active <= n_spk);
assert(n_mic > 0);
assert(f0 < f1);

FS = 48000;
F_START = 1;
F_STOP = FS/2;
if F_START < f0
    F_START = f0;
end
if F_STOP > f1
    F_STOP = f1;
end

    

ess = exponential_sine_sweep(F_START, F_STOP, time_ess, FS);
essinv = inverse_exponential_sine_sweep(ess, F_START, F_STOP);

m = length(ess);
n = round(time_pause * FS);

stimulus = zeros(m + n, n_spk);
stimulus(1:m, spk_active) = ess * 10^(-3/20);


%@ do the electricoacoustic task
if strcmp(device, 'asio')
    % play and record with asio sound card
    audiowrite('ess-stimulus-minus-3db.wav', stimulus, FS, 'BitsPerSample', 32);
    system(['PaDynamic.exe --play ess-stimulus-minus-3db.wav --record response.wav --rate 48000 --channels ', num2str(n_mic) ,' --bits 32'])
    
elseif strcmp(device, 'fileio')
    % play and record on DUT

elseif strcmp(device, 'asio_fileio')
    % play ess with asio souncard, do mic capture with fileio on DUT

elseif strcmp(device, 'fileio_asio')
    % play ess with fileio on DUT, do mic capture with asio sound card
    
else
    %only do simulation
    distortion = true;
    [b,a] = ellip(5,0.5,20,0.4);
    freqz(b,a);
    n_mic = 1; %force response to be mono
    
    y = filter(b,a,stimulus(:,spk_active));
    if distortion
        ym = median(abs(y));
        y(y>ym) = ym;
    end
    audiowrite('response.wav', y, FS, 'BitsPerSample', 32);
end



%@ retrieve the response
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


distance_offset = time_ess / log(F_STOP/F_START);
distance_12 = round(log(2) * distance_offset * FS);
fundamental = zeros(nfft - (m-round(distance_12/3)-1), n_mic);
response_t = zeros(nfft, n_mic);

distance_13 = round(log(3) * distance_offset * FS);
distance_23 = distance_13 - distance_12;
harmonic_2nd = zeros(m-round(distance_12/3) - (m - distance_12 - round(distance_23/3)) + 1, n_mic);

for channel = 1:n_mic
    
    mic_ichannel = mics(:, channel);            
    impulse = real(ifft(fft(ess,nfft).* essinvfft, nfft))/nfft;
    response = real(ifft(fft(mic_ichannel,nfft).* essinvfft, nfft))/nfft;    
   
    figure; hold on; plot(impulse); plot(response); grid on;
    
    response_t(:,channel) = response;
    fundamental(:,channel) = response(m-round(distance_12/3):end);
    harmonic_2nd(:,channel) = response(m - distance_12 - round(distance_23/3) : m-round(distance_12/3));
end






end