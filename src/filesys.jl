module FileSys


using CommandLiner.Iter


using ..Entries


#Base.Filesystem.islink(x::AbstractEntry) = islink(x.st)


function fsreaddir(x::Union{DirEntry, Symlink{DirEntry}})
    _err = false
    ss = String[]
    try
        ss = readdir(x.path.s; join=false, sort=false)
    catch e
        if isa(e, Base.IOError)  &&  occursin("permission denied", string(e))
            _err = true
        else
            rethrow(e)
        end
    end
    _err  &&  erroruser("no access rights for dir '$(x.path.s)'")  # we avoid the "caused by" backtrace of 'excpt wthin excpt'

    basepath = islink(x)  ?  x.target.path  :  x.path
    pcs = PathCanon.(Ref(basepath), ss)
    fsecs = EntryCanon.(pcs)
    fses = Entry.(fsecs)
    return fses
end
fsreaddir(s::AbstractString=".") = fsreaddir(Entry(s))


ls(x::DirEntry) = fsreaddir(x)
ls(x::Symlink{DirEntry}) = fsreaddir(x.target)
ls(x::AbstractEntry) = [x]

ls(s::AbstractString) = ls(Entry(s))
ls() = ls(".")

ls(X::AbstractVector) = ls.(X) |> flatten

ll(args...) = ls(args...)




struct FsTreeIter
    state::Vector{AbstractEntry}
    skip_paths::Vector{String}
    FsTreeIter(x::AbstractEntry, skip_paths::AbstractVector{<:AbstractString}) = new([x], skip_paths)  # also works on files
end
Base.IteratorSize(::Type{FsTreeIter}) = Base.SizeUnknown()
Base.IteratorEltype(::Type{FsTreeIter}) = Base.HasEltype()
Base.eltype(::Type{FsTreeIter}) = AbstractEntry
Base.isdone(x::FsTreeIter, state=nothing) = length(x.state) == 0

_treechildren(x::Union{DirEntry, Symlink{DirEntry}}) = fsreaddir(x)
_treechildren(x::AbstractEntry) = AbstractEntry[]

Base.iterate(x::FsTreeIter) = iterate(x, nothing)
function Base.iterate(x::FsTreeIter, ::Nothing)
@label retry
    length(x.state) == 0  &&  return nothing

    item = popfirst!(x.state)
    path(item) in x.skip_paths  &&  @goto retry

    children = _treechildren(item)
    length(children) > 0  &&  ( prepend!(x.state, children) )

    return (item, nothing)
end

fswalkdir(x::AbstractEntry; skip_paths::AbstractVector{<:AbstractString}=String[]) = FsTreeIter(x, skip_paths)  # TODO skip_paths everywhere
fswalkdir(s::AbstractString; kwargs...) = fswalkdir(Entry(s); kwargs...)
fswalkdir(; kwargs...) = fswalkdir("."; kwargs...)


### OLD
# eachentry(args...; skip_paths=String[]) = fswalkdir(args...; skip_paths=skip_paths)  # empty or string or Entry
# eachentry(X::AbstractVector; skip_paths=String[]) = eachentry.(X; skip_paths=skip_paths) |> flatten_ 


eachentry(x::AbstractEntry; skip_paths::AbstractVector{<:AbstractString}=String[]) = fswalkdir(x; skip_paths=skip_paths)
eachentry(s::AbstractString; kwargs...) = eachentry(Entry(s); kwargs...)
eachentry(; kwargs...) = eachentry("."; kwargs...)
eachentry(args...; kwargs...) = eachentry.(args; kwargs...) |> flatten_ 


find(args...; skip_paths=String[]) = eachentry(args...; skip_paths=skip_paths) |> cl


findfiles(args...; kwargs...) = eachentry(args...; kwargs...) |> checkpaths(; quiet=true) |> filter_(isfile) |> mp(follow)

finddupl(args...; kwargs...) = eachentry(args...; kwargs...) |> checkpaths(; quiet=false) |> filter_(isfile) |> mp(follow) |> _getdupl_checkpaths_done


function getfiles(X::AbstractVector{<:AbstractEntry})  # TODO iterator variant
    return X |> filter_(isfile) |> mp(follow)
end


include("filesys.jl_exports")
include("filesys.jl_docs")
end # module