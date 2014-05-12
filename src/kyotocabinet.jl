module kyotocabinet

include("c.jl")

# Iteration
import Base: start, next, done

# Generic collections
import Base: isempty, empty!, length

# Indexed collections
import Base: getindex, setindex!

# Dict
import Base: Associative, haskey, getkey, get, get!, delete!, pop!

using .c

export
  # Types
  Db, KyotoCabinetException,

  # Db methods
  open, close, get, set, path, cas, bulkset!, bulkdelete!

type Db <: Associative
  ptr :: Ptr{Void}

  function Db(null=false)
    if (null)
      new(C_NULL)
    else
      ptr = kcdbnew()
      self = new(ptr)
      finalizer(self, destroy)
      self
    end
  end
end

type Cursor
  ptr :: Ptr{Void}
  db :: Db # DB should be GCed after

  function Cursor()
    new(C_NULL, Db(true))
  end

  function Cursor(db::Db)
    ptr = kcdbcursor(db.ptr)
    self = new(ptr, db)
    finalizer(self, destroy)
    self
  end
end

immutable RecordIterator
  cursor :: Cursor
end

immutable KyotoCabinetException <: Exception
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

# Iterable interface for Db

const RECORDS_EOF = RecordIterator(Cursor())

function start(db::Db)
  cur = Cursor(db)
  _start!(cur) ? RecordIterator(cur) : RECORDS_EOF
end

function next(db::Db, it::RecordIterator)
  if done(db, it)
    throw(KyotoCabinetException(KCENOREC, "Can not move forward"))
  end
  kv = _record(it.cursor)
  if (_next!(it.cursor))
    (kv, it)
  else
    destroy(it.cursor)
    (kv, RECORDS_EOF)
  end
end

function done(db::Db, it::RecordIterator)
  it.cursor.ptr == C_NULL
end

# Db methods

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
  kcdbclose(db.ptr)
  kcdbdel(db.ptr)
  db.ptr = C_NULL
end

function cas(db::Db, key::String, old::String, new::String)
  kbuf = bytestring(key)
  ovbuf = bytestring(old)
  nvbuf = bytestring(new)
  ok, code = throw_if(db, 0, KCELOGIC) do
    kcdbcas(db.ptr, kbuf, length(kbuf), ovbuf, length(ovbuf), nvbuf, length(nvbuf))
  end
  code == KCESUCCESS
end

function cas(db::Db, key::String, old::(), new::String)
  kbuf = bytestring(key)
  nvbuf = bytestring(new)
  ok, code = throw_if(db, 0, KCELOGIC) do
    kcdbcas(db.ptr, kbuf, length(kbuf), C_NULL, 0, nvbuf, length(nvbuf))
  end
  code == KCESUCCESS
end

function cas(db::Db, key::String, old::String, new::())
  kbuf = bytestring(key)
  ovbuf = bytestring(old)
  ok, code = throw_if(db, 0, KCELOGIC) do
    kcdbcas(db.ptr, kbuf, length(kbuf), ovbuf, length(ovbuf), C_NULL, 0)
  end
  code == KCESUCCESS
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

function bulkset!{T<:String}(db::Db, kvs::Dict{T,T}, atomic::Bool)
  # make a copy to prevent GC
  recbuf = [(bytestring(k), bytestring(v)) for (k, v) in kvs]
  recs = [KCREC(KCSTR(k, length(k)), KCSTR(v, length(v))) for (k, v) in recbuf]
  c = kcdbsetbulk(db.ptr, recs, length(recs), atomic ? 1 : 0)
  if (c == -1) throw(kcexception(db)) end
  c
end

function bulkdelete!{T<:String}(db::Db, keys::Array{T}, atomic::Bool)
  keybuf = [bytestring(k) for k in keys]
  ks = [KCSTR(k, length(k)) for k in keybuf]
  c = kcdbremovebulk(db.ptr, ks, length(ks), atomic ? 1 : 0)
  if (c == -1) throw(kcexception(db)) end
  c
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

# Cursor

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

function _record(cursor::Cursor)
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

function path(db::Db)
  _copy_bytestring(kcdbpath(db.ptr))
end

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

function _copy_bytestring(p)
  v = bytestring(p)
  ok = kcfree(p)
  if (ok == 0) throw(KyotoCabinetException(KCESYSTEM, "Can not free memory")) end
  v
end

end # module kyotocabinet
