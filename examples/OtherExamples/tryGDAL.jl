# SPDX-License-Identifier: BSD-2-Clause

using Unitful
using AxisArrays
using ClimatePref

import Unitful: °, °C, mm
import ArchGDAL
import Base.read
const AG = ArchGDAL

txy = [Float32, Int32(1), Int32(1)];
file = "/Users/claireh/Documents/PhD/Data/Worldclim/wc2.0_5m_tavg/wc2.0_5m_tavg_06.tif"
read(file) do dataset
    txy[1] = AG.getdatatype(AG.getband(dataset, 1))
    txy[2] = AG.width(AG.getband(dataset, 1))
    txy[3] = AG.height(AG.getband(dataset, 1))
    return print(dataset)
end

a = Array{txy[1], 2}(txy[2], txy[3]);
read(file) do dataset
    bd = AG.getband(dataset, 1)
    return AG.read!(bd, a)
end;

lat, long = size(a);
step = 180.0° / long;
worldtavg6 = AxisArray(a[:, long:-1:1] * °C,
                       Axis{:latitude}((-180.0°):step:(180.0° - step / 2)),
                       Axis{:longitude}((-90.0°):step:(90.0° - step / 2)));

if txy[1] <: AbstractFloat
    worldtavg6[worldtavg6 .== worldtavg6[Axis{:latitude}(0°),
    Axis{:longitude}(0°)]] *= NaN
end;

# The whole world
# Note the array is transposed relative to the world, so longitude is columns, etc.
worldtavg6
# Somewhere in the sea
worldtavg6[Axis{:latitude}(0°), Axis{:longitude}(0°)]
# Somewhere in Uganda
worldtavg6[Axis{:latitude}(30°), Axis{:longitude}(0°)]

file = "/Users/claireh/Documents/PhD/Data/Worldclim/wc2.0_5m_prec/wc2.0_5m_prec_06.tif"
read(file) do dataset
    txy[1] = AG.getdatatype(AG.getband(dataset, 1))
    txy[2] = AG.width(AG.getband(dataset, 1))
    txy[3] = AG.height(AG.getband(dataset, 1))
    return print(dataset)
end

a = Array{txy[1], 2}(txy[2], txy[3]);
read(file) do dataset
    bd = AG.getband(dataset, 1)
    return AG.read!(bd, a)
end;

lat, long = size(a);
step = 180.0° / long;
worldprec6 = AxisArray(a[:, long:-1:1] * mm,
                       Axis{:latitude}((-180.0°):step:(180.0° - step / 2)),
                       Axis{:longitude}((-90.0°):step:(90.0° - step / 2)));

if txy[1] <: AbstractFloat
    worldprec6[worldprec6 .== worldprec6[Axis{:latitude}(0°),
    Axis{:longitude}(0°)]] *= NaN
end;

# The whole world
# Note the array is transposed relative to the world, so longitude is columns, etc.
worldprec6
# Somewhere in the sea # There is no NaN for integers, so you just end up with -32768...
worldprec6[Axis{:latitude}(0°), Axis{:longitude}(0°)]
# Somewhere in Uganda
worldprec6[Axis{:latitude}(30°), Axis{:longitude}(0°)]

# Or convert to Float32 (in this case) to fix this... though I can't
# remember how you decide where the land and non-land is in fact.
worldprec6f = AxisArray(a[:, long:-1:1] * 1.0f0mm,
                        Axis{:latitude}((-180.0°):step:(180.0° - step / 2)),
                        Axis{:longitude}((-90.0°):step:(90.0° - step / 2)));

worldprec6f[worldprec6f .== worldprec6f[Axis{:latitude}(0°),
Axis{:longitude}(0°)]] *= NaN;

# The whole world
# Note the array is transposed relative to the world, so longitude is columns, etc.
worldprec6f
# Somewhere in the sea # There is no NaN for integers
worldprec6f[Axis{:latitude}(0°), Axis{:longitude}(0°)]
# Somewhere in Uganda
worldprec6f[Axis{:latitude}(30°), Axis{:longitude}(0°)]

# Or you could redefine isnan for Int16s:
import Base.isnan
isnan(x::Int16) = x == Int16(-32768)

count(isnan, worldprec6f)
count(isnan, worldprec6)
# Though this may screw up other things, so you could create a new
# function which mostly just calls isnan instead (and delete the above)
issea(x::Real) = isnan(x)
issea(x::Int16) = x == Int16(-32768)
issea(x::Quantity) = issea(x.val)
count(issea, worldprec6f)
count(issea, worldprec6)

# Obviously, it's easy to turn everything to Float64, say, where you
# create the AxisArray if that makes more sense, and then everything
# will just be NaN.

# Better solution to read everything in one go...
file = "/Users/claireh/Documents/PhD/Data/Worldclim/wc2.0_5m_tavg/wc2.0_5m_tavg_12.tif"
TYPE = °C
worldtavg12 = read(file) do dataset
    bd = AG.getband(dataset, 1)
    a = AG.read(bd)
    T = AG.getdatatype(bd)
    lat, long = size(a)
    step = 180.0° / long
    aa = AxisArray(a[:, long:-1:1] * TYPE,
                   Axis{:latitude}((-180.0°):step:(180.0° - step / 2)),
                   Axis{:longitude}((-90.0°):step:(90.0° - step / 2)))
    # Is there a NaN for this numeric type?
    if T <: AbstractFloat
        # If so take the value from 0°E at the equator as a NaN since
        # it's in the sea
        aa[aa .== aa[Axis{:latitude}(0°),
        Axis{:longitude}(0°)]] *= convert(T, NaN)
    end
    return aa
end

# Somewhere in the sea
worldtavg12[Axis{:latitude}(0°), Axis{:longitude}(0°)]
# Somewhere in Uganda
worldtavg12[Axis{:latitude}(30°), Axis{:longitude}(0°)]

nh = worldtavg6[Axis{:longitude}(0.0° .. 90.0°)] -
     worldtavg12[Axis{:longitude}(0.0° .. 90.0°)];
# The northern hemisphere is warmer in the summer
mean(nh[.!isnan.(nh)])

sh = worldtavg12[Axis{:longitude}(-90.0° .. 0.0°)] -
     worldtavg6[Axis{:longitude}(-90.0° .. 0.0°)];
# So is the southern hemisphere!
mean(sh[.!isnan.(sh)])

# Since there's more land in the northern hemisphere, June's warmer...
mean((worldtavg6 .- worldtavg12)[.!isnan.(worldtavg6)])
