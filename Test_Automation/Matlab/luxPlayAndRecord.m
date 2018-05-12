function [] = luxPlayAndRecord(wavFile, length, streams)

fid = fopen('device_test.sh','w');
fprintf(fid,'paplay /home/owner/test.wav &\n');
fprintf(fid,'parecord --channels=2 --rate=16000 --file-format=wav /home/owner/record.wav &\n');
for i = 1 : max(size(streams))
    fprintf(fid,'MicDspClient save %s 1\n', char(streams(i)));
end
fprintf(fid,'sleep %d\n',length);
for i = 1 : max(size(streams))
    fprintf(fid,'MicDspClient save %s 0\n', char(streams(i)));
end
fprintf(fid,'killall -9 parecord\n');
fprintf(fid,'killall -9 paplay\n');
fprintf(fid,'\n');
fclose(fid);

system(sprintf('sdb push %s /home/owner/test.wav', wavFile));
system('sdb push device_test.sh /home/owner/');
system('sdb shell ". /home/owner/device_test.sh"');
system('sdb pull /home/owner/record.wav .');
for i = 1 : max(size(streams))
    system(sprintf('sdb pull /opt/usr/media/dump/capture/%s.raw .', char(streams(i))));
end

