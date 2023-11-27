# Julia binding for KyotoCabinet

[![Build Status](https://travis-ci.org/tuzzeg/KyotoCabinet.jl.svg)](https://travis-ci.org/tuzzeg/KyotoCabinet.jl)

This package provides bindings for [KyotoCabinet](http://fallabs.com/kyotocabinet) key-value storage.

## Installation

```julia
Pkg.add("KyotoCabinet")
```

## Generic interface

```julia
using KyotoCabinet
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

import Base

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
for (k, v) in db
  println("k=$k v=$v")
end
for k in keys(db)
  println("k=$k")
end
```

## Serialization/Deserialization
[KyotoCabinet](http://fallabs.com/kyotocabinet) treats keys and values as byte arrays.
To make it work with arbitrary types, one needs to define
```Base.convert(t::Type{<your type>}, v::Bytes)::<your type> ``` and
```Base.convert(t::Type{Bytes>}, v::<your type>)::Bytes ```
methods.

```julia
struct Key
  x::Int
end

struct Val
  a::Int
  b::String
end

function KyotoCabinet.pack(k::Key)::Bytes
  io = IOBuffer()
  write(io, convert(Int32, k.x))
  take!(io)
end

function KyotoCabinet.unpack(k::Type{Key}, buf::Bytes)::Key
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

function KyotoCabinet.unpack(v::Type{Val}, buf::Bytes)::Val
  io = IOBuffer(buf)
  a = read(io, Int32)
  b = read(io, String)
  Val(a,b)
end
```

After that these types can be used as keys/values:

```julia
open(Db{Key, Val}(), "db.kch", "w+") do db
  db[Key(1)] = Val(1, "a")
  db[Key(1999999999)] = Val(2, repeat("b",100))
end

k = Key(1)
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

[![Build Status](https://github.com/eugeneai/KyotoCabinet.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/eugeneai/KyotoCabinet.jl/actions/workflows/CI.yml?query=branch%3Amaster)
