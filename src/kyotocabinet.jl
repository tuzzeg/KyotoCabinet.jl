module kyotocabinet

include("constants.jl")

export
  Db, Cursor, KyotoCabinetException,
  open, close, get, set, _jump, _next, _current_record,
  start, next, done,
  KCOREADER, KCOWRITER, KCOCREATE, KCOTRUNCATE, KCOAUTOTRAN,
  KCOAUTOSYNC, KCONOLOCK, KCOTRYLOCK, KCONOREPAIR

# C API types
typealias KCDBPtr Ptr{Void}
typealias KCCursorPtr Ptr{Void}
typealias CString Ptr{Uint8}

# C API methods
const c_kcdbnew = (:kcdbnew, "libkyotocabinet")
const c_kcdbdel = (:kcdbdel, "libkyotocabinet")
const c_kcdbopen = (:kcdbopen, "libkyotocabinet")
const c_kcdbclose = (:kcdbclose, "libkyotocabinet")
const c_kcdbset = (:kcdbset, "libkyotocabinet")
const c_kcdbget = (:kcdbget, "libkyotocabinet")
const c_kcdbcursor = (:kcdbcursor, "libkyotocabinet")
const c_kcdbecode = (:kcdbecode, "libkyotocabinet")
const c_kcdbemsg = (:kcdbemsg, "libkyotocabinet")

const c_kcfree = (:kcfree, "libkyotocabinet")

const c_kccurdel = (:kccurdel, "libkyotocabinet")
const c_kccurget = (:kccurget, "libkyotocabinet")
const c_kccurstep = (:kccurstep, "libkyotocabinet")
const c_kccurjump = (:kccurjump, "libkyotocabinet")
const c_kccurecode = (:kccurecode, "libkyotocabinet")
const c_kccuremsg = (:kccuremsg, "libkyotocabinet")

const EXCP_CUR_NO_RECORD = convert(Cint, 7)

type Db
  ptr :: Ptr{Void}

  function Db()
    ptr = ccall(c_kcdbnew, KCDBPtr, ())
    self = new(ptr)
    finalizer(self, destroy)
    self
  end
end

type Cursor
  ptr :: Ptr{Void}
  row :: Uint # Inner counter, incremented at each move
  done :: Bool

  function Cursor(db::Db)
    ptr = ccall(c_kcdbcursor, KCCursorPtr, (KCDBPtr,), db.ptr)
    self = new(ptr)
    finalizer(self, destroy)
    self
  end
end

function Base.start(cur::Cursor)
  cur.done = !_jump(cur)
  cur.row = convert(Uint, 0)
end

function Base.next(cur::Cursor, st::Uint)
  if st == cur.row - 1
    kv = _current_record(cur)
  elseif st == cur.row
    kv = _current_record(cur)
    cur.done = !_next(cur)
    cur.row += 1
  else
    throw(KyotoCabinetException(EXCP_CUR_NO_RECORD, "Can not move forward"))
  end
  (kv, cur.row)
end

Base.done(cur::Cursor, st::Uint) = cur.done

type KyotoCabinetException <: Exception
  code :: Int32
  message :: String
end

function open(db::Db, file::String, mode::Uint)
  ok = ccall(c_kcdbopen, Int32, (KCDBPtr, CString, Cuint), db.ptr, bytestring(file), mode)
  if (ok == 0) throw(kcexception(db)) end
end

function close(db::Db)
  ok = ccall(c_kcdbclose, Int32, (KCDBPtr,), db.ptr)
  if (ok == 0) throw(kcexception(db)) end
end

function destroy(db::Db)
  if db.ptr == C_NULL
    return
  end
  ok = ccall(c_kcdbdel, Void, (KCDBPtr,), db.ptr)
  if (ok == 0) throw(kcexception(db)) end
  db.ptr = C_NULL
end

function set(db::Db, k::String, v::String)
  kb = bytestring(k)
  vb = bytestring(v)
  ok = ccall(c_kcdbset, Int32, (KCDBPtr, CString, Cuint, CString, Cuint),
    db.ptr, kb, length(kb), vb, length(vb))
  if (ok == 0) throw(kcexception(db)) end
  return
end

function get(db::Db, k::String)
  kb = bytestring(k)
  vSize = Cuint[0]
  v = ccall(c_kcdbget, CString, (KCDBPtr, CString, Cuint, Ptr{Cuint}),
    db.ptr, kb, length(kb), vSize)
  if (v == C_NULL) throw(kcexception(db)) end
  bytestring(v, vSize[1])
end

# Jump to the first record. Return false if there is no first record.
function _jump(cursor::Cursor)
  function f(cursor::Cursor)
    ccall(c_kccurjump, Cuint, (KCCursorPtr,), cursor.ptr)
  end
  _cur_move(cursor, f)
end

# Move to the next record. Return false if there no next record.
function _next(cursor::Cursor)
  function f(cursor::Cursor)
    ccall(c_kccurstep, Cuint, (KCCursorPtr,), cursor.ptr)
  end
  _cur_move(cursor, f)
end

function _cur_move(cursor::Cursor, f)
  ok = f(cursor)
  if (ok == 0)
    code = ccall(c_kccurecode, Cint, (KCCursorPtr,), cursor.ptr)
    if (code == EXCP_CUR_NO_RECORD)
      return false
    else
      message = bytestring(ccall(c_kccuremsg, CString, (KCCursorPtr,), cursor.ptr))
      throw(KyotoCabinetException(code, message))
    end
  else
    return true
  end
end

function _current_record(cursor::Cursor)
  pkSize = Cuint[1]
  pvSize = Cuint[1]
  pv = CString[1]
  k = ccall(c_kccurget, CString,
    (KCCursorPtr, Ptr{Cuint}, Ptr{CString}, Ptr{Cuint}, Cint),
    cursor.ptr, pkSize, pv, pvSize, 0)
  if (k == C_NULL) throw(kcexception(cursor)) end

  res = (bytestring(k, pkSize[1]), bytestring(pv[1], pvSize[1]))
  ok = ccall(c_kcfree, Void, (CString,), k)
  if (ok == 0) throw(kcexception(cursor)) end

  res
end

# KyotoCabinet exceptions
function kcexception(db::Db)
  @assert db.ptr != C_NULL

  code = ccall(c_kcdbecode, Cint, (KCDBPtr,), db.ptr)
  message = bytestring(ccall(c_kcdbemsg, CString, (KCDBPtr,), db.ptr))

  KyotoCabinetException(code, message)
end

function kcexception(cur::Cursor)
  @assert cur.ptr != C_NULL

  code = ccall(c_kccurecode, Cint, (KCCursorPtr,), cur.ptr)
  message = bytestring(ccall(c_kccuremsg, CString, (KCCursorPtr,), cur.ptr))

  KyotoCabinetException(code, message)
end

function destroy(cursor::Cursor)
  if cursor.ptr == C_NULL
    return
  end
  ccall(c_kccurdel, Void, (KCCursorPtr,), cursor.ptr)
  cursor.ptr = C_NULL
end

end # module kyotocabinet
