# FieldMetadata

[![Build Status](https://travis-ci.org/rafaqz/FieldMetadata.jl.svg?branch=master)](https://travis-ci.org/rafaqz/FieldMetadata.jl)
[![codecov.io](http://codecov.io/github/rafaqz/FieldMetadata.jl/coverage.svg?branch=master)](http://codecov.io/github/rafaqz/FieldMetadata.jl?branch=master)

This package lets you define metadata about fields in a struct, like tags
in Go. It uses a similar syntax to Parameters.jl, with a `|` bar instead of `=`.
You can use it as a minimalist replacement for Parameters.jl with the aid of
[FieldDefaults.jl](https://github.com/rafaqz/FieldDefaults.jl).

FieldMetadata on nested structs can be flattened into a vector or tuple very efficiently with [Flatten.jl](https://github.com/rafaqz/Flatten.jl), where they are also used to 
exclude fields from flattening.

__NOTIFICATION:__ There have been major syntax changes for v0.2. Read the
examples below for the new syntax.


This example that adds string description metadata to fields in a struct:

```julia
using FieldMetadata
@metadata describe ""

@describe mutable struct Described
   a::Int     | "an Int with a description"  
   b::Float64 | "a Float with a description"
end

d = Described(1, 1.0)

julia> describe(d, :a) 
"an Int with a description"  

julia> describe(d, :b) 
"a Float with a description"  

julia> describe(d, :c) 
""  
```

A more complex example. Here we type-check metadata for `describe` to be 
`String` and `bounds` to be `Tuple`, by passing an extra argument to the macro:

```julia
using Parameters
@metadata describe "" String
@metadata bounds (0, 1) Tuple

@bounds @describe @with_kw struct WithKeyword{T}
    a::T = 3 | (0, 100) | "a field with a range, description and default"
    b::T = 5 | (2, 9)   | "another field with a range, description and default"
end

k = WithKeyword()

julia> describe(k, :b) 
"another field with a range, description and default"

julia> bounds(k, :a) 
(0, 100)
""  
```

You can chain as many metadata macros together as you want. As of
FieldMetadata.jl v0.2, macros are written in the same order as the metadata
columns, as opposed to the opposite order which was the syntax in v0.1

However, @with_kw from Parameters.jl must be the last macro and the first field, 
if it is used.

You can also update or add fields on a type that is already declared using a
`begin` block syntax. You don't need to include all fields or their types.

This is another change from the syntax in v0.1, where `@re` was prepended
to update using the same struct syntax.

```julia
julia> describe(d)                                                                                                     
("an Int with a description", "a Float with a description")  

@describe Described begin
   b | "a much better description"
end

julia> d = Described(1, 1.0)

julia> describe(d)
("an Int with a description", "a much better description")
```

We can use `typeof(x)` and a little meta-programming instead of the type name, 
which can be useful for anonymous function parameters:

```
@describe :($(typeof(d))) begin
   a | "a description without using the type"
end

julia> describe(d)
("a description without using the type", "a much better desc ription")
```


# Metadata placeholders

FieldMetadata provides an api of some simple metadata tags to be used across
packages: 

| Metadata    | Default     | Type           | Use case                                        |
| ----------- | ----------- | -------------- | ----------------------------------------------- |
| default     | nothing     | Any            | Default values (see FieldDefaults.jl)           |
| units       | 1           | Any            | Unitful.jl unit                                 |
| prior       | nothing     | Any            | Prior probability distributions                 |
| label       | ""          | AbstractString | Short labels                                    |
| description | ""          | AbstractString | Complete descriptions                           |
| bounds      | (0.0, 1.0)  | Tuple          | Upper and lower bounds in optimisers            |
| limits      | (0.0, 1.0)  | Tuple          | Legacy - use `bounds`                           |
| logscaled   | false       | Bool           | For log sliders or log plots                    |
| flattenable | true        | Bool           | For flattening structs with Flatten.jl          |
| plottable   | true        | Bool           | For finding plottable content in nested structs |
| selectable  | Nothing     | Bool           | Supertypes to select child constructors from    |

To use them, call:

```julia
import FieldMetadata: @prior, prior
```

You _must_ `import` at least the function to use these placeholders, `using` is
not enough as you are effectively adding methods for you own types. 

Calling `@prior` or similar on someone else's struct may be type piracy and
shouldn't be done in a published package unless the macro is also defined there.
However, it can be useful in scripts.
