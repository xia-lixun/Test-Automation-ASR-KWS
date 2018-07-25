
function raw2wav_24bit(raw_file, channels, fs, wav_file)

    fid = fopen(raw_file, 'r');
    x = fread(fid, inf, 'uint8');
    n = length(x);
    
    u = int32(zeros(n/3,1));
    
    y = [uint8(zeros(1, n/3)); reshape(x, 3, n/3)];
    for i = 1:n/3
        u(i) = typecast(y(:,i), 'int32');
    end

    m = reshape(u, channels, n/3/channels);
    audiowrite(wav_file, m.', fs, 'BitsPerSample', 32);
    fclose(fid);
end