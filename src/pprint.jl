
function colorize(s::AbstractString, COLORS...)
    !CONF.colors  &&  return s
    RET = s
    for COLOR in COLORS
        RET = COLOR(RET)
    end
    return RET
end
colorizeas(s::AbstractString, ::FileEntry) = colorize(s, LIGHT_GREEN_FG)
colorizeas(s::AbstractString, ::DirEntry) = colorize(s, LIGHT_BLUE_FG)
colorizeas(s::AbstractString, ::OtherEntry) = colorize(s, YELLOW_FG)
    #=special case=# colorizeas(s::AbstractString, ::UnknownEntryNONEXIST) = colorize(s, RED_FG)

colorizeas(s::AbstractString, ::Symlink{FileEntry}) = colorize(s, GREEN_FG, NEGATIVE)
colorizeas(s::AbstractString, ::Symlink{DirEntry}) = colorize(s, BLUE_FG, NEGATIVE)
colorizeas(s::AbstractString, ::Symlink{OtherEntry}) = colorize(s, YELLOW_FG, NEGATIVE)
colorizeas(s::AbstractString, ::Symlink{UnknownEntryNONEXIST}) = colorize(s, RED_FG, NEGATIVE)
#----------
colorizeas(s::AbstractString, ::Type{FileEntry}) = colorize(s, LIGHT_GREEN_FG)
colorizeas(s::AbstractString, ::Type{DirEntry}) = colorize(s, LIGHT_BLUE_FG)
colorizeas(s::AbstractString, ::Type{OtherEntry}) = colorize(s, YELLOW_FG)
    #=special case=# colorizeas(s::AbstractString, ::Type{UnknownEntryNONEXIST}) = colorize(s, RED_FG)

colorizeas(s::AbstractString, ::Type{Symlink{FileEntry}}) = colorize(s, GREEN_FG, NEGATIVE)
colorizeas(s::AbstractString, ::Type{Symlink{DirEntry}}) = colorize(s, BLUE_FG, NEGATIVE)
colorizeas(s::AbstractString, ::Type{Symlink{OtherEntry}}) = colorize(s, YELLOW_FG, NEGATIVE)
colorizeas(s::AbstractString, ::Type{Symlink{UnknownEntryNONEXIST}}) = colorize(s, RED_FG, NEGATIVE)






function describe(S::FsStats)
    # LINE 1
    line = []
    if nfiles(S) == 0
        push!(line, DARK_GRAY_FG("[ no files ]"))
    else
        push!(line, colorizeas("[ $(tostr´(nfiles(S))) files ", FileEntry))
        if nsyml2fileentries(S) == 0
            push!(line, DARK_GRAY_FG("( none of which symlinked )"))
        else
            push!(line, colorizeas("( $(tostr´(nsyml2fileentries(S))) symlinked )", Symlink{FileEntry}))
        end
        fsize = filesize(S)
        if fsize <= 2^10
            push!(line, colorizeas(" -- $(tostr´(fsize)) bytes ", FileEntry))
        else
            push!(line, colorizeas(" -- $(fsizehuman(fsize)) -- $(tostr´(fsize)) bytes ", FileEntry))
        end
        push!(line, DARK_GRAY_FG("( #paths:$(nsetfilepaths(S))  #dev:$(nsetfiledevices(S))  #inodes&dev:$(nsetfiledeviceinodes(S)) )"))
        push!(line, colorizeas(" ]", FileEntry))
    end
    println(line...)

    # LINE 2
    line = []
    if nfiles(S) > 0
        _d = group(S.files; fkey=Ext)
        d = sortbyval(_d; by=length, rev=true)
        push!(line, "{ ")
        for (k,v) in d
            push!(line, ":" * string(k) * " ")
            _d2 = group(v, fkey=ext)
            d2 =  sortbyval(_d2; by=length, rev=true)
            for (k2,v2) in d2
                if k2 === nothing
                    push!(line, string(length(v2)) * "<> ")
                else
                    push!(line, string(length(v2)) * "/\"" * k2 *"\" ")
                end
            end
        end
        push!(line, "}")

        println(line...)
    end


    # LINE 3
    line = []
    if ndirs(S) == 0
        push!(line, DARK_GRAY_FG("[ no dirs ]"))
    else
        push!(line, colorizeas("[ $(tostr´(ndirs(S))) dirs ", DirEntry))
        if nsyml2direntries(S) == 0
            push!(line, DARK_GRAY_FG("( no syml )"))
        else
            push!(line, colorizeas("( $(tostr´(nsyml2direntries(S))) symlinked )", Symlink{DirEntry}))
        end
        push!(line, DARK_GRAY_FG(" ( #paths:$(nsetdirpaths(S)) )"))
        push!(line, colorizeas(" ]", DirEntry))
    end

    push!(line, DARK_GRAY_FG(" :: "))

    if nothers(S) == 0
        push!(line, DARK_GRAY_FG("[ no dev,sock,fifo.. ]"))
    else
        push!(line, colorizeas("[ $(tostr´(nothers(S))) dev,sock,fifo ", OtherEntry))
        if nsyml2otherentries(S) == 0
            push!(line, DARK_GRAY_FG("( no syml )"))
        else
            push!(line, colorizeas("( $(tostr´(nsyml2otherentries(S))) syml )", Symlink{OtherEntry}))
        end        
        push!(line, colorizeas(" ]", OtherEntry))
    end

    push!(line, DARK_GRAY_FG(" :: "))

    if nunknowns(S) == 0
        push!(line, DARK_GRAY_FG("[ no unknown/broken ]"))
    else
        push!(line, colorizeas("[ $(tostr´(nunknowns(S))) unknown/broken ", UnknownEntryNONEXIST))
        if nsyml2unknownentriesNONEXIST(S) == 0
            push!(line, DARK_GRAY_FG("( no syml )"))
        else
            push!(line, colorizeas("( $(tostr´(nsyml2unknownentriesNONEXIST(S))) syml )", Symlink{UnknownEntryNONEXIST}))
        end        
        push!(line, colorizeas(" ]", UnknownEntryNONEXIST))
    end

    println(line...)
end

describe(X::AbstractVector{<:AbstractEntry}) = describe(stats(X))



function _show(io::IO, X::AbstractVector{<:AbstractEntry})
    println("$(length(X))-element Vector{AbstractEntry}:")
    tmp = tk(X, 11)
    for x in tk_(tmp, 10)
        print(" ")
        _show(io, x)
        println()
    end
    length(tmp) == 11  &&  println(" ...")
    println()
    #println("describe():")
    describe(X)
end














# function infoOLD(X::AbstractVector{<:AbstractEntry})
#     nfile = X |> cn(is(FileEntry))
#     ndir = X |> cn(is(DirEntry))
#     nother = X |> cn(is(OtherEntry))

#     nsyml2file = X |> cn(is(Symlink{FileEntry}))
#     nsyml2dir = X |> cn(is(Symlink{DirEntry}))
#     nsyml2other = X |> cn(is(Symlink{OtherEntry}))
#     nsyml2nonexist = X |> cn(is(Symlink{UnknownEntryNONEXIST}))

#     ntot = nfile + ndir + nother     + nsyml2file + nsyml2dir + nsyml2other + nsyml2nonexist

#     ntot != length(X)  &&  error("INTERNAL ERROR: sum of file system entry types does not match total entries")

#     dext = OrderedDict()
#     for x in X
#         !isfilelike(x)  &&  continue
#         s = ext(x)
#         !haskey(dext, s)  &&  ( dext[s] = 0 )
#         dext[s] += 1
#     end

#     print("""
# --- by file system entry type:
# files, regular                          $(nfile)
# dirs, regular                           $(ndir)
# other (fifos, devices..)                $(nother)

# symlinks to file                        $(nsyml2file)
# symlinks to dir                         $(nsyml2dir)
# symlinks to other                       $(nsyml2other)
# symlinks BROKEN                         $(nsyml2nonexist)

# SUM                                     $(ntot)   

# --- by likeness:
# file-likes, regular and symlinked        $(nfile + nsyml2file)
# dir-likes, regular and symlinked         $(ndir + nsyml2dir)
# other, regular and symlinked             $(nother + nsyml2other)
# symlinks BROKEN                         $(nsyml2nonexist)

# --- file-likes, by extension:
# """)
#     for k in cl(keys(dext))  #[ filter(isnothing, keys(dext)) ; sort([x for x in keys(dext) if x!== nothing]) ]
#         n = dext[k]
#         k === nothing  &&  ( k = "<no dot; no ext>" )
#         k == ""        &&  ( k = "<dot; no ext>" )
#         if length(k) < 20
#             println("$(k)" * " "^(20-length(k)), n)
#         else
#             println("$(k)" * "   ", n)
#         end
#     end
#     return nothing  # to pass on in pipe
# end 








include("pprint.jl_exports")

