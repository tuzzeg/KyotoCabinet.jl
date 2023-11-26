using Test

import Base: ==

using KyotoCabinet

struct Key
  x::Int
end

struct Val
  a::Int
  b::String
end

==(x::Key, y::Key) = x.x == y.x
==(x::Val, y::Val) = (x.a == y.a) && (x.b == y.b)

KyotoCabinet.pack(v::String)::Bytes = Bytes(v)
KyotoCabinet.unpack(String, buf::Bytes) = String(buf)

function KyotoCabinet.pack(k::Key)::Bytes
  io = IOBuffer()
  write(io, convert(Int32, k.x))
  take!(io)
end

function KyotoCabinet.unpack(Key, buf::Bytes)::Key
  io = IOBuffer(buf)
  x = read(io, Int32)
  Key(convert(Int, x))
end

function KyotoCabinet.pack(v::Val)::Bytes
  io = IOBuffer()
  write(io, convert(Int32, v.a))
  write(io, v.b)
  take!(io)
end

function KyotoCabinet.unpack(Val, buf::Bytes)::Val
  io = IOBuffer(buf)
  a = read(io, Int32)
  b = read(io, String)
  Val(a,b)
end

tempdb() = tempname() * ".kch"

@testset "get_set" begin
  file = tempdb()
  open(Db{Key, Val}(), file, "w+") do db
    db[Key(1)] = Val(1, "a")
    db[Key(1999999999)] = Val(2, repeat("b",100))
  end
  open(Db{Key, Val}(), file, "r") do db
    @test Val(1, "a") == db[Key(1)]
    @test Val(2, repeat("b",100)) == db[Key(1999999999)]
  end
end

@testset "iter" begin
    file = tempdb()
    open(Db{Key, Val}(), file, "w+") do db
        db[Key(1)] = Val(1, "a")
        db[Key(1999999999)] = Val(2, repeat("b",100))
    end
    open(Db{Key, Val}(), file, "r") do db
        for (k,v) in db
            println(k, "=", v)
        end
        # s0 = start(db)
        # kv, s0 = next(db, s0)
        # @test K(1) == kv[1]
        # @test V(1, "a") == kv[2]

        # kv, s0 = next(db, s0)
        # @test K(1999999999) == kv[1]
        # @test V(2, repeat("b", 100)) == kv[2]
    end
end

tempdb() = tempname() * ".kch"
