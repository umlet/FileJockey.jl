#!/usr/bin/env julia

using Test

import CommandLiner.Iter.Hack: map, filter
using CommandLiner

using FileJockey


@testset "Deps_Juliettine" begin
    @test [1,2,3] |> mp(x->x^2) |> length == 3
end

@testset "EntryOps" begin
    @test Entry("_test_sandbox/") |> isdir == true
    @test Entry("_test_sandbox/ok/test.jpg") |> isfile == true
    @test Entry("_test_sandbox/") |> isstandard

    @test Entry("_test_sandbox/ok/test.jpg") |> path |> is(String)
    @test Entry("_test_sandbox/ok/test.tiff") |> filesize > 0
end

@testset "EntriesTrees" begin
    @test find("_test_sandbox/") |> length > 0
    @test find("_test_sandbox/") |> getfiles |> length > 0

    @test eachentry("_test_sandbox/") |> first |> isdir

    @test length(findfiles("_test_sandbox/ok")) == length(find("_test_sandbox/ok") |> getfiles)
end

@testset "ExtFilter" begin
    @test find("_test_sandbox/") |> filter(hasext("jpg")) |> length > 0
    @test find("_test_sandbox/") |> filter(hasext(:jpeg)) |> length > 0
end

@testset "Exify" begin
    @test exify("_test_sandbox/ok/test.jpg") |> exif2shortdate |> is(AbstractString)
    @test find("_test_sandbox/") |> getfiles |> exify |> length > 1
end

@testset "Checkpaths" begin

    # OK/no dupl paths
    @test find("_test_sandbox/ok/") |> checkpaths(;quiet=true) |> length > 0



    ##### checks that must throw!
    # encounter same dir entries (1c)
    @test begin
        v1 = find("_test_sandbox/ok/")
        v2 = find("_test_sandbox/ok/")
        v = [v1; v2]
        try
            println("MUST FAIL AT 1c")
            checkpaths(v; quiet=true)
            false
        catch
            true
        end
    end

    # encounter same file entries (2c)
    @test begin
        v = find("_test_sandbox/ok/") |> getfiles
        v = [v; v]
        try
            println("MUST FAIL AT 2c")
            checkpaths(v; quiet=true)
            false
        catch
            true
        end
    end

    # set up circular symlink2dir
    @test begin
        if !ispath("_test_sandbox/err_syml2dir")
            mkdir("_test_sandbox/err_syml2dir")
            mkdir("_test_sandbox/err_syml2dir/sub")

            cp("_test_sandbox/ok/test.jpg", "_test_sandbox/err_syml2dir/sub/test.jpg")
            symlink("sub", "_test_sandbox/err_syml2dir/syml2sub"; dir_target=true)
        end
        try
            println("MUST FAIL AT 1a")
            find("_test_sandbox/err_syml2dir/") |> checkpaths(; quiet=true)
            false
        catch
            true
        end
    end

    # set up circular symlink2file
    @test begin
        if !ispath("_test_sandbox/err_syml2file")
            mkdir("_test_sandbox/err_syml2file")

            cp("_test_sandbox/ok/test.jpg", "_test_sandbox/err_syml2file/test.jpg")
            symlink("test.jpg", "_test_sandbox/err_syml2file/syml2test.jpg"; dir_target=false)
        end
        try
            println("MUST FAIL AT 2a")
            find("_test_sandbox/err_syml2file/") |> checkpaths(; quiet=true)
            false
        catch
            true
        end
    end

    # set up 2 symlink2file to same file
    @test begin
        if !ispath("_test_sandbox/err_syml2file_ext0")
            mkdir("_test_sandbox/err_syml2file_ext0")
            mkdir("_test_sandbox/err_syml2file_ext1")

            # external file
            cp("_test_sandbox/ok/test.jpg", "_test_sandbox/err_syml2file_ext1/test.jpg")
            # 2 symlinks to it
            symlink("../err_syml2file_ext1/test.jpg", "_test_sandbox/err_syml2file_ext0/ext1a_syml2test.jpg"; dir_target=false)
            symlink("../err_syml2file_ext1/test.jpg", "_test_sandbox/err_syml2file_ext0/ext1b_syml2test.jpg"; dir_target=false)
        end
        try
            println("MUST FAIL AT 2a")
            find("_test_sandbox/err_syml2file_ext0/") |> checkpaths(; quiet=true)
            false
        catch
            true
        end
    end

end


@testset "Checkdupl" begin
    if !ispath("_test_sandbox/err_dupl")
        mkdir("_test_sandbox/err_dupl")
        cp("_test_sandbox/ok/test.jpg", "_test_sandbox/err_dupl/test.jpg")
        cp("_test_sandbox/ok/test.jpg", "_test_sandbox/err_dupl/test_copy.jpg")
    end


    @test aredupl("_test_sandbox/err_dupl/test.jpg", "_test_sandbox/err_dupl/test_copy.jpg")

    # must throw
    try
        aredupl("_test_sandbox/err_dupl/test.jpg", "_test_sandbox/err_dupl/test.jpg")
        false
    catch
        true
    end

    @test begin
        dupl = find("_test_sandbox/err_dupl/") |> getfiles |> getdupl
        !isempty(dupl._d)
    end

    @test begin
        try
            dupl = find("_test_sandbox/err_dupl/") |> getfiles |> checkdupl
            false
        catch
            println("dupes found; retrieving from '__DUPL__'..")
            !isempty(__DUPL__._d)
        end
    end
end


@testset "Checksame" begin

    @test begin
        f1 = Entry("_test_sandbox/ok/test.jpg")
        f2 = Entry("_test_sandbox/ok/test.jpg")
        try
            aresame(f1, f2)
            false
        catch
            true
        end
    end

    @test begin
        if !ispath("_test_sandbox/err_hard/")
            mkdir("_test_sandbox/err_hard")
            cp("_test_sandbox/ok/test.jpg", "_test_sandbox/err_hard/test.jpg")
            hardlink("_test_sandbox/err_hard/test.jpg", "_test_sandbox/err_hard/hard2test.jpg")
        end
        aresame("_test_sandbox/err_hard/test.jpg", "_test_sandbox/err_hard/hard2test.jpg")
    end

    @test begin
        try
            aredupl("_test_sandbox/err_hard/test.jpg", "_test_sandbox/err_hard/hard2test.jpg")
            false
        catch
            true
        end
    end

end
