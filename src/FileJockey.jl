module FileJockey


using Base.Filesystem
using OrderedCollections
using Crayons
using Crayons.Box


using Juliettine


include("conf.jl")

include("entries.jl")
include("trees.jl")

include("stats.jl")

include("pprint.jl")

include("check.jl")


# include("./ext.jl")



# function __init__()
#     @info "Initializing known file extensions"
#     initext()
# end








# Base.readline(x::FsFile) = readline(x.path)

# function hasext(fse::FsFile, ext::AbstractString)
#     _,fseext = splitext(fse.path)
#     return fseext == ext
# end
# hasext(ext::AbstractString) = x -> hasext(x, ext)
# export hasext


Juliettine.ext(x::AbstractEntry) = ext(x.path.s)













end # module
