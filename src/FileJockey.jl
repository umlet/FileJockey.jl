module FileJockey


using Base.Filesystem
using UUIDs
using OrderedCollections
using JSON

#using Crayons
#using Crayons.Box


#using CommandLiner


# include("colorbox.jl")
# using .ColorBox
# include("colorbox.jl_exports")

#include("conf.jl")

include("entries.jl")
using .Entries
include("entries.jl_exports")

# include("ext.jl")
# using .Ext
# include("ext.jl_exports")

include("entriesstats.jl")
using .EntriesStats
include("entriesstats.jl_exports")



include("filesys.jl")
using .FileSys
include("filesys.jl_exports")



#include("check.jl")

#include("exify.jl")




# function __init__()
#     Ext.initext()
# end








# Base.readline(x::FsFile) = readline(x.path)

# function hasext(fse::FsFile, ext::AbstractString)
#     _,fseext = splitext(fse.path)
#     return fseext == ext
# end
# hasext(ext::AbstractString) = x -> hasext(x, ext)
# export hasext


#CommandLiner.ext(x::AbstractEntry) = ext(x.path.s)

#CommandLiner.save(io::IO, x::AbstractEntry) = save(io, path(x))











end # module
