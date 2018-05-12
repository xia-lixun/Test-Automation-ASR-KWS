function turntable_rotate(serial_port, degree, direction)
% degree with precision up to one decimal
% direction = 'CCW' or 'CW'

dg = sprintf('%3.1f', degree);
for i = 1:5-length(dg)
    dg = ['0', dg];
end

s = serial(['COM' num2str(serial_port)], 'BaudRate', 19200, 'StopBits', 1, 'DataBits', 8);
fopen(s);

fprintf(s, ['GoTo ', direction, ' +', dg, ' ', char(13)]);
readback = fscanf(s, '%c', 3);

fclose(s);


end



