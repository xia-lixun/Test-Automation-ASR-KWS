function essinv = inverse_exponential_sine_sweep(ess, f_start, f_stop)
    
    slope = 20*log10(0.5);
    attn = slope.*log2(f_stop/f_start)/(length(ess) - 1);
    gain = 0;

    essinv = flipud(ess);
    for i = 1:length(essinv)
        essinv(i) = essinv(i) * (10.^(gain/20+1));
        gain = gain + attn;
    end
    %figure; plot(essinv); grid;

    n1 = length(ess);
    n2 = length(essinv);
    assert(n1 == n2);
    %figure; plot(abs(fft(ess)) .* abs(fft(essinv))); grid on;
end