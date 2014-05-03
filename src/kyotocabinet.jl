module kyotocabinet

include("c.jl")

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


# Iterable interface
function Base.start(cur::Cursor)
  cur.done = !_start!(cur)
  cur.row = convert(Uint, 0)
end

function Base.next(cur::Cursor, st::Uint)
  if st == cur.row
    kv = _get(cur)
    cur.done = !_next!(cur)
    cur.row += 1
  else
    throw(KyotoCabinetException(KCENOREC, "Can not move forward"))
  end
  (kv, cur.row)
end

Base.done(cur::Cursor, st::Uint) = cur.done

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
  return
end

function get(db::Db, k::String)
  kb = bytestring(k)
  vSize = Cuint[1]
  v = kcdbget(db.ptr, kb, length(kb), vSize)
  if (v == C_NULL) throw(kcexception(db)) end
  bytestring(v, vSize[1])
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
  ok = f(cursor)
  if (ok == 0)
    code = kccurecode(cursor.ptr)
    if (code == KCENOREC)
      return false
    else
      message = bytestring(kccuremsg(cursor.ptr))
      throw(KyotoCabinetException(code, message))
    end
  else
    return true
  end
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
