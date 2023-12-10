module c

include("../deps/deps.jl")

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

Bytes = Array{UInt8,1}

struct KCSTR
    buf::Bytes
    size::Csize_t

    #KCSTR(buf::Cstring, size::Csize_t) = new(buf, size)
    #KCSTR(buf, size) = new(convert(Cstring, buf), convert(Csize_t, size))
    #KCSTR(buf::Cstring) = new(convert(Cstring, buf), convert(Csize_t, length(buf)))

    KCSTR(buf::Bytes, size::Csize_t) = new(buf, size)
    KCSTR(buf, size) = new(convert(Bytes, buf), convert(Csize_t, size))
    KCSTR(buf::Bytes) = new(convert(Bytes, buf), convert(Csize_t, length(buf)))
    # finalizer(self) do bufdef
    #     if bufdef.buf == C_NULL
    #         bufdef.size = 0
    #         return
    #     end
    #     free(bufdef.buf)
    #     bufdef.buf = C_NULL
    #     bufdef.size = 0
    # end
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
function kcfree(ptr::Ptr{UInt8})::Nothing
    ccall((:kcfree, libkyotocabinet), Cvoid, (Ptr{Cvoid},), ptr)
    nothing
end

function kcfree(ptr::Cstring)::Nothing
    ccall((:kcfree, libkyotocabinet), Cvoid, (Cstring,), ptr)
    nothing
end

# Create a polymorphic database object.
kcdbnew() = ccall((:kcdbnew, libkyotocabinet), KCDBPtr, ())

# Destroy a database object.
function kcdbdel(db::KCDBPtr)::Nothing
  ccall((:kcdbdel, libkyotocabinet), Cvoid, (KCDBPtr,), db)
end

# Open a database file.
function kcdbopen(db::KCDBPtr, path::AbstractString, mode::UInt)::Bool
    ccall((:kcdbopen, libkyotocabinet), Cint, (KCDBPtr, Cstring, Cuint), db, path, mode)
end

# Close the database file.
function kcdbclose(db::KCDBPtr)::Bool
    ccall((:kcdbclose, libkyotocabinet), Cint, (KCDBPtr,), db)
end

# Get the code of the last happened error.
function kcdbecode(db::KCDBPtr)::Int32
    ccall((:kcdbecode, libkyotocabinet), Cint, (KCDBPtr,), db)
end

# Get the supplement message of the last happened error.
function kcdbemsg(db::KCDBPtr)::Cstring
    ccall((:kcdbemsg, libkyotocabinet), Cstring, (KCDBPtr,), db)
end

# Set the value of a record.
function kcdbset(db::KCDBPtr, kbuf::Ptr{UInt8}, ksize::Int, vbuf::Ptr{UInt8}, vsize::Int)::Bool
    ccall((:kcdbset, libkyotocabinet), Cint, (KCDBPtr, Cstring, Cuint, Cstring, Cuint),
          db, kbuf, ksize, vbuf, vsize)
end

# Retrieve the value of a record.
function kcdbget(db::KCDBPtr, kbuf, ksize::Int, vsizePtr::Ptr{Csize_t})::Ptr{UInt8}
    ccall((:kcdbget, libkyotocabinet), Ptr{UInt8}, (KCDBPtr, Cstring, Cuint, Ptr{Csize_t}),
          db, kbuf, ksize, vsizePtr)
end

# Check the existence of a record.
function kcdbcheck(db::KCDBPtr, kbuf::Ptr{UInt8}, ksize::Int)::Int32
  ccall((:kcdbcheck, libkyotocabinet), Cint, (KCDBPtr, Cstring, Csize_t),
    db, kbuf, ksize)
end

# Get the number of records.
function kcdbcount(db::KCDBPtr)::Int64
  ccall((:kcdbcount, libkyotocabinet), Clonglong, (KCDBPtr,), db)
end

# Remove all records.
function kcdbclear(db::KCDBPtr)::Bool
  ccall((:kcdbclear, libkyotocabinet), Cint, (KCDBPtr,), db)
end

# Remove a record.
function kcdbremove(db::KCDBPtr, kbuf, ksize::Int)::Bool
  ccall((:kcdbremove, libkyotocabinet), Cint, (KCDBPtr, Cstring, Csize_t),
    db, kbuf, ksize)
end

# Retrieve the value of a record and remove it atomically.
function kcdbseize(db::KCDBPtr, kbuf, ksize::Int, vsize::Ptr{Csize_t})::Ptr{UInt8}
  ccall((:kcdbseize, libkyotocabinet), Ptr{UInt8}, (KCDBPtr, Cstring, Cuint, Ptr{Csize_t}),
    db, kbuf, ksize, vsize)
end

# Get the path of the database file.
function kcdbpath(db::KCDBPtr)::Cstring
  ccall((:kcdbpath, libkyotocabinet), Cstring, (KCDBPtr,), db)
end

# Perform compare-and-swap.
function kcdbcas(db::KCDBPtr, kbuf, ksize::Int, ovbuf, ovsize::Int,
                 nvbuf, nvsize::Int)::Bool
    i = ccall((:kcdbcas, libkyotocabinet), Cint,
              (KCDBPtr, Cstring, Csize_t, Cstring, Csize_t, Cstring, Csize_t),
              db, kbuf, ksize, ovbuf, ovsize, nvbuf, nvsize)
end

# Store records at once.
function kcdbsetbulk(db::KCDBPtr, recs, rnum::Int, atomic::Int)::Int64
  ccall((:kcdbsetbulk, libkyotocabinet), Int64,
    (KCDBPtr, Ptr{UInt}, Csize_t, Cint),
    db, recs, rnum, atomic)
end

# Remove records at once.
function kcdbremovebulk(db::KCDBPtr, keys, knum::Int, atomic::Int)
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
function kccurget(cursor::KCCURPtr, ksize::Ptr{Csize_t}, v::Ptr{Ptr{UInt8}}, vsize::Ptr{Csize_t}, step::Int)
  ccall((:kccurget, libkyotocabinet), Ptr{UInt8}, # Cstring,
    (KCCURPtr, Ptr{Csize_t}, Ptr{Ptr{UInt8}}, Ptr{Csize_t}, Cint),
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
