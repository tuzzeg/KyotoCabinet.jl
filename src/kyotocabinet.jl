module kyotocabinet

include("c.jl")

import Base: length, start, next, done
import Base: haskey, get, get!, getindex, setindex!

using .c

export
  # Types
  Db, Cursor, KyotoCabinetException,

  # Db methods
  open, close, get, set

type Db
  ptr :: Ptr{Void}

  function Db()
    ptr = kcdbnew()
    self = new(ptr)
    # finalizer(self, destroy)
    self
  end
end

type Cursor
  ptr :: Ptr{Void}
  row :: Uint # Inner counter, incremented at each move
  done :: Bool

  function Cursor(db::Db)
    ptr = kcdbcursor(db.ptr)
    self = new(ptr)
    # finalizer(self, destroy)
    self
  end
end

type KyotoCabinetException <: Exception
  code :: Int32
  message :: String
end

# Base functions
function length(db::Db)
  count = kcdbcount(db.ptr)
  if (count == -1) throw(kcexception(db)) end
  count
end

# TODO Support length() for generator over cursor. Does it make sense?
function length(cur::Cursor)
  db_ptr = kccurdb(cur.ptr)
  if (db_ptr == C_NULL) throw(kcexception(cur)) end
  count = kcdbcount(db_ptr)
  if (count == -1)
    code = kcdbecode(db_ptr)
    message = bytestring(kcdbemsg(db_ptr))
    throw(KyotoCabinetException(code, message))
  end
  count
end

# Iterable interface
function start(cur::Cursor)
  cur.done = !_start!(cur)
  cur.row = convert(Uint, 0)
end

function next(cur::Cursor, st::Uint)
  if st == cur.row
    kv = _get(cur)
    cur.done = !_next!(cur)
    cur.row += 1
  else
    throw(KyotoCabinetException(KCENOREC, "Can not move forward"))
  end
  (kv, cur.row)
end

done(cur::Cursor, st::Uint) = cur.done

function open(db::Db, file::String, mode::Uint)
  ok = kcdbopen(db.ptr, bytestring(file), mode)
  if (ok == 0) throw(kcexception(db)) end
end

function close(db::Db)
  ok = kcdbclose(db.ptr)
  if (ok == 0) throw(kcexception(db)) end
end

function destroy(db::Db)
  if db.ptr == C_NULL
    return
  end
  kcdbdel(db.ptr)
  db.ptr = C_NULL
end

function set(db::Db, k::String, v::String)
  kb = bytestring(k)
  vb = bytestring(v)
  ok = kcdbset(db.ptr, kb, length(kb), vb, length(vb))
  if (ok == 0) throw(kcexception(db)) end
  v
end

function get(db::Db, k::String)
  kb = bytestring(k)
  vSize = Cuint[1]
  v = kcdbget(db.ptr, kb, length(kb), vSize)
  if (v == C_NULL) throw(kcexception(db)) end
  bytestring(v, vSize[1])
end

function get(db::Db, k::String, default::String)
  kbuf = bytestring(k)
  vsize = Csize_t[1]
  pv, code = throw_if(db, C_NULL, KCENOREC) do
    kcdbget(db.ptr, kbuf, length(kbuf), pointer(vsize))
  end
  code == KCENOREC ? default : bytestring(pv, vsize[1])
end

function get(default::Function, db::Db, k::String)
  kbuf = bytestring(k)
  vsize = Csize_t[1]
  pv, code = throw_if(db, C_NULL, KCENOREC) do
    kcdbget(db.ptr, kbuf, length(kbuf), pointer(vsize))
  end
  code == KCENOREC ? default() : bytestring(pv, vsize[1])
end

get!(db::Db, k::String, default::String) = get!(()->default, db, k)

function get!(default::Function, db::Db, k::String)
  kbuf = bytestring(k)
  vsize = Csize_t[1]
  pv, code = throw_if(db, C_NULL, KCENOREC) do
    kcdbget(db.ptr, kbuf, length(kbuf), pointer(vsize))
  end
  code == KCENOREC ? set(db, k, default()) : bytestring(pv, vsize[1])
end

# Indexable collection
getindex(db::Db, k::String) = get(db, k)
setindex!(db::Db, v::String, k::String) = set(db, k, v)

function haskey(db::Db, k::String)
  kbuf = bytestring(k)
  v, code = throw_if(db, -1, KCENOREC) do
    kcdbcheck(db.ptr, kbuf, length(kbuf))
  end
  code != KCENOREC
end

# Jump to the first record. Return false if there is no first record.
function _start!(cursor::Cursor)
  f(cursor::Cursor) = kccurjump(cursor.ptr)
  _move!(cursor, f)
end

# Move to the next record. Return false if there no next record.
function _next!(cursor::Cursor)
  f(cursor::Cursor) = kccurstep(cursor.ptr)
  _move!(cursor, f)
end

function _move!(cursor::Cursor, f)
  ok, code = throw_if(cursor, 0, KCENOREC) do
    f(cursor)
  end
  code != KCENOREC
end

function _get(cursor::Cursor)
  pkSize = Cuint[1]
  pvSize = Cuint[1]
  pv = CString[1]
  k = kccurget(cursor.ptr, pkSize, pv, pvSize, 0)
  if (k == C_NULL) throw(kcexception(cursor)) end

  res = (bytestring(k, pkSize[1]), bytestring(pv[1], pvSize[1]))
  ok = kcfree(k)
  if (ok == 0) throw(kcexception(cursor)) end

  res
end

close(cursor::Cursor) = destroy(cursor)

# KyotoCabinet exceptions
function throw_if(f::Function, db::Db, result_invalid, ecode_valid)
  result = f()
  if (result == result_invalid)
    code = kcdbecode(db.ptr)
    if (code == ecode_valid)
      return (result, code)
    else
      message = bytestring(kcdbemsg(db.ptr))
      throw(KyotoCabinetException(code, message))
    end
  end
  (result, KCESUCCESS)
end

function throw_if(f::Function, cursor::Cursor, result_invalid, ecode_valid)
  result = f()
  if (result == result_invalid)
    code = kccurecode(cursor.ptr)
    if (code == ecode_valid)
      return (result, code)
    else
      message = bytestring(kccuremsg(cursor.ptr))
      throw(KyotoCabinetException(code, message))
    end
  end
  (result, KCESUCCESS)
end

function kcexception(db::Db)
  @assert db.ptr != C_NULL

  code = kcdbecode(db.ptr)
  message = bytestring(kcdbemsg(db.ptr))

  KyotoCabinetException(code, message)
end

function kcexception(cur::Cursor)
  @assert cur.ptr != C_NULL

  code = kccurecode(cur.ptr)
  message = bytestring(kccuremsg(cur.ptr))

  KyotoCabinetException(code, message)
end

function destroy(cursor::Cursor)
  if cursor.ptr == C_NULL
    return
  end
  kccurdel(cursor.ptr)
  cursor.ptr = C_NULL
end

end # module kyotocabinet
