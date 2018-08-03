# MetaFields

[![Build Status](https://travis-ci.org/rafaqz/MetaFields.jl.svg?branch=master)](https://travis-ci.org/rafaqz/MetaFields.jl)
[![Coverage Status](https://coveralls.io/repos/rafaqz/MetaFields.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/rafaqz/MetaFields.jl?branch=master)

This package allows defining metadata for fields in a struct, similar to tags in go. But named and infinitely
extensible.

They use a similar syntax to Parameters.jl, with a `|` bar instead of
`=`. You can, in fact, use it as a replacement for Parameters.jl with the aid of 
[Defaults.jl](https://github.com/rafaqz/Defaults.jl).

```julia
@metafield describe ""

@describe mutable struct Described
   a::Int     | "an Int with a description"  
   b::Float64 | "a Float with a description"
end

d = Described(1, 1.0)

julia>describe(d, :a) 
"an Int with a description"  

julia>describe(d, :b) 
"a Float with a description"  

julia>describe(d, :c) 
""  
```

A more complex example :

```julia
using Parameters
@metafield describe ""
@metafield paramrange [0, 1]

@describe @paramrange @with_kw struct Keyword{T}
    a::T = 3 | [0, 100] | "a field with a range, description and default"
    b::T = 5 | [2, 9]   | "another field with a range, description and default"
end

k = Keyword()

julia> describe(k, :b) 
"another field with a range, description and default"

julia> paramrange(k, :a) 
[0, 100]
""  
```

You can chain as many metafields together as you want. 

Just remember that the data for the first `@metafield` macro
goes at the end on the line in the struct. This makes sense when you consider that @with_kw
from Parameters.jl has to be the last macro, but the first item in the row after
the field type.

You can also update or add fields on a type that is already declared using the
same syntax, but you don't need to include all fields, or even their types.
