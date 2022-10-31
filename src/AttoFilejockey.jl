module AttoFilejockey


# from fsentries
export PathCanon, FsEntryCanon
export AbstractFsEntry
export FileEntry, DirEntry, FsSymlink, OtherEntry, FsUnknownNonexist
export FsEntry
export @fs_str

export path, pathcanon
export isstandard
export isfilelike, isdirlike
export follow


# from DirEntrys
export fsreaddir, fswalkdir
export ls, find, finditer


# from fsbatch
export AbstractBatchTrait

export AllEntriesAreStandard
export TheDirlikesAreDistinct
#export TheFilelikesAreUnique
export FsBatch, batch
export ensure!

# from conf
export CONF, Conf


export ext, Ext
export @ex_str
export hasext, hasExt

export FsStats, stats, info

# todo: temp!!!
export colorize
export pprint, lpad




using Base.Filesystem

using OrderedCollections

using Crayons
using Crayons.Box

using AttoFunctionAliases
#using AttoHabits


include("./fsentries.jl")
include("./fsdirs.jl")

include("./ext.jl")

include("./fsbatch.jl")

include("./conf.jl")

include("./pprint.jl")

function __init__()
    @info "Initializing known file extensions"
    initext()
end


# # just checks uniqueness of FsEntries (path & stat)
# # hardlinks will differ here!
# # non-unique entries occur if list was filled erroneously, or if symlinks-to-dirs point inside a subdir
# function check_nonuniquepaths(fses::Vector{T}) where {T<:Union{FsFile, DirEntry}}
#     d = OrderedDict{String, Int64}()
#     for fse in fses
#         !haskey(d, fse.path)  &&  ( d[fse.path] = 0 )
#         d[fse.path] += 1
#     end

#     RET = OrderedDict{String, Int64}()
#     for (k, v) in d
#         v > 1  &&  ( RET[k] = v )
#     end
#     return RET
# end ; export nonunique_paths

# Base.readline(x::FsFile) = readline(x.path)

# function hasext(fse::FsFile, ext::AbstractString)
#     _,fseext = splitext(fse.path)
#     return fseext == ext
# end
# hasext(ext::AbstractString) = x -> hasext(x, ext)
# export hasext

# # isafsfile(fse::FsEntry) = false  # NOTE false for symlinks; those should be "resolved" first
# # isafsfile(fse::FsFile) = true
# # isafsfile() = x -> isafsfile(x)
# # export isafsfile

# # isafsdir(fse::FsEntry) = false
# # isafsdir(fse::DirEntry) = true
# # isafsdir() = x -> isafsdir(x)
# # export isafsdir


AttoFunctionAliases.ext(x::AbstractFsEntry) = ext(x.path.s)

# files and symlink to files
# isfilelike(x::Union{FsFile, FsSymlink{FsFile}}) = true
# isfilelike(x::AbstractFsEntry) = false




# # function excludesingle(X::Vector{FsEntry}, pathtoexclude::AbstractString)
# #     paths = path.(X)
# #     nfound = 0
# #     ifound = -1
# #     for i in eachindex(paths)
# #         path = paths[i]
# #         if path == pathtoexclude
# #             nfound += 1
# #             ifound = 1
# #         end
# #     end
# #     nfound == 0  &&  error("no entry found with path '$(pathtoexclude)'")
# #     nfound > 1   &&  error("no single entry found with path '$(pathtoexclude)'; encountered $(nfound) instances")
# #     return deleteat!(deepcopy(X), ifound)
# # end ; export excludesingle





# function check_duplsyml2targets(fseregs::Vector{T}, symlinks::Vector{FsSymlink{T}}) where {T<:Union{DirEntry, FsFile}}
#     RET = Vector{FsSymlink{T}}()    

#     tmpset = Set(path.(fseregs))
#     for symlink in symlinks
#         path(symlink.linkto) in tmpset  &&  push!(RET, symlink)
#     end
#     return RET
# end



# struct FsFilesUnique
#     files::OrderedSet{FsFile}

#     function FsFilesUnique(X::Vector{FsEntry}; quiet=false)
#         files::Vector{FsFile}                   = X |> flt(is(FsFile))
#         dirs::Vector{DirEntry}                     = X |> flt(is(DirEntry))
#         others::Vector{OtherEntry}                 = X |> flt(is(OtherEntry))
#         syml2files::Vector{FsSymlink{FsFile}}   = X |> flt(is(FsSymlink{FsFile}))
#         syml2dirs::Vector{FsSymlink{DirEntry}}     = X |> flt(is(FsSymlink{DirEntry}))
#         syml2others::Vector{FsSymlink{OtherEntry}} = X |> flt(is(FsSymlink{OtherEntry}))
#         syml2nonexists::Vector{FsSymlink{FsUnknownNonexist}} = X |> flt(is(FsSymlink{FsUnknownNonexist}))

#         @assert length(X) == length(files) + length(dirs) + length(others) + length(syml2files) + length(syml2dirs) + length(syml2others) + length(syml2nonexists)


#         quiet  ||  @info "checking if a symlink-to-dir points to an already-known directory..."
#         problems = check_duplsyml2targets(dirs, syml2dirs)  
#         if length(problems) > 0
#             println("ERROR: file system entries contain symlink(s) to known target dir:")
#             for symlink in problems
#                 println()
#                 println("'$(symlink.path)' -> '$(symlink.linkto.path)'")
#                 println("..to fix, run:") 
#                 println("""> troddir(<dir>; exclude=["$(symlink.path)"])""")
#             end
#             if length(problems) > 1
#                 println("")
#                 println("(even for multiple errors here, maybe start removing just one link in the upper hierarchy first; could fix the rest as well)")
#             end
#             return nothing
#         end
#         quiet  ||  @info "OK"

#         quiet  ||  @info "checking if all dir-likes (regular and symlink-to-dirs) are unique (can fail, e.g., if dir is manually entered twice)..."
#         alldirs = [ dirs ; [ x.linkto for x in syml2dirs ] ]
#         problems = check_nonuniquepaths(alldirs)
#         if length(problems) > 0
#             println("ERROR: duplicate dir entries:")
#             for (k,v) in problems
#                 println("'$(k)': found $(v) times")
#             end
#             return nothing
#         end
#         quiet  ||  @info "OK"

#         quiet  ||  @info "checking if a symlink-to-file points to an already-known file..."
#         problems = check_duplsyml2targets(files, syml2files)  
#         if length(problems) > 0
#             println("ERROR: file system entries contain symlink(s) to known target files:")
#             for symlink in problems
#                 println()
#                 println("'$(symlink.path)' -> '$(symlink.linkto.path)'")
#                 println("..to fix, run:") 
#                 println("""> troddir(<dir>; exclude=["$(symlink.path)"])""")
#             end
#             return nothing
#         end
#         quiet  ||  @info "OK"

#         quiet  ||  @info "checking if all file-likes (regular and symlink-to-dirs) are unique (can fail, e.g., if file is manually entered twice)..."
#         allfiles = [ files ; [ x.linkto for x in syml2files ] ]
#         problems = check_nonuniquepaths(allfiles)
#         if length(problems) > 0
#             println("ERROR: duplicate file entries:")
#             for (k,v) in problems
#                 println("'$(k)': found $(v) times")
#             end
#             return nothing
#         end
#         quiet  ||  @info "OK"

#         # TODO check that no Other, Broken etc.
#         tmp = OrderedSet(allfiles)
#         @assert length(tmp) == length(allfiles)
#         return new(tmp)
#     end
# end
# export FsFilesUnique

# paths(x::FsFilesUnique) = path.(x.files)
# export paths


# function fsizehuman(x)
#     RET = Base.format_bytes(x)
#     RET = replace(RET, "i" => "")
#     RET = replace(RET, "B" => "b")
#     return RET
# end

# abstract type FsImage end

# struct FsImage_jpg   <:FsImage   path::String;  dir::String;  base::String;  basestem::String;  ext::String;  st::StatStruct;  _tags::Dict{Symbol, String};  exiftags::Dict{String, String}  end
# struct FsImage_cr2   <:FsImage   path::String;  dir::String;  base::String;  basestem::String;  ext::String;  st::StatStruct;  _tags::Dict{Symbol, String};  exiftags::Dict{String, String}  end
# struct FsImage_gif   <:FsImage   path::String;  dir::String;  base::String;  basestem::String;  ext::String;  st::StatStruct;  _tags::Dict{Symbol, String};  exiftags::Dict{String, String}  end
# struct FsImage_bmp   <:FsImage   path::String;  dir::String;  base::String;  basestem::String;  ext::String;  st::StatStruct;  _tags::Dict{Symbol, String};  exiftags::Dict{String, String}  end
# struct FsImage_OTHER <:FsImage   path::String;  dir::String;  base::String;  basestem::String;  ext::String;  st::StatStruct;  _tags::Dict{Symbol, String};  exiftags::Dict{String, String}  end

# path(x::FsImage) = x.path


# FSIMAGETYPES = Dict{String, Type}(
#                                      ".jpg" => FsImage_jpg
#                                     ,".cr2" => FsImage_cr2
#                                     )

# function FsImage(f::FsFile)
#     path = f.path
#     dir = dirname(path)
#     base = basename(path)
#     basestem,ext = splitext(base)
#     st = f.st
#     haskey(FSIMAGETYPES, ext)  &&  return FSIMAGETYPES[ext](path, dir, base, basestem, ext, st, Dict{Symbol, String}(), Dict{String, String}())
#     return FsImage_OTHER(path, dir, base, basestem, ext, st, Dict{Symbol, String}(), Dict{String, String}())
# end ; export FsImage
# function _show(io::IO, f::FsImage)
#     print(io, """
# --- image file: ---
# type:               $(typeof(f))
# path:               $(f.path)
# dir:                $(f.dir)
# base/basestem/ext:  $(f.base) | $(f.basestem) | $(f.ext)
# size:               $(f.st.size) ($(fsizehuman(f.st.size)))
# """)
# end
# Base.show(io::IO, ::MIME"text/plain", x::FsImage) = _show(io, x)

# function Base.getindex(f::FsImage, key::Symbol)  return f._tags[key];  end
# function Base.setindex!(f::FsImage, value::String, key::Symbol)  f._tags[key] = value;  end

# function Base.getproperty(f::FsImage, s::Symbol)
#     s in (:path, :dir, :base, :basestem, :ext, :st, :_tags, :exiftags)  &&  return getfield(f, s)
#     return f[s]
# end
# function Base.setproperty!(f::FsImage, s::Symbol, value)
#     s in (:path, :dir, :base, :basestem, :ext, :st, :_tags, :exiftags)  &&  error("tag/field name '$(string(s))' is read-only")
#     typeof(value) != String  &&  error("value must be a string")
#     f[s] = value
# end


# struct FsImages
#     files::OrderedSet{FsImage}

#     function FsImages(F::FsFilesUnique)
#         tmp = OrderedSet{FsImage}()
#         for f in F.files
#             push!(tmp, FsImage(f))
#         end
#         return new(tmp)
#     end
# end ; export FsImages


# paths(X::FsImages) = path.(X.files)
# export paths






end # module
