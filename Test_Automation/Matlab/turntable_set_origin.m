function turntable_set_origin(serial_port)



s = serial(['COM' num2str(serial_port)], 'BaudRate', 19200, 'StopBits', 1, 'DataBits', 8);
fopen(s);


% sanity check
fprintf(s, '%s', ['Get BaudRate' char(13)]);
readback = fscanf(s,'%c',6)
if readback == '19200 '
    disp('baud rate ok');
end


% disable analog input (must) to prevent noise input
fprintf(s, '%s', ['Set AnalogInput OFF ' char(13)]);
readback = fscanf(s, '%c', 3);

fprintf(s, '%s', ['Set PulseInput OFF ' char(13)]);
readback = fscanf(s, '%c', 3);

fprintf(s, '%s', ['Set Torque 70.0 ' char(13)]);
readback = fscanf(s, '%c', 3);

fprintf(s, '%s', ['Set SmartTorque ON ' char(13)]);
readback = fscanf(s, '%c', 3);

fprintf(s, '%s', ['Set Velocity 2.00 ' char(13)]);
readback = fscanf(s, '%c', 3);


fprintf(s, '%s', ['Set Origin ' char(13)]);
readback = fscanf(s, '%c', 3);


fclose(s);


end