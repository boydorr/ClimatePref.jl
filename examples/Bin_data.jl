addprocs(24)
@everywhere using StatsBase
@everywhere using Unitful
@everywhere using JuliaDB
using ClimatePref
using JLD
@everywhere import Unitful.ustrip
@everywhere ustrip(x::DataValues.DataValue) = ustrip(x.value)

dir = "../Worldclim/"
worldclim = map(searchdir(dir, "")) do str
    Symbol(str)
end
dir = "final/"
genera = searchdir(dir, ".csv")


bins = SharedArray{Int64, 3}(30, 7, length(genera))
splits = Dict(zip(worldclim, [collect(0:100:3000), collect(0:2300:70000), collect(-70:4:50),
    collect(-70:4:50), collect(-80:4:40), collect(0:0.13:4), collect(0:1:30)]))
@sync @parallel for i in eachindex(genera)
    genus = load(string("Genera/Worldclim/", split(genera[i], ".csv")[1]))
    hist = map( x-> fit(Histogram, ustrip.(select(genus, x)), splits[x]).weights,
        worldclim)
    bins[:, :, i] = hcat(hist...)
end
JLD.save("Binned_data.jld", "Binned_data", bins)
