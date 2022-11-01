

#Base.Filesystem.islink(x::AbstractFsEntry) = islink(x.st)


function fsreaddir(x::Union{DirEntry, Symlink{DirEntry}})
    ss = readdir(x.path.s; join=false, sort=false)
    # now we are sure that x is a dirlike
    basepath = islink(x)  ?  x.target.path  :  x.path
    pcs = PathCanon.(Ref(basepath), ss)
    fsecs = FsEntryCanon.(pcs)
    fses = FsEntry.(fsecs)
    return fses
end
fsreaddir(s::AbstractString=".") = fsreaddir(FsEntry(s))



struct FsTreeIter
    state::Vector{AbstractFsEntry}
    FsTreeIter(x::AbstractFsEntry) = new([x])  # also works on files
end
Base.IteratorSize(::Type{FsTreeIter}) = Base.SizeUnknown()
Base.IteratorEltype(::Type{FsTreeIter}) = Base.HasEltype()
Base.eltype(::Type{FsTreeIter}) = AbstractFsEntry
Base.isdone(x::FsTreeIter, state=nothing) = length(x.state) == 0

_treechildren(x::Union{DirEntry, Symlink{DirEntry}}) = fsreaddir(x)
_treechildren(x::AbstractFsEntry) = AbstractFsEntry[]

Base.iterate(x::FsTreeIter) = iterate(x, nothing)
function Base.iterate(x::FsTreeIter, ::Nothing)
    length(x.state) == 0  &&  return nothing

    item = popfirst!(x.state)
    children = _treechildren(item)
    length(children) > 0  &&  ( prepend!(x.state, children) )
    return (item, nothing)
end

fswalkdir(x::AbstractFsEntry) = FsTreeIter(x)
fswalkdir(s::AbstractString=".") = fswalkdir(FsEntry(s))


ls(x::AbstractFsEntry) = x
ls(x::DirEntry) = fsreaddir(x)
ls(x::Symlink{DirEntry}) = fsreaddir(x.target)
ls(s::AbstractString=".") = ls(FsEntry(s))

ll(x::AbstractFsEntry) = collect(fswalkdir(x))
ll(s::AbstractString=".") = ll(FsEntry(s))

find(args...) = ll(args...)


eachentry(args...) = fswalkdir(args...)
eachfile(args...) = eachentry(args...) |> fl(isfile) |> mp(follow)


