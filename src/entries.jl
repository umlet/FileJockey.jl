

struct PathCanon
    s::String  # canonical; up to symlink basename
    function PathCanon(x::PathCanon, relsegment::AbstractString)  # avoids realpath(); assumes existence of relsegment, and x being a dir
        @assert !occursin('/', relsegment)  # TODO WINDOWS
        return new(joinpath(x.s, relsegment))
    end
    function PathCanon(s::AbstractString=".")
        s == ""  &&  error("path must be non-empty string")
        # make sure trailing slashes do not trigger treat-link-as-dir logic
        s = rstrip(s, '/')  # TODO WINDOWS
        s == ""  &&  ( s = "/" )

        path = isabspath(s)  ?  s  :  abspath(s)
        path = islink(path)  ?  joinpath(realpath(dirname(path)), basename(path))  :  realpath(path)
        return new(path)
    end
end


struct EntryCanon
    path::PathCanon  
    st::StatStruct
    function EntryCanon(path::PathCanon)
        st = lstat(path)
        !ispath(st)  &&  error("file system entry '$(path.s)' not found")
        return new(path, st)
    end
end
EntryCanon(s::AbstractString=".") = EntryCanon(PathCanon(s))




abstract type AbstractEntry end


Base.show(io::IO, ::MIME"text/plain", x::AbstractEntry) = _show(io, x)
#Base.show(io::IO, x::AbstractEntry) = _show(io, x)


struct FileEntry <: AbstractEntry
    path::PathCanon
    st::StatStruct
    function FileEntry(x::EntryCanon)
        return new(x.path, x.st)
    end
end
FileEntry(s::AbstractString)::FileEntry = Entry(s)
_show(io::IO, x::FileEntry) = print(io, colorizeas("FileEntry", x), """("$(path(x))", $(Base.Filesystem.filemode_string(x.st)), $(filesize(x.st)) bytes)""")

struct DirEntry <: AbstractEntry
    path::PathCanon
    st::StatStruct
    function DirEntry(x::EntryCanon)
        return new(x.path, x.st)
    end
end
DirEntry(s::AbstractString)::DirEntry = Entry(s)
_show(io::IO, x::DirEntry) = print(io, colorizeas("DirEntry", x), """("$(path(x))", $(Base.Filesystem.filemode_string(x.st)))""")

struct OtherEntry <: AbstractEntry
    path::PathCanon
    st::StatStruct
    function OtherEntry(x::EntryCanon)
        return new(x.path, x.st)
    end
end
OtherEntry(s::AbstractString)::OtherEntry = Entry(s)
_show(io::IO, x::OtherEntry) = print(io, colorizeas("OtherEntry", x), """("$(path(x))", $(Base.Filesystem.filemode_string(x.st)))""")




struct Symlink{T} <: AbstractEntry
    path::PathCanon
    st::StatStruct  # stat of symlink!
    target::T
    function Symlink{T}(x::EntryCanon, target::T) where {T<:AbstractEntry}
        return new{T}(x.path, x.st, target)
    end
end
_show(io::IO, x::Symlink) = print(io, colorizeas("$(typeof(x))", x), """("$(path(x))" -> "$(path(x.target))")""")

struct UnknownEntryNONEXIST <: AbstractEntry
    path::String  # NOT path canon!
    st::StatStruct  # zero entries
    function UnknownEntryNONEXIST(f::AbstractString, st0::StatStruct)  # CHECK maybe hide st0 inside?
        return new(f, st0)  # new(f, st)
    end
end
_show(io::IO, x::UnknownEntryNONEXIST) = print(io, colorizeas("UnknownEntryNONEXIST", x), """(???$(x.path)???)""")

# ATTENTION: statstruct contains fname; do not use in identity checks!!!



function Entry(x::EntryCanon)
    if islink(x.st)
        s_readlink = readlink(x.path.s)
        s_path_target = s_readlink
        if !isabspath(s_path_target)
            s_path_target = joinpath(dirname(x.path.s), s_path_target)
        end

        st_target = stat(s_path_target)
        @assert !islink(st_target)

        if !ispath(st_target)  # broken symlink
            return Symlink{UnknownEntryNONEXIST}(x, UnknownEntryNONEXIST(s_readlink, st_target))  # keep original (possibly relative) link; no more ispath assert on rel path, as it could by incidence exist on call site
        end

        fse = Entry(s_path_target)
        return Symlink{typeof(fse)}(x, fse)
    end

    isfile(x.st)  &&  return FileEntry(x)
    isdir(x.st)   &&  return DirEntry(x)
    return OtherEntry(x)
end
Entry(s::AbstractString) = Entry(EntryCanon(s))




# macro fj_str(s)
#     Entry(s)
# end


path(x::AbstractEntry) = x.path.s
path(x::UnknownEntryNONEXIST) = x.path

haspath(x::AbstractEntry, s::AbstractString) = path(x) == s
haspath(s::AbstractString) = x -> haspath(x, s)

isstandard(x::Union{FileEntry, DirEntry, Symlink{FileEntry}, Symlink{DirEntry}}) = true
isstandard(x::AbstractEntry) = false

follow(x::AbstractEntry) = x
follow(x::Symlink) = x.target


function getfiles(X::AbstractVector{<:AbstractEntry})
    return X |> fl(isfile) |> mp(follow)
end


















include("entries.jl_base")
include("entries.jl_exports")
