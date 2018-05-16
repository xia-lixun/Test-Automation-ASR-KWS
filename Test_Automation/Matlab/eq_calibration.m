function hFIR = eq_calibration(mix_spk, mix_mic, f_anchor, atten)

    fs = 48000;
    ess_f0 = 10;
    ess_f1 = fs/2;
    ess_time = 30;
    ess_decay = 5;
    %atten = -20;
    nfft = 65536;
    nnyq = nfft/2+1;
    
    %@ measure the un-eq'd impulse response in the anechoic
    [fundamental, harmonics, response_t] = impulse_response_exponential_sine_sweep(mix_spk, mix_mic, ess_f0, ess_f1, ess_time, ess_decay, 'asio', [1], [1], atten);
    
    
    %@ cut the window with the impulse response out for analysis
    p = 4.3e4;
    x = fundamental(p+1:p+nfft);
    
    x_spec = fft(x)./nfft;
    x_phase = angle(x_spec);
    f = ((0:nnyq-1)'./nfft).*fs;
    x_spec_db = 20*log10(abs(x_spec(1:nnyq)));
    
    % smooth and plots
    Noct = 3;
    x_spec_db_sm = smoothSpectrum(x_spec_db,f,Noct);
    subplot(2,1,1); plot(x); title('Un-EQ impulse response in time domain'); xlabel('samples'); grid on;
    subplot(2,1,2); semilogx(f,x_spec_db,f,x_spec_db_sm); title('impulse response in frequency domain, with 1/3 octave smoothing'); xlabel('Hz'); grid on
    
    
    % construct a minimal phase filter of the smoothed impulse response
    x_spec_sm = 10.^(x_spec_db_sm/20);
    x_spec_sm = [x_spec_sm; flipud(x_spec_sm(2:end-1))];
    x_spec_sm = x_spec_sm .* exp(x_phase*1i);
    x_sm = real(ifft(x_spec_sm));
    
    zs = fft(x_sm);
    figure(2); semilogx(f, 20*log10(abs(zs(1:nnyq))), 'k'); hold on;
    
    zms = mps(fft(x_sm));
    zm = real(ifft(zms)); % it is not symmetrical
    zms = fft(zm);
    semilogx(f, 20*log10(abs(zms(1:nnyq))), 'c--'); 
    xlabel('Hz'); title('minimal phase filter constructed based on smoothed frequency response'); grid on;
    
    
    % do the actual flatten work
    f1 = 22;
    f2 = 22000;
    f1 = ceil(f1 * nfft / fs);
    f2 = floor(f2 * nfft / fs);
    target = x_spec_db_sm(round(f_anchor * nfft / fs));
    H = zeros(nnyq,1);
    H(f1:f2) = target - x_spec_db_sm(f1:f2);
    H(1:f1-1) = 10;
    figure(3); semilogx(f, H, 'r'); hold on; 
    
    % compensation filter in time and frequency domain
    H = 10.^(H/20) * nfft;
    H = [H; flipud(H(2:end-1))];
    H = H .* exp(x_phase*1i);
    h = real(ifft(H));
    hs = fft(h)./nfft;
    semilogx(f, 20*log10(abs(hs(1:nnyq))), 'b--');
    
    hms = mps(fft(h));
    hm = real(ifft(hms)); % it is not symmetrical
    hms = fft(hm)./nfft;
    semilogx(f, 20*log10(abs(hms(1:nnyq))), 'c--'); 
    xlabel('Hz'); title('Compensation filter and its minimal-phase realization'); grid on;
    figure(2); semilogx(f, 20*log10(abs(hms(1:nnyq)))+x_spec_db_sm, 'b'); grid on;
    
    [fundamental, harmonics, response_t] = impulse_response_exponential_sine_sweep(mix_spk, mix_mic, ess_f0, ess_f1, ess_time, ess_decay, 'asio', hm/nfft, [1], atten);
    figure(4); freqz(fundamental, [1]);
    hFIR = hm / nfft;
end