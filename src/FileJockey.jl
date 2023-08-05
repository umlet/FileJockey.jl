module FileJockey


using Base.Filesystem
using UUIDs
using OrderedCollections
using JSON

using Crayons
using Crayons.Box


using CommandLiner


include("conf.jl")

include("entries.jl")
include("trees.jl")

include("stats.jl")
include("pprint.jl")

include("check.jl")

include("exify.jl")

include("ext.jl")



function __init__()
    #@info "Initializing known file extensions"
    initext()
end








# Base.readline(x::FsFile) = readline(x.path)

# function hasext(fse::FsFile, ext::AbstractString)
#     _,fseext = splitext(fse.path)
#     return fseext == ext
# end
# hasext(ext::AbstractString) = x -> hasext(x, ext)
# export hasext


CommandLiner.ext(x::AbstractEntry) = ext(x.path.s)

CommandLiner.save(io::IO, x::AbstractEntry) = save(io, path(x))











end # module
