using Test

using KyotoCabinet
using KyotoCabinet.c

import Base: convert

BIG_DATA_LENGTH = 100

# TODO
# File creation failures.
# - Invalid file name
# - File name clash with existing dir

# Get/Set failures
# - Read non existing keys
# - Set value when opened in R/O mode

function empty_db(db::Db{String,String})
end

function abc_db(db::Db{String,String})
  set!(db, "a", "1")
  set!(db, "b", "2")
  set!(db, "c", "3")
end

function test_with(check::Function, configure::Function)
  file = tempname() * ".kch"
  open(Db{String, String}(), file, KCOWRITER | KCOCREATE) do db
    configure(db)
    check(db)
  end
end

@testset "open database" begin
    test_with(empty_db) do db
        @test true
    end
end

@testset "open database abc, check existence" begin
  test_with(abc_db) do db
    @test "1" == get(db, "a")::String
    @test "2" == get(db, "b")::String
    @test "3" == get(db, "c")::String
  end
end

@testset "length" begin
  test_with(empty_db) do db
    @test 0 == length(db)
  end
  test_with(abc_db) do db
    @test 3 == length(db)
  end
end

# Use cursor to iterate records
@testset "iterate_empty" begin
  test_with(empty_db) do db
    log = ""
    for (k, v) in db
      log = log * " $k:$v"
    end
    @test "" == log
  end
end

# Test for loop over records
@testset "iterate_non_empty" begin
  test_with(abc_db) do db
    log = string()
    for (k, v) = db
      log = log * " $k:$v"
    end
    @test " a:1 b:2 c:3" == log
  end
end

# next should fail on empty db
# @testset "iterate_nexts_empty" begin
#   test_with(empty_db) do db
#     s0 = start(db)
#     @test done(db, s0)
#     @test_throws next(db, s0)
#   end
# end

# Test next->next without done method
# All movements should be in next() method.
# function test_iterate_nexts()
#   test_with(abc_db) do db
#     s0 = start(db)
#     @assert !done(db, s0)
#     (kv0, s1) = next(db, s0)
#     (kv1, s2) = next(db, s1)
#     (kv2, s3) = next(db, s2)
#     @assert done(db, s3)

#     @assert ("a", "1") == kv0
#     @assert ("b", "2") == kv1
#     @assert ("c", "3") == kv2
#   end
# end

# Test generator syntax over records
@testset "generator" begin
  test_with(abc_db) do db
    log = join(["$k:$v" for (k, v) = db], " ")
    @test "a:1 b:2 c:3" == log
  end
end

# function test_iterate_next()
#   test_with(abc_db) do db
#     s0 = start(db)
#     @assert !done(db, s0)

#     rec, s1 = next(db, s0)
#     @assert ("a", "1") == rec
#     @assert !done(db, s1)

#     rec, s2 = next(db, s1)
#     @assert ("b", "2") == rec
#     @assert !done(db, s2)

#     rec, s3 = next(db, s2)
#     @assert ("c", "3") == rec
#     @assert done(db, s3)

#     @test_throws next(db, s3)
#   end
# end

# Test keys iterator
@testset "keys_empty" begin
  test_with(empty_db) do db
    log = string()
    for k = keys(db)
      log = log * " $k"
    end
    @test "" == log
  end
end

@testset "keys" begin
  test_with(abc_db) do db
    log = string()
    for k = keys(db)
      log = log * " $k"
    end
    @test " a b c" == log
  end
end

# Test values iterator
@testset "values_empty" begin
  test_with(empty_db) do db
    log = string()
    for k = values(db)
      log = log * " $k"
    end
    @test "" == log
  end
end

@testset "values" begin
  test_with(abc_db) do db
    log = string()
    for k = values(db)
      log = log * " $k"
    end
    @test " 1 2 3" == log
  end
end

# Test for loop over records
@testset "iterate" begin
  test_with(abc_db) do db
    log = string()
    for (k, v) = db
      log = log * " $k:$v"
    end
    @test " a:1 b:2 c:3" == log
  end
end

@testset "get_set_failures" begin
  test_with(abc_db) do db
    @test_throws KyotoCabinetException  get(db, "z")
  end
end

@testset "dict_haskey" begin
  test_with(abc_db) do db
    @test !haskey(db, "")

    @test haskey(db, "a")
    @test haskey(db, "b")
    @test !haskey(db, "z")
  end
end

@testset "dict_get" begin
  test_with(abc_db) do db
    @test "1" == get(db, "a", "0")
    @test "2" == get(db, "b", "0")
    @test "0" == get(db, "z", "0")

    f() = "0"
    @test "1" == get(f, db, "a")
    @test "2" == get(f, db, "b")
    @test "0" == get(f, db, "z")
  end
end

@testset "dict_get!" begin
  test_with(abc_db) do db
    @test "1" == get!(db, "a", "0")
    @test "2" == get!(db, "b", "0")
    @test "0" == get!(db, "z", "0")
    @test "0" == get(db, "z", "z")

    f() = "z"
    @test "1" == get!(f, db, "a")
    @test "2" == get!(f, db, "b")
    @test "z" == get!(f, db, "zz")
    @test "z" == get(db, "zz", "z")
  end
end

@testset "dict_modify" begin
  test_with(abc_db) do db
    @test 3 == length(db)
    empty!(db)
    @test isempty(db)
  end

  test_with(abc_db) do db
    @test "a" == getkey(db, "a", "0")
    @test "b" == getkey(db, "b", "0")
    @test "0" == getkey(db, "z", "0")

    @test haskey(db, "a")
    delete!(db, "a")
    @test !haskey(db, "a")

    @test haskey(db, "b")
    @test "2" == pop!(db, "b", "0")
    @test !haskey(db, "b")

    @test "0" == pop!(db, "z", "0")

    @test_throws KyotoCabinetException pop!(db, "z")
  end
end

@testset "associative" begin
  test_with(abc_db) do db
    @test "1" == db["a"]
    @test "2" == db["b"]
    @test_throws KyotoCabinetException db["z"]

    @test "0" == (db["z"] = "0")
    @test "0" == db["z"]
  end
end

# Generic Associative methods should work with Db as well
@testset "associative_merge" begin
    test_with(empty_db) do db
        @test !haskey(db, "a")
        @test !haskey(db, "b")
        merge!(db, ["a"=>"a1", "b"=>"b1"])
        @test "a1" == db["a"]
        @test "b1" == db["b"]
    end
end

@testset "path" begin
  file = tempname() * ".kch"
  open(Db{Bytes, Bytes}(), file, KCOWRITER | KCOCREATE) do db
    @test file == path(db)
  end
end

@testset "cas" begin
  test_with(abc_db) do db
    @test cas(db, "a", "1", "1a")
    @test "1a" == get(db, "a")

    @test !cas(db, "a", "1", "1b")
    @test "1a" == get(db, "a")

    @test !cas(db, "z", "0", "0z")

    @test cas(db, "z", nothing, "0")
    @test "0" == get(db, "z")
    @test !cas(db, "z", nothing, "0z")

    @test cas(db, "z", "0", nothing)
    @test !haskey(db, "z")
    @test !cas(db, "z", "0", nothing)
  end
end

# @testset "bulkset" begin
#   test_with(empty_db) do db
#     @test !haskey(db, "a")
#     @test !haskey(db, "b")
#     @test !haskey(db, "c")

#     @test 3 == bulkset!(db, ["a"=>"a1", "b"=>"b1", "c"=>"c1"], true)

#     @test "a1" == db["a"]
#     @test "b1" == db["b"]
#     @test "c1" == db["c"]

#     @test 2 == bulkset!(db, ["a"=>"a2", "b"=>"b2"], false)

#     @test "a2" == db["a"]
#     @test "b2" == db["b"]
#     @test "c1" == db["c"]
#   end
# end

# @testset "bulkdelete" begin
#   test_with(abc_db) do db
#     @test haskey(db, "a")
#     @test haskey(db, "b")
#     @test haskey(db, "c")

#     @test 2 == bulkdelete!(db, ["a", "b"], true)

#     @test !haskey(db, "a")
#     @test !haskey(db, "b")
#     @test haskey(db, "c")

#     @test 1 == bulkdelete!(db, ["a", "c"], true)
#     @test 0 == bulkdelete!(db, ["b", "c"], false)
#   end
# end

@testset "set_get_long_string" begin
    open(Db{String, String}(), tempname() * ".kch", KCOWRITER | KCOCREATE) do db
        s = "Hello " * repeat(" world ", BIG_DATA_LENGTH)

        # println(s,"::", typeof(s))

        db["1"] = s

        s1 = db["1"]
        # println(s1,"::", typeof(s1))

        @test s == s1
    end
end

@testset "set_get_long_bytes_vector" begin
    open(Db{String, Bytes}(), tempname() * ".kch", KCOWRITER | KCOCREATE) do db
        # bytes = "08 03 22 96 01" * repeat(" 61", 150)
        bytes = "99 99 99 99 99 99" * repeat(" 61", BIG_DATA_LENGTH) * " 88 88 88 88 88 88"
        s = map(s->parse(UInt8, s, base=16), split(bytes, " "))

        # println(s,"::", typeof(s))

        db["1"] = s

        s1 = db["1"]
        # println(s1,"::", typeof(s1))

        println(repeat("-", 80))
        @test s == s1
    end
end
