module kyotocabinet

include("c.jl")

# Basic methods
import Base: open, close

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
  Bytes, Db, KyotoCabinetException,

  # Db methods
  get, set!, path, cas, bulkset!, bulkdelete!,
  pack, unpack

typealias Bytes Array{Uint8,1}

type Db{K,V} <: Associative{K,V}
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

type Cursor{K,V}
  ptr :: Ptr{Void}
  db :: Db{K,V} # to prevent DB GCed before cursor

  function Cursor()
    new(C_NULL, Db{K,V}(true))
  end

  function Cursor(db::Db{K,V})
    ptr = kcdbcursor(db.ptr)
    self = Cursor{K,V}()
    self.ptr = ptr
    self.db = db
    finalizer(self, destroy)
    self
  end
end

immutable RecordIterator{K,V}
  cursor :: Cursor{K,V}
end

immutable KyotoCabinetException <: Exception
  code :: Int32
  message :: String
end

# Pack value into byte array (Array{Uint8,1})
pack(v::Bytes) = v

# Unpack byte array (Array{Uint8,1}) into value of type T.
# buf is not GCed and will be freed right after unpack
# use copy() to own
unpack(T::Type{Bytes}, buf::Bytes) = copy(buf)

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

function start{K,V}(db::Db{K,V})
  cur = Cursor{K,V}(db)
  _start!(cur) ? RecordIterator{K,V}(cur) : RecordIterator{K,V}(Cursor{K,V}())
end

function next{K,V}(db::Db{K,V}, it::RecordIterator{K,V})
  if done(db, it)
    throw(KyotoCabinetException(KCENOREC, "Can not move forward"))
  end
  kv = _record(it.cursor)
  if (_next!(it.cursor))
    (kv, it)
  else
    destroy(it.cursor)
    (kv, RecordIterator{K,V}(Cursor{K,V}()))
  end
end

function done(db::Db, it::RecordIterator)
  it.cursor.ptr == C_NULL
end

# Db methods

function open{K,V}(db::Db{K,V}, file::String, mode::String)
  open(db, file, _mode(mode))
end

function open{K,V}(f::Function, db::Db{K,V}, file::String, mode::String)
  open(f, db, file, _mode(mode))
end

function open{K,V}(db::Db{K,V}, file::String, mode::Uint)
  ok = kcdbopen(db.ptr, bytestring(file), mode)
  if (ok == 0) throw(kcexception(db)) end
  db
end

function open{K,V}(f::Function, db::Db{K,V}, file::String, mode::Uint)
  db = open(db, file, mode)
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

function cas{K,V}(db::Db{K,V}, key::K, old::V, new::V)
  kbuf = pack(key)
  ovbuf = pack(old)
  nvbuf = pack(new)
  ok, code = throw_if(db, 0, KCELOGIC) do
    kcdbcas(db.ptr, pointer(kbuf), length(kbuf), pointer(ovbuf), length(ovbuf), pointer(nvbuf), length(nvbuf))
  end
  code == KCESUCCESS
end

# To resolve conflict with V=nothing
cas{K}(db::Db{K,Nothing}, key::K, old::Nothing, new::Nothing) = KCESUCCESS

function cas{K,V}(db::Db{K,V}, key::K, old::Nothing, new::V)
  kbuf = pack(key)
  nvbuf = pack(new)
  ok, code = throw_if(db, 0, KCELOGIC) do
    kcdbcas(db.ptr, pointer(kbuf), length(kbuf), C_NULL, 0, pointer(nvbuf), length(nvbuf))
  end
  code == KCESUCCESS
end

function cas{K,V}(db::Db{K,V}, key::K, old::V, new::Nothing)
  kbuf = pack(key)
  ovbuf = pack(old)
  ok, code = throw_if(db, 0, KCELOGIC) do
    kcdbcas(db.ptr, pointer(kbuf), length(kbuf), pointer(ovbuf), length(ovbuf), C_NULL, 0)
  end
  code == KCESUCCESS
end

# Dict methods
function haskey{K,V}(db::Db{K,V}, k::K)
  kbuf = pack(k)
  v, code = throw_if(db, -1, KCENOREC) do
    kcdbcheck(db.ptr, pointer(kbuf), length(kbuf))
  end
  code != KCENOREC
end

function getkey{K,V}(db::Db{K,V}, key::K, default::K)
  haskey(db, key) ? key : default
end

function set!{K,V}(db::Db{K,V}, k::K, v::V)
  kbuf = pack(k)
  vbuf = pack(v)
  ok = kcdbset(db.ptr, pointer(kbuf), length(kbuf), pointer(vbuf), length(vbuf))
  if (ok == 0) throw(kcexception(db)) end
  v
end

function bulkset!{K,V}(db::Db{K,V}, kvs::Dict{K,V}, atomic::Bool)
  # make a copy to prevent GC
  recbuf = [(pack(k), pack(v)) for (k, v) in kvs]
  recs = [KCREC(KCSTR(k, length(k)), KCSTR(v, length(v))) for (k, v) in recbuf]
  c = kcdbsetbulk(db.ptr, recs, length(recs), atomic ? 1 : 0)
  if (c == -1) throw(kcexception(db)) end
  c
end

function bulkdelete!{K,V}(db::Db{K,V}, keys::Array{K,1}, atomic::Bool)
  keybuf = [pack(k) for k in keys]
  ks = [KCSTR(k, length(k)) for k in keybuf]
  c = kcdbremovebulk(db.ptr, ks, length(ks), atomic ? 1 : 0)
  if (c == -1) throw(kcexception(db)) end
  c
end

function get{K,V}(db::Db{K,V}, k::K)
  kbuf = pack(k)
  vsize = Csize_t[0]
  pv = kcdbget(db.ptr, pointer(kbuf), length(kbuf), vsize)
  if (pv == C_NULL) throw(kcexception(db)) end
  _unpack(V, pv, int(vsize[1]))
end

get(db::Db, k, default) = get(()->default, db, k)

function get{K,V}(default::Function, db::Db{K,V}, k::K)
  kbuf = pack(k)
  vsize = Csize_t[0]
  pv, code = throw_if(db, C_NULL, KCENOREC) do
    kcdbget(db.ptr, pointer(kbuf), length(kbuf), pointer(vsize))
  end
  code == KCENOREC ? default() : _unpack(V, pv, int(vsize[1]))
end

get!(db::Db, k, default) = get!(()->default, db, k)

function get!{K,V}(default::Function, db::Db{K,V}, k::K)
  kbuf = pack(k)
  vsize = Csize_t[0]
  pv, code = throw_if(db, C_NULL, KCENOREC) do
    kcdbget(db.ptr, pointer(kbuf), length(kbuf), pointer(vsize))
  end
  code == KCENOREC ? set!(db, k, default()) : _unpack(V, pv, int(vsize[1]))
end

function delete!{K,V}(db::Db{K,V}, k::K)
  kbuf = pack(k)
  ok = kcdbremove(db.ptr, pointer(kbuf), length(kbuf))
  if (ok == 0) throw(kcexception(db)) end
  db
end

function pop!{K,V}(db::Db{K,V}, k::K)
  kbuf = pack(k)
  vsize = Csize_t[0]
  pv = kcdbseize(db.ptr, pointer(kbuf), length(kbuf), vsize)
  if (pv == C_NULL) throw(kcexception(db)) end
  _unpack(V, pv, int(vsize[1]))
end

function pop!{K,V}(db::Db{K,V}, k::K, default::V)
  kbuf = pack(k)
  vsize = Csize_t[0]
  pv, code = throw_if(db, C_NULL, KCENOREC) do
    kcdbseize(db.ptr, pointer(kbuf), length(kbuf), pointer(vsize))
  end
  code == KCENOREC ? default : _unpack(V, pv, int(vsize[1]))
end

# Indexable collection
getindex(db::Db, k) = get(db, k)
setindex!(db::Db, v, k) = set!(db, k, v)

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

function _record{K,V}(cursor::Cursor{K,V})
  pkSize = Csize_t[0]
  pvSize = Csize_t[0]
  pv = CString[0]
  pk = kccurget(cursor.ptr, pointer(pkSize), pointer(pv), pointer(pvSize), 0)
  if (pk == C_NULL) throw(kcexception(cursor)) end

  res = (_unpack(K, pk, int(pkSize[1]), false), _unpack(V, pv[1], int(pvSize[1]), false))
  ok = kcfree(pk)
  if (ok == 0) throw(kcexception(cursor)) end

  res
end

function path(db::Db)
  p = kcdbpath(db.ptr)
  v = bytestring(p)
  ok = kcfree(p)
  if (ok == 0) throw(KyotoCabinetException(KCESYSTEM, "Can not free memory")) end
  v
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

function _unpack(T, p::Ptr{Uint8}, length, free=true)
  v = unpack(T, pointer_to_array(p, length))
  if free
    ok = kcfree(p)
    if (ok == 0) throw(KyotoCabinetException(KCESYSTEM, "Can not free memory")) end
  end
  v
end

_modes = {
  "r" => KCOREADER,
  "w" => KCOWRITER,
  "w+" => KCOWRITER | KCOCREATE
}
_mode(mode::String) = get(_modes, mode, KCOREADER)

end # module kyotocabinet
