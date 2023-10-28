# FileJockey

FileJockey is a light-weight wrapper around file system entries and paths. It provides primitives to facilitate batch operations on large numbers of them.

Essentially, it uses dedicated types for the various kinds of entries:

```julia
julia> entry(".")
DirEntry("/home/martin", drwxr-xr-x)

julia> entry("A.txt")
FileEntry("/home/martin/A.txt", -rw-r--r--, 4 bytes)

julia> entry("syml2A.txt")  #this is a symbolic link
Symlink{FileEntry}("/home/martin/syml2A.txt" -> "/home/martin/A.txt")
```

<br>
<br>

Some problem areas FileJockey tries to help you with:

* Unix natively provides support for batch file system ops, e.g., via `find . | xargs ...`. One has to be careful, though, and cope with errors during processing, properly handle spaces in filenames, account for or skip symlinks, etc. FileJockey wraps the path strings into dedicated file entry types to make this smoother.

* Traversing large directories that contain symlinks (especially symlinks to directories inside the very same hierarchy) can easily lead to duplicate file paths in our pipeline. On the other hand, skipping symlinks could "lose" files if the symlinks refer to dirs outside the original hierarchy. FileJockey explicitly tracks symlinks and can check for those pitfalls.

* Using raw strings as paths can be error-prone. Say, for example, you want to remove duplicate files (i.e., different file entries whose file contents are identical). Yet the paths "A.txt" and "../mydir/A.txt" could easily actually be the same file entry--deleting one of them could delete *that one* file. While it would be tempting to just `realpath` everything, this would also destroy valuable symlink information. FileJockey treats paths in a canonical way so you don't have to worry about `normpath`-/`abspath`-/`realpath`-ing anything. (For example, a symlink's file entry path consists of its "real" (symlink-free) dirname combined with the symlink's basename.) Paths are thus identical *if and only if* the underlying entries are.

* We often don't thing about using functions like `isfile` or `isdir`--but those can be costly operations, especially when working with many files on slow network drives. FileJockey caches a file system entry's `StatStruct`; those operation become basically free (or unnecessary, as we can dispatch on the FileJockey types).

<br>
<br>

This should help us tackle higher-level issues in a more hassle-free way:

* Safely detect and remove duplicate files.

* Easily traverse dir hierarchies and filter the results by type, extension, etc.

* Apply arbitrary operations to such file batches, e.g., create hardlinks to each input file for a new, zero-diskspace view on your photo library.

* Process EXIF data from files, by calling outside EXIF tools in sub-batches (i.e., partitions of 100 files at a time) to largely sidestep costly startup time.

* Aaaand.. backups, dir-diffs, customizable recursive grepping,...

<br>
<br>



### API

[in progress; use `?` in Julia on:]

`entry`

`ls`

`find` and `eachentry`

`finddupl`



<br>
<br>
<br>
<br>

#### Version History

0.1 Initial version.
