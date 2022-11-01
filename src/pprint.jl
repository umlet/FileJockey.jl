
lpad(s::AbstractString, upto::Int64) = ( upto < length(s)  &&  error("lpad '$upto' too small for string 's'")  ;  return " "^(upto-length(s)) * s )
lpad(upto::Int64) = x -> lpad(x, upto)

lpad(X::AbstractVector{<:AbstractString}) = ( maxlen = maximum(length.(X))  ;  return [ lpad(x, maxlen) for x in X ] )


function colorize(s::AbstractString, COLORS...)
    !CONF.colors  &&  return s
    RET = s
    for COLOR in COLORS
        RET = COLOR(RET)
    end
    return RET
end
colorizeas(s::AbstractString, ::FileEntry) = colorize(s, GREEN_FG)
colorizeas(s::AbstractString, ::DirEntry) = colorize(s, BLUE_FG)
colorizeas(s::AbstractString, ::OtherEntry) = colorize(s, YELLOW_FG)
    #=special case=# colorizeas(s::AbstractString, ::UnknownEntryNONEXIST) = colorize(s, RED_FG)

colorizeas(s::AbstractString, ::FsSymlink{FileEntry}) = colorize(s, GREEN_FG, NEGATIVE)
colorizeas(s::AbstractString, ::FsSymlink{DirEntry}) = colorize(s, BLUE_FG, NEGATIVE)
colorizeas(s::AbstractString, ::FsSymlink{OtherEntry}) = colorize(s, YELLOW_FG, NEGATIVE)
colorizeas(s::AbstractString, ::FsSymlink{UnknownEntryNONEXIST}) = colorize(s, RED_FG, NEGATIVE)
#----------
colorizeas(s::AbstractString, ::Type{FileEntry}) = colorize(s, GREEN_FG)
colorizeas(s::AbstractString, ::Type{DirEntry}) = colorize(s, BLUE_FG)
colorizeas(s::AbstractString, ::Type{OtherEntry}) = colorize(s, YELLOW_FG)
    #=special case=# colorizeas(s::AbstractString, ::Type{UnknownEntryNONEXIST}) = colorize(s, RED_FG)

colorizeas(s::AbstractString, ::Type{FsSymlink{FileEntry}}) = colorize(s, GREEN_FG, NEGATIVE)
colorizeas(s::AbstractString, ::Type{FsSymlink{DirEntry}}) = colorize(s, BLUE_FG, NEGATIVE)
colorizeas(s::AbstractString, ::Type{FsSymlink{OtherEntry}}) = colorize(s, YELLOW_FG, NEGATIVE)
colorizeas(s::AbstractString, ::Type{FsSymlink{UnknownEntryNONEXIST}}) = colorize(s, RED_FG, NEGATIVE)



filedevice(st::StatStruct)::UInt64 = st.device
fileinode(st::StatStruct)::UInt64 = st.inode
filedeviceinode(st::StatStruct)::Tuple{UInt64, UInt64} = (filedevice(st), fileinode(st))


struct FsStats  # mutable avoids some boilerplate in construction
    # PARTITION for counting
    # - standard
    fileentries::Vector{FileEntry}
    syml2fileentries::Vector{FsSymlink{FileEntry}}
    direntries::Vector{DirEntry}
    syml2direntries::Vector{FsSymlink{DirEntry}}
    # non-standard
    otherentries::Vector{OtherEntry}
    syml2otherentries::Vector{FsSymlink{OtherEntry}}

    syml2unknownentriesNONEXIST::Vector{FsSymlink{UnknownEntryNONEXIST}}  # shortcut for '2unknownnonexist'


    # standard combinations
    symltarget_fileentries::Vector{FileEntry}
    symltarget_direntries::Vector{DirEntry}
    symltarget_otherentries::Vector{OtherEntry}
    symltarget_unknownentriesNONEXIST::Vector{UnknownEntryNONEXIST}

    files::Vector{FileEntry} 
    dirs::Vector{DirEntry} 

    function FsStats(X::AbstractVector{<:AbstractFsEntry})
        # BASE
        # standard
        fileentries::Vector{FileEntry} = FileEntry[]
        direntries::Vector{DirEntry} = DirEntry[]
        syml2fileentries::Vector{FsSymlink{FileEntry}} = FsSymlink{FileEntry}[]
        syml2direntries::Vector{FsSymlink{DirEntry}} = FsSymlink{DirEntry}[]
    
        # non-standard
        otherentries::Vector{OtherEntry} = FsSymlink{DirEntry}[]
        syml2otherentries::Vector{FsSymlink{OtherEntry}} = FsSymlink{OtherEntry}[]
        syml2unknownentriesNONEXIST::Vector{FsSymlink{UnknownEntryNONEXIST}} = FsSymlink{UnknownEntryNONEXIST}[]  # shortcut for '2unknownnonexist'
    
        for x in X
            x isa FileEntry  &&  push!(fileentries, x)
            x isa DirEntry  &&  push!(direntries, x)
            x isa FsSymlink{FileEntry}  &&  ( push!(syml2fileentries, x) )
            x isa FsSymlink{DirEntry}  &&  ( push!(syml2direntries, x) )

            x isa OtherEntry  &&  push!(otherentries, x)
            x isa FsSymlink{OtherEntry}  &&  push!(syml2otherentries, x)
            x isa FsSymlink{UnknownEntryNONEXIST}  &&  push!(syml2unknownentriesNONEXIST, x)
        end

        # combinations
        symltarget_fileentries::Vector{FileEntry} = follow.(syml2fileentries)
        symltarget_direntries::Vector{DirEntry} = follow.(syml2direntries)
        symltarget_otherentries::Vector{OtherEntry} = follow.(syml2otherentries)
        symltarget_unknownentriesNONEXIST::Vector{UnknownEntryNONEXIST} = follow.(syml2unknownentriesNONEXIST)

        files::Vector{FileEntry} = [ fileentries ; symltarget_fileentries ]
        dirs::Vector{DirEntry} = [ direntries ; symltarget_direntries ]
    
        # setregfiledevices::Set{UInt64} = Set{UInt64}( filedevice(stat(x)) for x in files )
        # setregdirdevices::Set{UInt64} = Set{UInt64}( filedevice(stat(x)) for x in dirs )
        # setsymlink2filedevices::Set{UInt64} = Set{UInt64}( filedevice(lstat(x)) for x in syml2files )   # ! lstat
        # setsyml2dirdevices::Set{UInt64} = Set{UInt64}( filedevice(lstat(x)) for x in syml2dirs )        # ! lstat
    
        # setsymltarget_filedevices::Set{UInt64} = Set{UInt64}( filedevice(x) for x in files )
        # setsymltarget_dirdevices::Set{UInt64} = Set{UInt64}( filedevice(x) for x in files )

        return new(
            fileentries,
            syml2fileentries,
            direntries,
            syml2direntries,
            otherentries,
            syml2otherentries,
            syml2unknownentriesNONEXIST,

            symltarget_fileentries,
            symltarget_direntries,
            symltarget_otherentries,
            symltarget_unknownentriesNONEXIST,

            files,
            dirs
        )
    end    
end
stats(X::AbstractVector{<:AbstractFsEntry}) = FsStats(X)

filesize(S::FsStats) = sum(filesize.(S.files))

nfiles(S::FsStat) = length(S.files)
nsyml2fileentries(S::FsStat) = length(S.syml2fileentries)



function info(S::FsStats)
    line = Any[]
    if nfiles(S) == 0
        push!(line, DARK_GRAY_FG("[ no files ]"))
    else
        push!(line, colorizeas("[ $(tostr_thsep(nfiles(S)))", FileEntry))
        if nsyml2fileentries(S) == 0
            push!(line, DARK_GRAY_FG("( none symlinked )"))
        else
            push!(line, colorizeas("( $(tostr_thsep(nsyml2fileentries(S)) symlinked )", Symlink{FileEntry}))
        end

    end
    println(line...)

end
info(X::AbstractVector{<:AbstractFsEntry}) = info(stats(X))
















function statsOLD(X::AbstractVector{<:AbstractFsEntry})
    dtype = Dict{Type{<:AbstractFsEntry}, Int64}()
    dExt = Dict{Symbol, Dict{Union{String, Nothing}, Int64}}()

    for x in X
        key = typeof(x)
        !haskey(dtype, key)  &&  ( dtype[key] = 0 )
        dtype[key] += 1

        key = Ext(x)
        !haskey(dExt, key)  &&  ( dExt[key] = Dict{Union{String, Nothing}, Int64}() )
        dext = dExt[key]

        key = ext(x)
        !haskey(dext, key)  &&  ( dext[key] = 0 )
        dext[key] += 1
    end

    return (;dtype, dExt)
end


function infoNEWER(X::AbstractVector{<:AbstractFsEntry})
    dt,dE = stats(X)

    v = sort(collect(dE), by=x->sum(values(x[2])), rev=true)

    i = findfirst(x->x[1]===:__empty__, v)
    noext = v[i]
    deleteat!(v, i)

    vs = []
    for (_,de) in v
        tmpv = sort(collect(de), by=x->x[2], rev=true)
        push!(vs, tmpv)
    end

    for (p,ps) in zip(v, vs)
        sExt = ':'*string(p[1])
        sexts = join([s[1] for s in ps])
        println(sExt, " ", sexts)
    end
end

function infoOLD(X::AbstractVector{<:AbstractFsEntry})
    nfile = X |> cn(is(FileEntry))
    ndir = X |> cn(is(DirEntry))
    nother = X |> cn(is(OtherEntry))

    nsyml2file = X |> cn(is(FsSymlink{FileEntry}))
    nsyml2dir = X |> cn(is(FsSymlink{DirEntry}))
    nsyml2other = X |> cn(is(FsSymlink{OtherEntry}))
    nsyml2nonexist = X |> cn(is(FsSymlink{UnknownEntryNONEXIST}))

    ntot = nfile + ndir + nother     + nsyml2file + nsyml2dir + nsyml2other + nsyml2nonexist

    ntot != length(X)  &&  error("INTERNAL ERROR: sum of file system entry types does not match total entries")

    dext = OrderedDict()
    for x in X
        !isfilelike(x)  &&  continue
        s = ext(x)
        !haskey(dext, s)  &&  ( dext[s] = 0 )
        dext[s] += 1
    end

    print("""
--- by file system entry type:
files, regular                          $(nfile)
dirs, regular                           $(ndir)
other (fifos, devices..)                $(nother)

symlinks to file                        $(nsyml2file)
symlinks to dir                         $(nsyml2dir)
symlinks to other                       $(nsyml2other)
symlinks BROKEN                         $(nsyml2nonexist)

SUM                                     $(ntot)   

--- by likeness:
file-likes, regular and symlinked        $(nfile + nsyml2file)
dir-likes, regular and symlinked         $(ndir + nsyml2dir)
other, regular and symlinked             $(nother + nsyml2other)
symlinks BROKEN                         $(nsyml2nonexist)

--- file-likes, by extension:
""")
    for k in cl(keys(dext))  #[ filter(isnothing, keys(dext)) ; sort([x for x in keys(dext) if x!== nothing]) ]
        n = dext[k]
        k === nothing  &&  ( k = "<no dot; no ext>" )
        k == ""        &&  ( k = "<dot; no ext>" )
        if length(k) < 20
            println("$(k)" * " "^(20-length(k)), n)
        else
            println("$(k)" * "   ", n)
        end
    end
    return nothing  # to pass on in pipe
end 




# NOT NEEDED <=> .*
# function Base.:*(X::AbstractVector{<:AbstractString}, Y::AbstractVector{<:AbstractString})
#     length(X) != length(Y)  &&  error("length mismatch")
#     return [ x*y for (x,y) in zip(X, Y) ]
# end




function pprint(batch::FsBatch; colors::Bool=true)
    S = stats(batch._v)


    # dtype,dExt = stats(batch._v)

    # start1,start2 = lpad(String[ tostr_thsep(nfiles), tostr_thsep(ndirs) ]) .* [" files ", " dirs  "]
    # cstart1 = BLUE_FG(start1)
    # cstart2 = GREEN_FG(start2)
    
    # sym1 = nsymfiles > 0   ?  "[$(nsymfiles) of which symlinked]"  :  "(none symlinked)"
    # sym2 = nsymdirs > 0    ?  "[$(nsymdirs) of which symlinked]"   :  "(none symlinked)"
    # csym1 = nsymfiles > 0  ?  NEGATIVE(BLUE_FG(sym1))  :  DARK_GRAY_FG(sym1)
    # csym2 = nsymdirs > 0   ?  NEGATIVE(GREEN_FG(sym2)) :  DARK_GRAY_FG(sym2)

    # size1 = " -- $(fsizehuman(fsize)) -- $(tostr_thsep(fsize)) bytes"
    # csize1 = BLUE_FG(size1)

    # sep = "  :::  "
    # csep = DARK_GRAY_FG(sep)

    # if noth+nsymoth == 0
    #     oth = "(no dev/socket/fifo; none syml)"
    #     coth = DARK_GRAY_FG(oth)
    # else
    #     if nsymoth == 0
    #         oth0 = "$(noth) dev/socket/fifo "
    #         oth1 = "(none syml)"

    #         oth = oth0 * oth1
    #         coth = YELLOW_FG(oth0, DARK_GRAY_FG(oth1))
    #     else
    #         oth0 = "$(noth) dev/socket/fifo "
    #         oth1 = "[$(nsymoth) syml]"

    #         oth = oth0 * oth1
    #         coth = YELLOW_FG(oth0, NEGATIVE(oth1))
    #     end
    # end

    # if nbrk == 0
    #     brk = "(no broken syml)"
    #     cbrk = DARK_GRAY_FG(brk)
    # else
    #     brk = "$(nbrk) broken syml"
    #     cbrk = NEGATIVE(RED_FG(brk))
    # end

    # if colors
    #     println(cstart1, csym1, csize1)
    #     println(cstart2, csym2, csep, coth, csep, cbrk)
    # end

end

