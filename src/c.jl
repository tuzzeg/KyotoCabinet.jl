module c

include("../deps/deps.jl")

export
  # Types
  KCDBPtr, KCCURPtr, CString,

  # Error codes
  KCESUCCESS, KCENOIMPL, KCEINVALID, KCENOREPOS, KCENOPERM, KCEBROKEN, KCEDUPREC, KCENOREC, KCELOGIC, KCESYSTEM, KCEMISC,

  # Open modes
  KCOREADER, KCOWRITER, KCOCREATE, KCOTRUNCATE, KCOAUTOTRAN, KCOAUTOSYNC, KCONOLOCK, KCOTRYLOCK, KCONOREPAIR,

  # General functions
  kcfree,

  # DB functions
  kcdbnew, kcdbdel, kcdbopen, kcdbclose, kcdbecode, kcdbemsg, kcdbset, kcdbget, kcdbcursor, kcdbcount,

  # Cursor functions
  kccurdel, kccurjump, kccurstep, kccurget, kccurecode, kccuremsg, kccurdb

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
kcfree(ptr) = ccall((:kcfree, libkyotocabinet), Void, (Ptr{Void},), ptr)

# Create a polymorphic database object.
kcdbnew() = ccall((:kcdbnew, libkyotocabinet), KCDBPtr, ())

# Destroy a database object.
function kcdbdel(db::KCDBPtr)
  ccall((:kcdbdel, libkyotocabinet), Void, (KCDBPtr,), db)
end

# Open a database file.
function kcdbopen(db::KCDBPtr, path, mode)
  ccall((:kcdbopen, libkyotocabinet), Cint, (KCDBPtr, CString, Cuint), db, path, mode)
end

# Close the database file.
function kcdbclose(db::KCDBPtr)
  ccall((:kcdbclose, libkyotocabinet), Cint, (KCDBPtr,), db)
end

# Get the code of the last happened error.
function kcdbecode(db::KCDBPtr)
  ccall((:kcdbecode, libkyotocabinet), Cint, (KCDBPtr,), db)
end

# Get the supplement message of the last happened error.
function kcdbemsg(db::KCDBPtr)
  ccall((:kcdbemsg, libkyotocabinet), CString, (KCDBPtr,), db)
end

# Set the value of a record.
function kcdbset(db::KCDBPtr, kbuf, ksize, vbuf, vsize)
  ccall((:kcdbset, libkyotocabinet), Cint, (KCDBPtr, CString, Cuint, CString, Cuint),
    db, kbuf, ksize, vbuf, vsize)
end

# Retrieve the value of a record.
function kcdbget(db::KCDBPtr, kbuf, ksize, vsize)
  ccall((:kcdbget, libkyotocabinet), CString, (KCDBPtr, CString, Cuint, Ptr{Cuint}),
    db, kbuf, ksize, vsize)
end

# Get the number of records.
function kcdbcount(db::KCDBPtr)
  ccall((:kcdbcount, libkyotocabinet), Clonglong, (KCDBPtr,), db)
end

# Create a polymorphic cursor object.
function kcdbcursor(db::KCDBPtr)
  ccall((:kcdbcursor, libkyotocabinet), KCCURPtr, (KCDBPtr,), db)
end

# Destroy a cursor object.
function kccurdel(cursor::KCCURPtr)
  ccall((:kccurdel, libkyotocabinet), Void, (KCCURPtr,), cursor)
end

# Get a pair of the key and the value of the current record.
function kccurget(cursor::KCCURPtr, ksize, v, vsize, step)
  ccall((:kccurget, libkyotocabinet), CString,
    (KCCURPtr, Ptr{Cuint}, Ptr{CString}, Ptr{Cuint}, Cint),
    cursor, ksize, v, vsize, step)
end

# Jump the cursor to the first record for forward scan.
function kccurjump(cursor::KCCURPtr)
  ccall((:kccurjump, libkyotocabinet), Cint, (KCCURPtr,), cursor)
end

# Step the cursor to the next record.
function kccurstep(cursor::KCCURPtr)
  ccall((:kccurstep, libkyotocabinet), Cint, (KCCURPtr,), cursor)
end

# Get the database object.
function kccurdb(cursor::KCCURPtr)
  ccall((:kccurdb, libkyotocabinet), KCDBPtr, (KCCURPtr,), cursor)
end

# Get the code of the last happened error.
function kccurecode(cursor::KCCURPtr)
  ccall((:kccurecode, libkyotocabinet), Cint, (KCCURPtr,), cursor)
end

# Get the supplement message of the last happened error.
function kccuremsg(cursor::KCCURPtr)
  ccall((:kccuremsg, libkyotocabinet), CString, (KCCURPtr,), cursor)
end

end # module c
