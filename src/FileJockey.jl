module FileJockey


# using Base.Filesystem
# using UUIDs
# using OrderedCollections
# using JSON


#include("conf.jl")


include("entries.jl")
using .Entries
include("entries.jl_exports")


include("entriesstats.jl")
using .EntriesStats
include("entriesstats.jl_exports")


include("filesys.jl")
using .FileSys
include("filesys.jl_exports")


using OrderedCollections
using CommandLiner
import .EntriesStats.Stats  # TODO modularize
include("check.jl")
# TODO factor Dupl out of Check

#include("exify.jl")




# function __init__()
#     Ext.initext()
# end




# Base.readline(x::FsFile) = readline(x.path)


# just forward splitext; this satisfies hasext interface!

# function hasext(fse::FsFile, ext::AbstractString)
#     _,fseext = splitext(fse.path)
#     return fseext == ext
# end
# hasext(ext::AbstractString) = x -> hasext(x, ext)
# export hasext

#CommandLiner.ext(x::AbstractEntry) = ext(x.path.s)


# TODO
#CommandLiner.save(io::IO, x::AbstractEntry) = save(io, path(x))











end # module

