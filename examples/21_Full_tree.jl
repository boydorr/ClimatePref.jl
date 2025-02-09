# SPDX-License-Identifier: BSD-2-Clause

using PhyloNetworks
using GLM
using JuliaDB
using JuliaDBMeta
using Unitful
using ClimatePref
using ClimatePref.Unitful
using StatsBase
using JLD
using OnlineStats
using Unitful.DefaultSymbols
using Statistics
using DataFrames
@everywhere using Unitful
@everywhere using Unitful.DefaultSymbols
@everywhere using OnlineStats
@everywhere using StatsBase

# Load tree
tree = readTopology("Qian2016.tree")
tipnames = tipLabels(tree)
tip_names = join.(split.(tipnames, "_"), " ")

# Load GBIF data
gbif = JuliaDB.load("CERA_JOIN_SIMPLE")
spp = collect(JuliaDB.select(gbif, :SppID))
numspp = unique(spp)

# Load Species names
spp_names = JLD.load("Species_names.jld", "spp_names")
spp_ids = JLD.load("Species_names.jld", "spp_ids")
sppdict = Dict(zip(spp_ids, spp_names))
iddict = Dict(zip(spp_names, spp_ids))
spp_names = [sppdict[i] for i in numspp]

# Get top 5000 most common species
cross_species = spp_names ∩ tip_names
cross_ids = [iddict[i] for i in cross_species]

# Filter GBIF data for common species and delete from tree
gbif_fil = filter(g -> g.SppID in cross_ids, gbif)
missing_species = setdiff(tip_names, cross_species)
for i in eachindex(missing_species)
    deleteleaf!(tree, join(split(missing_species[i], " "), "_"))
end

### LAMBDAS FOR RAW DATA ###

# Group gbif data by Species ID and get mean and percentiles of data
phylo_traits = @groupby gbif_fil :SppID {tmin = mean(ustrip(:tmin)),
                                         tmin10 = percentile(ustrip(:tmin), 10),
                                         tmax = mean(ustrip(:tmax)),
                                         tmax90 = percentile(ustrip(:tmax), 90),
                                         tmean = mean(ustrip(:tmean)),
                                         trng = mean(ustrip(:trng)),
                                         stl1 = mean(ustrip(:stl1mean)),
                                         stl2 = mean(ustrip(:stl2mean)),
                                         stl3 = mean(ustrip(:stl3mean)),
                                         stl4 = mean(ustrip(:stl4mean)),
                                         swvl1 = mean(ustrip(:swvl1mean)),
                                         swvl2 = mean(ustrip(:swvl2mean)),
                                         swvl3 = mean(ustrip(:swvl3mean)),
                                         swvl4 = mean(ustrip(:swvl4mean)),
                                         ssr = mean(ustrip(:ssrmean)),
                                         tp = mean(ustrip(:tpmean))}

# Add in tip names to data and save
trait_ids = collect(JuliaDB.select(phylo_traits, :SppID))
new_cross_species = [sppdict[i] for i in trait_ids]
phylo_traits = pushcol(phylo_traits, :tipNames,
                       join.(split.(new_cross_species, " "), "_"))
JuliaDB.save(phylo_traits, "Phylo_traits")

# Convert to dataframe
dat = DataFrame(collect(phylo_traits))

# Fit lambda models and save
lambdas = fitLambdas(tree, dat, names(dat)[2:(end - 1)])
JLD.save("Lambdas_common_full.jld", "lambdas", lambdas)

mins = [
    197.0K,
    197.0K,
    197.0K,
    0K,
    197.0K,
    197.0K,
    197.0K,
    197.0K,
    0.0m^3,
    0.0m^3,
    0.0m^3,
    0.0m^3,
    0.0J / m^2,
    0.0m
]
maxs = [
    320.0K,
    320.0K,
    320.0K,
    80K,
    320.0K,
    320.0K,
    320.0K,
    320.0K,
    1.0m^3,
    1.0m^3,
    1.0m^3,
    1.0m^3,
    3.0e7J / m^2,
    0.1m
]

# Load EVi and gbif counts
total_evi_counts = JLD.load("Total_evi_counts.jld", "total")
total_gbif_counts = JLD.load("Total_gbif_counts.jld", "total")

# Adjustment - remove NaNs and Infs
adjustment = total_gbif_counts ./ total_evi_counts
adjustment[isnan.(adjustment)] .= 1
adjustment[isinf.(adjustment)] .= 1

# Apply adjustment to data grouped by Species ID
phylo_traits_adj = @groupby gbif_fil :SppID {tmin = adjust(uconvert.(K, :tmin),
                                                           adjustment[:, 1],
                                                           mins[1], maxs[1]),
                                             tmax = adjust(uconvert.(K, :tmax),
                                                           adjustment[:, 2],
                                                           mins[2], maxs[2]),
                                             tmean = adjust(uconvert.(K,
                                                                      :tmean),
                                                            adjustment[:, 3],
                                                            mins[3], maxs[3]),
                                             trng = adjust(uconvert.(K, :trng),
                                                           adjustment[:, 4],
                                                           mins[4], maxs[4]),
                                             stl1 = adjust(uconvert.(K,
                                                                     :stl1mean),
                                                           adjustment[:, 5],
                                                           mins[5], maxs[5]),
                                             stl2 = adjust(uconvert.(K,
                                                                     :stl2mean),
                                                           adjustment[:, 6],
                                                           mins[6], maxs[6]),
                                             stl3 = adjust(uconvert.(K,
                                                                     :stl3mean),
                                                           adjustment[:, 7],
                                                           mins[7], maxs[7]),
                                             stl4 = adjust(uconvert.(K,
                                                                     :stl4mean),
                                                           adjustment[:, 8],
                                                           mins[8], maxs[8]),
                                             swvl1 = adjust(:swvl1mean,
                                                            adjustment[:, 9],
                                                            mins[9], maxs[9]),
                                             swvl2 = adjust(:swvl2mean,
                                                            adjustment[:, 10],
                                                            mins[10], maxs[10]),
                                             swvl3 = adjust(:swvl3mean,
                                                            adjustment[:, 11],
                                                            mins[11], maxs[11]),
                                             swvl4 = adjust(:swvl4mean,
                                                            adjustment[:, 12],
                                                            mins[12], maxs[12]),
                                             ssr = adjust(:ssrmean,
                                                          adjustment[:, 13],
                                                          mins[13], maxs[13]),
                                             tp = adjust(:tpmean,
                                                         adjustment[:, 14],
                                                         mins[14], maxs[14])}
trait_ids = collect(JuliaDB.select(phylo_traits_adj, :SppID))
new_cross_species = [sppdict[i] for i in trait_ids]
phylo_traits_adj = pushcol(phylo_traits_adj, :tipNames,
                           join.(split.(new_cross_species, " "), "_"))

# Convert to dataframe
dat = DataFrame(collect(phylo_traits_adj))

# Fit lambda models and save
lambdas = fitLambdas(tree, dat, names(dat)[2:(end - 1)], 0.1)
JLD.save("Lambdas_effort_full.jld", "lambdas", lambdas)

using JLD
using Plots
using Statistics
import Plots.px
pyplot()
lambdas_1 = JLD.load("data/Lambdas_common_full.jld", "lambdas")
lambdas_2 = JLD.load("data/Lambdas_effort_full.jld", "lambdas")
subset = [[1, 3, 5]; collect(7:16)]
subset2 = [collect(1:3); collect(5:14)]

x = ["Raw", "Effort"]
y = [
    "tmin",
    "tmax",
    "tmean",
    "stl1",
    "stl2",
    "stl3",
    "stl4",
    "swvl1",
    "swvl2",
    "swvl3",
    "swvl4",
    "ssr",
    "tp"
]
lambdas = hcat(lambdas_1[subset], lambdas_2[subset2])
heatmap(y, x, transpose(lambdas),
        seriescolor = cgrad([:red, :white, :blue], [0, mean(lambdas), 1]),
        colorbar = :legend, legend = :top, size = (900, 400),
        guidefontsize = 12, tickfontsize = 12, xrotation = 90,
        clim = (0, 1), colorbar_title = "λ", layout = (@layout [a; b]),
        title = "A", title_loc = :left, titlefontsize = 16)
#Plots.pdf("examples/FullLambda.pdf")

pyplot()
lambdas_1 = JLD.load("data/Lambdas_common.jld", "lambdas")
lambdas_2 = JLD.load("data/Lambdas_EVI_adjust.jld", "lambdas")
subset = [[1, 3, 5]; collect(7:16)]
subset2 = [collect(1:3); collect(5:14)]

x = ["Raw", "Effort"]
y = [
    "tmin",
    "tmax",
    "tmean",
    "stl1",
    "stl2",
    "stl3",
    "stl4",
    "swvl1",
    "swvl2",
    "swvl3",
    "swvl4",
    "ssr",
    "tp"
]
lambdas = hcat(lambdas_1[subset], lambdas_2[subset2])
heatmap!(y, x, transpose(lambdas),
         seriescolor = cgrad([:red, :white, :blue], [0, mean(lambdas), 1]),
         colorbar = :legend, legend = :top, size = (900, 400),
         guidefontsize = 12, tickfontsize = 12, xrotation = 90,
         clim = (0, 1), colorbar_title = "λ", subplot = 2, title = "B",
         title_loc = :left, titlefontsize = 16)
Plots.pdf("examples/FullLambda.pdf")
