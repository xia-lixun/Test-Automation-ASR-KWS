function [] = luxPlay(wavFile)

system(sprintf('sdb push %s /home/owner/test.wav', wavFile));
system('sdb shell "paplay /home/owner/test.wav"');
