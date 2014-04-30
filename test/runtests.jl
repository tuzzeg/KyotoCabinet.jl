using kyotocabinet
using Base.Test

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

function test_cursor_empty()
  test_with(abc_db) do db
    cur = Cursor(db)
    @assert !_jump(cur)
  end
end

function test_cursor()
  test_with(abc_db) do db
    cur = Cursor(db)
    @assert _jump(cur)
    @assert ("a", "1") == _current_record(cur)
    @assert _next(cur)
    @assert ("b", "2") == _current_record(cur)
    @assert _next(cur)
    @assert ("c", "3") == _current_record(cur)
    @assert !_next(cur)
    @test_throws _current_record(cur)
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
  end
end

function test_generator()
  # log = join(["$k:$v" for (k, v) = cur], " ")
  # @assert "a:1 b:2 c:3" == log
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

function empty_db(db::Db)
end

function abc_db(db::Db)
  set(db, "a", "1")
  set(db, "b", "2")
  set(db, "c", "3")
end

function test_with(check::Function, configure::Function)
  db = Db()
  open(db, tempname() * ".kch", KCOWRITER | KCOCREATE)
  try
    configure(db)
    check(db)
  finally
    close(db)
  end
end

test_open()
test_get_set()
test_cursor()
test_iterate_empty()
test_iterate()

test_get_set_failures()
