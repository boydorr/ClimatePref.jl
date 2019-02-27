module ClimatePref

using Requires
function __init__()
    @require PyCall="438e738f-606a-5dbb-bf0a-cddfbfd45ab0" begin
        println("Creating ECMWF interface ...")
        include("ERA_interim_tools.jl")
        export retrieve_era_interim
    end
end

include("ClimateTypes.jl")
export Worldclim, Bioclim, ERA, CERA, Reference

include("ReadData.jl")
export read, searchdir, readworldclim, readbioclim, readERA, readCERA, readfile

include("ExtractClimate.jl")
export extractvalues

include("DataCleaning.jl")
export create_reference, gardenmask, genus_worldclim_average,
    genus_worldclim_monthly, upresolution, getprofile

include("PhyloModels.jl")
export Brownian, Lambda, fitBrownian, fitLambda, varcovar

end
