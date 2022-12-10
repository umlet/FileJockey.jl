

# factor our
function counter(X; f::Function=identity)
    RET = OrderedDict{Any, Int64}()
    for x in X
        key = f(x)
        !haskey(RET, key)  &&  ( RET[key] = 0 )
        RET[key] += 1
    end
    return RET
end
function duplicates(X)
    dcnt = counter(X)
    return filter(x->x[2]>1, dcnt) |> OrderedDict
end


function check1a(S::FsStats)
    msg = "Are the realpaths of all regular directories distint?\n        (should only occur on wrong manual input, not via single dir traversal)\n        "
    entries = S.direntries;  nentries = length(entries)
    nentries == 0  &&  ( @info msg * "none found -- OK";  return )
    dups = duplicates(path.(entries))
    length(dups) == 0  &&  ( @info msg * "$(tostr´(nentries)) '$(typeof(entries[1]))'s checked -- OK";  return )

    erroruser("duplicate found: '$(first(dups)[1])'")
end
function check1b(S::FsStats)
    msg = "Are the realpaths of all symlinks-to-directories distinct?\n        (should only occur on wrong manual input, not via single dir traversal)\n        "
    entries = S.syml2direntries;  nentries = length(entries)
    nentries == 0  &&  ( @info msg * "none found -- OK";  return )
    dups = duplicates(path.(entries))
    length(dups) == 0  &&  ( @info msg * "$(tostr´(nentries)) '$(typeof(entries[1]))'s checked -- OK";  return )

    erroruser("duplicate found: '$(first(dups)[1])'")
end
function check1c(S::FsStats)
    msg = "Are the realpaths of all symlink target directories distinct?\n        (e.g., in dir traversal, several different symlinks point to the same target directory)\n        "
    entries = S.symltarget_direntries;  nentries = length(entries)
    nentries == 0  &&  ( @info msg * "none found -- OK";  return )
    dups = duplicates(path.(entries))
    length(dups) == 0  &&  ( @info msg * "$(tostr´(nentries)) '$(typeof(entries[1]))'s checked -- OK";  return )

    duptarget = first(dups)[1]
    symls = S.syml2direntries |> fl(x->path(follow(x))==duptarget)
    length(symls) < 2  &&  error("UNREACHABLE")  # TODO
    syml1,syml2 = first(symls, 2)
    erroruser("symlinks '$(path(syml1))' and '$(path(syml2))' point to the same dir '$(duptarget)'")
end










function check_1_syml2dir_toknown(S::FsStats)
    @info "Check 1: Symlinks to already-known dirs.."
    entries = S.syml2direntries |> fl(x->x.target in S.direntries);  nentries = length(entries)
    nentries == 0  &&  ( @info "none found -- OK";  return true )

    e = first( sort(entries; by=x->length(path(x))) )
    erroruser("Symlink to known dir detected: '$(path(e))' -> '$(path(e.target))'; remove or skip")
end

function check_2_syml2dirs_tosameexternal(S::FsStats)
    @info "Check 2: Symlinks to external dirs.."
    entries = S.syml2direntries |> fl(x->!(x.target in S.direntries));  nentries = length(entries)
    nentries == 0  &&  ( @info "none found -- OK";  return true )

    d = OrderedDict()  # target -> symlinks
    for x in entries
        key = path(x.target)
        !haskey(d, key)  &&  ( d[key] = [] )
        push!(d[key], x)
    end
    v = sort(cl(d); by=x->length(x[2])) |> fl(x->length(x[2])>1)
    length(v) == 0  &&  ( @info "$(tostr´(nentries)) '$(typeof(entries[1]))'s checked -- OK";  return true )

    targetpath,symlinks = first(v)
    s = [ "'$(path(x))'" for x in symlinks ] |> jn(", ")
    erroruser("Symlinks to same external dir detected: symlinks {$(s)} all point to same dir -> '$(targetpath)'; remove or skip ALL BUT ONE symlink")
end

function check_3_dirs_distinctpaths(S::FsStats)
    @info "Check 3: All dirs (known and externally symlinked).. (possible input error)"
    entries = S.dirs;  nentries = length(entries)
    nentries == 0  &&  ( @info "none found -- OK";  return true )
    nsetdirpaths(S) == nentries  &&  ( @info "$(tostr´(nentries)) '$(typeof(entries[1]))'s checked -- OK";  return true )

    set = Set{String}()
    for s in path.(entries)
        s in set  &&  erroruser("Duplicate dir found: '$(s)'; fix input (should not be possible via standard tree traversal)")
        push!(set, s)
    end
    @assert false
end

function dedup(X::AbstractVector{<:AbstractEntry})
    S = stats(X)

msg = """Duplicate files in a tree are often due to symlinks-to-directories within it.
(But skipping all symlinks can be wrong if a symlinked dir is 'external'/outside the tree.)
"""
    @info msg

    check_1_syml2dir_toknown(S)

    check_2_syml2dirs_tosameexternal(S)

    check_3_dirs_distinctpaths(S)

end

export dedup

