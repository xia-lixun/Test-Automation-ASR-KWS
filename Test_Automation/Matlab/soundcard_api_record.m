function pcm = soundcard_api_record(mix, duration, fs)
% mixer:    mixer matrix for soundcard to pcm.
%           matrix colums be soundcard recording channels,
%           matrix rows be pcm channels.
% duration: time to record in seconds
% fs:       sample rate the soundcard works on
% note:     this function is always blocking!
% example:
%           sndcard: 1 2 3 4 5 6 7 8
%           4ch wav: 1 2 3 4
%           mixer:
%               1.0  0    0    0   
%               0    1.0  0    0   
%               0    0    0.2  0   
%               0    0    0    0.5 
%               0    0    0    0
%               0    0    0    0
%               0    0    0    0
%               0    0    0    0
%
% soundcard_channels = 8;
% wav_channels = 4;
% mix = zeros(soundcard_channels, wav_channels);
% mix(1,1) = 1.0;
% mix(2,2) = 1.0;
% mix(3,3) = 0.2;
% mix(4,4) = 0.5;
% pcm = soundcard_api_record(mix, 3.3, 48000);

    capture = '_soundcard_capture.wav';
    system(['soundcard_api.exe --record ',capture,' --rate ',num2str(fs),' --channels ', num2str(size(mix,1)), ' --duration ', num2str(duration), ' --bits 32'])
    [pcm_snd, rate] = audioread(capture);
    assert(rate == fs);
 
    pcm = mixer(pcm_snd, mix);   
end