


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

lpad(X::AbstractVector{<:AbstractString}) = ( maxlen = maximum(length.(X))  ;  return X |> mp(lpad) )

function pprint()
    nfiles = 15764; nsymfiles = 15
    ndirs = 345; nsymdirs = 0

    lines = String[ tostr_thsep(nfiles), tostr_thsep(ndirs) ]
end