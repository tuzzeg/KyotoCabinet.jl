using kyotocabinet
using Base.Test

# Open KC file.
# Expected: file created
function test_open()
  db = Db()
  open(db, "t.kch", KCOWRITER | KCOCREATE)
  close(db)
end

# Get/Set values.
function test_get_set()
  db = Db()
  open(db, "t.kch", KCOWRITER | KCOCREATE)

  set(db, "a", "1")
  set(db, "b", "2")

  @assert "1" == get(db, "a")
  @assert "2" == get(db, "b")

  close(db)
end

function test_cursor_empty()
  db = Db()
  open(db, tempname() * ".kch", KCOWRITER | KCOCREATE)

  cur = Cursor(db)
  @assert !_jump(cur)

  close(db)
end

function test_cursor()
  db = Db()
  open(db, tempname() * ".kch", KCOWRITER | KCOCREATE)

  set(db, "a", "1")
  set(db, "b", "2")
  set(db, "c", "3")

  cur = Cursor(db)
  @assert _jump(cur)
  @assert ("a", "1") == _current_record(cur)
  @assert _next(cur)
  @assert ("b", "2") == _current_record(cur)
  @assert _next(cur)
  @assert ("c", "3") == _current_record(cur)
  @assert !_next(cur)
  @test_throws _current_record(cur)

  close(db)
end

# Iterate through values
function test_iterate_empty()
  db = Db()
  open(db, tempname() * ".kch", KCOWRITER | KCOCREATE)

  cur = Cursor(db)
  log = string()
  for (k, v) = cur
    log = log * " $k:$v"
  end
  @assert "" == log

  close(db)
end

function test_iterate()
  db = Db()
  open(db, tempname() * ".kch", KCOWRITER | KCOCREATE)

  set(db, "a", "1")
  set(db, "b", "2")
  set(db, "c", "3")

  cur = Cursor(db)
  log = string()
  for (k, v) = cur
    log = log * " $k:$v"
  end
  @assert " a:1 b:2 c:3" == log

  # log = join(["$k:$v" for (k, v) = cur], " ")
  # @assert "a:1 b:2 c:3" == log

  close(db)
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
  db = Db()
  open(db, "t.kch", KCOWRITER | KCOCREATE)

  set(db, "a", "1")
  set(db, "b", "2")
  set(db, "c", "3")

  @test_throws get(db, "z")

  close(db)
end

test_open()
test_get_set()
test_cursor()
test_iterate_empty()
test_iterate()

test_get_set_failures()
