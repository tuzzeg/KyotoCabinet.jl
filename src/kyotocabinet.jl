module kyotocabinet

include("c.jl")

# Iteration
import Base: start, next, done

# Generic collections
import Base: isempty, empty!, length

# Indexed collections
import Base: getindex, setindex!
# Dict
import Base: haskey, getkey, get, get!, delete!, pop!

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

# Generic collections
isempty(db::Db) = (length(db) == 0)

function length(db::Db)
  count = kcdbcount(db.ptr)
  if (count == -1) throw(kcexception(db)) end
  count
end

function empty!(db::Db)
  ok = kcdbclear(db.ptr)
  if (ok == 0) throw(kcexception(db)) end
  db
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

function open(file::String, mode::Uint)
  db = Db()
  ok = kcdbopen(db.ptr, bytestring(file), mode)
  if (ok == 0) throw(kcexception(db)) end
  db
end

function open(f::Function, file::String, mode::Uint)
  db = open(file, mode)
  try
    f(db)
  finally
    close(db)
    destroy(db)
  end
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

# Dict methods
function haskey(db::Db, k::String)
  kbuf = bytestring(k)
  v, code = throw_if(db, -1, KCENOREC) do
    kcdbcheck(db.ptr, kbuf, length(kbuf))
  end
  code != KCENOREC
end

function getkey(db::Db, key::String, default::String)
  haskey(db, key) ? key : default
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
  vsize = Cuint[1]
  pv = kcdbget(db.ptr, kb, length(kb), vsize)
  if (pv == C_NULL) throw(kcexception(db)) end
  _copy_bytestring(pv, vsize[1])
end

function get(db::Db, k::String, default::String)
  kbuf = bytestring(k)
  vsize = Csize_t[1]
  pv, code = throw_if(db, C_NULL, KCENOREC) do
    kcdbget(db.ptr, kbuf, length(kbuf), pointer(vsize))
  end
  code == KCENOREC ? default : _copy_bytestring(pv, vsize[1])
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

function delete!(db::Db, k::String)
  kbuf = bytestring(k)
  ok = kcdbremove(db.ptr, kbuf, length(kbuf))
  if (ok == 0) throw(kcexception(db)) end
  db
end

function pop!(db::Db, k::String)
  kb = bytestring(k)
  vsize = Cuint[1]
  pv = kcdbseize(db.ptr, kb, length(kb), vsize)
  if (pv == C_NULL) throw(kcexception(db)) end
  _copy_bytestring(pv, vsize[1])
end

function pop!(db::Db, k::String, default::String)
  kbuf = bytestring(k)
  vsize = Csize_t[1]
  pv, code = throw_if(db, C_NULL, KCENOREC) do
    kcdbseize(db.ptr, kbuf, length(kbuf), pointer(vsize))
  end
  code == KCENOREC ? default : _copy_bytestring(pv, vsize[1])
end

# Indexable collection
getindex(db::Db, k::String) = get(db, k)
setindex!(db::Db, v::String, k::String) = set(db, k, v)

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

function _copy_bytestring(p, size)
  v = bytestring(p, size)
  ok = kcfree(p)
  if (ok == 0) throw(KyotoCabinetException(KCESYSTEM, "Can not free memory")) end
  v
end

end # module kyotocabinet
