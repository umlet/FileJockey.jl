

# # factor our
# function counter(X; f::Function=identity)
#     RET = OrderedDict{Any, Int64}()
#     for x in X
#         key = f(x)
#         !haskey(RET, key)  &&  ( RET[key] = 0 )
#         RET[key] += 1
#     end
#     return RET
# end
# function duplicates(X)
#     dcnt = counter(X)
#     return filter(x->x[2]>1, dcnt) |> OrderedDict
# end


# function check1a(S::FsStats)
#     msg = "Are the realpaths of all regular directories distint?\n        (should only occur on wrong manual input, not via single dir traversal)\n        "
#     entries = S.direntries;  nentries = length(entries)
#     nentries == 0  &&  ( @info msg * "none found -- OK";  return )
#     dups = duplicates(path.(entries))
#     length(dups) == 0  &&  ( @info msg * "$(tostr´(nentries)) '$(typeof(entries[1]))'s checked -- OK";  return )

#     erroruser("duplicate found: '$(first(dups)[1])'")
# end
# function check1b(S::FsStats)
#     msg = "Are the realpaths of all symlinks-to-directories distinct?\n        (should only occur on wrong manual input, not via single dir traversal)\n        "
#     entries = S.syml2direntries;  nentries = length(entries)
#     nentries == 0  &&  ( @info msg * "none found -- OK";  return )
#     dups = duplicates(path.(entries))
#     length(dups) == 0  &&  ( @info msg * "$(tostr´(nentries)) '$(typeof(entries[1]))'s checked -- OK";  return )

#     erroruser("duplicate found: '$(first(dups)[1])'")
# end
# function check1c(S::FsStats)
#     msg = "Are the realpaths of all symlink target directories distinct?\n        (e.g., in dir traversal, several different symlinks point to the same target directory)\n        "
#     entries = S.symltarget_direntries;  nentries = length(entries)
#     nentries == 0  &&  ( @info msg * "none found -- OK";  return )
#     dups = duplicates(path.(entries))
#     length(dups) == 0  &&  ( @info msg * "$(tostr´(nentries)) '$(typeof(entries[1]))'s checked -- OK";  return )

#     duptarget = first(dups)[1]
#     symls = S.syml2direntries |> fl(x->path(follow(x))==duptarget)
#     length(symls) < 2  &&  error("UNREACHABLE")  # TODO
#     syml1,syml2 = first(symls, 2)
#     erroruser("symlinks '$(path(syml1))' and '$(path(syml2))' point to the same dir '$(duptarget)'")
# end










function check_11_syml2dir_toknown(S::FsStats)
    msg = "1.1 Check if a symlink points to an already known regular dir.. "
    entries = S.syml2direntries |> fl(x->x.target in S.direntries);  nentries = length(entries)
    nentries == 0  &&  ( @info msg * "none found -- OK";  return true )

    # error!
    @info msg
    e = first( sort(entries; by=x->length(path(x))) )
    erroruser("""Symlink to known regular dir detected (<syml-path> -> <target-path>):
    "$(path(e))" -> "$(path(e.target))"
    => delete symlink, or add the <symlink-path> to the 'skip_paths' option.""")
end

function check_12_syml2dirs_tosameexternal(S::FsStats)  # after the previous test, they will point to unknown/external dirs
    msg = "1.2 Check if two symlinks point to the same dir.. "
    entries = S.syml2direntries #=|> fl(x->!(x.target in S.direntries))=#;  nentries = length(entries)
    nentries == 0  &&  ( @info msg * "none found -- OK";  return true )

    d = group(entries;  fkey=path∘follow, fhaving=x->length(x)>=2)  # TODO improve anonymous function
    length(d) == 0  &&  ( @info msg * "$(tostr´(nentries)) '$(typeof(entries[1]))'s checked -- OK";  return true )

    # error!
    @info msg
    targetpath,symlinks = first(d)
    s = [ "\"$(path(x))\" -> \"$(targetpath)\"" for x in symlinks ] |> jn("\n")
    erroruser("""Symlinks to same dir detected (<syml-path> -> <target-path>):
    $(s)
    => for ALL BUT ONE of the symlinks: delete symlink, or add <symlink-path> to the 'skip_paths' option.""")
end

function check_13_dirs_distinctpaths(S::FsStats)
    msg = "1.3 Check if all dirs (known and symlinked) have distinct paths.. "
    entries = S.dirs;  nentries = length(entries)
    nentries == 0  &&  ( @info msg * "none found -- OK";  return true )
    nsetdirpaths(S) == nentries  &&  ( @info msg * "$(tostr´(nentries)) '$(typeof(entries[1]))'s checked -- OK";  return true )

    # maybe error!
    set = Set{String}()
    for s in path.(entries)
        if s in set
            @info msg
            erroruser("""Duplicate dir found:
            "$(s)"
            => fix your input; this should not happen with standard tree traversal and sane symlinks-to-dirs""")
        end
        push!(set, s)
    end
end




function check_21_syml2file_toknown(S::FsStats)
    msg = "2.1 Check if a symlink points to an already known regular file.. "
    entries = S.syml2fileentries |> fl(x->x.target in S.fileentries);  nentries = length(entries)
    nentries == 0  &&  ( @info msg * "none found -- OK";  return true )

    # error!
    @info msg
    e = first( sort(entries; by=x->length(path(x))) )
    erroruser("""Symlink to known regular file detected (<syml-path> -> <target-path>):
    "$(path(e))" -> "$(path(e.target))"
    => delete symlink, or add the <symlink-path> to the 'skip_paths' option.""")
end

function check_22_syml2files_tosameexternal(S::FsStats)
    msg = "2.2 Check if two symlinks point to the same file.. "
    entries = S.syml2fileentries #=|> fl(x->!(x.target in S.direntries))=#;  nentries = length(entries)
    nentries == 0  &&  ( @info msg * "none found -- OK";  return true )

    d = group(entries;  fkey=path∘follow, fhaving=x->length(x)>=2)
    length(d) == 0  &&  ( @info msg * "$(tostr´(nentries)) '$(typeof(entries[1]))'s checked -- OK";  return true )

    # error!
    @info msg
    targetpath,symlinks = first(d)
    s = [ "\"$(path(x))\" -> \"$(targetpath)\"" for x in symlinks ] |> jn("\n")
    erroruser("""Symlinks to same file detected (<syml-path> -> <target-path>):
    $(s)
    => for ALL BUT ONE of the symlinks: delete symlink, or add <symlink-path> to the 'skip_paths' option.""")
end

function check_23_files_distinctpaths(S::FsStats)
    msg = "2.3 Check if all files (known and symlinked) have distinct paths.. "
    entries = S.files;  nentries = length(entries)
    nentries == 0  &&  ( @info msg * "none found -- OK";  return true )
    nsetfilepaths(S) == nentries  &&  ( @info msg * "$(tostr´(nentries)) '$(typeof(entries[1]))'s checked -- OK";  return true )

    # maybe error!
    set = Set{String}()
    for s in path.(entries)
        if s in set
            @info msg
            erroruser("""Duplicate file found:
            "$(s)"
            => fix your input; this should not happen with standard tree traversal and sane symlinks-to-dirs""")
        end
        push!(set, s)
    end
end



function checkdist(X::AbstractVector{<:AbstractEntry})
    S = stats(X)


    @info "1. Checking sanity of symlinks-to-dirs and dirs (most likely cause for duplicate files in a tree):"

    check_11_syml2dir_toknown(S)
    check_12_syml2dirs_tosameexternal(S)
    check_13_dirs_distinctpaths(S)


    @info "2. Checking sanity of symlinks-to-files and files:"

    check_21_syml2file_toknown(S)
    check_22_syml2files_tosameexternal(S)
    check_23_files_distinctpaths(S)

    return X
end
#dedupfiles(X::AbstractVector{<:AbstractEntry}) = dedup(X) |> fl(isfile) |> mp(follow)


# TODO intermediate step; check for hardlinks
# issame..

function isduplicate(x::FileEntry, y::FileEntry)
    filesize(x) != filesize(y)  &&  ( return false )
    scmd = "cmp $(path(x)) $(path(y))"
    R = exe(scmd; fail=false, splitlines=false)
    R.exitcode == 0  &&  return true
    # non-zero exit:
    occursin(" differ: ", R.out)  &&  return false
    # other, unexpected 'cmp' error; panic
    error("unexpected exit of 'cmp': stdout = '$(R.out)'; stderr = '$(R.err)'")
end


function checkdupl(X::AbstractVector{<:FileEntry})
    RET = Vector{Vector{FileEntry}}()

    d = group(X; fkey=filesize, Tkey=Int64, Tval=FileEntry, fhaving=x->length(x)>=2) 
    for (s,fs) in d
        @info "Checking files of same size $(s):"
        for f in fs  println(path(f))  end

        REF_FS = Vector{Vector{FileEntry}}()
        for f in fs
            length(REF_FS) == 0  &&  ( push!(REF_FS, FileEntry[f]);  continue )
            for ref_fs in REF_FS
                ref_f = ref_fs[1]
                if isduplicate(ref_f, f)
                    push!(ref_fs, f)
                    @info "duplicate found!"
                    break # ref check can end here
                else
                    push!(REF_FS, FileEntry[f])
                    @info "DUPLICATE DISMISSED"
                    break # ref check MUST end here, as otherwise loop gets longer!!!
                end
            end
        end
        for ref_fs in REF_FS
            length(ref_fs) >= 2  &&  push!(RET, ref_fs)
        end
    end    
    return nothing
end


include("check.jl_exports")

