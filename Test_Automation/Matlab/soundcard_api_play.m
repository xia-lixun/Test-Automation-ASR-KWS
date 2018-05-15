function soundcard_api_play(pcm, mix, fs, isblocking)
% pcm:     pcm source for playback
% mix:     mixer matrix for pcm source to soundcard.
%          matrix colums be soundcard playback channels,
%          matrix rows be pcm channels.
% fs:      sample rate the soundcard works on
% example:
%          4ch wav: 1 2 3 4
%          sndcard: 1 2 3 4 5 6 7 8
%          mixer:
%               0.1  0    0    0    0    0    0    0
%               0    0.9  0    0    0    0    0    0
%               0    0    1    0    0    0    0    0
%               0    0    0    0.5  0    0    0    0
%
% soundcard_channels = 8;
% wav_channels = 4;
% mix = zeros(wav_channels, soundcard_channels);
% mix(1,1) = 0.1;
% mix(2,2) = 0.9;
% mix(3,3) = 1.0;
% mix(4,4) = 0.5;
%
%[pcm, fs] = audioread('D:\SpeechPlatform-Release-Jan2017\SpeechPlatform-OnLabPC\SpeechTalkerAndAmbient.wav');
%soundcard_api_play(pcm, mix, 48000);
    
    if nargin < 4
        isblocking = true;
    end
    
    playback = '_soundcard_playback.wav';
    audiowrite(playback, mixer(pcm, mix), fs);
    
    if isblocking
        system(['soundcard_api.exe --play ',playback,' --rate ',num2str(fs)]);
    else
        system(['soundcard_api.exe --play ',playback, ' --rate ',num2str(fs), ' &']);
    end
end