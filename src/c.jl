module c

const LIB = "libkyotocabinet"

# C API types
typealias KCDBPtr Ptr{Void}
typealias KCCURPtr Ptr{Void}
typealias CString Ptr{Uint8}

# Error codes
const KCESUCCESS = convert(Cint,  0) # success
const KCENOIMPL  = convert(Cint,  1) # not implemented
const KCEINVALID = convert(Cint,  2) # invalid operation
const KCENOREPOS = convert(Cint,  3) # no repository
const KCENOPERM  = convert(Cint,  4) # no permission
const KCEBROKEN  = convert(Cint,  5) # broken file
const KCEDUPREC  = convert(Cint,  6) # record duplication
const KCENOREC   = convert(Cint,  7) # no record
const KCELOGIC   = convert(Cint,  8) # logical inconsistency
const KCESYSTEM  = convert(Cint,  9) # system error
const KCEMISC    = convert(Cint, 15) # miscellaneous error

# Open modes
const KCOREADER   = convert(Uint, 1 << 0) # open as a reader
const KCOWRITER   = convert(Uint, 1 << 1) # open as a writer
const KCOCREATE   = convert(Uint, 1 << 2) # writer creating
const KCOTRUNCATE = convert(Uint, 1 << 3) # writer truncating
const KCOAUTOTRAN = convert(Uint, 1 << 4) # auto transaction
const KCOAUTOSYNC = convert(Uint, 1 << 5) # auto synchronization
const KCONOLOCK   = convert(Uint, 1 << 6) # open without locking
const KCOTRYLOCK  = convert(Uint, 1 << 7) # lock without blocking
const KCONOREPAIR = convert(Uint, 1 << 8) # open without auto repair

# Release a region allocated in the library.
kcfree(ptr::Ptr{Void}) = ccall((:kcfree, LIB), Void, (Ptr{Void},))
kcfree(ptr::CString) = ccall((:kcfree, LIB), Void, (CString,))

# Create a polymorphic database object.
kcdbnew() = ccall((:kcdbnew, LIB), KCDBPtr, ())

# Destroy a database object.
kcdbdel(db::KCDBPtr) = ccall((:kcdbdel, LIB), Void, (KCDBPtr,), db)

# Open a database file.
function kcdbopen(db::KCDBPtr, path::CString, mode::Cuint)
  ccall((:kcdbopen, LIB), Cint, (KCDBPtr, CString, Cuint), db, path, mode)
end

# Close the database file.
function kcdbclose(db::KCDBPtr)
  ccall((:kcdbclose, LIB), Cint, (KCDBPtr,), db.ptr)
end

# Get the code of the last happened error.
function kcdbecode(db::KCDBPtr)
  ccall((:kcdbecode, LIB), Cint, (KCDBPtr,), db)
end

# Get the supplement message of the last happened error.
function kcdbemsg(db::KCDBPtr)
  ccall((:kcdbemsg, LIB), Cint, (KCDBPtr,), db)
end

# Set the value of a record.
function kcdbset(db::KCDBPtr, kbuf::CString, ksize::Cuint, vbuf::CString, vsize::Cuint)
  ccall((:kcdbset, LIB), Cint, (KCDBPtr, CString, Cuint, CString, Cuint),
    db, kbuf, ksize, vbuf, vsize)
end

# Retrieve the value of a record.
function kcdbget(db::KCDBPtr, kbuf::CString, ksize::Cuint, vsize::Ptr{Cuint})
  ccall((:kcdbset, LIB), CString, (KCDBPtr, CString, Cuint, Ptr{Cuint}),
    db, kbuf, ksize, vsize)
end

# Create a polymorphic cursor object.
function kcdbcursor(db::KCDBPtr)
  ccall((:kcdbcursor, LIB), KCCURPtr, (KCDBPtr,), db.ptr)
end

# Destroy a cursor object.
function kccurdel(cursor::KCCURPtr)
  ccall((:kccurdel, lib), Void, (KCCursorPtr,), cursor)
end

# Get a pair of the key and the value of the current record.
function kccurget(cursor::KCCURPtr, ksize::Ptr{Cuint}, v::Ptr{CString}, vsize::Ptr{Cuint}, step::Cint)
  ccall(c_kccurget, CString,
    (KCCURPtr, Ptr{Cuint}, Ptr{CString}, Ptr{Cuint}, Cint),
    cursor, ksize, v, vsize, step)
end

# Jump the cursor to the first record for forward scan.
function kccurjump(cursor::KCCURPtr)
  ccall((:kccurjump, LIB), Int32, (KCCursorPtr,), cursor)
end

# Step the cursor to the next record.
function kccurstep(cursor::KCCURPtr)
  ccall((:kccurstep, LIB), Cuint, (KCCursorPtr,), cursor)
end

# Get the code of the last happened error.
function kccurecode(cursor::KCCURPtr)
  ccall((:kccurecode, LIB), Cint, (KCCURPtr,), cursor)
end

# Get the supplement message of the last happened error.
function kccuremsg(cursor::KCCURPtr)
  ccall((:kccuremsg, LIB), Cint, (KCCURPtr,), cursor)
end

end # module c
