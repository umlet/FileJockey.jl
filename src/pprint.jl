
# lpad(s::AbstractString, upto::Int64) = ( upto < length(s)  &&  error("lpad '$upto' too small for string 's'")  ;  return " "^(upto-length(s)) * s )
# lpad(upto::Int64) = x -> lpad(x, upto)

# lpad(X::AbstractVector{<:AbstractString}) = ( maxlen = maximum(length.(X))  ;  return [ lpad(x, maxlen) for x in X ] )


function info(S::FsStats)
    # LINE 1
    line = []
    if nfiles(S) == 0
        push!(line, DARK_GRAY_FG("[ no files ]"))
    else
        push!(line, colorizeas("[ $(tostr´(nfiles(S))) files ", FileEntry))
        if nsyml2fileentries(S) == 0
            push!(line, DARK_GRAY_FG("( none of which symlinked )"))
        else
            push!(line, colorizeas("( $(tostr´(nsyml2fileentries(S))) symlinked )", Symlink{FileEntry}))
        end
        fsize = filesize(S)
        if fsize <= 2^10
            push!(line, colorizeas(" -- $(tostr´(fsize)) bytes ", FileEntry))
        else
            push!(line, colorizeas(" -- $(fsizehuman(fsize)) -- $(tostr´(fsize)) bytes ", FileEntry))
        end
        push!(line, DARK_GRAY_FG("( #paths:$(nsetfilepaths(S))  #dev:$(nsetfiledevices(S))  #inodes:$(nsetfiledeviceinodes(S)) )"))
        push!(line, colorizeas(" ]", FileEntry))
    end
    println(line...)

    # LINE 2
    line = []
    if ndirs(S) == 0
        push!(line, DARK_GRAY_FG("[ no dirs ]"))
    else
        push!(line, colorizeas("[ $(tostr´(ndirs(S))) dirs ", DirEntry))
        if nsyml2direntries(S) == 0
            push!(line, DARK_GRAY_FG("( no syml )"))
        else
            push!(line, colorizeas("( $(tostr´(nsyml2direntries(S))) symlinked )", Symlink{DirEntry}))
        end
        push!(line, DARK_GRAY_FG(" ( #paths:$(nsetdirpaths(S)) )"))
        push!(line, colorizeas(" ]", DirEntry))
    end

    push!(line, DARK_GRAY_FG(" :: "))

    if nothers(S) == 0
        push!(line, DARK_GRAY_FG("[ no dev,sock,fifo.. ]"))
    else
        push!(line, colorizeas("[ $(tostr´(nothers(S))) dev,sock,fifo ", OtherEntry))
        if nsyml2otherentries(S) == 0
            push!(line, DARK_GRAY_FG("( no syml )"))
        else
            push!(line, colorizeas("( $(tostr´(nsyml2otherentries(S))) syml )", Symlink{OtherEntry}))
        end        
        push!(line, colorizeas(" ]", OtherEntry))
    end

    push!(line, DARK_GRAY_FG(" :: "))

    if nunknowns(S) == 0
        push!(line, DARK_GRAY_FG("[ no unknown/broken ]"))
    else
        push!(line, colorizeas("[ $(tostr´(nunknowns(S))) unknown/broken ", UnknownEntryNONEXIST))
        if nsyml2unknownentriesNONEXIST(S) == 0
            push!(line, DARK_GRAY_FG("( no syml )"))
        else
            push!(line, colorizeas("( $(tostr´(nsyml2unknownentriesNONEXIST(S))) syml )", Symlink{UnknownEntryNONEXIST}))
        end        
        push!(line, colorizeas(" ]", UnknownEntryNONEXIST))
    end

    println(line...)


end
info(X::AbstractVector{<:AbstractEntry}) = info(stats(X))
















function statsOLD(X::AbstractVector{<:AbstractEntry})
    dtype = Dict{Type{<:AbstractEntry}, Int64}()
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


function infoNEWER(X::AbstractVector{<:AbstractEntry})
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

function infoOLD(X::AbstractVector{<:AbstractEntry})
    nfile = X |> cn(is(FileEntry))
    ndir = X |> cn(is(DirEntry))
    nother = X |> cn(is(OtherEntry))

    nsyml2file = X |> cn(is(Symlink{FileEntry}))
    nsyml2dir = X |> cn(is(Symlink{DirEntry}))
    nsyml2other = X |> cn(is(Symlink{OtherEntry}))
    nsyml2nonexist = X |> cn(is(Symlink{UnknownEntryNONEXIST}))

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




# function pprint(batch::FsBatch; colors::Bool=true)
#     S = stats(batch._v)


#     # dtype,dExt = stats(batch._v)

#     # start1,start2 = lpad(String[ tostr_thsep(nfiles), tostr_thsep(ndirs) ]) .* [" files ", " dirs  "]
#     # cstart1 = BLUE_FG(start1)
#     # cstart2 = GREEN_FG(start2)
    
#     # sym1 = nsymfiles > 0   ?  "[$(nsymfiles) of which symlinked]"  :  "(none symlinked)"
#     # sym2 = nsymdirs > 0    ?  "[$(nsymdirs) of which symlinked]"   :  "(none symlinked)"
#     # csym1 = nsymfiles > 0  ?  NEGATIVE(BLUE_FG(sym1))  :  DARK_GRAY_FG(sym1)
#     # csym2 = nsymdirs > 0   ?  NEGATIVE(GREEN_FG(sym2)) :  DARK_GRAY_FG(sym2)

#     # size1 = " -- $(fsizehuman(fsize)) -- $(tostr_thsep(fsize)) bytes"
#     # csize1 = BLUE_FG(size1)

#     # sep = "  :::  "
#     # csep = DARK_GRAY_FG(sep)

#     # if noth+nsymoth == 0
#     #     oth = "(no dev/socket/fifo; none syml)"
#     #     coth = DARK_GRAY_FG(oth)
#     # else
#     #     if nsymoth == 0
#     #         oth0 = "$(noth) dev/socket/fifo "
#     #         oth1 = "(none syml)"

#     #         oth = oth0 * oth1
#     #         coth = YELLOW_FG(oth0, DARK_GRAY_FG(oth1))
#     #     else
#     #         oth0 = "$(noth) dev/socket/fifo "
#     #         oth1 = "[$(nsymoth) syml]"

#     #         oth = oth0 * oth1
#     #         coth = YELLOW_FG(oth0, NEGATIVE(oth1))
#     #     end
#     # end

#     # if nbrk == 0
#     #     brk = "(no broken syml)"
#     #     cbrk = DARK_GRAY_FG(brk)
#     # else
#     #     brk = "$(nbrk) broken syml"
#     #     cbrk = NEGATIVE(RED_FG(brk))
#     # end

#     # if colors
#     #     println(cstart1, csym1, csize1)
#     #     println(cstart2, csym2, csep, coth, csep, cbrk)
#     # end

# end






include("pprint.jl_exports")

