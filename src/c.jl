module c

# include("../deps/deps.jl")

export
  # Types
  KCDBPtr, KCCURPtr, Cstring, KCREC, KCSTR,

  # Error codes
  KCESUCCESS, KCENOIMPL, KCEINVALID, KCENOREPOS, KCENOPERM, KCEBROKEN, KCEDUPREC, KCENOREC, KCELOGIC, KCESYSTEM, KCEMISC,

  # Open modes
  KCOREADER, KCOWRITER, KCOCREATE, KCOTRUNCATE, KCOAUTOTRAN, KCOAUTOSYNC, KCONOLOCK, KCOTRYLOCK, KCONOREPAIR,

  # General functions
  kcfree,

  # DB functions
  kcdbnew, kcdbdel, kcdbopen, kcdbclose, kcdbecode, kcdbemsg, kcdbset, kcdbget,
  kcdbcursor, kcdbcount, kcdbcheck, kcdbclear, kcdbremove, kcdbseize,
  kcdbpath, kcdbcas,
  kcdbsetbulk, kcdbremovebulk,

  # Cursor functions
  kccurdel, kccurjump, kccurstep, kccurget, kccurecode, kccuremsg, kccurdb

using Base.Libc

# C API types
KCDBPtr = Ptr{Cvoid}
KCCURPtr = Ptr{Cvoid}

struct KCSTR
  buf::Cstring
  size::Csize_t

  KCSTR(buf::Cstring, size::Csize_t) = malloc(buf, size)
  KCSTR(buf, size) = malloc(convert(Cstring, buf), convert(Csize_t, size))
  KCSTR(buf::Cstring) = malloc(convert(Cstring, buf), convert(Csize_t, length(buf)))
end

struct KCREC
  key::KCSTR
  value::KCSTR
end

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
const KCOREADER   = convert(UInt, 1 << 0) # open as a reader
const KCOWRITER   = convert(UInt, 1 << 1) # open as a writer
const KCOCREATE   = convert(UInt, 1 << 2) # writer creating
const KCOTRUNCATE = convert(UInt, 1 << 3) # writer truncating
const KCOAUTOTRAN = convert(UInt, 1 << 4) # auto transaction
const KCOAUTOSYNC = convert(UInt, 1 << 5) # auto synchronization
const KCONOLOCK   = convert(UInt, 1 << 6) # open without locking
const KCOTRYLOCK  = convert(UInt, 1 << 7) # lock without blocking
const KCONOREPAIR = convert(UInt, 1 << 8) # open without auto repair

# Release a region allocated in the library.
kcfree(ptr) = ccall((:kcfree, libkyotocabinet), Cvoid, (Ptr{Cvoid},), ptr)

# Create a polymorphic database object.
kcdbnew() = ccall((:kcdbnew, libkyotocabinet), KCDBPtr, ())

# Destroy a database object.
function kcdbdel(db::KCDBPtr)
  ccall((:kcdbdel, libkyotocabinet), Cvoid, (KCDBPtr,), db)
end

# Open a database file.
function kcdbopen(db::KCDBPtr, path, mode)
  ccall((:kcdbopen, libkyotocabinet), Cint, (KCDBPtr, Cstring, Cuint), db, path, mode)
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
  ccall((:kcdbemsg, libkyotocabinet), Cstring, (KCDBPtr,), db)
end

# Set the value of a record.
function kcdbset(db::KCDBPtr, kbuf, ksize, vbuf, vsize)
  ccall((:kcdbset, libkyotocabinet), Cint, (KCDBPtr, Cstring, Cuint, Cstring, Cuint),
    db, kbuf, ksize, vbuf, vsize)
end

# Retrieve the value of a record.
function kcdbget(db::KCDBPtr, kbuf, ksize, vsize)
  ccall((:kcdbget, libkyotocabinet), Cstring, (KCDBPtr, Cstring, Cuint, Ptr{Cuint}),
    db, kbuf, ksize, vsize)
end

# Check the existence of a record.
function kcdbcheck(db::KCDBPtr, kbuf, ksize)
  ccall((:kcdbcheck, libkyotocabinet), Cint, (KCDBPtr, Cstring, Csize_t),
    db, kbuf, ksize)
end

# Get the number of records.
function kcdbcount(db::KCDBPtr)
  ccall((:kcdbcount, libkyotocabinet), Clonglong, (KCDBPtr,), db)
end

# Remove all records.
function kcdbclear(db::KCDBPtr)
  ccall((:kcdbclear, libkyotocabinet), Cint, (KCDBPtr,), db)
end

# Remove a record.
function kcdbremove(db::KCDBPtr, kbuf, ksize)
  ccall((:kcdbremove, libkyotocabinet), Cint, (KCDBPtr, Cstring, Csize_t),
    db, kbuf, ksize)
end

# Retrieve the value of a record and remove it atomically.
function kcdbseize(db::KCDBPtr, kbuf, ksize, vsize)
  ccall((:kcdbseize, libkyotocabinet), Cstring, (KCDBPtr, Cstring, Cuint, Ptr{Cuint}),
    db, kbuf, ksize, vsize)
end

# Get the path of the database file.
function kcdbpath(db::KCDBPtr)
  ccall((:kcdbpath, libkyotocabinet), Cstring, (KCDBPtr,), db)
end

# Perform compare-and-swap.
function kcdbcas(db::KCDBPtr, kbuf, ksize, ovbuf, ovsize, nvbuf, nvsize)
  ccall((:kcdbcas, libkyotocabinet), Cint,
    (KCDBPtr, Cstring, Csize_t, Cstring, Csize_t, Cstring, Csize_t),
    db, kbuf, ksize, ovbuf, ovsize, nvbuf, nvsize)
end

# Store records at once.
function kcdbsetbulk(db::KCDBPtr, recs, rnum, atomic)
  ccall((:kcdbsetbulk, libkyotocabinet), Int64,
    (KCDBPtr, Ptr{KCREC}, Csize_t, Cint),
    db, convert(Ptr{KCREC}, pointer(recs)), rnum, atomic)
end

# Remove records at once.
function kcdbremovebulk(db::KCDBPtr, keys, knum, atomic)
  ccall((:kcdbremovebulk, libkyotocabinet), Int64,
    (KCDBPtr, Ptr{KCSTR}, Csize_t, Cint),
    db, convert(Ptr{KCSTR}, pointer(keys)), knum, atomic)
end

# Create a polymorphic cursor object.
function kcdbcursor(db::KCDBPtr)
  ccall((:kcdbcursor, libkyotocabinet), KCCURPtr, (KCDBPtr,), db)
end

# Destroy a cursor object.
function kccurdel(cursor::KCCURPtr)
  ccall((:kccurdel, libkyotocabinet), Cvoid, (KCCURPtr,), cursor)
end

# Get a pair of the key and the value of the current record.
function kccurget(cursor::KCCURPtr, ksize, v, vsize, step)
  ccall((:kccurget, libkyotocabinet), Cstring,
    (KCCURPtr, Ptr{Cuint}, Ptr{Cstring}, Ptr{Cuint}, Cint),
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
  ccall((:kccuremsg, libkyotocabinet), Cstring, (KCCURPtr,), cursor)
end

end # module c
