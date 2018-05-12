# Network Controlled Relay IP: 192.168.1.199:12345 (client)
# Host IP: 192.168.1.190:6000 (server)

function power_cycle(port)

    #@async begin
        server = listen(IPv4(0), port)
        #while true
            sock = accept(server)
            println("AT:")
            write(sock, [0x41 0x54 0x0D 0x0A])
            status = readline(sock)
            println(status)

            println("AT+LINKSTAT:")
            write(sock, [0x41 0x54 0x2B 0x4C 0x49 0x4E 0x4B 0x53 0x54 0x41 0x54 0x3D 0x3F 0x0D 0x0A])
            status = readline(sock)
            println(status)
            
            println("AT+MODEL:")
            write(sock, [0x41 0x54 0x2B 0x4D 0x4F 0x44 0x45 0x4C 0x3D 0x3F 0x0D 0x0A])
            status = readline(sock)
            println(status)

            println("Init Status:")
            write(sock, [0x41 0x54 0x2B 0x53 0x54 0x41 0x43 0x48 0x30 0x3D 0x3F 0x0D 0x0A])
            for i = 1:4
                status = readline(sock)
                println(status)
            end

            println("Turn off all switches:")
            write(sock, [0x41 0x54 0x2B 0x53 0x54 0x41 0x43 0x48 0x30 0x3D 0x30 0x0D 0x0A])
            status = readline(sock)
            println(status)
            
            sleep(5)

            println("Turn on switch 1:")
            write(sock, [0x41 0x54 0x2B 0x53 0x54 0x41 0x43 0x48 0x31 0x3D 0x31 0x0D 0x0A])
            status = readline(sock)
            println(status)
            
            sleep(20)

            println("Turn on switch 2:")
            write(sock, [0x41 0x54 0x2B 0x53 0x54 0x41 0x43 0x48 0x32 0x3D 0x31 0x0D 0x0A])
            status = readline(sock)
            println(status)
            
            println("Status:")
            write(sock, [0x41 0x54 0x2B 0x53 0x54 0x41 0x43 0x48 0x30 0x3D 0x3F 0x0D 0x0A])
            for i = 1:4
                status = readline(sock)
                println(status)
            end
            close(sock)            
        #end
    #end
end

power_cycle(6000)




