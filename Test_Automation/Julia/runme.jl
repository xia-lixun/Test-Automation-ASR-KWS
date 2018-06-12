using Tk
using Plots




include("auto.jl")
gr()
display(plot(zeros(100)))
auto(Tk.GetOpenFile())

