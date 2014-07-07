# Julia binding for KyotoCabinet

[![Build Status](https://travis-ci.org/tuzzeg/kyotocabinet.jl.svg)](https://travis-ci.org/tuzzeg/kyotocabinet.jl)

This package provides bindings for [KyotoCabinet](http://fallabs.com/kyotocabinet) key-value storage.

## Installation

```julia
Pkg.add("kyotocabinet")
```

## Generic interface

```julia
using kyotocabinet
```

To open database, use `open` method:
```julia
db = open("db.kch", "r")
# db::Dict{Array{Uint8,1},Array{Uint8,1}}
close(db)
```

There is also bracketed version:

```julia
open(Db{K,V}(), "db.kch", "w+") do db
  # db::Dict{K,V}
  # do stuff...
end
```

`Db` object implements basic collections and `Dict` methods.

```julia
open(Db{String,String}(), "db.kch", "w+") do db
  # Basic getindex, setindex! methods
  db["a"] = "1"
  println(db["a"])

  # Dict methods also implemented:
  # haskey, getkey, get, get!, delete!, pop!
  if (!haskey(db, "x"))
    x = get(db, "x", "default")
    y = get!(db, "y", "set_value_if_non_exists")
  end
end
```

Support iteration over records, keys and values:

```julia
for (k, v) = db
  println("k=$k v=$v")
end
for k = keys(db)
  println("k=$k")
end
```

## Serialization/Deserialization
[KyotoCabinet](http://fallabs.com/kyotocabinet) treats keys and values as byte arrays.
To make it work with arbitrary types, one needs to define pack/unpack methods.

```julia
immutable K
  x::Int
end

immutable V
  a::Int
  b::String
end

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
```

After that these types can be used as keys/values:

```julia
open(Db{K, V}(), "db.kch", "w+") do db
  db[K(1)] = V(1, "a")
  db[K(1999999999)] = V(2, repeat("b",100))
end

k = K(1)
println(db[k])
```

## KyotoCabinet specific
There are also [KyotoCabinet](http://fallabs.com/kyotocabinet) specific methods.

### Database info

```julia
# Get the path of the database file
p = path(db)
```

### Compare-and-swap

`cas(db::Db, key, old, new)`

Compare-and-swap method. Update the value only if it's in the expected state.
Returns `true` if value have been updated.

```julia
cas(db, "k", "old", "new") # update only if db["k"] == "old"
cas(db, "k", "old", ())    # remove record, only if db["k"] == "old"
cas(db, "k", (), "new")    # add record, only if "k" not in db
```

### Bulk operations

```julia
# Updates records in one operation, atomically if needed.
bulkset!(db, ["a" => "1", "b" => "2"], true)

# Removes records in one operation, atomically if needed.
bulkdelete!(db, ["a", "b"], true)
```
