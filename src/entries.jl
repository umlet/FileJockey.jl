module Entries


using Base.Filesystem


using CommandLiner.ColorBox




# struct PathCanon
#     s::String  # canonical; up to symlink basename
#     # fast
#     # avoids slow realpath(); assumes existence of relsegment, and x being a dir; used internally only from dir walk
#     function PathCanon(x::PathCanon, relsegment::AbstractString)
#         @assert !occursin('/', relsegment)  # TODO WINDOWS
#         return new(joinpath(x.s, relsegment))
#     end
#     # slow
#     function PathCanon(s::AbstractString)
#         s == ""  &&  error("path must be non-empty string")

#         # remove trailing or duplicate path delimiters for Linux&Windows
#         s = s |> splitpath |> joinpath
#         path = isabspath(s)  ?  s  :  abspath(s)

#         st = lstat(path)  # works even if no read access rights; TODO check access rights later
#         !ispath(st)  &&  erroruser("files system entry '$path' not found")
#         path = islink(st)  ?  joinpath(realpath(dirname(path)), basename(path))  :  realpath(path)

#         return new(path)
#     end
# end
# struct EntryCanon
#     path::PathCanon  
#     st::StatStruct
#     function EntryCanon(path::PathCanon)
#         st = lstat(path)
#         !ispath(st)  &&  error("file system entry '$(path.s)' not found")
#         return new(path, st)
#     end
# end
# EntryCanon(s::AbstractString) = EntryCanon(PathCanon(s))

# abstract type AbstractEntry end
# #Base.show(io::IO, ::MIME"text/plain", x::AbstractEntry) = _show(io, x)
# #Base.show(io::IO, x::AbstractEntry) = _show(io, x)
# struct FileEntry <: AbstractEntry
#     path::PathCanon
#     st::StatStruct
#     function FileEntry(x::EntryCanon)
#         return new(x.path, x.st)
#     end
# end
# FileEntry(s::AbstractString)::FileEntry = Entry(s)
# _show(io::IO, x::FileEntry) = print(io, Cbx("FileEntry", x), """("$(path(x))", $(Base.Filesystem.filemode_string(x.st)), $(filesize(x.st)) bytes)""")
# struct DirEntry <: AbstractEntry
#     path::PathCanon
#     st::StatStruct
#     function DirEntry(x::EntryCanon)
#         return new(x.path, x.st)
#     end
# end
# DirEntry(s::AbstractString)::DirEntry = Entry(s)
# _show(io::IO, x::DirEntry) = print(io, Cbx("DirEntry", x), """("$(path(x))", $(Base.Filesystem.filemode_string(x.st)))""")
# struct OtherEntry <: AbstractEntry
#     path::PathCanon
#     st::StatStruct
#     function OtherEntry(x::EntryCanon)
#         return new(x.path, x.st)
#     end
# end
# OtherEntry(s::AbstractString)::OtherEntry = Entry(s)
# _show(io::IO, x::OtherEntry) = print(io, Cbx("OtherEntry", x), """("$(path(x))", $(Base.Filesystem.filemode_string(x.st)))""")
# struct Symlink{T} <: AbstractEntry
#     path::PathCanon
#     st::StatStruct  # stat of symlink!
#     target::T
#     function Symlink{T}(x::EntryCanon, target::T) where {T<:AbstractEntry}
#         return new{T}(x.path, x.st, target)
#     end
# end
# _show(io::IO, x::Symlink) = print(io, Cbx("$(typeof(x))", x), """("$(path(x))" -> "$(path(x.target))")""")
# struct UnknownEntryNONEXIST <: AbstractEntry
#     path::String  # NOT path canon!
#     st::StatStruct  # zero entries
#     function UnknownEntryNONEXIST(f::AbstractString, st0::StatStruct)  # CHECK maybe hide st0 inside?
#         return new(f, st0)  # new(f, st)
#     end
# end
# _show(io::IO, x::UnknownEntryNONEXIST) = print(io, Cbx("UnknownEntryNONEXIST", x), """(???$(x.path)???)""")



struct Abspathstripped
    s::String
    function Abspathstripped(s::AbstractString)
        s == ""  &&  error("path must be non-empty string")
    
        # abspath() implies normpath()
        s = abspath(s)  

        # abspath() keeps 1 trailing delim <=> if n were there; we strip it safely here (rstrip would have do deal with root on Linux&Win..)
        s = s |> splitpath |> joinpath  # safer than rstrip for "/" input
        return new(s)
    end
end
struct Pathseg  # real or synth
    s::String
    global ___Pathseg(s::AbstractString) = new(s)  # fast internal variant, if checks are already done, e.g., in dir traversal
    # only allows clean, 1-part, relative segment:
    # - no empty string
    # - abspath not allowed
    # - multi-part not allowed
    # - "foo/", i.e., training delim, not allowed
    function Pathseg(s::AbstractString)
        s == ""  &&  error("path segment is empty")
        isabspath(s)  &&  error("path segment is absolute")
        length(splitpath(s)) != 1  &&  error("path seqment is multi-part ")
        ( (Sys.iswindows() && endwith(s, '\\'))  ||  endswith(s, '/') )  &&  error("path segment '$(s)' ends with path delimiter")
        return new(s)
    end
end
struct Realpath
    s::String
    global ___Realpath(s::AbstractString) = new(s)  # fast internal variant, if checks are already done
    # only place in code where realpath() is called!
    # would fail on s==""
    Realpath(s::AbstractString) = new(realpath(s))  # realpath() is safe w.r.t. trailing delims => they are always fully removed
end
struct Realpathbutone
    s::String
    #global ___Realpathbutone(s::AbstractString) = new(s)
    function Realpathbutone(realpath_dirnm::Realpath, pathseg_basenm::Pathseg)
        return new(joinpath(realpath_dirnm.s, pathseg_basenm.s))
    end
end
struct Invalidpath
    s::String
    global function Invalidpath(x::Abspathstripped)  # not rel paths allowed, as path could become valid if pwd changes
        @assert !ispath(x.s)  # we take perf. hit here, just to make 100% sure; invalid should also be unusual case
        return new(x.s)
    end
end
function splitrealdir(x::Abspathstripped)::Union{Realpath, Invalidpath, Tuple{Realpath, Pathseg}}  # x is restricted to make sure != "", but especially that path is rstripped of path delim
    dirnm,basenm = splitdir(x.s)
    basenm == ""  &&  return Realpath(dirn)  # no assert on =="/" because of Win

    realpath_dirnm = try
        Realpath(dirnm)
    catch
        return Invalidpath(x)
    end
    pathseg_basenm = Pathseg(basenm)
    
    return (realpath_dirnm, pathseg_basenm)
end


abstract type AbstractEntry end
struct FileEntry <: AbstractEntry
    path::Realpath
    st::StatStruct
    global _FileEntry(path::Realpath, st::StatStruct) = ( @assert isfile(st);  new(path, st) )   # should not be called by user, as path and StatStruct could become out-or-sync
end
_show(io::IO, x::FileEntry) = print(io, Cbx("FileEntry", x), """("$(path(x))", $(Base.Filesystem.filemode_string(x.st)), $(filesize(x.st)) bytes)""")

struct DirEntry <: AbstractEntry
    path::Realpath
    st::StatStruct
    global _DirEntry(path::Realpath, st::StatStruct) = ( @assert isdir(st);  new(path, st) )
end
_show(io::IO, x::DirEntry) = print(io, Cbx("DirEntry", x), """("$(path(x))", $(Base.Filesystem.filemode_string(x.st)))""")

struct OtherEntry <: AbstractEntry
    path::Realpath
    st::StatStruct
    global _OtherEntry(path::Realpath, st::StatStruct) = ( @assert !islink(st) && !isfile(st) && !isdir(st);  new(path, st) )
end
_show(io::IO, x::OtherEntry) = print(io, Cbx("OtherEntry", x), """("$(path(x))", $(Base.Filesystem.filemode_string(x.st)))""")

struct UnknownEntryNONEXIST <: AbstractEntry
    path::Invalidpath
    st::StatStruct  # zero entries
    global _UnknownEntryNONEXIST(path::Invalidpath) = new(path, StatStruct())  # constructor return zero-StatStruct!
end
_show(io::IO, x::UnknownEntryNONEXIST) = print(io, Cbx("UnknownEntryNONEXIST", x), """(???$(x.path)???)""")

struct Symlink{T} <: AbstractEntry
    path::Realpathbutone
    st::StatStruct  # stat of symlink!
    target::T
    function Symlink{T}(path::Realpathbutone, st::StatStruct, target::T) where {T<:AbstractEntry}
        return new{T}(path, st, target)
    end
end
_show(io::IO, x::Symlink) = print(io, Cbx("$(typeof(x))", x), """("$(path(x))" -> "$(path(x.target))")""")


path(x::AbstractEntry) = x.path.s






# helpers
function _Entry(path::Realpath, st::StatStruct)
    @assert ispath(st)
    @assert !islink(st)

    isfile(st)  &&  return _FileEntry(path, st)
    isdir(st)   &&  return _DirEntry(path, st)
    return _OtherEntry(path, st)    
end
function _Entry(path::Realpathbutone, st::StatStruct)
    @assert ispath(st)
    @assert islink(st)

    s = readlink(path.s)
    s = joinpath(dirname(path.s), s)  # if s was absolute, joinpath returns it!
    e = Entry(s, allownonexist=true)
    return Symlink{typeof(e)}(path, st, e)
end


# only places where lstat is called
function Entry(path::Realpath; allownonexist=false)
    st = lstat()  # lstat becomes stat; we just want to the !islink assert to work later on..
    return _Entry(path, st)
end
function Entry(path::Invalidpath; allownonexist=false)
    allownonexist  &&  return _UnknownEntryNONEXIST(path)
    error("file system entry '$(path.s)' not found")
end
function Entry(realpath_dirnm::Realpath, pathseg_basenm::Pathseg; allownonexist=false)
    mayberealpath::String = joinpath(realpath_dirnm.s, pathseg_basenm.s)
    st = lstat(mayberealpath)

    !ispath(st)  &&  return Entry(Invalidpath(Abspathstripped(mayberealpath)); allownonexist=allownonexist)

    !islink(st)  &&  return _Entry(___Realpath(mayberealpath), st)  # this avoid duplicate realpath() call

    return _Entry(Realpathbutone(realpath_dirnm, pathseg_basenm), st)  # this join could be replaced with ___Realpathbutone(); we keep type checks
end



function Entry(x::Abspathstripped; allownonexist=false)
    path_or_invalid_or_tuple = splitrealdir(x)
    e = Entry(path_or_invalid_or_tuple...; allownonexist=allownonexist)
    return e
end



# TODO: check if disallow
# e = entry("ssyml_MYDIR/")

# only deals with original trailing '/'
function Entry(s::AbstractString; allownonexist=false)
    abspathstripped = Abspathstripped(s)
    # check if original intention was to get a dir entry
    #dirrequested = ( last(s) != last(abspathstripped.s) )
    dirrequested = Sys.iswindows()  ?  endswith(s, '\\')  :  endswith(s, '/')
    e = Entry(abspathstripped; allownonexist=allownonexist)
    if dirrequested
        !isdir(e)  &&  error("'$(s)' not a directory")
        # and prohibit ambiguity for Symlink{Direntry}
        !isa(e, DirEntry)  &&  error("The entry '$(basename(abspathstripped.s))/' could refer to a symlink2dir or its target dir; DISALLOWED; remove trailing delimiter to get the symlink entry, or use the dir path to get the dir entry")
    end
    return e
end

entry(s::AbstractString; allownonexist=false) = Entry(s; allownonexist=allownonexist)



















# function Entry(x::EntryCanon)
#     if islink(x.st)
#         s_readlink = readlink(x.path.s)
#         s_path_target = s_readlink
#         if !isabspath(s_path_target)
#             s_path_target = joinpath(dirname(x.path.s), s_path_target)
#         end

#         st_target = stat(s_path_target)
#         @assert !islink(st_target)

#         if !ispath(st_target)  # broken symlink
#             return Symlink{UnknownEntryNONEXIST}(x, UnknownEntryNONEXIST(s_readlink, st_target))  # keep original (possibly relative) link; no more ispath assert on rel path, as it could by incidence exist on call site
#         end

#         fse = Entry(s_path_target)
#         return Symlink{typeof(fse)}(x, fse)
#     end

#     isfile(x.st)  &&  return FileEntry(x)
#     isdir(x.st)   &&  return DirEntry(x)
#     return OtherEntry(x)
# end
# Entry(s::AbstractString) = Entry(EntryCanon(s))
# entry(s::AbstractString) =Entry(s)



# macro fj_str(s)
#     Entry(s)
# end



haspath(x::AbstractEntry, s::AbstractString) = path(x) == s
haspath(s::AbstractString) = x -> haspath(x, s)


isstandard(x::Union{FileEntry, DirEntry, Symlink{FileEntry}, Symlink{DirEntry}}) = true
isstandard(x::AbstractEntry) = false


follow(x::AbstractEntry) = x
follow(x::Symlink) = follow(x.target)  # should work for syml2syml2..

follow1(x::AbstractEntry) = x
follow1(x::Symlink) = x.target

symlinkdepth(x::AbstractEntry) = 0
symlinkdepth(x::Symlink) = 1 + symlinkdepth(x.target)


filesizehuman(x) = sizehuman(filesize(x))  # overridden in base

name(x::AbstractEntry) = basename(x)  # overridden in base

hasname(x::AbstractEntry, s::AbstractString) = name(x) == s
hasname(s::AbstractString) = x -> hasname(x, s)


sizegt(x::FileEntry, n::Int64) = filesize(x) > n
sizegt(n::Int64) = x -> sizegt(x, n)

sizelt(x::FileEntry, n::Int64) = filesize(x) < n
sizelt(n::Int64) = x -> sizelt(x, n)

sizeeq(x::FileEntry, n::Int64) = filesize(x) == n
sizeeq(n::Int64) = x -> sizeeq(x, n)

sizezero(x::FileEntry) = sizeeq(x, 0)





# function _show(io::IO, X::AbstractVector{<:AbstractEntry})
#     println("$(length(X))-element Vector{AbstractEntry}:")
#     tmp = tk(X, 11)
#     for x in take_(tmp, 10)
#         print(" ")
#         _show(io, x)
#         println()
#     end
#     length(tmp) == 11  &&  println(" ...")
#     println()
#     #println("describe():")
#     describe(X)
# end


ColorBox.style(x::AbstractEntry) = ColorBox.style(typeof(x))

ColorBox.style(::Type{FileEntry}) = "g"
ColorBox.style(::Type{DirEntry}) = "b"
ColorBox.style(::Type{OtherEntry}) = "y"
ColorBox.style(::Type{UnknownEntryNONEXIST}) = "r"

ColorBox.style(::Type{Symlink{FileEntry}}) = "g!"
ColorBox.style(::Type{Symlink{DirEntry}}) = "b!"
ColorBox.style(::Type{Symlink{OtherEntry}}) = "y!"
ColorBox.style(::Type{Symlink{UnknownEntryNONEXIST}}) = "r!"



# colorizeas(s::AbstractString, ::FileEntry) = colorize(s, LIGHT_GREEN_FG)
# colorizeas(s::AbstractString, ::DirEntry) = colorize(s, LIGHT_BLUE_FG)
# colorizeas(s::AbstractString, ::OtherEntry) = colorize(s, YELLOW_FG)
#     #=special case=# colorizeas(s::AbstractString, ::UnknownEntryNONEXIST) = colorize(s, RED_FG)

# colorizeas(s::AbstractString, ::Symlink{FileEntry}) = colorize(s, GREEN_FG, NEGATIVE)
# colorizeas(s::AbstractString, ::Symlink{DirEntry}) = colorize(s, BLUE_FG, NEGATIVE)
# colorizeas(s::AbstractString, ::Symlink{OtherEntry}) = colorize(s, YELLOW_FG, NEGATIVE)
# colorizeas(s::AbstractString, ::Symlink{UnknownEntryNONEXIST}) = colorize(s, RED_FG, NEGATIVE)
# #----------
# colorizeas(s::AbstractString, ::Type{FileEntry}) = colorize(s, LIGHT_GREEN_FG)
# colorizeas(s::AbstractString, ::Type{DirEntry}) = colorize(s, LIGHT_BLUE_FG)
# colorizeas(s::AbstractString, ::Type{OtherEntry}) = colorize(s, YELLOW_FG)
#     #=special case=# colorizeas(s::AbstractString, ::Type{UnknownEntryNONEXIST}) = colorize(s, RED_FG)

# colorizeas(s::AbstractString, ::Type{Symlink{FileEntry}}) = colorize(s, GREEN_FG, NEGATIVE)
# colorizeas(s::AbstractString, ::Type{Symlink{DirEntry}}) = colorize(s, BLUE_FG, NEGATIVE)
# colorizeas(s::AbstractString, ::Type{Symlink{OtherEntry}}) = colorize(s, YELLOW_FG, NEGATIVE)
# colorizeas(s::AbstractString, ::Type{Symlink{UnknownEntryNONEXIST}}) = colorize(s, RED_FG, NEGATIVE)







include("entries.jl_base")
include("entries.jl_exports")
end # module