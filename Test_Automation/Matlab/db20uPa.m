function dbspl = db20uPa(calib_record, ...
                         measure_record, ...
                         symbol, ...
                         repeat, ...
                         symbol_start, ...
                         symbol_stop, ...
                         frequency_low, ...
                         frequency_high, ...
                         calibrator_spl_db, ...
                         sample_rate, ...
                         frame_size, ...
                         hop_size)
    
% calib_record: recording of the calibrator by the reference mic
% measure_record: recording that contains the signal of interest for SPL measurement
% symbol: the signal of interest for SPL measurement
% repeat: number of symbols that exists in the measure recording
% symbol_start: starting point of the active part of the symbol (in seconds)
% symbol_stop: ending point of the active part of the symbol (in seconds)
% frequency_low: lowest frequency for analysis (energy lower will be lost)
% frequency_high: highest frequency for analysis (energy above will be lost)
% calibrator_spl_db: reading of the calibrator, in either dB or dBA
% sample_rate: sample rate of all time series
% frame_size: analysis frame size
% hop_size: analysis window shift size

    channels = size(measure_record,2);
    dbspl = zeros(1, channels);
    
    % calculate power spectrum of the calibration recording
    window = hann_symm(frame_size);
    power_calib = power_spectrum(calib_record, frame_size, hop_size, frame_size, window);
    power_calib = mean(power_calib,2);

    fl = floor(frequency_low/sample_rate * frame_size);
    fh = floor(frequency_high/sample_rate * frame_size);
    offset = 10 * log10(sum(power_calib(fl:fh)) + eps());    

    % if symbol_start >= symbol_stop we use entire symbol
    if symbol_start < symbol_stop
        assert(size(symbol,1) >= floor(sample_rate * symbol_stop));
        symbol = symbol(1+floor(sample_rate * symbol_start):floor(sample_rate * symbol_stop));
    end

    % calculate relative db value cross all channels
    for c = 1:channels
        [lbs,peaks,extracted] = locate_sync_symbol(measure_record(:,c),symbol,repeat);
        power_measure = power_spectrum(extracted, frame_size, hop_size, frame_size, window);
        power_measure = mean(power_measure,2);
        dbspl(c) = 10 * log10(sum(power_measure(fl:fh)) + eps()) + (calibrator_spl_db - offset);
    end
end






function p = power_spectrum(x, frame_size, hop_size, nfft, window)
    if nfft < frame_size
        error('fft length must be greater than or equal to frame size')
    end
    if size(window,1) ~= nfft
        error('window size must be equal to nfft')
    end
    y = buffer(x, frame_size, frame_size - hop_size, 'nodelay');
    m = nfft / 2 + 1;
    n = size(y,2);
    %p = zeros(m,n);
    y = fft(repmat(window,1,n) .* [y; zeros(nfft-frame_size,size(y,2))]);
    p = (1/nfft) * (abs(y(1:m,:)).^2);
end

function y = hann_symm(n)
% creates symmetrical hann window
    y = zeros(n,1);
    alpha = 0.5;
    beta = 1 - alpha;
    for i = 0:n-1
        y(i+1) = alpha - beta * cos(2 * pi * i / (n-1));
    end
end