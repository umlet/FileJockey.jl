

Base.Filesystem.islink(x::AbstractFsEntry) = islink(x.st)

function fsreaddir(x::Union{DirEntry, FsSymlink{DirEntry}})
    ss = readdir(x.path.s; join=false, sort=false)
    # now we are sure that x is a dirlike
    basepath = islink(x)  ?  x.target.path  :  x.path
    pcs = PathCanon.(Ref(basepath), ss)
    fsecs = FsEntryCanon.(pcs)
    fses = FsEntry.(fsecs)
    return fses
end
fsreaddir(s::AbstractString=".") = fsreaddir(FsEntry(s))



# #------------------------------------------------------------------------------
# function _fswalkdir(x::Union{DirEntry, FsSymlink{DirEntry}}, RET::Vector{AbstractFsEntry})
#     push!(RET, x)
#     fsecs = fsreaddir(x)
#     for fsec in fsecs
#         _fswalkdir(fsec, RET)
#     end
# end
# _fswalkdir(x::AbstractFsEntry, RET::Vector{AbstractFsEntry}) = push!(RET, x)

# function fswalkdir(x::AbstractFsEntry)
#     RET = AbstractFsEntry[]
#     _fswalkdir(x, RET)
#     return RET
# end
# fswalkdir(s::AbstractString=".") = fswalkdir(FsEntry(s))



#------------------------------------------------------------------------------
struct FsTreeIter
    state::Vector{AbstractFsEntry}
    FsTreeIter(x::AbstractFsEntry) = new([x])
end
Base.IteratorSize(::Type{FsTreeIter}) = Base.SizeUnknown()
Base.IteratorEltype(::Type{FsTreeIter}) = Base.HasEltype()
Base.eltype(::Type{FsTreeIter}) = AbstractFsEntry
Base.isdone(x::FsTreeIter, state=nothing) = length(x.state) == 0

_treechildren(x::Union{DirEntry, FsSymlink{DirEntry}}) = fsreaddir(x)
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
ls(x::FsSymlink{DirEntry}) = fsreaddir(x.target)

ls(s::AbstractString=".") = ls(FsEntry(s))


finditer(args...) = fswalkdir(args...)
find(args...) = collect(fswalkdir(args...))


