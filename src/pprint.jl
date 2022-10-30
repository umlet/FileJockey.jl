


function stats(X::AbstractVector{<:AbstractFsEntry})
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

    return (dtype, dExt)
end

function info(X::AbstractVector{<:AbstractFsEntry})
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
    nfile = X |> cn(is(FsFile))
    ndir = X |> cn(is(FsDir))
    nother = X |> cn(is(FsOther))

    nsyml2file = X |> cn(is(FsSymlink{FsFile}))
    nsyml2dir = X |> cn(is(FsSymlink{FsDir}))
    nsyml2other = X |> cn(is(FsSymlink{FsOther}))
    nsyml2nonexist = X |> cn(is(FsSymlink{FsUnknownNonexist}))

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
file-likes, regular and symlinks        $(nfile + nsyml2file)
dir-likes, regular and symlinks         $(ndir + nsyml2dir)
other, regular and symlinks             $(nother + nsyml2other)
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


lpad(s::AbstractString, upto::Int64) = ( upto < length(s)  &&  error("lpad '$upto' too small for string 's'")  ;  return " "^(upto-length(s)) * s )
lpad(upto::Int64) = x -> lpad(x, upto)

lpad(X::AbstractVector{<:AbstractString}) = ( maxlen = maximum(length.(X))  ;  return [ lpad(x, maxlen) for x in X ] )


# NOT NEEDED <=> .*
# function Base.:*(X::AbstractVector{<:AbstractString}, Y::AbstractVector{<:AbstractString})
#     length(X) != length(Y)  &&  error("length mismatch")
#     return [ x*y for (x,y) in zip(X, Y) ]
# end




function pprint(nfiles, nsymfiles, ndirs, nsymdirs, noth, nsymoth, nbrk; colors::Bool=true)
    fsize = 5676453653;

    start1,start2 = lpad(String[ tostr_thsep(nfiles), tostr_thsep(ndirs) ]) .* [" files ", " dirs  "]
    cstart1 = BLUE_FG(start1)
    cstart2 = GREEN_FG(start2)
    
    sym1 = nsymfiles > 0   ?  "[$(nsymfiles) of which symlinked]"  :  "(none of which symlinked)"
    sym2 = nsymdirs > 0    ?  "[$(nsymdirs) of which symlinked]"   :  "(none of which symlinked)"
    csym1 = nsymfiles > 0  ?  NEGATIVE(BLUE_FG(sym1))  :  DARK_GRAY_FG(sym1)
    csym2 = nsymdirs > 0   ?  NEGATIVE(GREEN_FG(sym2)) :  DARK_GRAY_FG(sym2)

    size1 = " -- $(fsizehuman(fsize)) -- $(tostr_thsep(fsize)) bytes"
    csize1 = BLUE_FG(size1)

    sep = "  :::  "
    csep = DARK_GRAY_FG(sep)

    if noth+nsymoth == 0
        oth = "(0 dev/socket/fifo; none syml)"
        coth = DARK_GRAY_FG(oth)
    else
        if nsymoth == 0
            oth0 = "$(noth) dev/socket/fifo "
            oth1 = "(none syml)"

            oth = oth0 * oth1
            coth = YELLOW_FG(oth0, DARK_GRAY_FG(oth1))
        else
            oth0 = "$(noth) dev/socket/fifo "
            oth1 = "[$(nsymoth) syml]"

            oth = oth0 * oth1
            coth = YELLOW_FG(oth0, NEGATIVE(oth1))
        end
    end

    if nbrk == 0
        brk = "(0 broken syml)"
        cbrk = DARK_GRAY_FG(brk)
    else
        brk = "$(nbrk) broken syml"
        cbrk = NEGATIVE(RED_FG(brk))
    end

    if colors
        println(cstart1, csym1, csize1)
        println(cstart2, csym2, csep, coth, csep, cbrk)
    end

end