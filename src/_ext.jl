module Ext


using OrderedCollections



# NOTE:
# implementing 'Base.splitext()' is all that is needed for a type to interact with the extension helpers below:
#
# Example:
# struct MyType  s::String  end
#
# Base.splitext(x::MyType) = splitext(x.s)




function ext(x)
    _,e = splitext(x)
    e == ""  &&  return nothing
    @assert startswith(e, '.')
    return chop(e; head=1, tail=0)
end




# This list of extension synonym was scraped from Phil Harvey's exiftool homepage: https://exiftool.org/ -- the respective license applies
include("ext.jl_data")


_SYM_EMPTY::Symbol = :_empty_
setsym_empty(sym::Symbol) = ( global _SYM_EMPTY = sym )
_SYM_UNREG::Symbol = :_unreg_
setsym_unreg(sym::Symbol) = ( global _SYM_UNREG = sym )


const _EXT2EXTY = OrderedDict{String, Symbol}();
function register_extgroups(extgroups::AbstractVector{<:AbstractVector{<:AbstractString}})
    global _EXT2EXTY
    empty!(_EXT2EXTY)

    for extgroup in extgroups
        isempty(extgroup)  &&  error("extension group is empty")

        exty = nothing
        for ext in extgroup
            ext = ext |> strip |> lowercase
            isempty(ext)  &&  error("empty-string extension in '$(extgroup)'")
            '.' in ext    &&  error("extension '$(ext)' contains '.'")
            ext == string(_SYM_EMPTY)  &&  error("extension '$(ext)' clashes with symbol name for empty extension; use 'set_symempty'")
            ext == string(_SYM_UNREG)  &&  error("extension '$(ext)' clashes with symbol name for unregistered extension; use 'set_symunreg'")
            haskey(_EXT2EXTY, ext)  &&  error("duplicate extension '$(ext)'")

            exty === nothing  &&  (exty = Symbol(ext))  # first ext in extgroup           
            _EXT2EXTY[ext] = exty
        end
    end
    return nothing
end


function show_extgroups()
    lastexty = nothing
    for (ext,exty) in _EXT2EXTY
        if exty != lastexty
            println()
            print(":$(exty) <=> ")
            lastexty = exty
        end
        print(" \"$(ext)\"")
    end
    println()
    println()
    println(""":$(_SYM_EMPTY) <=> "" nothing""")
    println(":$(_SYM_UNREG) <=> .. all other unregistered extensions")
    println()
end




function ext2exty(sn::Union{AbstractString, Nothing})::Symbol
    sn === nothing  &&  return _SYM_EMPTY
    sn == ""        &&  return _SYM_EMPTY

    ext = lowercase(sn)
    return get(_EXT2EXTY, ext, _SYM_UNREG)
end

exty(x) = ext(x) |> ext2exty




function hasext(x, sn::Union{AbstractString, Nothing})
    sn === nothing  &&  return ext(x) === nothing
    ext2 = lowercase(sn)

    sn = ext(x)
    sn === nothing  &&  return false
    ext1 = lowercase(sn)

    return ext1 == ext2
end
hasext(sn::Union{AbstractString, Nothing}) = x -> hasext(x, sn)


function hasext(x, sym::Symbol)::Bool
    sym === Symbol("")  &&  error("""invalid 'Symbol("")' used; use ':$(_SYM_EMPTY)' instead""")

    sym in [_SYM_EMPTY, _SYM_UNREG]  &&  return exty(x) in [_SYM_EMPTY, _SYM_UNREG]

    s = string(sym)  # convert to canonical exty (1st entry in extgroup)
    exty2 = ext2exty(s)

    exty1 = exty(x)
    return exty1 === exty2
end
hasext(sym::Symbol) = x -> hasext(x, sym)








function __init__()
    # prepare defaults in vec-vec format
    for s in ___EXTGROUPS_DEFAULT_RAWSTRINGS
        ss = split(s, ",")
        ss = [ strip(s) for s in ss ]  # just for default convenience; lowercase will always be done later/during register
        push!(___EXTGROUPS_DEFAULT, ss)
    end

    register_extgroups(___EXTGROUPS_DEFAULT)
end



include("ext.jl_docs")
include("ext.jl_exports")
end # module

