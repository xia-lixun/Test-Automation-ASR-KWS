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
function [fundamental, harmonic, response_t] = impulse_response_exponential_sine_sweep(mix_spk, ...
                                                                                       mix_mic, ...
                                                                                       f0, ...
                                                                                       f1, ...
                                                                                       time_ess, ...
                                                                                       time_decay, ...
                                                                                       device, ...
                                                                                       B, ...
                                                                                       A, ...
                                                                                       atten_db)
%   spk_active: loud speaker numer that plays the stimulus
%   n_spk:      number of total loud speakers
%   n_mic:      number of total mics
%   f0:         chirp start frequency
%   f1:         chirp stop frequency
%   time_ess:   chirp elapse time in seconds
%   time_decay: chirp decaying time for stablization
%   save_raw:   save wavs to a folder with a timestamp
%   device:     'asio', 'fileio', 'asio_fileio', 'fileio_asio'
%   B,A:        EQ filter added for compensation test
%   atten_db:   attenuation of the stimulus to prevent distortion and clipping after EQ
%
%   1. ess -> EQ -> attenuate -> convolution H() -> response
%   1. The sample rate is always fixed at 48000 sps.
%   2. MIMO example: multiple loud speakers and mics shown below
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



%@ some default parameters
FS = 48000;
F_START = 1;
F_STOP = FS/2;
assert(f0 < f1);
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
stimulus = zeros(m + n, 1);
stimulus(1:m, 1) = ess;

%@ passing through EQ filter and then attenuate
stimulus = filter(B,A,stimulus) * (10^(atten_db/20));
if max(abs(stimulus)) >= 1.0
    error('stimulus clipping! try lower the atten value... abort');
end





%@ do the electric-acoustic tasks
if strcmp(device, 'asio')
    
    % play and record with asio sound card  
    mics = soundcard_api_playrecord(stimulus, mix_spk, mix_mic, FS);


elseif strcmp(device, 'simulation')
    
    %only do simulation
    distortion = true;
    [b,a] = ellip(5,0.5,20,0.4);
    freqz(b,a);
    y = filter(b,a,stimulus);
    if distortion
        ym = median(abs(y));
        y(y>ym) = ym;
    end
    mics = y;
    

else
    %@ Asynchronous operations -- mixture of ASIO/FileIO
    g = sync_symbol(220, 8000, 1, FS) * (10^(-20/20));
    context_switch = 6;
    symbol_decay = 3;
    stimulus_async = add_sync_symbol(stimulus, context_switch, g, symbol_decay, FS);
    
    
    %@ fireface + DUT
    luxInit()
    if strcmp(device, 'fileio')  % play and record on DUT
        
        playback = '_dut_playback.wav';
        capture = '_dut_capture.wav';
        audiowrite(playback, mixer(stimulus_async, mix_spk), FS, 'BitsPerSample', 32);
        
        luxPlayAndRecord(playback, ceil(length(stimulus_async)/FS), cellstr('mic_8ch_16k_s16_le'))   %blocking
        raw2wav_16bit('mic_8ch_16k_s16_le.raw', size(mix_mic,2), 16000, 'mic_8ch_16k_s16_le.wav');
        [temp, rate] = audioread('mic_8ch_16k_s16_le.wav');
        assert(rate == 16000);
        audiowrite(capture, resample(temp,FS,16000), FS, 'BitsPerSample',32);
        
        [temp, rate] = audioread(capture);
        assert(rate == FS);
        mics = mixer(temp, mix_mic);
        % timing diagram
        % enforced by DUT operations
        
    elseif strcmp(device, 'asio_fileio')  % play with souncard, mic capture on DUT
        
        capture = '_dut_capture.wav';
        soundcard_api_play(stimulus_async, mix_spk, FS, false);   % is_blocking == false
        
        luxRecord(ceil(length(stimulus_async)/FS), cellstr('mic_8ch_16k_s16_le'))   %blocking
        raw2wav_16bit('mic_8ch_16k_s16_le.raw', size(mix_mic,2), 16000, 'mic_8ch_16k_s16_le.wav');
        [temp, rate] = audioread('mic_8ch_16k_s16_le.wav');
        assert(rate == 16000);
        audiowrite(capture, resample(temp,FS,16000), FS, 'BitsPerSample',32);
        
        [temp, rate] = audioread(capture);
        assert(rate == FS);
        mics = mixer(temp, mix_mic);
        % timing diagram
        % play:     +~~lat(PaDynamic)~~+---------stimulus_async---------+
        % record:   +~~~~~lat(file_io_dut)~~~~~+------len(stimulus_async)--------+
        
        
    elseif strcmp(device, 'fileio_asio')   % play on DUT, mic capture via soundcard
        
        playback = '_dut_playback.wav';
        file_io_dut_latency = 5;
        time_recording = size(stimulus_async,1)/FS + file_io_dut_latency;
        audiowrite(playback, mixer(stimulus_async, mix_spk), FS, 'BitsPerSample', 32);
        
        system(sprintf('sdb push %s /home/owner/test.wav', playback));
        system('sdb shell "paplay /home/owner/test.wav" &');               % non-blocking
        
        mics = soundcard_api_record(mix_mic, time_recording, FS);          % blocking
        % timing diagram
        % play:     +~~~~~~lat(file_io_dut)~~~~~~~~+---------stimulus_async---------+
        % record:   +~~lat(PaDynamic)~~+------len(stimulus_async)--------+----lat(file_io_dut)----+
        
    else
        error('wrong device type! [asio, fileio, asio_fileio, fileio_asio]')
    end
    
    
    %@ extract(decode) the response
    n_mic = size(mix_mic, 1);
    symbol_locs = zeros(2,n_mic);
    for channel = 1:n_mic
        [left_bounds, corr_peaks, extracted]= locate_sync_symbol(mics(:,channel), g, 2);
        symbol_locs(:,channel) = left_bounds;
    end
    disp('sync symbol locations for each channel (columns):')
    disp(symbol_locs);
    delta = symbol_locs(2,:) - symbol_locs(1,:);
    disp('sync symbol delta:')
    disp(delta)
    
    theoretical = length(g) + round(symbol_decay*FS) + size(stimulus,1);
    disp('theoretical delta:')
    disp(theoretical)
    for channel = 1:n_mic
        assert(abs(delta(channel) - theoretical) <= 16);
        disp('recordings sanity check ok, samples = ');
        disp([delta(channel); corr_peaks(2) - corr_peaks(1)]);
    end
    relative_latency = symbol_locs(1,:) - min(symbol_locs(1,:));
    disp('relative latency of each mic channels (sample):');
    disp(relative_latency);
    
    mics_extracted = zeros(size(stimulus,1),n_mic);
    hyperthetical_delay = 2048;
    for channel = 1:n_mic
        loc = symbol_locs(1,channel) + length(g) + round(symbol_decay*FS) - hyperthetical_delay;
        mics_extracted(:,channel) = mics(loc : loc+size(stimulus,1)-1,channel);
    end
    mics = mics_extracted;
    
end





%@ save playback and recording files to a folder with current timestamp
% if save_raw
%     path = replace(datestr(datetime()), ':', '-');
%     mkdir(path);
%     copyfile(playback, fullfile(path, playback))
%     copyfile(capture, fullfile(path, capture))
% end


%@calculate impulse response
%@convolve with the gain-compensated inverse filter
period = m + n;
n_mic = size(mix_mic,1);
nfft = 2^(nextpow2(m + period - 1));
essinvfft = fft(essinv,nfft);


distance_offset = time_ess / log(F_STOP/F_START);
distance_12 = round(log(2) * distance_offset * FS);
fundamental = zeros(nfft - (m-round(distance_12/2)-1), n_mic);
response_t = zeros(nfft, n_mic);

%distance_13 = round(log(3) * distance_offset * FS);
%distance_23 = distance_13 - distance_12;
%harmonic_2nd = zeros(m-round(distance_12/2) - (m - distance_12 - round(distance_23/2)) + 1, n_mic);
harmonic = zeros(m-round(distance_12/2), n_mic);

for channel = 1:n_mic
    
    mic_ichannel = mics(:, channel);            
    impulse = real(ifft(fft(ess,nfft).* essinvfft, nfft))/nfft;
    response = real(ifft(fft(mic_ichannel,nfft).* essinvfft, nfft))/nfft;    
   
    figure; hold on; plot(impulse); plot(response); grid on;
    
    response_t(:,channel) = response;
    fundamental(:,channel) = response(m-round(distance_12/2):end);
    
    %harmonic_2nd(:,channel) = response(m - distance_12 - round(distance_23/3) : m-round(distance_12/3));
    harmonic(:,channel) = response(1:m-round(distance_12/2));
end






end