function play = exponential_sine_sweep(f_start, f_stop, time, sample_rate)
    %Exponential sine sweep signal generation
    sps = round(time * sample_rate);

    mul = (f_stop / f_start) ^ (1 / sps);
    delta = (2*pi) * f_start / sample_rate;
    play = zeros(sps,1);

    %calculate the phase increment gain
    %closed form --- [i.play[pauseSps] .. i.play[pauseSps + chirpSps - 1]]
    kbn_error = 0.0;
	phi = 0.0;
    for k = 1:sps
        play(k) = phi;
        [phi, kbn_error] = sum_kbn(delta, phi, kbn_error);
        delta = delta * mul;
    end
    
    %the exp sine sweeping time could be non-integer revolutions of 2 * pi for phase phi.
    %Thus we find the remaining and cut them evenly from each sweeping samples as a constant bias.
	delta = -mod(play(sps), 2*pi);
	delta = delta / (sps - 1);
    kbn_error = 0.0;
	phi = 0.0;
    for k = 1:sps
        play(k) = sin(play(k) + phi);
        [phi, kbn_error] = sum_kbn(delta, phi, kbn_error);
    end
    
end
