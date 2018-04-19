function [a,b] = parabolic_fit_2(y)
    % given three points (x, y1) (x+1, y2) and (x+2, y3) there exists 
    % the only parabolic-2 fit y = ax^2+bx+c with a < 0. 
    % Therefore a global miximum can be found over the fit.
    %
    % To fit all thress points: let (x1 = 0, y1 = 0) then we have
    % other points (1, y2-y1) and (2, y3 - y1).
    %       0 = a * 0^2 + b * 0 + c => c = 0    (1)
    %       y2 - y1 = a + b                     (2)
    %       y3 - y1 = 4 * a + 2 * b             (3)
    %
    %       => a = y3/2 - y2 + y1/2             (4)
    %       => b = -y3/2 + 2*y2 - 3/2*y1        (5)
    a = 0.5 * y(3) - y(2) + 0.5 * y(1);
    b = -0.5 * y(3) + 2 * y(2) - 1.5 * y(1);
end



% validation
% y = [0.5; 1.0; 0.8];
% [a,b] = parabolic_fit_2(y);
% figure; plot([0;1;2], y-y(1), '+'); hold on; grid on;
% m = -0.5*b/a;
% ym = a * m^2 + b * m;
% plot(m, ym, 's');
% x = -1:0.001:5;
% plot(x,a*x.^2+b*x, '--');
