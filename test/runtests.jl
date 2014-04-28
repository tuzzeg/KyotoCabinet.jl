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

function test_cursor()
  db = Db()
  open(db, "t.kch", KCOWRITER | KCOCREATE)

  set(db, "a", "1")
  set(db, "b", "2")
  set(db, "c", "3")

  cur = Cursor(db)
  _jump(cur)
  @assert ("a", "1") == _next(cur)
  @assert ("b", "2") == _next(cur)
  @assert ("c", "3") == _next(cur)

  close(db)
end

# Iterate through values
function test_iterate()
  @assert 1==0
end

# File creation failures.
# - Invalid file name
# - File name clash with existing dir

# Get/Set failures
# - Read non existing keys
# - Set value when opened in R/O mode

test_open()
test_get_set()
test_cursor()
test_iterate()
