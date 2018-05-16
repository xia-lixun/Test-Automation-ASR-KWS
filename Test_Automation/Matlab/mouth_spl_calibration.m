function mouth_spl_calibration(param)

% 
[symbol, rate] = audioread('Data/Symbol/LevelCalibration.wav');
assert(rate == fs);

spk_route = zeros(size(symbol,2), soundcard_spk_channels);
if mouth50cm ~= '""'
    spk_route(1,7) = 1.0;
end
if mouth1m ~= '""'
    spk_route(1,8) = 1.0;
end
if mouth3m ~= '""'
    spk_route(1,9) = 1.0;
end
if mouth5m ~= '""'
    spk_route(1,9) = 1.0;
end

[g_mouth, dba_42aa] = spl_calibrate(symbol, -30, spk_route.', mic_route, '26AM', fs, mouthlevel, 0.0, 'asio');


end