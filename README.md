# Julia binding for KyotoCabinet

[![Build Status](https://travis-ci.org/tuzzeg/kyotocabinet.jl.svg)](https://travis-ci.org/tuzzeg/kyotocabinet.jl)

This package provides bindings for [KyotoCabinet](http://fallabs.com/kyotocabinet) key-value storage.

## Installation

```julia
Pkg.add("kyotocabinet")
```

## Usage

```julia
using kyotocabinet
```

To open database, use `open` method:
```julia
db = open("db.kch", KCOREADER)
close(db)
```

There is also bracketed version:

```julia
open("db.kch", KCOWRITER | KCOCREATE) do db
  # do stuff...
end
```

`Db` object implements basic collections and `Dict` methods.

```julia
open("db.kch", KCOWRITER | KCOCREATE) do db
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

To iterate through records, use `Cursor` object:

```julia
open("db.kch", KCOREADER) do db
  cur = Cursor(db)
  for (k, v) = cur
    println("k=$k v=$v")
  end
  close(cur)
end
```

There are also [KyotoCabinet](http://fallabs.com/kyotocabinet) specific methods.

**`cas(db::Db, key, old, new)`**

Compare-and-swap method. Update the value only if it's in the expected state.
Returns `true` if value have been updated.

```julia
cas(db, "k", "old", "new") # update only if db["k"] == "old"
cas(db, "k", "old", ())    # remove record, only if db["k"] == "old"
cas(db, "k", (), "new")    # add record, only if "k" not in db
```

**`bulkset!(db::Db, kvs::Dict, atomic)`**

Updates records in one operation, atomically if needed.

```julia
bulkset!(db, ["a" => "1", "b" => "2"], true)
```

**`bulkdelete!(db::Db, keys, atomic)`**

Removes records in one operation, atomically if needed.

```julia
bulkdelete!(db, ["a", "b"], true)
```
