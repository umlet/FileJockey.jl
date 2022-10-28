

abstract type AbstractBatchTrait end



# Filelikes (FsFiles or Symlink{FsFile}) have
# 1. different paths, AND
# 2. are different entries, i.e., no hardlinks to same file
struct FilelikesAreUnique <: AbstractBatchTrait end
function arefilelikesunique(X::AbstractVector{<:AbstractFsEntry})::Bool
    v = X |> fl(isfilelike) |> mp(follow)


    return false
end
traitfunction(::Type{FilelikesAreUnique}) = havedistinctpaths



struct FsBatch
    _v::Vector{AbstractFsEntry}
    traits::Set{<:AbstractBatchTrait}
    function FsBatch(X::AbstractVector{<:AbstractFsEntry})
        return new(X, Set{<:AbstractFsEntry}())
    end
end
FsBatch(X) = FsBatch(cl())

batch(args...) = FsBatch(args...)