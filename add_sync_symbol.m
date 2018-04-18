function y = add_sync_symbol(test_signal, time_context_switch, sync_symbol, time_symbol_decay, fs)
    % this function encode the content of the stimulus for playback if sync
    % (guard) symbols are needed for asynchronous operations.
    %
    % for example:
    %     signal = [randn(8192,1); zeros(65536,1)];
    %     g = sync_symbol(1000, 1250, 1, 48000) * (10^(-3/20));
    %     y = add_sync_symbol(signal, 3, g, 2, 48000);
    %
    % we now have a stimulus of pre-silence of 3 seconds, guard chirp of
    % length 1 second, chirp decaying marging of 2 seconds, a measurement
    % of random noise.
    n_ch = size(test_signal,2);
    ch_active = sum(test_signal,1) ~= 0;
    
    t_switch = zeros(round(time_context_switch * fs), n_ch);
    t_symbol = zeros(length(sync_symbol), n_ch);
    t_symbol(:,ch_active) = sync_symbol;
    t_decay = zeros(round(time_symbol_decay * fs), n_ch);
    
    y = [t_switch; t_symbol; t_decay; test_signal; t_symbol; t_decay];
end