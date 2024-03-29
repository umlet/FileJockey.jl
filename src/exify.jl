



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

Base.show(io::IO, ::MIME"text/plain", x::ExifData) = _show(io, x)

function _show(io::IO, x::ExifData)
    info(x)
end







function _date2shortdatetime(s::AbstractString)
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

function exif2shortdatetime(x::ExifData)
    if haskey(x._d, :Time__CreateDate)  
        s = _date2shortdatetime(x.Time__CreateDate)
        !startswith(s, "0000")  &&  ( return s )  # '0000' observed for existing CreateDate in a .mov file
    end
    if haskey(x._d, :Time__FileModifyDate)  
        s = _date2shortdatetime(x.Time__FileModifyDate)
        !startswith(s, "0000")  &&  ( return _date2shortdatetime(x.Time__FileModifyDate) )
    end
    return "unknown"
end
function exif2shortdate(x::ExifData)
    s = exif2shortdatetime(x)
    s == "unknown"  &&  ( return s )
    s = split(s, "_")[1]
    @assert length(s) == 8
    return s
end
function exif2shortyear(x::ExifData)
    s = exif2shortdate(x)
    s == "unknown"  &&  ( return s )
    return s[1:4]
end
function exif2shortyearmonth(x::ExifData)
    s = exif2shortdate(x)
    s == "unknown"  &&  ( return s )
    return s[1:6]
end








function _dnames_and_hardlink(f::FileEntry, x::ExifData, dname)
    RET_dnames_full = String[]

    fname_base = basename(f)
    sext = ext(fname_base)
    sext = sext === nothing  ?  ""  :  "." * sext
    lname_base = exif2shortdatetime(x) * "___exifuse" * string(uuid4()) * sext

    dname_rel_1 = exif2shortyear(x)
    dname_full_1 = joinpath(dname, dname_rel_1)
    push!(RET_dnames_full, dname_full_1)
    if dname_rel_1 == "unknown"
        RET_lname_full = joinpath(dname_full_1, lname_base)
        return (RET_dnames_full, RET_lname_full)
    end

    dname_rel_2 = exif2shortyearmonth(x)
    dname_full_2 = joinpath(dname_full_1, dname_rel_2)
    push!(RET_dnames_full, dname_full_2)
    RET_lname_full = joinpath(dname_full_2, lname_base)
    return (RET_dnames_full, RET_lname_full)
end

function hardlinker(F::AbstractVector{<:FileEntry}, X::AbstractVector{ExifData}, d::DirEntry)
    length(F) == 0  &&  erroruser("no input files given")
    length(F) != length(X)  &&  erroruser("files and their exifdata do not match in size")

    dname = path(d)
    dnames_full = String[]
    lnames_full = String[]
    for (f,x) in zip(F, X)
        _dnames_full,_lname_full = _dnames_and_hardlink(f, x, dname)
        append!(dnames_full, _dnames_full)
        push!(lnames_full, _lname_full)
    end

    # check that all inputs are on same device, as well as the target dir
    tmp = stat.(F) |> mp(filedevice) |> Set
    @assert length(tmp) != 0
    length(tmp) > 1  &&  erroruser("input files do not reside on the same device")
    first(tmp) != filedevice(stat(d))  &&  erroruser("target path for hardlinks not on same device as input files")

    #check for unique target filenames
    length(Set(lnames_full)) != length(lnames_full)  &&   erroruser("hardlink paths are not unique; maybe use uuid4() in link names")

    # make sure none of the target hardlinks exist; impossible if non-existing target dir is enforced, but possible for import functionality
    for lname_full in lnames_full
        ispath(lname_full)  &&  error("hardlink path '$(lname_full)' already exists")
    end


    # create intermediate dirs
    dnames_full = OrderedSet(dnames_full) |> collect
    for dname_full in dnames_full
        isdir(dname_full)  &&  continue
        mkdir(dname_full)
    end

    # create hardlinks
    for (f,lname_full) in zip(F, lnames_full)
        println(path(f), " <-- ", lname_full, " created")
        hardlink(path(f), lname_full)
    end


    @info "$(length(dnames_full)) new, intermediate dirs created"
    @info "$(length(lnames_full)) hardlinks created"
    return nothing
end
hardlinker(F::AbstractVector{<:FileEntry}, X::AbstractVector{ExifData}, dname::AbstractString) = hardlinker(F, X, DirEntry(dname))









function _exify_base(ss::Vector{<:AbstractString})  # ! all fs must be valid, readable filenames
    exiftool_options = [
        # "-S",           # very short output format: tagnames and no spaces -- OF NO USE WITH -json
        # "-duplicates",  # =='-a': extracts duplicates as well -- OF NO USE AS IMPLIE WITH -json
        "-json",
        "-G2"               # groups by TIME, IMAGE, CAMERA, OTHER/FS
    ]
    # what does prevent XXX reading text files? -fast??? TODO

    #scmd = "exiftool" * " " * join(exiftool_options, " ") * " " * join(ss, " ")
    #s = exe(scmd; splitlines=false)[2]

    cmds = ["exiftool"]
    append!(cmds, exiftool_options)
    append!(cmds, ss)
    s = exe(cmds; splitlines=false)

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


exify(itr) =                itr |> part(100) |> mp(_exify) |> flatten_
exify(X::AbstractVector) =    X |> part(100) |> mp(_exify) |> flatten_ |> cl  # TODO mb use invoke w/ type Any?

exify(x::AbstractEntry) = exify([x]) |> first
exify(s::AbstractString) = exify(FileEntry(s))



include("exify.jl_exports")
