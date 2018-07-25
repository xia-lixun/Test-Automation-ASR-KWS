function raw2wav_16bit(raw_file, channels, fs, wav_file)
%raw_file = 'mic_8ch_16k_s16_le.raw';
%channels = 8;
%fs = 16000;

    fid = fopen(raw_file,'r');
    x = fread(fid, inf, 'int16');
    n = length(x);
    x = reshape(x, channels, n/channels);
    audiowrite(wav_file, int16(x.'), fs, 'BitsPerSample', 16);
    fclose(fid);
end



