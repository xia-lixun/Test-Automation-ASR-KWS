function add_equalization_filters(eqFilter, eqTarget)
% eqTarget in ['Mouth-05', 'Mouth-10', 'Mouth-35', 'LoudSPK-1', 'LoudSPK-2', 'LoudSPK-3', 'LoudSPK-4']
    
    figure; freqz(eqFilter, 1);
    root = 'Data/Equalization/';
    timestamp = datestr(datetime());
    timestamp = replace(timestamp, ' ', '_');
    timestamp = replace(timestamp, ':', '-');
    
    mkdir(fullfile(root, eqTarget));
    folder = fullfile(root, eqTarget, timestamp);
    mkdir(folder);
    path = fullfile(folder, 'fir_min_phase.mat');
    save(path, 'eqFilter');
    
end