

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



struct FsTreeIter
    state::Vector{AbstractEntry}
    FsTreeIter(x::AbstractEntry) = new([x])  # also works on files
end
Base.IteratorSize(::Type{FsTreeIter}) = Base.SizeUnknown()
Base.IteratorEltype(::Type{FsTreeIter}) = Base.HasEltype()
Base.eltype(::Type{FsTreeIter}) = AbstractEntry
Base.isdone(x::FsTreeIter, state=nothing) = length(x.state) == 0

_treechildren(x::Union{DirEntry, Symlink{DirEntry}}) = fsreaddir(x)
_treechildren(x::AbstractEntry) = AbstractEntry[]

Base.iterate(x::FsTreeIter) = iterate(x, nothing)
function Base.iterate(x::FsTreeIter, ::Nothing)
    length(x.state) == 0  &&  return nothing

    item = popfirst!(x.state)
    children = _treechildren(item)
    length(children) > 0  &&  ( prepend!(x.state, children) )
    return (item, nothing)
end

fswalkdir(x::AbstractEntry) = FsTreeIter(x)
fswalkdir(s::AbstractString=".") = fswalkdir(Entry(s))

eachentry(args...) = fswalkdir(args...)
eachfile(args...) = eachentry(args...) |> fl(isfile) |> mp(follow)

ls(x::DirEntry) = fsreaddir(x)
ls(x::Symlink{DirEntry}) = fsreaddir(x.target)
ls(s::AbstractString=".") = ls(Entry(s))
ls(x::AbstractEntry) = [x]

ll(x::AbstractEntry) = fswalkdir(x) |> cl
ll(s::AbstractString=".") = ll(Entry(s))



