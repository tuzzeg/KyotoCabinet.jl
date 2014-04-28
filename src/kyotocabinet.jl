module kyotocabinet

include("constants.jl")

export
  Db, Cursor,
  open, close, get, set, _jump, _next,
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
const c_kccurdel = (:kccurdel, "libkyotocabinet")
const c_kccurget = (:kccurget, "libkyotocabinet")
const c_kccurjump = (:kccurjump, "libkyotocabinet")
const c_kcfree = (:kcfree, "libkyotocabinet")

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

  function Cursor(db::Db)
    ptr = ccall(c_kcdbcursor, KCCursorPtr, (KCDBPtr,), db.ptr)
    self = new(ptr)
    finalizer(self, destroy)
    self
  end
end

function open(db::Db, file::String, mode::Uint)
  ccall(c_kcdbopen, Int32, (KCDBPtr, CString, Cuint), db.ptr, bytestring(file), mode)
end

function close(db::Db)
  ccall(c_kcdbclose, Int32, (KCDBPtr,), db.ptr)
end

function destroy(db::Db)
  if db.ptr == C_NULL
    return
  end
  ccall(c_kcdbdel, Void, (KCDBPtr,), db.ptr)
  db.ptr = C_NULL
end

function set(db::Db, k::String, v::String)
  kb = bytestring(k)
  vb = bytestring(v)
  ccall(c_kcdbset, Int32, (KCDBPtr, CString, Cuint, CString, Cuint),
    db.ptr, kb, length(kb), vb, length(vb))
end

function get(db::Db, k::String)
  kb = bytestring(k)
  vSize = Cuint[0]
  v = ccall(c_kcdbget, CString, (KCDBPtr, CString, Cuint, Ptr{Cuint}),
    db.ptr, kb, length(kb), vSize)
  bytestring(v, vSize[1])
end

# Cursor methods
function _jump(cursor::Cursor)
  ccall(c_kccurjump, Cuint, (KCCursorPtr,), cursor.ptr)
end

function _next(cursor::Cursor)
  pkSize = Cuint[1]
  pvSize = Cuint[1]
  pv = CString[1]
  k = ccall(c_kccurget, CString,
    (KCCursorPtr, Ptr{Cuint}, Ptr{CString}, Ptr{Cuint}, Cint),
    cursor.ptr, pkSize, pv, pvSize, 1)

  res = (bytestring(k, pkSize[1]), bytestring(pv[1], pvSize[1]))
  ccall(c_kcfree, Void, (CString,), k)
  res
end

function destroy(cursor::Cursor)
  if cursor.ptr == C_NULL
    return
  end
  ccall(c_kccurdel, Void, (KCCursorPtr,), cursor.ptr)
  cursor.ptr = C_NULL
end

end # module kyotocabinet
