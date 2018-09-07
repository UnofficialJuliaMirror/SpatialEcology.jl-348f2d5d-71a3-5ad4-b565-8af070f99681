
@enum coordstype auto griddata pointdata

# Insertion point for defining my own functions. They are mainly abstract
# over the full type and it's view, so another possibility would be to
# implement with unions
abstract type SESpatialData <: EcoBase.AbstractPlaces end
abstract type SELocations <: EcoBase.AbstractLocations end
abstract type SEPointData <: SELocations end
abstract type SEGrid <: EcoBase.AbstractGrid end
abstract type SEThings{D <: Real} <: EcoBase.AbstractThings end

abstract type AbstractComMatrix{ D<:Real } end


# I could implement sitestats as a Dict with several DataFrames to make space for big data sets, but I prefer to not do this now. Example below.

# I could do a lot more with immutable types if I had a clearer view/copy implementation
mutable struct GridTopology
    xmin::Number
    xcellsize::Number
    xcells::Int
    ymin::Number
    ycellsize::Number
    ycells::Int
end

mutable struct Bbox
    xmin::Number
    xmax::Number
    ymin::Number
    ymax::Number
end


# Do I need sitenames here? I think so, they should match those in sitestats, and be separate
mutable struct PointData <: SEPointData
    coords::Matrix{Float64}
    sitestats::DataFrames.DataFrame
    # inner constructor
    function PointData(coords, sitestats = DataFrames.DataFrame(id = 1:size(coords,1)))

        DataFrames.nrow(sitestats) == size(coords, 1) || throw(DimensionMismatch("Wrong number of rows in sitestat")) # a little check for the right number
        new(coords, sitestats)
    end
end


mutable struct GridData <: SEGrid
    indices::Matrix{Int}
    grid::GridTopology
    sitestats::DataFrames.DataFrame

    function GridData(indices, grid, sitestats = DataFrames.DataFrame(id = 1:size(coords,1)))
        DataFrames.nrow(sitestats) == size(indices, 1) || throw(DimensionMismatch("Wrong number of rows in sitestat")) # a little check for the right number
        new(indices, grid, sitestats)
    end
end

#it's a question how many of these structs need to be mutable, as opposed to when you want to allocate a new object
mutable struct ComMatrix{D} <: AbstractComMatrix{D}
    occurrences::SparseMatrixCSC{D}
    specnames::Vector{String}
    sitenames::Vector{String}
    ComMatrix{D}(occ::SparseMatrixCSC{D}, spn::Vector{String}, sin::Vector{String}) where {D} = new(dropzeros!(occ), spn, sin)
end

# likewise, do I need a specnames here? Should traits have a :series field (like now) or all matching be done on the specnames?
mutable struct SpeciesData{D} <: SEThings{D}
    commatrix::ComMatrix{D}
    traits::DataFrames.DataFrame
    function SpeciesData{D}(commatrix::ComMatrix{D}, traits::DataFrames.DataFrame) where D <: Real
        DataFrames.nrow(traits) ==  nspecies(commatrix) || throw(DimensionMismatch("Wrong number of species in traits"))
        new(commatrix, traits)
    end
end

# Not really sure what this type is for
mutable struct SiteData{S} <: SESpatialData where S <: SELocations
    site::S
end

abstract type SEAssemblage{D<:Real, P<:SELocations} <: EcoBase.AbstractAssemblage{D, SpeciesData, P} end

mutable struct Assemblage{D<:Real, P<:SELocations} <: SEAssemblage{D, P} # A type to keep subtypes together, ensuring that they are all aligned at all times
    site::P
    occ::SpeciesData

    # inner constructor
    function Assemblage{D, P}(site::P, occ::SpeciesData, com::ComMatrix{D}) where {P <: SELocations, D <: Real}
        size(occurrences(occ), 2) == size(coordinates(site), 1) || error("Length mismatch between occurrence matrix and coordinates")
        #TODO activate this # sitenames(occ) == sitenames(site) || error("sitenames do not match") #I need a constructor that matches them up actively
        new(site, occ)
    end
end
