


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

        # original (":"=>"__"-corrected) keys as symbols
        for (k,v) in d  _d[Symbol(k)] = v  end

        # shortcut keys, if unique
        dtmp = OrderedDict()
        for (korig,_) in d
            ss = split(korig, "__")
            @assert length(ss) == 1  ||  length(ss) == 2
            length(ss) == 1  &&  continue  # possible for 'SourceFile'
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
        occursin("__", k)  &&  error("exif dict key '$(k)' contains '__'")
        count(':', k) >= 2  &&  error("exif dict key '$(k)' contains 2+ colons")
        k2 = replace(k, ':'=>"__")
        RET[k2] = v
    end
    return RET
end



function info(x::ExifData, grep=nothing)
    len = keys(x._d) |> mp(string) |> mp(length) |> maximum
    for (k,v) in x._d
        if grep !== nothing
            !occursin(grep, string(k))  &&  continue
        end
        println(":", rpad(k, len), " = ", v)
    end
end









function _date2sanedatetime(s::AbstractString)
    # time with and without time zone correction
    length(s) in (19, 25)  ||  error("invalid date format in '$(s)'")
    YYYY = s[1:4]
    MM = s[6:7]
    DD = s[9:10]
    hh = s[12:13]
    mm = s[15:16]
    ss = s[18:19]
    return YYYY * MM * DD * "_" * hh * mm * ss
end

function exif_sane_datetime(x::ExifData)
    if haskey(x._d, :Time__CreateDate)  
        s = _date2sanedatetime(x.Time__CreateDate)
        !startswith(s, "0000")  &&  ( return s )  # '0000' observed for existing CreateDate in a .mov file
    end
    haskey(x._d, :Time__FileModifyDate)  &&  ( return _date2sanedatetime(x.Time__FileModifyDate) )
    return "unknown"
end
function exif_sane_date(x::ExifData)
    s = exif_sane_datetime(x)
    s == "unknown"  &&  ( return s )
    s = split(s, "_")[1]
    @assert length(s) == 8
    return s
end
function exif_sane_year(x::ExifData)
    s = exif_sane_date(x)
    s == "unknown"  &&  ( return s )
    return s[1:4]
end
function exif_sane_yearmonth(x::ExifData)
    s = exif_sane_date(x)
    s == "unknown"  &&  ( return s )
    return s[1:6]
end





function _dnames_and_hardlink(f::FileEntry, x::ExifData, dname)
    RET_dnames_full = String[]

    fname_base = basename(f)
    lname_base = exif_sane_datetime(x) * "___" * fname_base

    dname_rel_1 = exif_sane_year(x)
    dname_full_1 = joinpath(dname, dname_rel_1)
    push!(RET_dnames_full, dname_full_1)
    if dname_rel_1 == "unknown"
        RET_lname_full = joinpath(dname_full_1, lname_base)
        return (RET_dnames_full, RET_lname_full)
    end

    dname_rel_2 = exif_sane_yearmonth(x)
    dname_full_2 = joinpath(dname_full_1, dname_rel_2)
    push!(RET_dnames_full, dname_full_2)
    RET_lname_full = joinpath(dname_full_2, lname_base)
    return (RET_dnames_full, RET_lname_full)
end

function hardlinker(F::AbstractVector{<:FileEntry}, X::AbstractVector{ExifData}, dname)
    dname = path(DirEntry(dname))
    length(F) != length(X)  &&  error("length mismatch files and exifdata")

    dnames_full = String[]
    lnames_full = String[]
    for (f,x) in zip(F, X)
        _dnames_full,_lname_full = _dnames_and_hardlink(f, x, dname)
        append!(dnames_full, _dnames_full)
        push!(lnames_full, _lname_full)
    end

    #check for unique target filenames
    if length(Set(lnames_full)) != length(lnames_full)
        error("link paths are not unique!")
    else
        @info "$(length(lnames_full)) unique links will be created"
    end
    # make sure none of the target hardlinks exist
    for lname_full in lnames_full
        ispath(lname_full)  &&  error("path '$(lname_full)' already exists")
    end
    @info "(..none of them exists)"

    # create intermediate dirs
    dnames_full = OrderedSet(dnames_full) |> collect
    @info "hardlinks will reside in $(length(dnames_full)) dirs; creating intermediate dirs.."

    for dname_full in dnames_full
        isdir(dname_full)  &&  continue
        mkdir(dname_full)
    end
    @info "dirs created"
    
    for (f,lname_full) in zip(F, lnames_full)
        println(path(f), " <-- ", lname_full, " created")
        hardlink(path(f), lname_full)
    end
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


exify(itr) =                itr |> pt(100) |> mp(_exify) |> flatten_
exify(X::AbstractVector) =    X |> pt(100) |> mp(_exify) |> flatten_ |> cl  # TODO mb use invoke w/ type Any?

exify(x::AbstractEntry) = exify([x]) |> first
exify(s::AbstractString) = exify(FileEntry(s))



include("exify.jl_exports")
