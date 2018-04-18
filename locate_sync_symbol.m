function [y,lbs] = locate_sync_symbol(x, s, repeat)
    % x, s must be colume vector 
    x = x + rand(size(x)) * 10^(-100/20);
    
    peaks = zeros(repeat,1);
    lbs = zeros(repeat,1);
    
    m = length(s);
    if m > length(x)
        x = [x; zeros(m-length(x),1)];
    end
    n = length(x);
    y = zeros(m * repeat, 1);

    R = abs(xcorr(s, x));
    figure; plot(R);
    Rs = sort(R(local_maxima(R)), 'descend');
    figure; plot(Rs);
    if isempty(Rs) 
        return
    end

    % find the anchor point
    ploc = find(R==Rs(1));
    ploc = ploc(1);
    lb = n - ploc + 1;
    rb = min(lb + m - 1, length(x));
    y(1:1+rb-lb) = x(lb:rb);
    lbs(1) = lb;
    peaks(1) = ploc;
    ip = 1;
    
    if repeat > 1
        for i = 2:length(Rs)
            ploc = find(R==Rs(2));
            ploc = ploc(1);
            if sum(abs(peaks(1:ip) - ploc) > m) == ip
                ip = ip + 1;
                peaks(ip) = ploc;
                lb = n - ploc + 1;
                rb = min(lb + m - 1, length(x));
                y(1+(ip-1)*m : ip*m) = x(lb:rb);
                lbs(ip) = lb;
                if ip == repeat
                    break
                end
            end
        end
        peaks = sort(peaks);
        lbs = sort(lbs);
    end
end



function y = local_maxima(x)
% x must be colume vector
    gtl = [false; x(2:end) > x(1:end-1)];
    gtu = [x(1:end-1) >= x(2:end); false];
    y = gtl & gtu;
end



%% validation
% close all;
% clear all;
% clc;
% 
% signal = [exponential_sine_sweep(22,48000/2,10,48000) * 10^(-3/20); zeros(48000*5,1)];
% g = sync_symbol(800, 1200, 1, 48000) * (10^(-3/20));
% y = add_sync_symbol(signal, 3, g, 2, 48000);
% plot(y)
% [extracted, loc] = locate_sync_symbol(y, g, 2);
