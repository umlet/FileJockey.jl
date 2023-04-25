


function check_11_syml2dir_toknown(S::FsStats; quiet=false)
    msg = "  Check if a symlink points to an already known regular dir.. "
    entries = S.syml2direntries |> fl(x->x.target in S.direntries);  nentries = length(entries)
    nentries == 0  &&  ( quiet  ||  @info msg * "none found -- OK";  return true )

    # error!
    quiet  ||  @info msg
    e = first( sort(entries; by=x->length(path(x))) )
    erroruser("""Symlink to known regular dir detected (<syml-path> -> <target-path>):
    "$(path(e))" -> "$(path(e.target))"
    => delete symlink, or add the <symlink-path> to the 'skip_paths' option.""")
end

function check_12_syml2dirs_tosameexternal(S::FsStats; quiet=false)  # after the previous test, they will point to unknown/external dirs
    msg = "  Check if two symlinks point to the same dir.. "
    entries = S.syml2direntries #=|> fl(x->!(x.target in S.direntries))=#;  nentries = length(entries)
    nentries == 0  &&  ( quiet  ||  @info msg * "none found -- OK";  return true )

    d = group(entries;  fkey=path∘follow, fhaving=x->length(x)>=2)  # TODO improve anonymous function
    length(d) == 0  &&  ( quiet  ||  @info msg * "$(tostr´(nentries)) '$(typeof(entries[1]))'s checked -- OK";  return true )

    # error!
    quiet  ||  @info msg
    targetpath,symlinks = first(d)
    s = [ "\"$(path(x))\" -> \"$(targetpath)\"" for x in symlinks ] |> jn("\n")
    erroruser("""Symlinks to same dir detected (<syml-path> -> <target-path>):
    $(s)
    => for ALL BUT ONE of the symlinks: delete symlink, or add <symlink-path> to the 'skip_paths' option.""")
end

function check_13_dirs_distinctpaths(S::FsStats; quiet=false)
    msg = "  Check if all dirs (known and symlinked) have distinct paths.. "
    entries = S.dirs;  nentries = length(entries)
    nentries == 0  &&  ( quiet  ||  @info msg * "none found -- OK";  return true )
    nsetdirpaths(S) == nentries  &&  ( quiet  ||  @info msg * "$(tostr´(nentries)) '$(typeof(entries[1]))'s checked -- OK";  return true )

    # maybe error!
    set = Set{String}()
    for s in path.(entries)
        if s in set
            quiet  ||  @info msg
            erroruser("""Duplicate dir found:
            "$(s)"
            => fix your input; this should not happen with standard tree traversal and sane symlinks-to-dirs""")
        end
        push!(set, s)
    end
end




function check_21_syml2file_toknown(S::FsStats; quiet=false)
    msg = "  Check if a symlink points to an already known regular file.. "
    entries = S.syml2fileentries |> fl(x->x.target in S.fileentries);  nentries = length(entries)
    nentries == 0  &&  ( quiet  ||  @info msg * "none found -- OK";  return true )

    # error!
    quiet  ||  @info msg
    e = first( sort(entries; by=x->length(path(x))) )
    erroruser("""Symlink to known regular file detected (<syml-path> -> <target-path>):
    "$(path(e))" -> "$(path(e.target))"
    => delete symlink, or add the <symlink-path> to the 'skip_paths' option.""")
end

function check_22_syml2files_tosameexternal(S::FsStats; quiet=false)
    msg = "  Check if two symlinks point to the same file.. "
    entries = S.syml2fileentries #=|> fl(x->!(x.target in S.direntries))=#;  nentries = length(entries)
    nentries == 0  &&  ( quiet  ||  @info msg * "none found -- OK";  return true )

    d = group(entries;  fkey=path∘follow, fhaving=x->length(x)>=2)
    length(d) == 0  &&  ( quiet  ||  @info msg * "$(tostr´(nentries)) '$(typeof(entries[1]))'s checked -- OK";  return true )

    # error!
    quiet  ||  @info msg
    targetpath,symlinks = first(d)
    s = [ "\"$(path(x))\" -> \"$(targetpath)\"" for x in symlinks ] |> jn("\n")
    erroruser("""Symlinks to same file detected (<syml-path> -> <target-path>):
    $(s)
    => for ALL BUT ONE of the symlinks: delete symlink, or add <symlink-path> to the 'skip_paths' option.""")
end

function check_23_files_distinctpaths(S::FsStats; quiet=false)
    msg = "  Check if all files (known and symlinked) have distinct paths.. "
    entries = S.files;  nentries = length(entries)
    nentries == 0  &&  ( quiet  ||  @info msg * "none found -- OK";  return true )
    nsetfilepaths(S) == nentries  &&  ( quiet  ||  @info msg * "$(tostr´(nentries)) '$(typeof(entries[1]))'s checked -- OK";  return true )

    # maybe error!
    set = Set{String}()
    for s in path.(entries)
        if s in set
            quiet  ||  @info msg
            erroruser("""Duplicate file found:
            "$(s)"
            => fix your input; this should not happen with standard tree traversal and sane symlinks-to-dirs""")
        end
        push!(set, s)
    end
end



function checkpaths(X::AbstractVector{<:AbstractEntry}; quiet=false)
    S = stats(X)

    quiet  ||  @info "Checking sanity of symlinks-to-dirs and dirs (most likely cause for duplicate files in a tree):"

    check_11_syml2dir_toknown(S; quiet=quiet)
    check_12_syml2dirs_tosameexternal(S; quiet=quiet)
    check_13_dirs_distinctpaths(S; quiet=quiet)


    quiet  ||  @info "Checking sanity of symlinks-to-files and files:"

    check_21_syml2file_toknown(S; quiet=quiet)
    check_22_syml2files_tosameexternal(S; quiet=quiet)
    check_23_files_distinctpaths(S; quiet=quiet)

    return X
end

checkpaths(itr; kwargs...) = checkpaths(collect(itr); kwargs...)

checkpaths(; kwargs...) = X -> checkpaths(X; kwargs...)


###############################################################################




function aresame(x::FileEntry, y::FileEntry)
    path(x) == path(y)  &&  erroruser("aresame: check for hardlinks requires distinct file paths; got '$(path(x))' twice")
    return x.st.device == y.st.device  &&  x.st.inode == y.st.inode
end
aresame(s1::AbstractString, s2::AbstractString) = aresame(FileEntry(s1), FileEntry(s2))

struct Same
    _d::OrderedDict{FileEntry, Vector{FileEntry}}
    function Same(X::AbstractVector{FileEntry})
        checkpaths(X)  # TODO quiet, and mb catch exception?
        d = group(X; fkey=x->filedeviceinode(x.st), fhaving=x->length(x)>=2)
        RET = OrderedDict{FileEntry, Vector{FileEntry}}()
        for (_,v) in d
            RET[v[end]] = v[1:end-1]  # TODO function; default to LAST
        end
        return new(RET)
    end
end
getsame(X::AbstractVector{FileEntry}) = Same(X)

Base.show(io::IO, ::MIME"text/plain", x::Same) = _show(io, x)  # TODO out to base
function _show(io::IO, x::Same)
    if isempty(x._d)
        println("Same files/hardlinks structure: EMPTY/no hardlinks found")
        return
    end

    println("""Same files/hardlinks structure with $(length(x._d)) group$(length(x._d)==1 ? "" : "s"):""")
    for (k,v) in x._d
        println("  ", path(k), " => ", string(path.(v)))
    end
end

function checksame(X::AbstractVector{FileEntry})
    sames = Same(X)
    isempty(sames._d)  &&  return X
    erroruser("files contain same entries/handlinks; use 'getsame' to identify")
end



###############################################################################



import Mmap
function _aredupl_mmap(x::FileEntry, y::FileEntry)
    open(path(x)) do f
    open(path(y)) do g
        return Mmap.mmap(f) == Mmap.mmap(g)
    end
    end
end

function _aredupl_os(x::FileEntry, y::FileEntry)
    cmds = Sys.iswindows()  ?  ["fc", "/B", path(x), path(y)]  :  ["cmp", path(x), path(y)]
    R = exe(cmds; fail=false, splitlines=false)
    R.exitcode == 0  &&  return true

    # only return valid 'false' for confirmed file difference:
    if Sys.iswindows()
        # fc returns 0/same; 1/diff; 2/other error
        R.exitcode == 1  &&  return false
    else
        occursin(" differ: ", R.out)  &&  return false
    end
    # something else has gone wrong; panic:
    error("unexpected result of 'OS'-mode file compare: stdout = '$(R.out)'; stderr = '$(R.err)'")
end

function aredupl(x::FileEntry, y::FileEntry; mode=:mmap)  # or :os
    !(mode in (:mmap, :os))  &&  error("aredupl: invalid mode ':$(mode)'")

    path(x) == path(y)  &&  erroruser("aredupl: distinct file paths required; got '$(path(x))' twice")
    aresame(x, y)       &&  erroruser("aredupl: same files/hardlinks not allowed: '$(path(x))' === '$(path(y))'")
    filesize(x) != filesize(y)  &&  return false

    mode == :mmap  &&  return _aredupl_mmap(x, y)
    return _aredupl_os(x, y)
end
aredupl(s1::AbstractString, s2::AbstractString) = aredupl(FileEntry(s1), FileEntry(s2))



function _info_msg_dupl(size::Int64, fname1::AbstractString, fname2::AbstractString, result::AbstractString)
    ss = [
        "Checking potential duplicates of same size $(size):",
        fname1,
        fname2,
        result
    ]
    return join(ss, "\n")
end

struct Dupl
    _d::OrderedDict{FileEntry, Vector{FileEntry}}
    function Dupl(X::AbstractVector{FileEntry})
        checkpaths(X)  # throws exception on error
        #checksame(X)   # no longer checked

        RET = OrderedDict{FileEntry, Vector{FileEntry}}()

        d = group(X; fkey=filesize, Tkey=Int64, Tval=FileEntry, fhaving=x->length(x)>=2)
        if isempty(d)
            @info "no files with same size => no duplicates"
            return new(RET)
        end
        ncand = values(d) .|> length |> sum        


        GROUPS = Vector{Vector{FileEntry}}()
        nnodup = 0
        for (size, fs) in d
            @info "Checking potential duplicates of same size $(size):"
            for f in fs  println(" ", path(f))  end

            REF_FS = Vector{Vector{FileEntry}}()
            for f in fs
                length(REF_FS) == 0  &&  ( push!(REF_FS, FileEntry[f]);  continue )
                for ref_fs in REF_FS
                    ref_f = ref_fs[1]
                    if aredupl(ref_f, f)
                        push!(ref_fs, f)
                        @info "!!!!! DUPLICATE FOUND !!!!!"
                        break # ref check can end here
                    else
                        push!(REF_FS, FileEntry[f])
                        @info "(contents differ; duplicate dismissed)"
                        break # ref check MUST end here, as otherwise loop gets longer!!!
                    end
                end
            end
            for ref_fs in REF_FS
                @assert length(ref_fs) > 0
                if length(ref_fs) >= 2  
                    push!(GROUPS, ref_fs)
                else
                    nnodup += 1
                end
            end
        end

        ndupes = 0
        length(GROUPS) > 0  &&  ( ndupes = GROUPS .|> length |> sum )
        dstat = group(GROUPS; fkey=length, fval=x->1, freduce=sum)

        for x in GROUPS
            k = x[end]
            v = x[1:end-1]
            @assert length(v) > 0
            RET[k] = v
        end

        size_saving = 0
        nremove = 0
        if length(RET) > 0  
            size_saving = values(RET) |> flatten |> mp(filesize) |> sum
            nremove = values(RET) .|> length |> sum
        end

        println()
        @info "checked $(length(X)) files"
        @info "found $(ncand) potential duplicates via size check"
        @info "..dismissed via full content check for $(nnodup) files"

        #@info "expected dupes: $(ncand-nnodup)"
        #@info "---"
        @assert ncand-nnodup == ndupes

        @info "---"
        @info "duplicates: $(ndupes)"
        for (s,n) in dstat
            @info "  groups of size $(s): $(n) [removable: $((s-1)*n)]"
        end
        @info "---"
        @info "removable files: $(nremove)"
        @info "..with disk space: $(tostr´(size_saving)) bytes"

        return new(RET)
    end
end
getdupl(X::AbstractVector{FileEntry}) = Dupl(X)







# old; remove

# # TODO better name
# function isduplicate(x::FileEntry, y::FileEntry)
#     filesize(x) != filesize(y)  &&  ( return false )
#     cmds = ["cmp", path(x), path(y)]  # TODO Windows!!!
#     R = exe(cmds; fail=false, splitlines=false)
#     R.exitcode == 0  &&  return true
#     # non-zero exit:
#     occursin(" differ: ", R.out)  &&  return false
#     # other, unexpected 'cmp' error; panic
#     error("unexpected exit of 'cmp'/'fc': stdout = '$(R.out)'; stderr = '$(R.err)'")
# end


# old; remove

# TODO FileEntry interface; checkpaths; checksame
# function getdupl(X::AbstractVector{<:FileEntry})
#     checkpaths(X)  # throws exception on error
#     checksame(X)   # throws exception on error


#     RET = Vector{Vector{FileEntry}}()

#     d = group(X; fkey=filesize, Tkey=Int64, Tval=FileEntry, fhaving=x->length(x)>=2) 
#     ncand = values(d) .|> length |> sum

#     nnodup = 0
#     for (s,fs) in d
#         @info "Checking potential duplicate files of same size $(s):"
#         for f in fs  println(path(f))  end

#         REF_FS = Vector{Vector{FileEntry}}()
#         for f in fs
#             length(REF_FS) == 0  &&  ( push!(REF_FS, FileEntry[f]);  continue )
#             for ref_fs in REF_FS
#                 ref_f = ref_fs[1]
#                 if isduplicate(ref_f, f)
#                     push!(ref_fs, f)
#                     @info "DUPLICATE FOUND!"
#                     break # ref check can end here
#                 else
#                     push!(REF_FS, FileEntry[f])
#                     @info "OK: contents differ; duplicate dismissed"
#                     break # ref check MUST end here, as otherwise loop gets longer!!!
#                 end
#             end
#         end
#         for ref_fs in REF_FS
#             @assert length(ref_fs) > 0
#             if length(ref_fs) >= 2  
#                 push!(RET, ref_fs)
#             else
#                 nnodup += 1
#             end
#         end
#     end

#     ndupes = 0
#     length(RET) > 0  &&  ( ndupes = RET .|> length |> sum )
#     dstat = group(RET; fkey=length, fval=x->1, freduce=sum)

#     DICT_RET = OrderedDict{FileEntry, Vector{FileEntry}}()
#     for x in RET
#         k = x[1]
#         v = x[2:end]
#         @assert length(v) > 0
#         DICT_RET[k] = v
#     end

#     size_saving = 0
#     nremove = 0
#     if length(DICT_RET) > 0  
#         size_saving = values(DICT_RET) |> mp(x->sum(filesize, x)) |> sum
#         nremove = values(DICT_RET) .|> length |> sum
#     end

#     println()
#     @info "checked $(length(X)) files"
#     @info "found $(ncand) candidate dupes via size check"
#     @info "false dupe alarm for $(nnodup) files"
#     @info "expected dupes: $(ncand-nnodup)"
#     @info "---"
#     @info "dupes: $(ndupes)"
#     for (s,n) in dstat
#         @info "  sets of size $(s): $(n) [removable: $((s-1)*n)]"
#     end
#     @info "---"
#     @info "removable files: $(nremove)"
#     @info "..with disk space: $(tostr´(size_saving)) bytes"

#     return DICT_RET
# end



# TODO make const?, export
__DUPL__ = nothing
function checkdupl(X::AbstractVector{<:FileEntry})
    dupl = getdupl(X);  global __DUPL__ = dupl
    length(dupl._d) == 0  &&  return X
    erroruser("duplicate files found and stored in '__DUPL__' (or use getdupl)")
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
include("check.jl_docs")

