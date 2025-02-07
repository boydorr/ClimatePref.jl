# SPDX-License-Identifier: BSD-2-Clause

############### TEST DATA FROM ERA INTERIM - TEMPERATURE AT 2M #################
############# LOADED AND VALUES EXTRACTED FOR SUBSET OF GBIF DATA ##############

using NetCDF
using Unitful
using Unitful.DefaultSymbols
using AxisArrays
using ClimatePref.Units
using ClimatePref
#using RCall
using JuliaDB
using Plots
pyplot()

# Load example dataset downloaded from EMCWF
ncinfo("/Users/claireh/Downloads/test.nc")

test = readERA("/Users/claireh/Downloads/test.nc", "t2m",
               collect((1.0month):(1month):(2month)))

### Load world temperature data downloaded from ERA interim ###

# Basic info about data
ncinfo("data/era_interim_moda_1990")
# Extract data for t2m parameter - temperature at 2m
dir1 = "data/era_interim_moda_1980"
tempax1 = readERA(dir1, "t2m", collect((1.0month):(1month):(10year)))
dir2 = "data/era_interim_moda_1990"
tempax2 = readERA(dir2, "t2m", collect((121month):(1month):(20year)))
dir3 = "data/era_interim_moda_2000"
tempax3 = readERA(dir3, "t2m", collect((241month):(1month):(30year)))
dir4 = "data/era_interim_moda_2010"
tempax4 = readERA(dir4, "t2m", collect((361month):(1month):(38year)))

tempax = ERA(cat(dims = 3, tempax1.array, tempax2.array, tempax3.array,
                 tempax4.array))

# Collect lats and lons from array
lon = ustrip(AxisArrays.axes(tempax.array, 1).val)
lat = ustrip(AxisArrays.axes(tempax.array, 2).val)
# Strip array of units to plot
tempsC = ustrip(Array(tempax.array))
# Plot array as pdf with world shapefile on top
using RCall
@rput tempsC
@rput lat;
@rput lon;
R"pdf(file='plots/testERAint.pdf', paper = 'a4r', height= 8.27, width=11.69 )
library(rgdal)
library(fields)
world = readOGR('data/ne_10m_land/ne_10m_land.shp', layer='ne_10m_land')
image.plot(lon, lat, tempsC[,,1], xlab='', ylab='')
plot(world, add = T)
dev.off()"

# Load data for land cover
file = "data/World.tif"
world = readfile(file)
wrld = ustrip.(world)
@rput wrld
R"image(wrld)"

# Use to mask out oceans from t2m array and plot as PDF
mask = isnan.(world)
tempsC[find(mask)] = NaN
@rput tempsC
@rput lat;
@rput lon;
R"pdf(file='plots/testERAint_mask.pdf', paper = 'a4r', height= 8.27, width=11.69 )
library(rgdal)
library(fields)
world = readOGR('data/ne_10m_land/ne_10m_land.shp', layer='ne_10m_land')
image.plot(lon, lat, tempsC[,,1], xlab='', ylab='')
plot(world, add = T)
dev.off()"

# Load GBIF data in order to extract t2m values from GPS locations
sol = load("/Users/claireh/Documents/PhD/Data/GBIF/Solanum/output")
sol = pushcol(sol, :id, collect(1:215440))
coords = select(sol, (:decimallatitude, :decimallongitude))
x = select(coords, :decimallongitude);
y = select(coords, :decimallatitude);
years = select(sol, :year)
vals = extractvalues(x * °, y * °, years, tempax, 1980, 2000)

@rput x;
@rput y;
R"jpeg(file='plots/EAG.jpeg', height= 595, width=842)
library(rgdal)
library(fields)
world = readOGR('data/ne_10m_land/ne_10m_land.shp', layer='ne_10m_land')
image.plot(lon, lat, tempsC[,,1], xlab='', ylab='')
points(x, y, pch='.')
plot(world, add = T)
dev.off()"

# Try plotting histograms of values for subset of species
spp_names = [
    "Solanum dulcamara",
    "Solanum nigrum",
    "Solanum americanum",
    "Solanum parvifolium"
]
for i in eachindex(spp_names)
    spp = filter(p -> p[:species] == spp_names[i], sol)
    ids = select(spp, :id)
    subvals = ustrip.(vals[ids])
    res = vcat(subvals...)
    res = res[.!isnan.(res)]
    if i == 1
        display(histogram(res, bins = -20:2:30, grid = false,
                          xlabel = "Temperature °C", label = "",
                          layout = (2, 2),
                          title = spp_names[i]))
    else
        display(histogram!(res, bins = -20:2:30, grid = false,
                           xlabel = "Temperature °C", label = "", subplot = i,
                           title = spp_names[i]))
    end
end

### COMPARE DIRECTLY WITH WORLDCLIM ###
dir = "/Users/claireh/Documents/PhD/Data/Worldclim/wc2.0_5m/wc2.0_5m_tavg"
# Extract worldclim data for average temperature
tavg = readworldclim(dir)
vals = extractvalues(x * °, y * °, tavg, (1month):(1month):(12month))

# Run through same species and plot histograms
for i in spp_names
    spp = filter(p -> p[:species] == i, sol)
    ids = select(spp, :id)
    subvals = ustrip.(vals[ids, :])
    res = vcat(subvals...)
    res = res[!isnan.(res)]

    @rput res
    @rput i
    R"library(ggplot2);library(cowplot);library(gridExtra)
    q = qplot(as.vector(res), geom='histogram',
                xlab ='Average temperature (deg C)')+
                stat_bin(breaks=seq(-20, 35, by=2.5))
    pdf(file=paste('plots/worldclim_',i,'.pdf', sep=''), paper = 'a4r', height= 8.27, width=11.69 )
    print(q)
    dev.off()
    "
end

# Load GBIF data in order to extract t2m values from GPS locations
#sol = JuliaDB.load("/Users/claireh/Documents/PhD/Data/GBIF/Solanum/output")
#sol = pushcol(sol, :id, collect(1:215440))
#coords = select(sol, (:decimallatitude, :decimallongitude))
#x = select(coords, :decimallongitude); y = select(coords, :decimallatitude)
#years = select(sol, :year)
#vals = extractvalues(x * °, y * °, years, temp, 1980, 2000)
#sol = pushcol(sol, :val, ustrip.(vals))
#JuliaDB.save(sol, "/Users/claireh/Documents/PhD/Data/GBIF/Solanum/era_output")
