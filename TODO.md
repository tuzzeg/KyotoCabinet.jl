- Iterator methods for cursor
- Tests

- Implement
-- Iterable
start(iter) :: state
done(iter, state) :: Bool
next(iter, state) :: item, state

-- Collection
isempty(collection) :: Bool
length(collection) :: Integer
empty!(collection)

-- Associative

-- Indexed collection
getindex(t, k)
setindex!(t, v, k)

-- Dict interface
haskey(collection, key)
get(collection, key, default)
get(f::Function, collection, key)
get!(collection, key, default)
get!(f::Function, collection, key)

getkey(collection, key, default)
delete!(collection, key)
pop!(collection, key[, default])
keys(collection)
values(collection)

# merge(collection, others...)
merge!(collection, others...)

# KyotoCabinet specific
cas
bulk (get, set, remove)

# Immutable structures?
