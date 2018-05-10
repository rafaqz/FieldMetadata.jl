# MetaParameters

[![Build Status](https://travis-ci.org/rafaqz/MetaParameters.jl.svg?branch=master)](https://travis-ci.org/rafaqz/MetaParameters.jl)
[![Coverage Status](https://coveralls.io/repos/rafaqz/MetaParameters.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/rafaqz/MetaParameters.jl?branch=master)

This package allows defining metadata that relate to parameters that are fields
in a struct, using a similar syntax to Parameters.jl, with a `|` bar instead of
`=`.


```juliarepl
@metaparam description ""

@description mutable struct Described
   a::Int     | "an Int with a description"  
   b::Float64 | "a Float with a description"
end

d = Described(1, 1.0)

julia>description(d, :a) 
"an Int with a description"  

julia>description(d, :b) 
"a Float with a description"  

julia>description(d, :c) 
""  
```

A more complex example :

```juliarepl
using Parameters
@metaparam description ""
@metaparam paramrange [0, 1]

@description @paramrange @with_kw struct Keyword{T}
    a::T = 3 | [0, 100] | "a parameter with a range, description and default"
    b::T = 5 | [2, 9]   | "another parameter with a range, description and default"
end

k = Keyword()

julia> description(k, :a) 
"another parameter with a range, description and default"

julia> paramrange(k, :a) 
[0, 100]
""  
```

You chain as many metaparams together as you want. The data for the first `@metaparam` macro
goes at the end on the line in the struct! This makes sense when you consider that @with_kw
from Parameters.jl has to be the last macro, but the first item in the row after
the field type.
