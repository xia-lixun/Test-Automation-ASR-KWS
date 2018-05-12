function pcm_record = soundcard_api_playrecord(pcm_play, mix_play, mix_record, fs)
% pcm_play:    pcm for playback
% mixer_play:  mixer matrix for pcm source to soundcard.
%              matrix colums be pcm channels,
%              matrix rows be soundcard playback channels.
% duration: time to record in seconds
% fs:       sample rate the soundcard works on
% note:     this function is always blocking!
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
%   pcm_record = soundcard_api_playrecord(pcm_play, mix_p.', mix_r.', 48000);
%   figure; plot(pcm_play, 'r--'); hold on; grid on; plot(pcm_record, 'b');

    playback = '_soundcard_playback.wav';
    capture = '_soundcard_capture.wav';
    
    audiowrite(playback, mixer(pcm_play, mix_play), fs);
    system(['soundcard_api.exe --play ',playback,' --record ',capture,' --rate ',num2str(fs),' --channels ', num2str(size(mix_record,2)) ,' --bits 32']);
    [pcm_record_snd, rate] = audioread(capture);
    assert(rate == fs);
    
    pcm_record = mixer(pcm_record_snd, mix_record);
end