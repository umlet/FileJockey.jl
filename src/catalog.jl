module Catalog


using OrderedCollections


import CommandLiner
import CommandLiner.Group: group
import CommandLiner.Ext: ext, exty
import CommandLiner.ColorBox: Cbx
import CommandLiner.Iter: map_
import CommandLiner.Tably: maketable, makerow, stringify
import CommandLiner.Conv: sizehuman

using ..Entries



@kwdef struct EntryCatalog
    regulars =           OrderedDict(FileEntry=>FileEntry[], DirEntry=>DirEntry[], OtherEntry=>OtherEntry[], UnknownEntryNONEXIST=>UnknownEntryNONEXIST[])
    symlinks =           OrderedDict(FileEntry=>Symlink[],   DirEntry=>Symlink[],  OtherEntry=>Symlink[],    UnknownEntryNONEXIST=>Symlink[])
    symlinktargets =     OrderedDict(FileEntry=>FileEntry[], DirEntry=>DirEntry[], OtherEntry=>OtherEntry[], UnknownEntryNONEXIST=>UnknownEntryNONEXIST[])
    all =                OrderedDict(FileEntry=>FileEntry[], DirEntry=>DirEntry[], OtherEntry=>OtherEntry[], UnknownEntryNONEXIST=>UnknownEntryNONEXIST[])

    samefilepaths =      OrderedDict{String, Vector{FileEntry}}()
    samedirpaths =       OrderedDict{String, Vector{DirEntry}}()

    filesbydevice =      OrderedDict{UInt64, Vector{FileEntry}}()
    filesbydeviceinode = OrderedDict{Tuple{UInt64, UInt64}, Vector{FileEntry}}()

    actualsamefiles =    OrderedDict{Tuple{UInt64, UInt64}, Vector{FileEntry}}()

    filesbyexty =        OrderedDict{Symbol, Vector{FileEntry}}()
end


device(x::AbstractEntry) = x.st.device
inode(x::AbstractEntry) = x.st.inode
deviceinode(x::AbstractEntry) = (device(x), inode(x))

function catalog(X::AbstractVector{<:AbstractEntry})
    RET = EntryCatalog()

    for x in X
        x isa Symlink  &&  ( push!(RET.symlinks[typeof(follow(x))], x);  continue )
        push!(RET.regulars[typeof(x)], x)
    end

    for (k,v) in RET.symlinktargets
        append!(v, follow.(RET.symlinks[k]))
    end

    for (k,v) in RET.all
        append!(v, [RET.regulars[k] ; RET.symlinktargets[k]])
    end

    merge!(RET.samefilepaths, group(RET.all[FileEntry]; fkey=path,        fhaving= >(1) ∘ length) )
    merge!(RET.samedirpaths,  group(RET.all[DirEntry];  fkey=path,        fhaving= >(1) ∘ length) )

    merge!(RET.filesbydevice, group(RET.all[FileEntry]; fkey=device) )
    merge!(RET.filesbydeviceinode, group(RET.all[FileEntry]; fkey=deviceinode) )  # used for actual size via first.(value())- this discards same-path and same-file cases

    # only use unique paths here to avoid false hardlink positives of same paths!
    merge!(RET.actualsamefiles, group(unique(RET.all[FileEntry]); fkey=deviceinode, fhaving= >(1) ∘ length) )

    merge!(RET.filesbyexty, group(RET.all[FileEntry]; fkey=exty, sort=true, sort_byvalue=true, sort_by=length, sort_rev=true) )

    return RET
end
catalog(X) = catalog(AbstractEntry[x for x in X])

function Base.show(io::IO, mime::MIME"text/plain", x::EntryCatalog)
    #print(io, "((()))")  # MIME is used in vector, if single line..!!!
    #return
    #dump(io.dict)

    for t in [FileEntry, DirEntry, OtherEntry, UnknownEntryNONEXIST]
        l = length(x.regulars[t]);  s = l == 1  ?  "regular entry"  :  "regular entries"
        println(io, "regulars[$(string(t))] = [ .. $(l) $(s) .. ]")
    end
    println()
    for t in [FileEntry, DirEntry, OtherEntry, UnknownEntryNONEXIST]
        l = length(x.symlinks[t]);  s = l == 1  ?  "symlink"  :  "symlinks"
        println(io, "symlinks[$(string(t))] = [ .. $(l) $(s) .. ]")
    end
    println(io)
    for t in [FileEntry, DirEntry, OtherEntry, UnknownEntryNONEXIST]
        l = length(x.symlinktargets[t]);  s = l == 1  ?  "target"  :  "targets"
        println(io, "symlinktargets[$(string(t))] = [ .. $(l) $(s) .. ]")
    end
    println(io)
    for t in [FileEntry, DirEntry, OtherEntry, UnknownEntryNONEXIST]
        l = length(x.all[t]);  s = l == 1  ?  "entry"  :  "entries"
        println(io, "all[$(string(t))] = [ .. $(l) $(s) .. ]")
    end

    println(io)
    l = length(x.samefilepaths);  s = l == 1  ?  "group"  :  "groups"
    println(io, "samefilepaths = OrderedDict( .. $(l) $(s) .. )")
    l = length(x.samedirpaths);  s = l == 1  ?  "group"  :  "groups"
    println(io, "samedirpaths = OrderedDict( .. $(l) $(s) .. )")

    println(io)
    l = length(x.filesbydevice);  s = l == 1  ?  "group"  :  "groups"
    println(io, "filesbydevice = OrderedDict( .. $(l) $(s) .. )")
    l = length(x.filesbydeviceinode);  s = l == 1  ?  "group"  :  "groups"
    println(io, "filesbydeviceinode = OrderedDict( .. $(l) $(s) .. )")

    println(io)
    l = length(x.actualsamefiles);  s = l == 1  ?  "group"  :  "groups"
    println(io, "actualsamefiles = OrderedDict( .. $(l) $(s) .. )")

    println(io)
    l = length(x.filesbyexty);  s = l == 1  ?  "group"  :  "groups"
    println(io, "filesbyexty = OrderedDict( .. $(l) $(s) .. )")
end


_s(x::Int64) = x == 1  ?  ""  :  "s"
function stats(x::EntryCatalog)
    line = []

    # line 1: files
    n = length(x.all[FileEntry])
    push!(line, Cbx("$(n) file$(_s(n))", FileEntry))
    if n > 0
        # ..symlinks
        n = length(x.symlinks[FileEntry])
        if n == 0
            push!(line, " ", Cbx("(none symlinked)", "p"))
        else
            push!(line, " ", Cbx("($(n) symlinked)", FileEntry))
        end

        #n = length(x.filesbydeviceinode)  # no files case
        #if n > 0
        s = x.filesbydeviceinode |> values |> map_(first) |> map_(filesize) |> sum |> sizehuman
        push!(line, "  ", s, " real")
        #end
    end
    println(line...)

    n = length(x.all[FileEntry])
    if n > 0
        # by type
        T = maketable(2)  #MiniRow{2}[]
        d = x.filesbyexty
        for (sym,fs) in d
            tmp_d = group(fs; fkey=ext)
            s = join([x for x in keys(tmp_d)], ", ")
            r = makerow([s, string(length(fs))])
            push!(T, r)
        end
        #Ts = Base.Iterators.partition(T, 2) |> map_(collect) |> collect
        #ss = stringify(Ts; rowinfix="   ")
        ss = stringify(T; #=n=0,=# firstprefix="  ", rowinfix="   ")
        foreach(println, ss)

        # additional tags
        line = []
        push!(line, "  ")
        if length(x.samefilepaths) == 0
            push!(line, Cbx("[paths unique/OK]", "p"))
            push!(line, " ")
        else
            push!(line, Cbx("[paths not unique]", "y"))
            push!(line, " ")
        end
        if length(x.filesbydevice) == 1
            push!(line, Cbx("[on same device/OK]", "p"))
            push!(line, " ")
        else
            push!(line, Cbx("[on $(length(x.filesbydevice)) devices]", "y"))
            push!(line, " ")
        end
        if length(x.actualsamefiles) == 0
            push!(line, Cbx("[no hardlinks/OK]", "p"))
            push!(line, " ")
        else
            push!(line, Cbx("[$(length(x.actualsamefiles)) hardlink group$(_s(length(x.actualsamefiles)))]", "y"))
            push!(line, " ")
        end

        println(line...)
    end

    # last line: dirs etc.
    line = []
    n = length(x.all[DirEntry])
    push!(line, Cbx("$(n) dir$(_s(n))", DirEntry))
    if n > 0
        n = length(x.symlinks[DirEntry])
        if n == 0
            push!(line, " ", Cbx("(none symlinked)", "p"))
        else
            push!(line, " ", Cbx("($(n) symlinked)", DirEntry))
        end
    end


    # other
    push!(line, Cbx(" :: ", "p"))
    n = length(x.all[OtherEntry])
    color = n > 0  ?  OtherEntry  :  "p"
    push!(line, Cbx("$(n) other=dev/sock/fifo..", color))
    if n > 0
        n = length(x.symlinks[OtherEntry])
        if n == 0
            push!(line, " ", Cbx("(none symlinked)", "p"))
        else
            push!(line, " ", Cbx("($(n) symlinked)", OtherEntry))
        end
    end

    # broken
    push!(line, Cbx(" :: ", "p"))
    n = length(x.all[UnknownEntryNONEXIST])
    color = n > 0  ?  UnknownEntryNONEXIST  :  "p"
    push!(line, Cbx("$(n) broken/unknown", color))
    if n > 0
        n = length(x.symlinks[UnknownEntryNONEXIST])
        if n == 0
            push!(line, " ", Cbx("(none symlinked)", "p"))
        else
            push!(line, " ", Cbx("($(n) symlinked)", UnknownEntryNONEXIST))
        end
    end

    println(line...)
end

stats(x) = stats(catalog(x))


include("catalog.jl_exports")
end # module

