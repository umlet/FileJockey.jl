

abstract type AbstractBatchTrait end


# fails if entries contain
# - otherlike (regular or symlink)
# - broken symlinks (FsSymlink{FsUnknwonNonexist})
struct AllEntriesAreStandard <: AbstractBatchTrait end
function areallentriesstandard(X::AbstractVector{<:AbstractFsEntry})::Bool
    !CONF.quiet  &&  @info """
Ensuring 'AllEntriesAreStandard'..
- Checks if all entries are standard ones: Files, Dirs, Symlinks-to-files, or Symlinks-to-dirs.
  (Fails if entries contain Others (like FIFOs, devices..), Symlinks-to-others, or broken symlinks.)
"""
    fs = X |> fl(!isstandard)
    success = length(fs) == 0

    if !success
        ss = fs |> tk(5) |> mp(string)
        length(fs) > 5  &&  push!(ss, "...")
        pushfirst!(ss, "Entries contain $(length(fs)) non-standard ones:")
        msg = join(ss, "\n")
        @error msg
        return false
    end

    !CONF.quiet  &&  @info "OK."
    return true
end
traitfunction(::Type{AllEntriesAreStandard}) = areallentriesstandard


struct TheDirlikesAreDistinct <: AbstractBatchTrait end
function arethedirlikesdistinct(X::AbstractVector{<:AbstractFsEntry})::Bool
    !CONF.quiet  &&  @info """
Ensuring 'TheDirlikesAreDistinct'..
Checks the soundness of the Dirlikes (Dirs and Symlinks-to-dirs) in this order:
- Ensure that no two Symlink-to-Dirs point to the same target Dir.
- Ensure that no Symlink-to-Dir target is a Dir already contained in the entries.
- Ensure that no two Dirs in the entries are the same.
(If all is met, one can 'follow()' all Symlink-to-dirs (i.e., replace them with their target),
and end up with distinct Dirs. The order of the checks should facilitate debugging, 
as few Symlink-to-dirs are most likely to cause many subsequent duplicate entries.)
"""
    ds = X |> fl(is(FsDir))
    dpaths = path.(ds)
    dpathset = Set(dpaths)

    sds = X |> fl(is(FsSymlink{FsDir}))
    sdproblems = sds |> fl(x -> x.target.path.s in dpathset)

    success = length(sdproblems) == 0

    if !success
        ss = sds |> tk(5) |> mp(string)
        length(sdproblems) > 5  &&  push!(ss, "...")
        pushfirst!(ss, "Entries contain $(length(sdproblems)) Symlinks-to-dirs pointing to known Dirs in entries:")
        msg = join(ss, "\n")
        @error msg
        return false
    end

    !CONF.quiet  &&  @info "OK."
    return true
end
traitfunction(::Type{TheDirlikesAreDistinct}) = arethedirlikesdistinct








# Filelikes (FsFiles or Symlink{FsFile}) have
# - different paths, AND
# - are different entries, i.e., no hardlinks to same file
struct TheFilelikesAreUnique <: AbstractBatchTrait end
function arethefilelikesunique(X::AbstractVector{<:AbstractFsEntry})::Bool
    v = X |> fl(isfilelike) |> mp(follow)


    return false
end
traitfunction(::Type{TheFilelikesAreUnique}) = havedistinctpaths







#------------------------------------------------------------------------------
struct FsBatch
    _v::Vector{AbstractFsEntry}
    traits::Set{AbstractBatchTrait}
    function FsBatch(X::AbstractVector{<:AbstractFsEntry})
        return new(X, Set())
    end
end
FsBatch(X) = FsBatch(cl())
batch(args...) = FsBatch(args...)


# returns X, or throws exception!
function ensure!(X::FsBatch, T::Type{<:AbstractBatchTrait})
    T() in X.traits  &&  return X

    f = traitfunction(T)
    !f(X._v)  &&  error("ensuring '$(T)' failed")

    push!(X.traits, T())
    return X
end
ensure!(T::Type{<:AbstractBatchTrait}) = X -> ensure!(X, T)