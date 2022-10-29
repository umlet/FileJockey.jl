

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
Checks if the Dirlikes (i.e., the Dirs and the Symlinks-to-dirs) contained in the entries are distinct:
- Ensures that all Dirs are distinct (Dir set A).
- Ensures that all target Dirs of the Symlink-to-Dirs are distinct (the targets are the Dir set B).
- Ensures that sets A and B are disjoint.
(Fails, e.g., if a 'find()' result contains a Symlink-to-dir pointing to another Dir in the same hierarchy;
or if duplicates were erroneously added in a manual setup of the entries..)
(If OK, one can 'follow()' all Symlink-to-dirs, i.e., replace them with their target, and end up with distinct Dirs.
XXXXX It also clears Symlink-to-dirs of any responsability rules out the most common cause for duplicate File entries, most often caused by redundant Symlinks-to-dirs.)
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