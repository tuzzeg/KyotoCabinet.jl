using Base.Test

using kyotocabinet
using kyotocabinet.c

kyotocabinet.pack(v::ASCIIString) = convert(Array{Uint8,1}, v)
kyotocabinet.unpack(T::Type{ASCIIString}, buf::Array{Uint8,1}) = bytestring(buf)

# TODO: add excpetion type to @test_throws
# See: https://github.com/JuliaLang/julia/commit/6fa50c4183358047c772a508e7a1a44a47c94a95

# TODO
# File creation failures.
# - Invalid file name
# - File name clash with existing dir

# Get/Set failures
# - Read non existing keys
# - Set value when opened in R/O mode

function test_open()
  test_with(empty_db) do db
  end
end

function test_get_set()
  test_with(abc_db) do db
    @assert "1" == get(db, "a")
    @assert "2" == get(db, "b")
    @assert "3" == get(db, "c")
  end
end

function test_length()
  test_with(empty_db) do db
    @assert 0 == length(db)
  end
  test_with(abc_db) do db
    @assert 3 == length(db)
  end
end

# Use cursor to iterate records
function test_iterate_empty()
  test_with(empty_db) do db
    log = string()
    for (k, v) = db
      log = log * " $k:$v"
    end
    @assert "" == log
  end
end

# Test for loop over records
function test_iterate()
  test_with(abc_db) do db
    log = string()
    for (k, v) = db
      log = log * " $k:$v"
    end
    @assert " a:1 b:2 c:3" == log
  end
end

# next should fail on empty db
function test_iterate_nexts_empty()
  test_with(empty_db) do db
    s0 = start(db)
    @assert done(db, s0)
    @test_throws next(db, s0)
  end
end

# Test next->next without done method
# All movements should be in next() method.
function test_iterate_nexts()
  test_with(abc_db) do db
    s0 = start(db)
    @assert !done(db, s0)
    (kv0, s1) = next(db, s0)
    (kv1, s2) = next(db, s1)
    (kv2, s3) = next(db, s2)
    @assert done(db, s3)

    @assert ("a", "1") == kv0
    @assert ("b", "2") == kv1
    @assert ("c", "3") == kv2
  end
end

# Test generator syntax over records
function test_generator()
  test_with(abc_db) do db
    log = join(["$k:$v" for (k, v) = db], " ")
    @assert "a:1 b:2 c:3" == log
  end
end

function test_iterate_next()
  test_with(abc_db) do db
    s0 = start(db)
    @assert !done(db, s0)

    rec, s1 = next(db, s0)
    @assert ("a", "1") == rec
    @assert !done(db, s1)

    rec, s2 = next(db, s1)
    @assert ("b", "2") == rec
    @assert !done(db, s2)

    rec, s3 = next(db, s2)
    @assert ("c", "3") == rec
    @assert done(db, s3)

    @test_throws next(db, s3)
  end
end

# Test keys iterator
function test_keys_empty()
  test_with(empty_db) do db
    log = string()
    for k = keys(db)
      log = log * " $k"
    end
    @assert "" == log
  end
end

function test_keys()
  test_with(abc_db) do db
    log = string()
    for k = keys(db)
      log = log * " $k"
    end
    @assert " a b c" == log
  end
end

# Test values iterator
function test_values_empty()
  test_with(empty_db) do db
    log = string()
    for k = values(db)
      log = log * " $k"
    end
    @assert "" == log
  end
end

function test_values()
  test_with(abc_db) do db
    log = string()
    for k = values(db)
      log = log * " $k"
    end
    @assert " 1 2 3" == log
  end
end

# Test for loop over records
function test_iterate()
  test_with(abc_db) do db
    log = string()
    for (k, v) = db
      log = log * " $k:$v"
    end
    @assert " a:1 b:2 c:3" == log
  end
end

function test_get_set_failures()
  test_with(abc_db) do db
    @test_throws get(db, "z")
  end
end

function test_dict_haskey()
  test_with(abc_db) do db
    @assert !haskey(db, "")

    @assert haskey(db, "a")
    @assert haskey(db, "b")
    @assert !haskey(db, "z")
  end
end

function test_dict_get()
  test_with(abc_db) do db
    @assert "1" == get(db, "a", "0")
    @assert "2" == get(db, "b", "0")
    @assert "0" == get(db, "z", "0")

    f() = "0"
    @assert "1" == get(f, db, "a")
    @assert "2" == get(f, db, "b")
    @assert "0" == get(f, db, "z")
  end
end

function test_dict_get!()
  test_with(abc_db) do db
    @assert "1" == get!(db, "a", "0")
    @assert "2" == get!(db, "b", "0")
    @assert "0" == get!(db, "z", "0")
    @assert "0" == get(db, "z", "z")

    f() = "z"
    @assert "1" == get!(f, db, "a")
    @assert "2" == get!(f, db, "b")
    @assert "z" == get!(f, db, "zz")
    @assert "z" == get(db, "zz", "z")
  end
end

function test_dict_modify()
  test_with(abc_db) do db
    @assert 3 == length(db)
    empty!(db)
    @assert isempty(db)
  end

  test_with(abc_db) do db
    @assert "a" == getkey(db, "a", "0")
    @assert "b" == getkey(db, "b", "0")
    @assert "0" == getkey(db, "z", "0")

    @assert haskey(db, "a")
    delete!(db, "a")
    @assert !haskey(db, "a")

    @assert haskey(db, "b")
    @assert "2" == pop!(db, "b", "0")
    @assert !haskey(db, "b")

    @assert "0" == pop!(db, "z", "0")

    @test_throws pop!(db, "z")
  end
end

function test_associative()
  test_with(abc_db) do db
    @assert "1" == db["a"]
    @assert "2" == db["b"]
    @test_throws db["z"]

    @test "0" == (db["z"] = "0")
    @assert "0" == db["z"]
  end
end

# Generic Associative methods should work with Db as well
function test_associative_merge()
  test_with(empty_db) do db
    @assert !haskey(db, "a")
    @assert !haskey(db, "b")
    merge!(db, ["a"=>"a1", "b"=>"b1"])
    @assert "a1" == db["a"]
    @assert "b1" == db["b"]
  end
end

function test_path()
  file = tempname() * ".kch"
  open(file, KCOWRITER | KCOCREATE) do db
    @assert file == path(db)
  end
end

function test_cas()
  test_with(abc_db) do db
    @assert cas(db, "a", "1", "1a")
    @assert "1a" == get(db, "a")

    @assert !cas(db, "a", "1", "1b")
    @assert "1a" == get(db, "a")

    @assert !cas(db, "z", "0", "0z")

    @assert cas(db, "z", nothing, "0")
    @assert "0" == get(db, "z")
    @assert !cas(db, "z", nothing, "0z")

    @assert cas(db, "z", "0", nothing)
    @assert !haskey(db, "z")
    @assert !cas(db, "z", "0", nothing)
  end
end

function test_bulkset()
  test_with(empty_db) do db
    @assert !haskey(db, "a")
    @assert !haskey(db, "b")
    @assert !haskey(db, "c")

    @assert 3 == bulkset!(db, ["a"=>"a1", "b"=>"b1", "c"=>"c1"], true)

    @assert "a1" == db["a"]
    @assert "b1" == db["b"]
    @assert "c1" == db["c"]

    @assert 2 == bulkset!(db, ["a"=>"a2", "b"=>"b2"], false)

    @assert "a2" == db["a"]
    @assert "b2" == db["b"]
    @assert "c1" == db["c"]
  end
end

function test_bulkdelete()
  test_with(abc_db) do db
    @assert haskey(db, "a")
    @assert haskey(db, "b")
    @assert haskey(db, "c")

    @assert 2 == bulkdelete!(db, ["a", "b"], true)

    @assert !haskey(db, "a")
    @assert !haskey(db, "b")
    @assert haskey(db, "c")

    @assert 1 == bulkdelete!(db, ["a", "c"], true)
    @assert 0 == bulkdelete!(db, ["b", "c"], false)
  end
end

function test_set_get_long_string()
  open(Db{ASCIIString, Array{Uint8,1}}(), tempname() * ".kch", KCOWRITER | KCOCREATE) do db
    bytes = "08 03 22 96 01" * repeat(" 61", 150)
    s = map(s->parseint(Uint8, s, 16), split(bytes, " "))

    db["1"] = s

    @assert s == db["1"]
  end
end

function empty_db(db::Db{ASCIIString,ASCIIString})
end

function abc_db(db::Db{ASCIIString,ASCIIString})
  set!(db, "a", "1")
  set!(db, "b", "2")
  set!(db, "c", "3")
end

function test_with(check::Function, configure::Function)
  file = tempname() * ".kch"
  open(Db{ASCIIString, ASCIIString}(), file, KCOWRITER | KCOCREATE) do db
    configure(db)
    check(db)
  end
end

test_open()
test_length()
test_path()
test_get_set()

test_iterate_empty()
test_iterate()
test_iterate_nexts_empty()
test_iterate_nexts()
test_iterate_next()

test_keys_empty()
test_keys()

test_values_empty()
test_values()

test_generator()
test_get_set_failures()

test_dict_haskey()
test_dict_get()
test_dict_get!()
test_dict_modify()

test_associative()
test_associative_merge()

test_cas()
test_bulkset()
test_bulkdelete()

test_set_get_long_string()
