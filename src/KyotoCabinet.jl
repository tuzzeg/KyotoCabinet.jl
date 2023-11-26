module KyotoCabinet

include("c.jl")

# Basic methods
import Base: open, close

# Iteration
import Base

# Generic collections
import Base: isempty, empty!, length

# Indexed collections
import Base: getindex, setindex!

# Dict
import Base: AbstractDict, haskey, getkey, get, get!, delete!, pop!

using .c

export
  # Types
  Bytes, Db, KyotoCabinetException,

  # Db methods
  get, set!, path, cas, bulkset!, bulkdelete!,
  pack, unpack

Bytes = Array{UInt8,1}

mutable struct Db{K,V} <: AbstractDict{K,V}
    ptr :: Ptr{Cvoid}

    function Db{K,V}(null=false) where {K,V}
        if (null)
            ptr = C_NULL
        else
            ptr = kcdbnew()
        end
        self = new{K,V}(C_NULL)
        self.ptr = ptr
        finalizer(self) do db
            if db.ptr == C_NULL
                return
            end
            kcdbclose(db.ptr)
            kcdbdel(db.ptr)
            db.ptr = C_NULL
        end
        self
    end
end

mutable struct Cursor{K,V}
  ptr :: Ptr{Cvoid}
  db :: Db{K,V} # to prevent DB GCed before cursor

  function Cursor()
    new{K,V}(C_NULL, Db{K,V}(true))
  end

  function Cursor(db::Db{K,V}) where {K,V}
    ptr = kcdbcursor(db.ptr)
    self = new{K,V}()
    self.ptr = ptr
    self.db = db

    finalizer(self) do cursor
        if cursor.ptr == C_NULL
            return
        end
        kccurdel(cursor.ptr)
        cursor.ptr = C_NULL
    end

    self
  end
end

struct KyotoCabinetException <: Exception
  code :: Int32
  message :: String
end

# Pack value into byte array (Array{Uint8,1})
pack(v::Bytes)::Bytes  = v

# Unpack byte array (Array{Uint8,1}) into value of type T.
# buf is not GCed and will be freed right after unpack
# use copy() to own
unpack(buf::Bytes)::Bytes = copy(buf)

# Generic collections

isempty(db::Db{K,V}) where {K,V} = (length(db) == 0)

function length(db::Db{K,V}) where {K,V}
  count = kcdbcount(db.ptr)
  if (count == -1) throw(kcexception(db)) end
  count
end

function empty!(db::Db{K,V}) where {K,V}
  ok = kcdbclear(db.ptr)
  if (ok == 0) throw(kcexception(db)) end
  db
end

# Iterable interface for Db

TupleOrNothing{K,V} = Union{Tuple{K,V},Nothing}

function _return(cur::Cursor{K,V})::TupleOrNothing{Tuple{K,V},Cursor{K,V}} where {K,V}
    if cur.ptr == C_NULL
        nothing
    else
        val = _record(cur)
        if val == nothing
            return nothing
        end
        (val, cur)
    end
end

function Base.iterate(db::Db{K,V})::TupleOrNothing{Tuple{K,V},Cursor{K,V}} where {K,V}
    cur = Cursor(db)
    Base.iterate(cur)
end

function Base.iterate(db::Db{K,V}, cur::Cursor{K,V})::TupleOrNothing{Tuple{K,V},Cursor{K,V}} where {K,V}
    rc = _return(cur)
    if rc == nothing
        return nothing
    end

    vk, _cur = rc
    Base.iterate(cur, vk)
end

function Base.iterate(cur::Cursor{K,V})::TupleOrNothing{Tuple{K,V},Cursor{K,V}} where {K,V}
    _start!(cur)
    _return(cur)
end

function Base.iterate(cur::Cursor{K,V},
                      state::TupleOrNothing{K,V})::TupleOrNothing{Tuple{K,V},Cursor{K,V}} where {K,V}
    _next!(cur)
    _return(cur)
end

# Db methods

function open(db::Db{K,V}, file::String, mode::String) where {K,V}
  open(db, file, _mode(mode))
end

function open(f::Function, db::Db{K,V}, file::String, mode::String) where {K,V}
  open(f, db, file, _mode(mode))
end

function open(db::Db{K,V}, file::String, mode::UInt) where {K,V}
  ok = kcdbopen(db.ptr, file, mode)
  if (ok == 0) throw(kcexception(db)) end
  db
end

function open(f::Function, db::Db{K,V}, file::String, mode::Int) where {K,V}
  db = open(db, file, mode)
  try
    f(db)
  finally
    close(db)
    # destroy(db)
  end
end

function close(db::Db{K,V}) where {K,V}
  ok = kcdbclose(db.ptr)
  if (ok == 0) throw(kcexception(db)) end
end

function cas(db::Db{K,V}, key::K, old::V, new::V) where {K,V}
  kbuf = pack(key)
  ovbuf = pack(old)
  nvbuf = pack(new)
  ok, code = throw_if(db, 0, KCELOGIC) do
    kcdbcas(db.ptr, pointer(kbuf),
            length(kbuf), pointer(ovbuf),
            length(ovbuf), pointer(nvbuf), length(nvbuf))
  end
  code == KCESUCCESS
end

# To resolve conflict with V=nothing
cas(db::Db{K,Nothing}, key::K, old::Nothing, new::Nothing) where K = KCESUCCESS

function cas(db::Db{K,V}, key::K, old::Nothing, new::V) where {K,V}
  kbuf = pack(key)
  nvbuf = pack(new)
  ok, code = throw_if(db, 0, KCELOGIC) do
    kcdbcas(db.ptr, pointer(kbuf), length(kbuf), C_NULL, 0, pointer(nvbuf), length(nvbuf))
  end
  code == KCESUCCESS
end

function cas(db::Db{K,V}, key::K, old::V, new::Nothing) where {K,V}
  kbuf = pack(key)
  ovbuf = pack(old)
  ok, code = throw_if(db, 0, KCELOGIC) do
    kcdbcas(db.ptr, pointer(kbuf), length(kbuf), pointer(ovbuf), length(ovbuf), C_NULL, 0)
  end
  code == KCESUCCESS
end

# Dict methods
function haskey(db::Db{K,V}, k::K) where {K,V}
  kbuf = pack(k)
  v, code = throw_if(db, -1, KCENOREC) do
    kcdbcheck(db.ptr, pointer(kbuf), length(kbuf))
  end
  code != KCENOREC
end

function getkey(db::Db{K,V}, key::K, default::K) where {K,V}
  haskey(db, key) ? key : default
end

function set!(db::Db{K,V}, k::K, v::V) where {K,V}
  kbuf = pack(k)
  vbuf = pack(v)
  ok = kcdbset(db.ptr, pointer(kbuf), length(kbuf), pointer(vbuf), length(vbuf))
  if (ok == C_NULL) throw(kcexception(db)) end
  v
end

function bulkset!(db::Db{K,V}, kvs::Dict{K,V}, atomic::Bool) where {K,V}
  # make a copy to prevent GC
  recbuf = [(pack(k), pack(v)) for (k, v) in kvs]
  recs = [KCREC(KCSTR(k, length(k)), KCSTR(v, length(v))) for (k, v) in recbuf]
  c = kcdbsetbulk(db.ptr, recs, length(recs), atomic ? 1 : 0)
  if (c == -1) throw(kcexception(db)) end
  c
end

function bulkdelete!(db::Db{K,V}, keys::Array, atomic::Bool) where {K,V}
  keybuf = [pack(k) for k in keys]
  ks = [KCSTR(k, length(k)) for k in keybuf]
  c = kcdbremovebulk(db.ptr, ks, length(ks), atomic ? 1 : 0)
  if (c == -1) throw(kcexception(db)) end
  c
end

function get(db::Db{K,V}, k::K)::V where {K,V}
  kbuf = pack(k)
  vsize = Csize_t[0]
  pv = kcdbget(db.ptr, pointer(kbuf), length(kbuf), pointer(vsize))
  if (pv == C_NULL) throw(kcexception(db)) end
  _unpack(pv, convert(Int, vsize[1]))::V
end

get(db::Db{K,V}, k, default) where {K,V} = get(()->default, db, k)

function get(default::Function, db::Db{K,V}, k::K) where {K,V}
  kbuf = pack(k)
  vsize = Csize_t[0]
  pv, code = throw_if(db, C_NULL, KCENOREC) do
    kcdbget(db.ptr, pointer(kbuf), length(kbuf), pointer(vsize))
  end
  code == KCENOREC ? default() : _unpack(V, pv, int(vsize[1]))
end

get!(db::Db{K,V}, k, default) where {K,V} = get!(()->default, db, k)

function get!(default::Function, db::Db{K,V}, k::K) where {K,V}
  kbuf = pack(k)
  vsize = Csize_t[0]
  pv, code = throw_if(db, C_NULL, KCENOREC) do
    kcdbget(db.ptr, pointer(kbuf), length(kbuf), pointer(vsize))
  end
  code == KCENOREC ? set!(db, k, default()) : _unpack(V, pv, int(vsize[1]))
end

function delete!(db::Db{K,V}, k::K) where {K,V}
  kbuf = pack(k)
  ok = kcdbremove(db.ptr, pointer(kbuf), length(kbuf))
  if (ok == 0) throw(kcexception(db)) end
  db
end

function pop!(db::Db{K,V}, k::K) where {K,V}
  kbuf = pack(k)
  vsize = Csize_t[0]
  pv = kcdbseize(db.ptr, pointer(kbuf), length(kbuf), pointer(vsize))
  if (pv == C_NULL) throw(kcexception(db)) end
  _unpack(V, pv, int(vsize[1]))
end

function pop!(db::Db{K,V}, k::K, default::V) where {K,V}
  kbuf = pack(k)
  vsize = Csize_t[0]
  pv, code = throw_if(db, C_NULL, KCENOREC) do
    kcdbseize(db.ptr, pointer(kbuf), length(kbuf), pointer(vsize))
  end
  code == KCENOREC ? default : _unpack(V, pv, int(vsize[1]))
end

# Indexable collection
getindex(db::Db{K,V}, k) where {K,V} = get(db, k)
setindex!(db::Db{K,V}, v, k) where {K,V} = set!(db, k, v)

# Cursor

function _start!(cursor::Cursor{K,V}) where {K,V}
  f(cursor::Cursor) = kccurjump(cursor.ptr)
  _move!(cursor, f)
end

# Move to the next record. Return false if there no next record.
function _next!(cursor::Cursor{K,V}) where {K,V}
  f(cursor::Cursor) = kccurstep(cursor.ptr)
  _move!(cursor, f)
end

function _move!(cursor::Cursor{K,V}, f) where {K,V}
  ok, code = throw_if(cursor, 0, KCENOREC) do
    f(cursor)
  end
  code != KCENOREC
end

function _record(cursor::Cursor{K,V})::TupleOrNothing{K,V} where {K,V}
    pkSize = Csize_t[0]
    pvSize = Csize_t[0]
    v = Vector{Ptr{UInt8}}(undef,1)
    pk = kccurget(cursor.ptr, pointer(pkSize), pointer(v), pointer(pvSize), 0)
    # if (pk == C_NULL) throw(kcexception(cursor)) end
    if (pk == C_NULL)
        return nothing
    end
    vk = v[1]

    key = _unpack(pk, convert(Int, pkSize[1]), false)::K
    val = _unpack(vk, convert(Int, pvSize[1]), false)::V
    # println(key, "-", val)
    res = (key, val)
    ok1 = kcfree(pk)
    # ok2 = kcfree(vk)
    if (ok1 == 0) throw(kcexception(cursor)) end

    res
end

function path(db::Db{K,V})::String where {K,V}
  p = kcdbpath(db.ptr)
  v = unsafe_string(p)
  ok = kcfree(p)
  if (ok == 0) throw(KyotoCabinetException(KCESYSTEM, "Can not free memory")) end
  v
end

# KyotoCabinet exceptions
function throw_if(f::Function, db::Db{K,V}, result_invalid, ecode_valid) where {K,V}
  result = f()
  if (result == result_invalid)
    code = kcdbecode(db.ptr)
    if (code == ecode_valid)
      return (result, code)
    else
      message = unsafe_string(kcdbemsg(db.ptr))
      throw(KyotoCabinetException(code, message))
    end
  end
  (result, KCESUCCESS)
end

function throw_if(f::Function, cursor::Cursor{K,V}, result_invalid, ecode_valid) where {K,V}
  result = f()
  if (result == result_invalid)
    code = kccurecode(cursor.ptr)
    if (code == ecode_valid)
      return (result, code)
    else
      message = unsafe_string(kccuremsg(cursor.ptr))
      throw(KyotoCabinetException(code, message))
    end
  end
  (result, KCESUCCESS)
end

function kcexception(db::Db{K,V}) where {K,V}
  @assert db.ptr != C_NULL

  code = kcdbecode(db.ptr)
  message = unsafe_string(kcdbemsg(db.ptr))

  KyotoCabinetException(code, message)
end

function kcexception(cur::Cursor{K,V}) where {K,V}
  @assert cur.ptr != C_NULL

  code = kccurecode(cur.ptr)
  message = unsafe_string(kccuremsg(cur.ptr))

  KyotoCabinetException(code, message)
end

function _unpack(p::Ptr{UInt8}, length::Int, free=true)
    bs::Bytes = unsafe_wrap(Bytes, p, length, own=false)
    v = unpack(bs::Bytes)
    if free
        ok = kcfree(p)
        if (ok == 0) throw(KyotoCabinetException(KCESYSTEM, "Can not free memory")) end
    end
    v
end

_modes = Dict{String,UInt}(
  "r" => KCOREADER,
  "w" => KCOWRITER,
  "w+" => KCOWRITER | KCOCREATE
)
_mode(mode::String) = get(_modes, mode, KCOREADER)

end # module KyotoCabinet
