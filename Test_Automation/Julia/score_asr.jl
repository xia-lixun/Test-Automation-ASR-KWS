



function score(file, channel::Int)

    done = false
    congestion = 0
    s = ""
    
    try
	while !done 
            s = readstring(`/home/lixun/dummy_client_package/dummy_client $(file) ENG$(channel)`)
            retry_condition = ismatch(Regex("Asif asif asif"), s) || 
                              ismatch(Regex("open: session creation failed"), s) ||
                              ismatch(Regex("send: connection is not established"), s)
            if retry_condition
		info("connection: retry")
                done = false
                congestion += 1
                congestion > 5 && error("network failure multiple times")
            else
             	done = true
            end
        end
    catch
        error("forgot to load lib env?")
    end
    s
end



function pscore(file)

    pid = myid()
    wid = workers()
    wid = sort(wid)
    channel = find(x->x==pid, wid)[1]
    assert(in(channel,collect(1:8)))

    s = score(file, channel)
    
    open("mapreduce-asr-$(pid).txt", "a") do fid
        write(fid, file * "    " * s)
    end
    nothing
end
