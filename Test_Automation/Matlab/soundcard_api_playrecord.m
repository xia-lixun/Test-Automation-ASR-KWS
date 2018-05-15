function pcmrecord = soundcard_api_playrecord(pcmplay, mixplay, mixrec, fs, isblocking)
% pcmplay:  pcm for playback
% mixplay:  mixer matrix for pcm source to soundcard.
% mixrec:   mixer matrix for soundcard to pcm recorded
% fs:       sample rate the soundcard works on
%
% note:     duration of the recording is the same as the length of the playback
%
% example:
%   sndout_channels = 8;
%   sndin_channels = 8;
%   play_channels = 1;
%   record_channels = 1;
%   mix_p = zeros(play_channels, sndout_channels);
%   mix_r = zeros(sndin_channels, record_channels);
%   mix_p(1,2) = 1.0;
%   mix_r(2,1) = 1.0;
%   pcm_play = [0.5*rand(48000,1);zeros(48000,1)];
%   pcm_record = soundcard_api_playrecord(pcm_play, mix_p, mix_r, 48000);
%   figure; plot(pcm_play, 'r--'); hold on; grid on; plot(pcm_record, 'b');

    if nargin < 5
        isblocking = true;
    end
    
    playback = '_soundcard_playback.wav';
    capture = '_soundcard_capture.wav';
    
    if isblocking
        audiowrite(playback, mixer(pcmplay, mixplay), fs);
        system(['soundcard_api.exe --play ',playback,' --record ',capture,' --rate ',num2str(fs),' --channels ', num2str(size(mixrec,1)) ,' --bits 32']);
        [pcm_record_snd, rate] = audioread(capture);
        assert(rate == fs);
        pcmrecord = mixer(pcm_record_snd, mixrec);
    else
        audiowrite(playback, mixer(pcmplay, mixplay), fs);
        system(['soundcard_api.exe --play ',playback,' --record ',capture,' --rate ',num2str(fs),' --channels ', num2str(size(mixrec,1)) ,' --bits 32 &']);
        % this mode is ugly but necessary because we need the standard
        % mic recording for all cases (quiet/noise/echo/echo+noise); so we
        % can put the blocking-end to luxRecord.m or luxPlayAndRecord.m
    end
end