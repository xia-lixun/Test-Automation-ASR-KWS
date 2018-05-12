function y = sync_symbol(f0, f1, elapse, fs)
    % sync symbol is the guard symbol for asynchronous recording/playback
    % 'asynchronous' means playback and recording may happen at different 
    % devices: for example, to measure mix distortion we play stimulus from
    % fireface and do mic recording at the DUT (with only file IO in most 
    % cases).
    %
    % we apply one guard symbol at both beginning and the end of the
    % session. visualized as:
    %
    % +-------+--------------------+-------+
    % | guard | actual test signal | guard |
    % +-------+--------------------+-------+
    %
    % NOTE:
    % The guard symbol shall contain not only the chirp but also a
    % sufficiently long pre and post silence. post silence is for the chirp
    % energy to decay, not to disturb the measurement; pre silence is to
    % prepare enough time for DUT audio framework context switching 
    % (products may have buggy glitches when change from system sound to
    % music). Our chirp signal is designed to have zero start and zero end
    % so it is safe to (pre/a)ppend zeros (no discontinuity issue).
    % 
    % 
    % typical paramters could be:
    %   f0 = 1000
    %   f1 = 1250
    %   elapse = 2.5
    %   fs = 48000
    x1 = exponential_sine_sweep(f0, f1, elapse, fs);
    x2 = -flipud(x1);
    y = [x1; x2(2:end)];
    % plot(x1, 'r'); hold on; plot(y, 'b--'); grid on
end

