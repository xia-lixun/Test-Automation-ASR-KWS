function dynamic_schedule(f, list)
    np = nprocs()
    n = length(list)
    result = Vector{Any}(n)

    i = 1
    nextidx() = (idx = i; i += 1; idx )

    @sync for p = 1:np
        if p != myid() || np == 1
            @async while true
                idx = nextidx()
                idx > n && break
                println("p,idx: $p, $idx")
                result[idx] = remotecall_fetch(f, p, list[idx])
            end
        end
    end
    result
end