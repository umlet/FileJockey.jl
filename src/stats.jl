

function colorize(s::AbstractString, COLORS...)
    !CONF.colors  &&  return s
    RET = s
    for COLOR in COLORS
        RET = COLOR(RET)
    end
    return RET
end
colorizeas(s::AbstractString, ::FileEntry) = colorize(s, GREEN_FG)
colorizeas(s::AbstractString, ::DirEntry) = colorize(s, BLUE_FG)
colorizeas(s::AbstractString, ::OtherEntry) = colorize(s, YELLOW_FG)
    #=special case=# colorizeas(s::AbstractString, ::UnknownEntryNONEXIST) = colorize(s, RED_FG)

colorizeas(s::AbstractString, ::Symlink{FileEntry}) = colorize(s, GREEN_FG, NEGATIVE)
colorizeas(s::AbstractString, ::Symlink{DirEntry}) = colorize(s, BLUE_FG, NEGATIVE)
colorizeas(s::AbstractString, ::Symlink{OtherEntry}) = colorize(s, YELLOW_FG, NEGATIVE)
colorizeas(s::AbstractString, ::Symlink{UnknownEntryNONEXIST}) = colorize(s, RED_FG, NEGATIVE)
#----------
colorizeas(s::AbstractString, ::Type{FileEntry}) = colorize(s, GREEN_FG)
colorizeas(s::AbstractString, ::Type{DirEntry}) = colorize(s, BLUE_FG)
colorizeas(s::AbstractString, ::Type{OtherEntry}) = colorize(s, YELLOW_FG)
    #=special case=# colorizeas(s::AbstractString, ::Type{UnknownEntryNONEXIST}) = colorize(s, RED_FG)

colorizeas(s::AbstractString, ::Type{Symlink{FileEntry}}) = colorize(s, GREEN_FG, NEGATIVE)
colorizeas(s::AbstractString, ::Type{Symlink{DirEntry}}) = colorize(s, BLUE_FG, NEGATIVE)
colorizeas(s::AbstractString, ::Type{Symlink{OtherEntry}}) = colorize(s, YELLOW_FG, NEGATIVE)
colorizeas(s::AbstractString, ::Type{Symlink{UnknownEntryNONEXIST}}) = colorize(s, RED_FG, NEGATIVE)



filedevice(st::StatStruct)::UInt64 = st.device
fileinode(st::StatStruct)::UInt64 = st.inode
filedeviceinode(st::StatStruct)::Tuple{UInt64, UInt64} = (filedevice(st), fileinode(st))


struct FsStats  # mutable avoids some boilerplate in construction
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

    function FsStats(X::AbstractVector{<:AbstractEntry})
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
            x isa Symlink{FileEntry}    &&  ( push!(syml2fileentries, x);           continue )
            x isa DirEntry              &&  ( push!(direntries, x);                 continue )
            x isa Symlink{DirEntry}     &&  ( push!(syml2direntries, x);            continue )

            x isa OtherEntry            &&  ( push!(otherentries, x);               continue )
            x isa Symlink{OtherEntry}   &&  ( push!(syml2otherentries, x);          continue )
            x isa UnknownEntryNONEXIST  &&  ( push!(unknownentriesNONEXIST, x);     continue )
            x isa Symlink{UnknownEntryNONEXIST}  &&  ( push!(syml2unknownentriesNONEXIST, x);  continue )
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
stats(X::AbstractVector{<:AbstractEntry}) = FsStats(X)

Base.filesize(S::FsStats) = sum(filesize.(S.files))

# fileentries::Vector{FileEntry}
# syml2fileentries::Vector{Symlink{FileEntry}}
# direntries::Vector{DirEntry}
# syml2direntries::Vector{Symlink{DirEntry}}
# # non-standard
# otherentries::Vector{OtherEntry}
# syml2otherentries::Vector{Symlink{OtherEntry}}
# unknownentriesNONEXIST::Vector{UnknownEntryNONEXIST}
# syml2unknownentriesNONEXIST::Vector{Symlink{UnknownEntryNONEXIST}}  # shortcut for '2unknownnonexist'

nfileentries(S::FsStats) = length(S.fileentries)
nsyml2fileentries(S::FsStats) = length(S.syml2fileentries)
ndirentries(S::FsStats) = length(S.direntries)
nsyml2direntries(S::FsStats) = length(S.syml2direntries)
notherentries(S::FsStats) = length(S.otherentries)
nsyml2otherentries(S::FsStats) = length(S.syml2otherentries)
nunknownentriesNONEXIST(S::FsStats) = length(S.unknownentriesNONEXIST)
nsyml2unknownentriesNONEXIST(S::FsStats) = length(S.syml2unknownentriesNONEXIST)

nsymltarget_fileentries(S::FsStats) = length(S.symltarget_fileentries)
nsymltarget_direntries(S::FsStats) = length(S.symltarget_direntries)
nsymltarget_otherentries(S::FsStats) = length(S.symltarget_otherentries)
nsymltarget_unknownentriesNONEXIST(S::FsStats) = length(S.symltarget_unknownentriesNONEXIST)

nfiles(S::FsStats) = length(S.files)
ndirs(S::FsStats) = length(S.dirs)
nothers(S::FsStats) = length(S.others)
nunknowns(S::FsStats) = length(S.unknowns)

nsetfilepaths(S::FsStats) = length(S.setfilepaths)
nsetfiledevices(S::FsStats) = length(S.setfiledevices)
nsetfiledeviceinodes(S::FsStats) = length(S.setfiledeviceinodes)

nsetdirpaths(S::FsStats) = length(S.setdirpaths)

# function info(S::FsStats)
#     # LINE 1
#     line = []
#     if nfiles(S) == 0
#         push!(line, DARK_GRAY_FG("[ no files ]"))
#     else
#         push!(line, colorizeas("[ $(tostr_thsep(nfiles(S))) files ", FileEntry))
#         if nsyml2fileentries(S) == 0
#             push!(line, DARK_GRAY_FG("( none of which symlinked )"))
#         else
#             push!(line, colorizeas("( $(tostr_thsep(nsyml2fileentries(S))) symlinked )", Symlink{FileEntry}))
#         end
#         fsize = filesize(S)
#         if fsize <= 2^10
#             push!(line, colorizeas(" -- $(tostr_thsep(fsize)) bytes ", FileEntry))
#         else
#             push!(line, colorizeas(" -- $(fsizehuman(fsize)) -- $(tostr_thsep(fsize)) bytes ", FileEntry))
#         end
#         push!(line, DARK_GRAY_FG("( #paths:$(nsetfilepaths(S))  #dev:$(nsetfiledevices(S))  #inodes:$(nsetfiledeviceinodes(S)) )"))
#         push!(line, colorizeas(" ]", FileEntry))
#     end
#     println(line...)

#     # LINE 2
#     line = []
#     if ndirs(S) == 0
#         push!(line, DARK_GRAY_FG("[ no dirs ]"))
#     else
#         push!(line, colorizeas("[ $(tostr_thsep(ndirs(S))) dirs ", DirEntry))
#         if nsyml2direntries(S) == 0
#             push!(line, DARK_GRAY_FG("( no syml )"))
#         else
#             push!(line, colorizeas("( $(tostr_thsep(nsyml2direntries(S))) symlinked )", Symlink{DirEntry}))
#         end
#         push!(line, DARK_GRAY_FG(" ( #paths:$(nsetdirpaths(S)) )"))
#         push!(line, colorizeas(" ]", DirEntry))
#     end

#     push!(line, DARK_GRAY_FG(" :: "))

#     if nothers(S) == 0
#         push!(line, DARK_GRAY_FG("[ no dev,sock,fifo.. ]"))
#     else
#         push!(line, colorizeas("[ $(tostr_thsep(nothers(S))) dev,sock,fifo ", OtherEntry))
#         if nsyml2otherentries(S) == 0
#             push!(line, DARK_GRAY_FG("( no syml )"))
#         else
#             push!(line, colorizeas("( $(tostr_thsep(nsyml2otherentries(S))) syml )", Symlink{OtherEntry}))
#         end        
#         push!(line, colorizeas(" ]", OtherEntry))
#     end

#     push!(line, DARK_GRAY_FG(" :: "))

#     if nunknowns(S) == 0
#         push!(line, DARK_GRAY_FG("[ no unknown/broken ]"))
#     else
#         push!(line, colorizeas("[ $(tostr_thsep(nunknowns(S))) unknown/broken ", UnknownEntryNONEXIST))
#         if nsyml2unknownentriesNONEXIST(S) == 0
#             push!(line, DARK_GRAY_FG("( no syml )"))
#         else
#             push!(line, colorizeas("( $(tostr_thsep(nsyml2unknownentriesNONEXIST(S))) syml )", Symlink{UnknownEntryNONEXIST}))
#         end        
#         push!(line, colorizeas(" ]", UnknownEntryNONEXIST))
#     end

#     println(line...)


# end
# info(X::AbstractVector{<:AbstractEntry}) = info(stats(X))


