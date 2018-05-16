function param = apply_loudspk_eq(param, i, fs)

        [data, rate] = audioread(param.task(i).noise);
        assert(rate == fs);         % if source file is not at the soundcard fs, change the source file
        assert(size(data,2) == 4);  % must be quad channel     

        for k = 1:4
            data(:,k) = filter(param.eq.spk(k).eqFilter, 1, data(:,k));
        end
        gain = max(max(abs(data)));
        param.task(i).data.noise = data / gain;
end