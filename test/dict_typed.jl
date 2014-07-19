using Base.Test

import Base: ==

require("src/kyotocabinet.jl")
using kyotocabinet

immutable K
  x::Int
end

immutable V
  a::Int
  b::String
end

==(x::K, y::K) = x.x == y.x
==(x::V, y::V) = (x.a == y.a) && (x.b == y.b)

kyotocabinet.pack(v::ASCIIString) = convert(Array{Uint8,1}, v)
kyotocabinet.unpack(T::Type{ASCIIString}, buf::Array{Uint8,1}) = bytestring(buf)

function kyotocabinet.pack(k::K)
  io = IOBuffer()
  write(io, int32(k.x))
  takebuf_array(io)
end
function kyotocabinet.unpack(T::Type{K}, buf::Array{Uint8,1})
  io = IOBuffer(buf)
  x = read(io, Int32)
  K(int(x))
end

function kyotocabinet.pack(v::V)
  io = IOBuffer()
  write(io, int32(v.a))
  write(io, int32(length(v.b)))
  write(io, v.b)
  takebuf_array(io)
end
function kyotocabinet.unpack(T::Type{V}, buf::Array{Uint8,1})
  io = IOBuffer(buf)
  a = read(io, Int32)
  l = read(io, Int32)
  b = bytestring(read(io, Uint8, l))
  V(int(a), b)
end

function test_get_set()
  file = tempdb()
  open(Db{K, V}(), file, "w+") do db
    db[K(1)] = V(1, "a")
    db[K(1999999999)] = V(2, repeat("b",100))
  end
  open(Db{K, V}(), file, "r") do db
    @assert V(1, "a") == db[K(1)]
    @assert V(2, repeat("b",100)) == db[K(1999999999)]
  end
end

function test_iter()
  file = tempdb()
  open(Db{K, V}(), file, "w+") do db
    db[K(1)] = V(1, "a")
    db[K(1999999999)] = V(2, repeat("b",100))
  end
  open(Db{K, V}(), file, "r") do db
    s0 = start(db)
    kv, s0 = next(db, s0)
    @assert K(1) == kv[1]
    @assert V(1, "a") == kv[2]

    kv, s0 = next(db, s0)
    @assert K(1999999999) == kv[1]
    @assert V(2, repeat("b", 100)) == kv[2]
  end
end

tempdb() = tempname() * ".kch"

# test_get_set()
test_iter()
