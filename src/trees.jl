

#Base.Filesystem.islink(x::AbstractEntry) = islink(x.st)


function fsreaddir(x::Union{DirEntry, Symlink{DirEntry}})
    ss = readdir(x.path.s; join=false, sort=false)
    # now we are sure that x is a dirlike
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

fswalkdir(x::AbstractEntry; skip_paths=String[]) = FsTreeIter(x, skip_paths)  # TODO skip_paths everywhere
fswalkdir(s::AbstractString="."; skip_paths=String[]) = fswalkdir(Entry(s); skip_paths=skip_paths)




eachentry(args...; skip_paths=String[]) = fswalkdir(args...; skip_paths=skip_paths)
eachentry(X::AbstractVector; skip_paths=String[]) = eachentry.(X; skip_paths=skip_paths) |> flatten_ 

eachfile(args...) = eachentry(args...) |> fl_(isfile) |> mp_(follow)





find(args...; skip_paths=String[]) = eachentry(args...; skip_paths=skip_paths) |> cl
#find(x::AbstractEntry; skip_paths=String[]) = fswalkdir(x; skip_paths=skip_paths) |> cl
#find(s::AbstractString="."; skip_paths=String[]) = find(Entry(s); skip_paths=skip_paths)
#find(X::AbstractVector; skip_paths=String[]) = find.(X; skip_paths=skip_paths) |> flatten

findfiles(args...) = eachfile(args...) |> cl



include("trees.jl_exports")
include("trees.jl_docs")
