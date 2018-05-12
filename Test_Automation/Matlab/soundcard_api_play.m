function soundcard_api_play(pcm, mix, fs, is_blocking)
% pcm:     pcm source for playback
% mixer:   mixer matrix for pcm source to soundcard.
%          matrix colums be pcm channels,
%          matrix rows be soundcard playback channels.
% fs:      sample rate the soundcard works on
% example:
%          6ch wav: 1 2 3 4 5 6
%          sndcard: 1 2 3 4 5 6 7 8
%          mixer:
%               0.1  0    0    0    0    0
%               0.5  0    0    0    0    0
%               0    0    0    0    0    0
%               0    0    0    0.5  0    0
%               0    0    0.1  0    0    0
%               0    0    0    0    0    0
%               0    0    0    0    0    0
%               0    0    0    0    0    0 
%
% soundcard_channels = 8;
% wav_channels = 6;
% mix = zeros(wav_channels, soundcard_channels);
% mix(1,1) = 0.1;
% mix(1,2) = 0.5;
% mix(3,5) = 0.1;
% mix(4,4) = 0.5;
%
%[pcm, fs] = audioread('D:\SpeechPlatform-Release-Jan2017\SpeechPlatform-OnLabPC\SpeechTalkerAndAmbient.wav');
%soundcard_api_play(pcm, mix.', 48000);
    
    if nargin < 4
        is_blocking = true;
    end
    
    playback = '_soundcard_playback.wav';
    audiowrite(playback, mixer(pcm, mix), fs);
    
    if is_blocking
        system(['soundcard_api.exe --play ',playback,' --rate ',num2str(fs)]);
    else
        system(['soundcard_api.exe --play ',playback, ' --rate ',num2str(fs), ' &']);
    end
end