using Tk
using Plots
include("auto.jl")

display(plot(zeros(100)))
auto(Tk.GetOpenFile())

