# SPDX-License-Identifier: BSD-2-Clause

# Load in example data

using Unitful
using AxisArrays
using ClimatePref

import Unitful: °, °C, mm
import ArchGDAL
import Base.read
const AG = ArchGDAL

using JuliaDB
latlon = loadtable("/Users/claireh/Documents/PhD/Data/GBIF/test",
                   indexcols = [
                       :phylum,
                       :class,
                       :order,
                       :family,
                       :genus,
                       :species,
                       :scientificname
                   ],
                   type_detect_rows = 5000,
                   colparsers = Dict(:datasetkey => String,
                                     :occurrenceid => String,
                                     :gbifid => String,
                                     :locality => String,
                                     :publishingorgkey => String,
                                     :taxonkey => String,
                                     :institutioncode => String,
                                     :catalognumber => String,
                                     :recordnumber => String))

# Fetch coordinates

coords = select(latlon, (:decimallatitude, :decimallongitude))

dir = "/Users/claireh/Documents/PhD/Data/Worldclim/wc2.0_5m/"
folders = searchdir(dir, "wc2.0_5m")
datasets = extractfolders(dir, folders)

#files = map(searchdir(folder, ".tif")) do files
#    string(folder,files)
#end

b = Array{txy[1], 3}(Int64(txy[2]), Int64(txy[3]), 12);
map(eachindex(files)) do count
    a = Array{txy[1], 2}(txy[2], txy[3])
    read(files[count]) do dataset
        bd = AG.getband(dataset, 1)
        return AG.read!(bd, a)
    end
    return b[:, :, count] = a
end

lat, long = size(b, 1), size(b, 2);
step = 180.0° / long;
worldtavg = AxisArray(b[:, long:-1:1, :] * °C,
                      Axis{:latitude}((-180.0°):step:(180.0° - step / 2)),
                      Axis{:longitude}((-90.0°):step:(90.0° - step / 2)),
                      Axis{:time}((1month):(1month):(12month)));

if txy[1] <: AbstractFloat
    worldtavg[worldtavg .== worldtavg[Axis{:latitude}(0°),
    Axis{:longitude}(0°),
    Axis{:time}(1month)]] *= NaN
end;

# Check what one of the maps looks like
tavg = ustrip.(worldtavg)
using RCall
@rput tavg
R"library(fields); image.plot(tavg[,,1])"

# Find values at plant locations
coords = hcat([select(coords, :decimallatitude),
                  select(coords, :decimallongitude)]...) * °

#function closest_index(x, val::Vector{Float64})
#  return Vector{Int}(round.((val.*° .- x[1]) / step)) .+1
#end

#function extractvalues(x::Array{Float64, 1}, y::Array{Float64, 1},
#   array::AxisArray, dim::Unitful.Time)
#   all(x .< 180.0) && all(x .> -180.0) ||
#   error("X coordinate is out of bounds")
#   all(y .< 90.0) && all(y .> -90.0) ||
#   error("Y coordinate is out of bounds")
#   latval = closest_index(collect(axes(array)[1].val), x)
#   lonval = closest_index(collect(axes(array)[2].val), y)
#   return map((i, j) -> array[i, j, dim], latval, lonval)
#end

#results = extractvalues(coords[:, 2],coords[:, 1], worldtavg, 1month)
#latlon = pushcol(latlon, :tavg, results)
# Look at results for test species
#AaP = filter(p-> p[:species] == "Aa paleacea", latlon)
#select(AaP, :tavg)

results = extractvalues(coords[:, 2], coords[:, 1], files)

na_mean(x) = mean(x[.!isnan.(x)])
na_max(x) = maximum(x[.!isnan.(x)])
na_min(x) = minimum(x[.!isnan.(x)])
na_var(x) = var(x[.!isnan.(x)])

names = map(folders) do str
    return Symbol(split(str, "wc2.0_5m_")[2])
end
for i in 1:length(names)
    latlon = pushcol(latlon, names[i], mapslices(na_mean, results[i], 2)[:, 1])
end

groupby((na_mean, na_max, na_min, na_var), latlon,
        :species, select = :tavg)

tavg_spp = map(unique(select(latlon, :species))[2:7]) do spp
    select_spp = filter(p -> p[:species] == spp, latlon)
    return select(select_spp, :tavg)
end

using RCall
map(tavg_spp) do spp
    return ustrip(spp)
end
@rput res
R"library(ggplot2); par(mfrow=c(2,3))
hist(as.vector(res))"

# Look at results for test species
AaP = filter(p -> p[:species] == "Aa paleacea", latlon)
for names in unique(select(latlon, :species))
    spp = filter(p -> p[:species] == names, latlon)
    res = hcat(map(i -> select(AaP, Symbol("tavg$i")), 1:12)...)
    using RCall
    res = ustrip(res)
    @rput res
    R"library(ggplot2);
    qplot(as.vector(res), geom='histogram')"
end
res = hcat(map(i -> select(AaP, Symbol("tavg$i")), 1:12)...)
using RCall
res = ustrip(res)
@rput res
R"library(ggplot2);
qplot(as.vector(res), geom='histogram')"
