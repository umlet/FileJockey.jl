module EntriesStats


using Base.Filesystem


using CommandLiner.Iter
using CommandLiner.Conv
using CommandLiner.Group
using CommandLiner.Ext
using CommandLiner.ColorBox


using ..Entries


filedevice(st::StatStruct)::UInt64 = st.device
fileinode(st::StatStruct)::UInt64 = st.inode
filedeviceinode(st::StatStruct)::Tuple{UInt64, UInt64} = (filedevice(st), fileinode(st))



# TODO chained symlinks could alter #symlinks!!!

struct Stats  # mutable avoids some boilerplate in construction
    # PARTITION for counting
    # - standard
    fileentries::Vector{FileEntry}
    syml2fileentries::Vector{Symlink{FileEntry}}
    direntries::Vector{DirEntry}
    syml2direntries::Vector{Symlink{DirEntry}}
    # non-standard
    otherentries::Vector{OtherEntry}
    syml2otherentries::Vector{Symlink{OtherEntry}}
    unknownentriesNONEXIST::Vector{UnknownEntryNONEXIST}
    syml2unknownentriesNONEXIST::Vector{Symlink{UnknownEntryNONEXIST}}  # shortcut for '2unknownnonexist'


    # standard combinations
    symltarget_fileentries::Vector{FileEntry}
    symltarget_direntries::Vector{DirEntry}
    symltarget_otherentries::Vector{OtherEntry}
    symltarget_unknownentriesNONEXIST::Vector{UnknownEntryNONEXIST}

    files::Vector{FileEntry} 
    dirs::Vector{DirEntry}
    others::Vector{OtherEntry}
    unknowns::Vector{UnknownEntryNONEXIST}

    setfilepaths::Set{String}
    setfiledevices::Set{UInt64}
    setfiledeviceinodes::Set{Tuple{UInt64, UInt64}}

    setdirpaths::Set{String}

    function Stats(X::AbstractVector{<:AbstractEntry})
        # BASE
        # standard
        fileentries::Vector{FileEntry} = FileEntry[]
        syml2fileentries::Vector{Symlink{FileEntry}} = Symlink{FileEntry}[]
        direntries::Vector{DirEntry} = DirEntry[]
        syml2direntries::Vector{Symlink{DirEntry}} = Symlink{DirEntry}[]
    
        # non-standard
        otherentries::Vector{OtherEntry} = OtherEntry[]
        syml2otherentries::Vector{Symlink{OtherEntry}} = Symlink{OtherEntry}[]
        unknownentriesNONEXIST::Vector{UnknownEntryNONEXIST} = UnknownEntryNONEXIST[]
        syml2unknownentriesNONEXIST::Vector{Symlink{UnknownEntryNONEXIST}} = Symlink{UnknownEntryNONEXIST}[]  # shortcut for '2unknownnonexist'
    
        for x in X
            x isa FileEntry             &&  ( push!(fileentries, x);                continue )
            x isa DirEntry              &&  ( push!(direntries, x);                 continue )
            x isa OtherEntry            &&  ( push!(otherentries, x);               continue )
            x isa UnknownEntryNONEXIST  &&  ( push!(unknownentriesNONEXIST, x);     continue )
            if x isa Symlink
                x = follow(x)
                x isa FileEntry             &&  ( push!(syml2fileentries, x);               continue )
                x isa DirEntry              &&  ( push!(syml2direntries, x);                continue )
                x isa OtherEntry            &&  ( push!(syml2otherentries, x);              continue )
                x isa UnknownEntryNONEXIST  &&  ( push!(syml2unknownentriesNONEXIST, x);    continue )
            end
            @assert false
        end

        symltarget_fileentries::Vector{FileEntry} = follow.(syml2fileentries)
        symltarget_direntries::Vector{DirEntry} = follow.(syml2direntries)
        symltarget_otherentries::Vector{OtherEntry} = follow.(syml2otherentries)
        symltarget_unknownentriesNONEXIST::Vector{UnknownEntryNONEXIST} = follow.(syml2unknownentriesNONEXIST)

        files::Vector{FileEntry} = [ fileentries ; symltarget_fileentries ]
        dirs::Vector{DirEntry} = [ direntries ; symltarget_direntries ]
        others::Vector{OtherEntry} = [ otherentries ; symltarget_otherentries ]
        unknowns::Vector{UnknownEntryNONEXIST} = [ unknownentriesNONEXIST ; symltarget_unknownentriesNONEXIST ]

        setfilepaths::Set{String} = Set{String}( path(x) for x in files )
        setfiledevices::Set{UInt64} = Set{UInt64}( filedevice(stat(x)) for x in files )
        setfiledeviceinodes::Set{Tuple{UInt64, UInt64}} = Set{Tuple{UInt64, UInt64}}( (filedeviceinode(stat(x))) for x in files)

        setdirpaths::Set{String} = Set{String}( path(x) for x in dirs )

        return new(
            fileentries,
            syml2fileentries,
            direntries,
            syml2direntries,
            otherentries,
            syml2otherentries,
            unknownentriesNONEXIST,
            syml2unknownentriesNONEXIST,

            symltarget_fileentries,
            symltarget_direntries,
            symltarget_otherentries,
            symltarget_unknownentriesNONEXIST,

            files,
            dirs,
            others,
            unknowns,

            setfilepaths,
            setfiledevices,
            setfiledeviceinodes,

            setdirpaths
        )
    end    
end
stats(X::AbstractVector{<:AbstractEntry}) = Stats(X)

Base.filesize(S::Stats) = sum(filesize.(S.files))

nfileentries(S::Stats) = length(S.fileentries)
nsyml2fileentries(S::Stats) = length(S.syml2fileentries)
ndirentries(S::Stats) = length(S.direntries)
nsyml2direntries(S::Stats) = length(S.syml2direntries)
notherentries(S::Stats) = length(S.otherentries)
nsyml2otherentries(S::Stats) = length(S.syml2otherentries)
nunknownentriesNONEXIST(S::Stats) = length(S.unknownentriesNONEXIST)
nsyml2unknownentriesNONEXIST(S::Stats) = length(S.syml2unknownentriesNONEXIST)

nsymltarget_fileentries(S::Stats) = length(S.symltarget_fileentries)
nsymltarget_direntries(S::Stats) = length(S.symltarget_direntries)
nsymltarget_otherentries(S::Stats) = length(S.symltarget_otherentries)
nsymltarget_unknownentriesNONEXIST(S::Stats) = length(S.symltarget_unknownentriesNONEXIST)

nfiles(S::Stats) = length(S.files)
ndirs(S::Stats) = length(S.dirs)
nothers(S::Stats) = length(S.others)
nunknowns(S::Stats) = length(S.unknowns)

nsetfilepaths(S::Stats) = length(S.setfilepaths)
nsetfiledevices(S::Stats) = length(S.setfiledevices)
nsetfiledeviceinodes(S::Stats) = length(S.setfiledeviceinodes)

nsetdirpaths(S::Stats) = length(S.setdirpaths)



include("entriesstats.jl_base")
include("entriesstats.jl_show")
include("entriesstats.jl_exports")
end # module