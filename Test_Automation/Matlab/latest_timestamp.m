function [latest, dt] = latest_timestamp(path)
% path: calibrator recording path, for example, 'Data/Calibration/42AA'
% latest: return the latest timestamp under path in string
% dt: return the latest timestamp under path in datetime 
    timestamp_list = dir(path);
    timestamps = [];
    for i = 3:length(timestamp_list)
        timestamps = [timestamps; datetime(timestamp_list(i).name, 'InputFormat', 'dd-MMM-yyy_HH-mm-ss')];
    end
    timestamps = sort(timestamps, 'descend');
    latest = datestr(timestamps(1));
    latest = replace(latest, ' ', '_');
    latest = replace(latest, ':', '-');
    dt = timestamps(1);
end