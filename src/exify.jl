


#using JSON
#using OrderedCollections



# module Exey
# export exe
# function exe(scmd::String; fail=true, okexits=[], splitlines=true)
#     cmd = Cmd(["bash", "-c", scmd])
#     bufout = IOBuffer()                                                     ; buferr = IOBuffer()
#     process = run(pipeline(ignorestatus(cmd), stdout=bufout, stderr=buferr))
#     exitcode = process.exitcode
    
#     sout = String(take!(bufout))                                            ; serr = String(take!(buferr))
#     close(bufout)                                                           ; close(buferr)

#     fail  &&  exitcode != 0  &&  !(exitcode in okexits)  &&  error("exe: OS system command failed: '$(scmd)'; stderr:\n$(serr)")

#     if splitlines
#         length(sout) > 0  &&  last(sout) == '\n'  &&  (sout = chop(sout))   ; length(serr) > 0  &&  last(serr) == '\n'  &&  (serr = chop(serr))
#         souts = sout != "" ? split(sout, '\n') : String[]                   ; serrs = serr != "" ? split(serr, '\n') : String[]
#         return (; exitcode, souts, serrs)
#     end
#     return (; exitcode, sout, serr)
# end
# end
# using .Exey





struct ExifData
    _d::OrderedDict{Symbol, Any}
    function ExifData(d::OrderedDict{String, Any})
        _d = OrderedDict{Symbol, Any}()

        # original/full keys as symbols
        for (k,v) in d  _d[Symbol(k)] = v  end

        # shortcut keys, if unique
        dtmp = OrderedDict()
        for (korig,_) in d
            ss = split(korig, '_')
            length(ss) != 2  &&  continue  # must be 2; >2 not possible; 1 possible for 'SourceFile'
            kshort = ss[2]
            haskey(dtmp, kshort)  ||  ( dtmp[kshort] = [] )
            push!(dtmp[kshort], korig)
        end
        for (kshort, korigs) in dtmp
            length(korigs) != 1  &&  continue
            _d[Symbol(kshort)] = _d[Symbol(korigs[1])]
        end

        return new(_d)
    end
end

function Base.getproperty(x::ExifData, sym::Symbol)
    sym == :_d  &&  ( return getfield(x, sym) )
    return x._d[sym]
end
Base.propertynames(x::ExifData) = Tuple(keys(x._d))


function changeexifkeys(d::OrderedDict{String, Any})
    RET = OrderedDict{String, Any}()
    for (k,v) in d
        occursin('_', k)  &&  error("exif dict key '$(k)' contains '_'")
        count(':', k) >= 2  &&  error("exif dict key '$(k)' contains 2+ colons")
        k2 = replace(k, ':'=>'_')
        RET[k2] = v
    end
    return RET
end



function info(x::ExifData)
    len = keys(x._d) |> mp(string) |> mp(length) |> maximum
    for (k,v) in x._d
        println(rpad(k, len), " = ", v)
    end
end

function _exif_date2sanedate(s::AbstractString)
    length(s) != 19  &&  error("exif value of 'Time_CreateDate' has length != 19")
    YYYY = s[1:4]
    MM = s[6:7]
    DD = s[9:10]
    hh = s[12:13]
    mm = s[15:16]
    ss = s[18:19]
    return YYYY * MM * DD * "_" * hh * mm * ss
end

function exif_create_datetime(x::ExifData)
    if haskey(x._d, :Time_CreateDate)
        s = x.Time_CreateDate
    end
    return _exif_date2sanedate(s)
end

















function _exify_base(ss::Vector{<:AbstractString})  # ! all fs must be valid, readable filenames
    exiftool_options = [
        # "-S",           # very short output format: tagnames and no spaces -- OF NO USE WITH -json
        # "-duplicates",  # =='-a': extracts duplicates as well -- OF NO USE AS IMPLIE WITH -json
        "-json",
        "-G2"               # groups by TIME, IMAGE, CAMERA, OTHER/FS
    ]
    # what does prevent XXX reading text files? -fast??? TODO

    scmd = "exiftool" * " " * join(exiftool_options, " ") * " " * join(ss, " ")
    s = exe(scmd; splitlines=false)[2]
    js = JSON.parse(s; dicttype=OrderedDict)
    return changeexifkeys.(js)
end
_exify_base(s::AbstractString) = _exify_base([s])[1]

function _exify(fs::AbstractVector{FileEntry})
    ds = _exify_base(path.(fs))
    ExifData.(ds)
end
function _exify(X::AbstractVector)  # TODO maybe more efficient???
    fs::Vector{FileEntry} = X
    return _exify(fs)
end
_exify(f::FileEntry) = _exify([f])[1]
_exify(s::AbstractString) = _exify(FileEntry(EntryCanon(s)))


exify(itr) =                itr |> pt(100) |> mp(_exify) |> iflatten
exify(X::AbstractVector) =    X |> pt(100) |> mp(_exify) |> iflatten |> cl  # TODO mb use invoke w/ type Any?

exify(x::AbstractEntry) = exify([x]) |> first
exify(s::AbstractString) = exify(FileEntry(s))



include("exify.jl_exports")
