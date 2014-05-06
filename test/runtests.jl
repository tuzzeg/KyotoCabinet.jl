using Base.Test

using kyotocabinet
using kyotocabinet.c

# Open KC file.
# Expected: file created
function test_open()
  test_with(empty_db) do db
  end
end

# Get/Set values.
function test_get_set()
  test_with(abc_db) do db
    @assert "1" == get(db, "a")
    @assert "2" == get(db, "b")
    @assert "3" == get(db, "c")
  end
end

# Length
function test_length()
  test_with(empty_db) do db
    @assert 0 == length(db)
  end
  test_with(abc_db) do db
    @assert 3 == length(db)
  end
end

function test_cursor_empty()
  test_with(abc_db) do db
    cur = Cursor(db)
    @assert !_jump(cur)
  end
end

# Iterate through values
function test_iterate_empty()
  test_with(empty_db) do db
    cur = Cursor(db)
    log = string()
    for (k, v) = cur
      log = log * " $k:$v"
    end
    @assert "" == log
    close(cur)
  end
end

function test_iterate()
  test_with(abc_db) do db
    cur = Cursor(db)
    log = string()
    for (k, v) = cur
      log = log * " $k:$v"
    end
    @assert " a:1 b:2 c:3" == log
    close(cur)
  end
end

function test_iterate_nexts_empty()
  test_with(empty_db) do db
    cur = Cursor(db)
    s0 = start(cur)
    @assert done(cur, s0)
    @test_throws next(cur, s0)
    close(cur)
  end
end

function test_iterate_nexts()
  test_with(abc_db) do db
    cur = Cursor(db)
    s0 = start(cur)
    @assert !done(cur, s0)
    (kv0, s1) = next(cur, s0)
    (kv1, s2) = next(cur, s1)
    (kv2, s3) = next(cur, s2)
    @assert done(cur, s3)

    @assert ("a", "1") == kv0
    @assert ("b", "2") == kv1
    @assert ("c", "3") == kv2

    close(cur)
  end
end

function test_iterate_nexts_throws()
  test_with(abc_db) do db
    cur = Cursor(db)
    s0 = start(cur)
    @assert !done(cur, s0)
    (kv0, s1) = next(cur, s0)
    @test_throws next(cur, s0)
    (kv1, s2) = next(cur, s1)
    @test_throws next(cur, s0)
    (kv2, s3) = next(cur, s2)
    @test_throws next(cur, s0)
    @assert done(cur, s3)

    close(cur)
  end
end

function test_generator()
  test_with(abc_db) do db
    cur = Cursor(db)
    log = join(["$k:$v" for (k, v) = cur], " ")
    @assert "a:1 b:2 c:3" == log
    close(cur)
  end
end

# File creation failures.
# - Invalid file name
# - File name clash with existing dir

# Get/Set failures
# - Read non existing keys
# - Set value when opened in R/O mode
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

    @assert cas(db, "z", (), "0")
    @assert "0" == get(db, "z")
    @assert !cas(db, "z", (), "0z")

    @assert cas(db, "z", "0", ())
    @assert !haskey(db, "z")
    @assert !cas(db, "z", "0", ())
  end
end

function empty_db(db::Db)
end

function abc_db(db::Db)
  set(db, "a", "1")
  set(db, "b", "2")
  set(db, "c", "3")
end

function test_with(check::Function, configure::Function)
  open(tempname() * ".kch", KCOWRITER | KCOCREATE) do db
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
test_iterate_nexts_throws()
test_generator()
test_get_set_failures()
test_dict_haskey()
test_dict_get()
test_dict_get!()
test_dict_modify()
test_associative()
test_cas()
