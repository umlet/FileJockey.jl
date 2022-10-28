

abstract type AbstractBatchTrait end


# fails if entries contain
# - Otherlike (regulas or symlink)
# - broken symlinks (FsSymlink{FsUnknwonNonexist})
struct AllEntriesAreStandard <: AbstractBatchTrait end
areallentriesstandard(X::AbstractVector{<:AbstractFsEntry})::Bool = ( cn(isstandard, X) == length(X))
traitfunction(::Type{AllEntriesAreStandard}) = areallentriesstandard




# Filelikes (FsFiles or Symlink{FsFile}) have
# - different paths, AND
# - are different entries, i.e., no hardlinks to same file
struct TheFilelikesAreUnique <: AbstractBatchTrait end
function arethefilelikesunique(X::AbstractVector{<:AbstractFsEntry})::Bool
    v = X |> fl(isfilelike) |> mp(follow)


    return false
end
traitfunction(::Type{TheFilelikesAreUnique}) = havedistinctpaths



struct FsBatch
    _v::Vector{AbstractFsEntry}
    traits::Set{AbstractBatchTrait}
    function FsBatch(X::AbstractVector{<:AbstractFsEntry})
        return new(X, Set{AbstractFsEntry}())
    end
end
FsBatch(X) = FsBatch(cl())

batch(args...) = FsBatch(args...)