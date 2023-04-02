


function check_11_syml2dir_toknown(S::FsStats)
    msg = "  Check if a symlink points to an already known regular dir.. "
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
    msg = "  Check if two symlinks point to the same dir.. "
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
    msg = "  Check if all dirs (known and symlinked) have distinct paths.. "
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
    msg = "  Check if a symlink points to an already known regular file.. "
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
    msg = "  Check if two symlinks point to the same file.. "
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
    msg = "  Check if all files (known and symlinked) have distinct paths.. "
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



function checksamepaths(X::AbstractVector{<:AbstractEntry})
    S = stats(X)

    @info "Checking sanity of symlinks-to-dirs and dirs (most likely cause for duplicate files in a tree):"

    check_11_syml2dir_toknown(S)
    check_12_syml2dirs_tosameexternal(S)
    check_13_dirs_distinctpaths(S)


    @info "Checking sanity of symlinks-to-files and files:"

    check_21_syml2file_toknown(S)
    check_22_syml2files_tosameexternal(S)
    check_23_files_distinctpaths(S)

    return X
end
#dedupfiles(X::AbstractVector{<:AbstractEntry}) = dedup(X) |> fl(isfile) |> mp(follow)













function checksamefiles(X::AbstractVector{FileEntry})
    S = stats(X)

    if nsetfiledeviceinodes(S) == nfiles(S)
        @info "Checking for same files (hardslinks).. OK: all files are distinct; no hardlinks found"
        return X
    end

    erroruser("same files/hardslinks found; use getsamefiles() to identify")
end






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


function getduplfiles(X::AbstractVector{<:FileEntry})
    RET = Vector{Vector{FileEntry}}()

    d = group(X; fkey=filesize, Tkey=Int64, Tval=FileEntry, fhaving=x->length(x)>=2) 
    ncand = values(d) .|> length |> sum

    nnodup = 0
    for (s,fs) in d
        @info "Checking potential duplicate files of same size $(s):"
        for f in fs  println(path(f))  end

        REF_FS = Vector{Vector{FileEntry}}()
        for f in fs
            length(REF_FS) == 0  &&  ( push!(REF_FS, FileEntry[f]);  continue )
            for ref_fs in REF_FS
                ref_f = ref_fs[1]
                if isduplicate(ref_f, f)
                    push!(ref_fs, f)
                    @info "DUPLICATE FOUND!"
                    break # ref check can end here
                else
                    push!(REF_FS, FileEntry[f])
                    @info "OK: contents differ; duplicate dismissed"
                    break # ref check MUST end here, as otherwise loop gets longer!!!
                end
            end
        end
        for ref_fs in REF_FS
            @assert length(ref_fs) > 0
            if length(ref_fs) >= 2  
                push!(RET, ref_fs)
            else
                nnodup += 1
            end
        end
    end

    ndupes = 0
    length(RET) > 0  &&  ( ndupes = RET .|> length |> sum )
    dstat = group(RET; fkey=length, fval=x->1, freduce=sum)

    DICT_RET = OrderedDict{FileEntry, Vector{FileEntry}}()
    for x in RET
        k = x[1]
        v = x[2:end]
        @assert length(v) > 0
        DICT_RET[k] = v
    end

    size_saving = 0
    nremove = 0
    if length(DICT_RET) > 0  
        size_saving = values(DICT_RET) |> mp(x->sum(filesize, x)) |> sum
        nremove = values(DICT_RET) .|> length |> sum
    end

    println()
    @info "checked $(length(X)) files"
    @info "found $(ncand) candidate dupes via size check"
    @info "false dupe alarm for $(nnodup) files"
    @info "expected dupes: $(ncand-nnodup)"
    @info "---"
    @info "dupes: $(ndupes)"
    for (s,n) in dstat
        @info "  sets of size $(s): $(n) [removable: $((s-1)*n)]"
    end
    @info "---"
    @info "removable files: $(nremove)"
    @info "..with disk space: $(tostr´(size_saving)) bytes"

    return DICT_RET
end

function checkduplfiles(X::AbstractVector{<:FileEntry})
    d = getduplfiles(X)
    length(d) == 0  &&  ( return X )
    erroruser("duplicate files found; use getduplfiles() to identify")
end







function script_dedup(X::OrderedDict{FileEntry, Vector{FileEntry}})
    RET = String[]

    push!(RET, "#!/bin/bash")
    
    append!(RET, ["","","","",""])
    push!(RET, "DRYRUN=1")
    append!(RET, ["","","","",""])

    i = 1
    for (f,fs) in X
        push!(RET, "############ CMP step")
        push!(RET, "# ORIG/KEEP: $(path(f))")        
        push!(RET, "echo '$(i): checking dupes of $(path(f))..'")
        foreach(x->push!(RET, "cmp $(path(f)) $(path(x))  ||  { exit 99; }"), fs)
        push!(RET, "echo 'OK'")
        i += 1
    end    

    append!(RET, ["","","","",""])
    push!(RET, "[[ \$DRYRUN == 1 ]]  &&  { echo 'dryrun completed successfully; exiting before rm..';  exit 0; }")
    append!(RET, ["","","","",""])

    i = 1
    for (f,fs) in X
        push!(RET, "############ RM step")
        push!(RET, "# ORIG/KEEP: $(path(f))")
        push!(RET, "echo '$(i): removing dupes of $(path(f))..'")
        foreach(x->push!(RET, "rm $(path(x))  ||  { exit 99; }"), fs)
        i += 1
    end
    return RET
end

include("check.jl_exports")

