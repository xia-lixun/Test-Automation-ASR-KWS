include("score_asr.jl")



function singlechannel_asr(path)

    a = list(path, t=".wav")
    open("report.txt", "w") do fid
    	for i in a
	    s = score(i,1)
	    write(fid, i * "    " * s[1:end-1] * "\n")
            info("$i ok")
    	end
    end
end



function list(path::String; t = "")
    
    x = Array{String,1}()
    for (root, dirs, files) in walkdir(path)
        for dir in dirs
            isempty(t) && push!(x, dir)
        end
        for file in files
            !isempty(t) && lowercase(file[end-length(t)+1:end])==lowercase(t) && push!(x, joinpath(root, file))
        end
    end
    x
end






function mapreduce_asr(path, n)

    a = list(path, t=".wav")
    addprocs(n)
    for i in workers()
        remotecall_fetch(include, i, "score.jl")
    end
    info("parallel session loaded")

    pmap(pscore, a)
    
    open("report.txt", "w") do rid
        for i in workers()
            s = open("mapreduce-asr-$(i).txt", "r") do fid
                readlines(fid)
            end
            for k in s
               write(rid, k*"\n")
            end
            rm("mapreduce-asr-$(i).txt")
        end
    end
    rmprocs(workers())
    nothing
end
