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
% Dependency: sound-card tool for play and recording if device = 'asio'
%
function [fundamental, harmonic_2nd, response_t] = impulse_response_exponential_sine_sweep(spk_active, n_spk, n_mic, f0, f1, time_ess, time_decay, save_raw, device)
%   spk_active: loud speaker numer that plays the stimulus
%   n_spk:      number of total loud speakers
%   n_mic:      number of total mics
%   f0:         chirp start frequency
%   f1:         chirp stop frequency
%   time_ess:   chirp elapse time in seconds
%   time_decay: chirp decaying time for stablization
%   save_raw:   save wavs to a folder with a timestamp
%   device:     'asio', 'fileio', 'asio_fileio', 'fileio_asio'
%
%   1. The sample rate is always fixed at 48000 sps.
%   2. mimo example: multiple loud speakers and mics shown below
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

assert(spk_active <= n_spk);
assert(n_mic > 0);
assert(f0 < f1);

%@ some default parameters
FS = 48000;
F_START = 1;
F_STOP = FS/2;
if F_START < f0
    F_START = f0;
end
if F_STOP > f1
    F_STOP = f1;
end


%@ generate the chirp
ess = exponential_sine_sweep(F_START, F_STOP, time_ess, FS);
essinv = inverse_exponential_sine_sweep(ess, F_START, F_STOP);
m = length(ess);
n = round(time_decay * FS);


%@ comply to the channel format of playback device
%  and insert the silence to hold response decay.
stimulus = zeros(m + n, n_spk);
stimulus(1:m, spk_active) = ess * 10^(-3/20);


%@ do the electric-acoustic tasks
playback = 'ess-stimulus-minus-3db.wav';
capture = 'response.wav';

if strcmp(device, 'asio')
    
    % play and record with asio sound card
    audiowrite(playback, stimulus, FS, 'BitsPerSample', 32);
    system(['PaDynamic.exe --play ',playback,' --record ',capture,' --rate ',num2str(FS),' --channels ', num2str(n_mic) ,' --bits 32'])
    [mics, fs_] = audioread(capture);
    assert(fs_ == FS);
    
elseif strcmp(device, 'fileio')
    
    % play and record on DUT
    g = sync_symbol(800, 1200, 1, FS) * (10^(-3/20));
    context_switch = 3;
    symbol_decay = 3;
    stimulus_async = add_sync_symbol(stimulus, context_switch, g, symbol_decay, FS);
    audiowrite(playback, stimulus_async, FS, 'BitsPerSample', 32);
    
    file_io_dut_sdb('play+record');
    
    [mics, fs_] = audioread(capture);
    assert(fs_ == FS);
    
    % extract the response
    symbol_locs = zeros(2,n_mic);
    for channel = 1:n_mic
        symbol_locs(:,channel) = locate_sync_symbol(mics(:,channel), g, 2);
    end
    delta = symbol_locs(2,:) - symbol_locs(1,:);
    for channel = 1:n_mic
        assert(delta(channel) == length(g) + round(symbol_decay*FS) + size(stimulus,1));
        disp('recordings sanity check ok');
    end
    relative_latency = symbol_locs(1,:) - min(symbol_locs(1,:));
    disp('relative latency of each mic channels (sample):');
    disp(relative_latency);
    
    mics_extracted = zeros(size(stimulus,1),n_mic);
    for channel = 1:n_mic
        loc = symbol_locs(1,channel) + length(g) + round(symbol_decay*FS) - 2048;
        mics_extracted(:,channel) = mics(loc : loc+size(stimulus,1)-1,channel);
    end
    mics = mics_extracted;
    
    
elseif strcmp(device, 'asio_fileio')
    % play ess with asio souncard, do mic capture with fileio on DUT

elseif strcmp(device, 'fileio_asio')
    % play ess with fileio on DUT, do mic capture with asio sound card
    
elseif strcmp(device, 'simulation')
    %only do simulation
    n_mic = 1; %force response to be mono
    distortion = true;
    [b,a] = ellip(5,0.5,20,0.4);
    freqz(b,a);
    y = filter(b,a,stimulus(:,spk_active));
    if distortion
        ym = median(abs(y));
        y(y>ym) = ym;
    end
    audiowrite(capture, y, FS, 'BitsPerSample', 32);
    
    [mics, fs_] = audioread(capture);
    assert(fs_ == FS);

else
    error('wrong device type! [asio, fileio, asio_fileio, fileio_asio]')
end



%@ save playback and recording files to a folder with current timestamp
if save_raw
    path = replace(datestr(datetime()), ':', '-');
    mkdir(path);
    copyfile(playback, fullfile(path, playback))
    copyfile(capture, fullfile(path, capture))
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