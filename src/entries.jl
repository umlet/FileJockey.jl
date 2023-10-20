module Entries


using Base.Filesystem


using CommandLiner.ColorBox




struct PathCanon
    s::String  # canonical; up to symlink basename
    # fast
    # avoids slow realpath(); assumes existence of relsegment, and x being a dir; used internally only from dir walk
    function PathCanon(x::PathCanon, relsegment::AbstractString)
        @assert !occursin('/', relsegment)  # TODO WINDOWS
        return new(joinpath(x.s, relsegment))
    end
    # slow
    function PathCanon(s::AbstractString)
        s == ""  &&  error("path must be non-empty string")

        # remove trailing or duplicate path delimiters for Linux&Windows
        s = s |> splitpath |> joinpath
        path = isabspath(s)  ?  s  :  abspath(s)

        st = lstat(path)  # works even if no read access rights; TODO check access rights later
        !ispath(st)  &&  erroruser("files system entry '$path' not found")
        path = islink(st)  ?  joinpath(realpath(dirname(path)), basename(path))  :  realpath(path)

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
EntryCanon(s::AbstractString) = EntryCanon(PathCanon(s))




abstract type AbstractEntry end


#Base.show(io::IO, ::MIME"text/plain", x::AbstractEntry) = _show(io, x)
#Base.show(io::IO, x::AbstractEntry) = _show(io, x)


struct FileEntry <: AbstractEntry
    path::PathCanon
    st::StatStruct
    function FileEntry(x::EntryCanon)
        return new(x.path, x.st)
    end
end
FileEntry(s::AbstractString)::FileEntry = Entry(s)
_show(io::IO, x::FileEntry) = print(io, Cbx("FileEntry", x), """("$(path(x))", $(Base.Filesystem.filemode_string(x.st)), $(filesize(x.st)) bytes)""")

struct DirEntry <: AbstractEntry
    path::PathCanon
    st::StatStruct
    function DirEntry(x::EntryCanon)
        return new(x.path, x.st)
    end
end
DirEntry(s::AbstractString)::DirEntry = Entry(s)
_show(io::IO, x::DirEntry) = print(io, Cbx("DirEntry", x), """("$(path(x))", $(Base.Filesystem.filemode_string(x.st)))""")

struct OtherEntry <: AbstractEntry
    path::PathCanon
    st::StatStruct
    function OtherEntry(x::EntryCanon)
        return new(x.path, x.st)
    end
end
OtherEntry(s::AbstractString)::OtherEntry = Entry(s)
_show(io::IO, x::OtherEntry) = print(io, Cbx("OtherEntry", x), """("$(path(x))", $(Base.Filesystem.filemode_string(x.st)))""")




struct Symlink{T} <: AbstractEntry
    path::PathCanon
    st::StatStruct  # stat of symlink!
    target::T
    function Symlink{T}(x::EntryCanon, target::T) where {T<:AbstractEntry}
        return new{T}(x.path, x.st, target)
    end
end
_show(io::IO, x::Symlink) = print(io, Cbx("$(typeof(x))", x), """("$(path(x))" -> "$(path(x.target))")""")

struct UnknownEntryNONEXIST <: AbstractEntry
    path::String  # NOT path canon!
    st::StatStruct  # zero entries
    function UnknownEntryNONEXIST(f::AbstractString, st0::StatStruct)  # CHECK maybe hide st0 inside?
        return new(f, st0)  # new(f, st)
    end
end
_show(io::IO, x::UnknownEntryNONEXIST) = print(io, Cbx("UnknownEntryNONEXIST", x), """(???$(x.path)???)""")

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
entry(s::AbstractString) =Entry(s)



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