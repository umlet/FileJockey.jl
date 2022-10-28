

struct PathCanon
    s::String  # canonical; up to symlink basename
    function PathCanon(x::PathCanon, relsegment::AbstractString)  # avoids realpath(); assumes existence and x being a dir
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


struct FsEntryCanon
    path::PathCanon  
    st::StatStruct
    function FsEntryCanon(path::PathCanon)
        st = lstat(path)
        !ispath(st)  &&  error("file system entry '$(path.s)' not found")
        return new(path, st)
    end
end
FsEntryCanon(s::AbstractString=".") = FsEntryCanon(PathCanon(s))
_show(io::IO, x::FsEntryCanon) = print(io, """FsEntryCanon($(x.path), $(Base.Filesystem.filemode_string(x.st)))""")
Base.show(io::IO, ::MIME"text/plain", x::FsEntryCanon) = _show(io, x)
Base.show(io::IO, x::FsEntryCanon) = _show(io, x)




abstract type AbstractFsEntry end


Base.show(io::IO, ::MIME"text/plain", x::AbstractFsEntry) = _show(io, x)
Base.show(io::IO, x::AbstractFsEntry) = _show(io, x)


struct FsFile <: AbstractFsEntry
    path::PathCanon
    st::StatStruct
    function FsFile(x::FsEntryCanon)
        return new(x.path, x.st)
    end
end
_show(io::IO, x::FsFile) = print(io, """FsFile($(x.path), $(Base.Filesystem.filemode_string(x.st)), $(filesize(x.st)) bytes)""")

struct FsDir <: AbstractFsEntry
    path::PathCanon
    st::StatStruct
    function FsDir(x::FsEntryCanon)
        return new(x.path, x.st)
    end
end
FsDir() = FsEntry(".")
_show(io::IO, x::FsDir) = print(io, """FsDir($(x.path), $(Base.Filesystem.filemode_string(x.st)))""")

struct FsOther <: AbstractFsEntry
    path::PathCanon
    st::StatStruct
    function FsOther(x::FsEntryCanon)
        return new(x.path, x.st)
    end
end
_show(io::IO, x::FsOther) = print(io, """FsOther($(x.path), $(Base.Filesystem.filemode_string(x.st)))""")

struct FsSymlink{T} <: AbstractFsEntry
    path::PathCanon
    st::StatStruct  # stat of symlink!
    target::T
    function FsSymlink{T}(x::FsEntryCanon, target::T) where {T<:AbstractFsEntry}
        return new{T}(x.path, x.st, target)
    end
end
_show(io::IO, x::FsSymlink) = print(io, """$(typeof(x))($(x.path) -> $(x.target.path))""")

struct FsUnknownNonexist <: AbstractFsEntry
    path::String
    function FsUnknownNonexist(f::AbstractString)
        return new(f)
    end
end
_show(io::IO, x::FsUnknownNonexist) = print(io, """FsUnknownNonexist(?$(x.path)?)""")


# function _show(io::IO, X::AbstractVector{<:AbstractFsEntry})
#     print("$(length(X))-element $(typeof(X)):")
#     for x in Base.Iterators.take(X, 5)
#         print("\n "); _show(io, x)
#     end
#     length(X) > 5  &&  print("\n ...")
#     # println()
#     # summary(X)
# end
# Base.show(io::IO, ::MIME"text/plain", X::AbstractVector{<:AbstractFsEntry}) = _show(io, X)
# Base.show(io::IO, X::AbstractVector{<:AbstractFsEntry}) = _show(io, X)


# issymlinkbroken(x::FsSymlink{FsUnknownNonexist}) = true
# issymlinkbroken(x::FsEntry) = false
# export issymlinkbroken


function FsEntry(x::FsEntryCanon)
    if islink(x.st)
        s_readlink = readlink(x.path.s)
        s_path_target = s_readlink
        if !isabspath(s_path_target)
            s_path_target = joinpath(dirname(x.path.s), s_path_target)
        end

        st_target = stat(s_path_target)
        @assert !islink(st_target)

        if !ispath(st_target)  # broken symlink
            return FsSymlink{FsUnknownNonexist}(x, FsUnknownNonexist(s_readlink))
        end

        fse = FsEntry(s_path_target)
        return FsSymlink{typeof(fse)}(x, fse)
    end

    isfile(x.st)  &&  return FsFile(x)
    isdir(x.st)   &&  return FsDir(x)
    return FsOther(x)
end
FsEntry(s::AbstractString) = FsEntry(FsEntryCanon(s))

macro fs_str(s)
    FsEntry(s)
end



path(x::AbstractFsEntry) = x.path.s
pathcanon(x::AbstractFsEntry) = x.path


isfilelike(x::Union{FsFile, FsSymlink{FsFile}}) = true
isfilelike(x::AbstractFsEntry) = false

isstandard(x::AbstractFsEntry) = false
isstandard(x::Union{FsFile, FsDir, FsSymlink{FsFile}, FsSymlink{FsDir}}) = true

follow(x::AbstractFsEntry) = x
follow(x::FsSymlink) = x.target













Base.endswith(x::AbstractFsEntry, a) = endswith(x.path.s, a)

Base.splitext(x::AbstractFsEntry) = splitext(x.path.s)



# OK, behaviour in line with lstat returning stat implicitly
Base.Filesystem.lstat(x::PathCanon) = lstat(x.s)
Base.Filesystem.stat(x::PathCanon) = stat(x.s)

# stat returns target
Base.Filesystem.stat(x::FsSymlink) = x.target.st
Base.Filesystem.stat(x::AbstractFsEntry) = x.st

# lstat defaults to stat if no symlink
Base.Filesystem.lstat(x::FsSymlink) = x.st
Base.Filesystem.lstat(x::AbstractFsEntry) = stat(x)

# stat & lstat should usually be sufficient to override
# however, Base.Filesystem throws in a rather weird joinpath; so we override that as well
Base.Filesystem.joinpath(x::AbstractFsEntry) = x
