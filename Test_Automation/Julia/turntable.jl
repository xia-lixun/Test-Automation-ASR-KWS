using SerialPorts


module Turntable

    function set_origin(id; baudrate = 19200)
        s = SerialPort(id, baudrate)
        write(s, "Get BaudRate" * string(Char(13)))
        fb = read(s, 6)
        info("baudrate: $fb")

        # disable analog input to prevent noise input (must)
        write(s, "Set AnalogInput OFF " * string(Char(13)))
        fb = read(s, 3);
        write(s, "Set PulseInput OFF " * string(Char(13)))
        fb = read(s, 3);
        write(s, "Set Torque 70.0 " * string(Char(13)))
        fb = read(s, 3);
        write(s, "Set SmartTorque ON " * string(Char(13)))
        fb = read(s, 3);
        write(s, "Set Velocity 2.00 " * string(Char(13)))
        fb = read(s, 3);
        write(s, "Set Origin " * string(Char(13)))
        fb = read(s, 3);
        close(s);
        return fb
    end

    function rotate(id, degree; direction="CCW", baudrate=19200)
        d = @sprintf("%3.1f", degree)
        for i = 1:5-length(d)
            d = "0" * d
        end
        s = SerialPort(id, baudrate)
        write(s, "GoTo " * direction * " +" * d * " " * string(Char(13)))
        fb = read(s, 3);
        close(s)
        return fb
    end
end