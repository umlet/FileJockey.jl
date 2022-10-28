

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


struct TheDirlikesAreUnique <: AbstractBatchTrait end
function arethedirlikesunique(X::AbstractVector{<:AbstractFsEntry})::Bool
    !CONF.quiet  &&  @info """
Ensuring 'TheDirlikesAreDistinct'..
- Checks if the Symlinks-to-dirs don't point to other, already-known, Dirs in the entries.
  (Fails, for example, if a 'find()' result contains a symlink to a Dir inside the same hierarchy.)
- Checks if all Dirlikes (Dirs and Symlink-to-dirs) point to distinct Dirs.
  (Fails, e.g., if the entries were set up with the same Dir occurring multiple times.)
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
traitfunction(::Type{TheDirlikesAreUnique}) = arethedirlikesunique






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