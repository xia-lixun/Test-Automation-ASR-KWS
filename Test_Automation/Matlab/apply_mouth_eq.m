function [param, soundcard_mouth_active] = apply_mouth_eq(param, i, fs)
% i is the task number

        [data, rate] = audioread([param.task(i).mouth05, param.task(i).mouth10, param.task(i).mouth30, param.task(i).mouth50]);  % concat path so that only one is legal
        assert(rate == fs);         % if source file is not at the soundcard fs, change the source file
        assert(size(data,2) == 1);  % only mono channel
        
        if ~isempty(param.task(i).mouth05)
            h = param.eq.mouth(1).eqFilter;
            soundcard_mouth_active = soundcard_mth_port(1);
            
        elseif ~isempty(param.task(i).mouth10)
            h = param.eq.mouth(2).eqFilter;
            soundcard_mouth_active = soundcard_mth_port(2);
            
        elseif ~isempty(param.task(i).mouth30) || ~isempty(param.task(i).mouth50)
            h = param.eq.mouth(3).eqFilter;
            soundcard_mouth_active = soundcard_mth_port(3);
        else
            error('no mouth input file found?');
        end
        
        data = filter(h, 1, data);
        gain = max(abs(data));
        param.task(i).data.mouth = data / gain;
        
end