module Heartbeat
# Network Controlled Relay IP: 192.168.1.199:12345 (client)
# Host IP: 192.168.1.190:6000 (server)

    function dutreset_server()

        op = Array{String,1}()
        #@async begin
            server = listen(IPv4(0), 6000)
            #while true
                sock = accept(server)
                write(sock, [0x41 0x54 0x0D 0x0A])
                status = readline(sock)
                push!(op, "AT: $status")

                write(sock, [0x41 0x54 0x2B 0x4C 0x49 0x4E 0x4B 0x53 0x54 0x41 0x54 0x3D 0x3F 0x0D 0x0A])
                status = readline(sock)
                push!(op, "AT+LINKSTAT: $status")
                
                write(sock, [0x41 0x54 0x2B 0x4D 0x4F 0x44 0x45 0x4C 0x3D 0x3F 0x0D 0x0A])
                status = readline(sock)
                push!(op, "AT+MODEL: $status")

                strtemp = "Init Status: "
                write(sock, [0x41 0x54 0x2B 0x53 0x54 0x41 0x43 0x48 0x30 0x3D 0x3F 0x0D 0x0A])
                for i = 1:4
                    status = readline(sock)
                    strtemp = strtemp * status
                end
                push!(op, strtemp)

                write(sock, [0x41 0x54 0x2B 0x53 0x54 0x41 0x43 0x48 0x30 0x3D 0x30 0x0D 0x0A])
                status = readline(sock)
                push!(op, "Turn off all switches: $status")
                sleep(5)


                write(sock, [0x41 0x54 0x2B 0x53 0x54 0x41 0x43 0x48 0x31 0x3D 0x31 0x0D 0x0A])
                status = readline(sock)
                push!(op, "Turn on switch 1: $status")
                sleep(20)


                write(sock, [0x41 0x54 0x2B 0x53 0x54 0x41 0x43 0x48 0x32 0x3D 0x31 0x0D 0x0A])
                status = readline(sock)
                push!(op, "Turn on switch 2: $status")
                
                
                strtemp = "Status: "
                write(sock, [0x41 0x54 0x2B 0x53 0x54 0x41 0x43 0x48 0x30 0x3D 0x3F 0x0D 0x0A])
                for i = 1:4
                    status = readline(sock)
                    strtemp = strtemp * status
                end
                push!(op, strtemp)
                close(sock)            
            #end
        #end
        return op
    end

    function dutreset_client()

        op = Array{String,1}()
        sock = connect(ip"192.168.1.199", 12345)

        write(sock, [0x41 0x54 0x0D 0x0A])
        status = readline(sock)
        push!(op, "AT: $status")

        write(sock, [0x41 0x54 0x2B 0x4C 0x49 0x4E 0x4B 0x53 0x54 0x41 0x54 0x3D 0x3F 0x0D 0x0A])
        status = readline(sock)
        push!(op, "AT+LINKSTAT: $status")
        
        write(sock, [0x41 0x54 0x2B 0x4D 0x4F 0x44 0x45 0x4C 0x3D 0x3F 0x0D 0x0A])
        status = readline(sock)
        push!(op, "AT+MODEL: $status")

        strtemp = "Init Status: "
        write(sock, [0x41 0x54 0x2B 0x53 0x54 0x41 0x43 0x48 0x30 0x3D 0x3F 0x0D 0x0A])
        for i = 1:4
            status = readline(sock)
            strtemp = strtemp * status
        end
        push!(op, strtemp)

        write(sock, [0x41 0x54 0x2B 0x53 0x54 0x41 0x43 0x48 0x30 0x3D 0x30 0x0D 0x0A])
        status = readline(sock)
        push!(op, "Turn off all switches: $status")
        sleep(5)

        write(sock, [0x41 0x54 0x2B 0x53 0x54 0x41 0x43 0x48 0x31 0x3D 0x31 0x0D 0x0A])
        status = readline(sock)
        push!(op, "Turn on switch 1: $status")
        sleep(20)

        write(sock, [0x41 0x54 0x2B 0x53 0x54 0x41 0x43 0x48 0x32 0x3D 0x31 0x0D 0x0A])
        status = readline(sock)
        push!(op, "Turn on switch 2: $status")
                
        strtemp = "Status: "
        write(sock, [0x41 0x54 0x2B 0x53 0x54 0x41 0x43 0x48 0x30 0x3D 0x3F 0x0D 0x0A])
        for i = 1:4
            status = readline(sock)
            strtemp = strtemp * status
        end
        push!(op, strtemp)
        close(sock)            
        return op
    end


end