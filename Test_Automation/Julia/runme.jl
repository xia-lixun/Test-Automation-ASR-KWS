using Tk
using Plots
include("auto.jl")


plot(zeros(100))
jsonconf = Tk.GetOpenFile()
auto(jsonconf)

