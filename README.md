# FieldMetadata

[![Build Status](https://travis-ci.org/rafaqz/FieldMetadata.jl.svg?branch=master)](https://travis-ci.org/rafaqz/FieldMetadata.jl)
[![Coverage Status](https://coveralls.io/repos/rafaqz/FieldMetadata.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/rafaqz/FieldMetadata.jl?branch=master)
[![codecov.io](http://codecov.io/github/rafaqz/FieldMetadata.jl/coverage.svg?branch=master)](http://codecov.io/github/rafaqz/FieldMetadata.jl?branch=master)

This package lets you define metadata about fields in a struct, like tags
in Go. It uses a similar syntax to Parameters.jl, with a `|` bar instead of `=`.
You can use it as a minimalist replacement for Parameters.jl with the aid of
[Defaults.jl](https://github.com/rafaqz/Defaults.jl).

FieldMetadata on nested structs can be flattened into a vector or tuple very efficiently with [Flatten.jl](https://github.com/rafaqz/Flatten.jl), where they are also used to 
exclude fields from flattening.

This example that adds string description metadata to fields in a struct:

```julia
@metadata describe ""

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
@metadata describe ""
@metadata limits (0, 1)

@describe @limits @with_kw struct WithKeyword{T}
    a::T = 3 | (0, 100) | "a field with a range, description and default"
    b::T = 5 | (2, 9)   | "another field with a range, description and default"
end

k = WithKeyword()

julia> describe(k, :b) 
"another field with a range, description and default"

julia> paramrange(k, :a) 
[0, 100]
""  
```

You can chain as many metadata macros together as you want. Just remember that 
the data for the first `@metadata` macro goes at the end on the
line in the struct. This makes sense when you consider that a macro like
@with_kw from Parameters.jl has to be the last macro, but the first item in the
row after the field type.

You can also update or add fields on a type that is already declared using the
same syntax, by prepending `re` to the start of the macro, like `@redescribe`.
You don't need to include all fields or their types.

```julia
julia> describe(d)                                                                                                     
("an Int with a description", "a Float with a description")  

@redescribe struct Described
   b | "a much better description"
end

julia> d = Described(1, 1.0)

julia> describe(d)
("an Int with a description", "a much better description")
```


# Metadata placeholders

FieldMetadata provides an api of some simple metadata tags to be used across
packages: 

| Metadata    | Default     |
| ----------- | ----------- |
| default     | : nothing   |
| units       | 1           |
| prior       | nothing     |
| description | ""          |
| limits      | (1e-7, 1.0) |
| label       | ""          |
| logscaled   | false       |
| flattenable | true        |
| plottable   | true        |
| selectable  | Nothing     |

To use them, call:

```julia
import FieldMetadata: @prior, @reprior, prior
```

You _must_ `import` at least the function to use these placeholders, `using` is
not enough as you are effectively adding methods for you own types. Calling
`@reprior` or similar on someone elses struct is type piracy and shouldn't be
done in a published package, but can be useful in scripts.
