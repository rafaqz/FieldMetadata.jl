using FieldMetadata, Parameters, Test, Markdown, REPL

abstract type AbstractTest end

import FieldMetadata: @description, description

@metadata paramrange [0, 1]

@description mutable struct Described{P}
   a::Int | "an Int"
   b      | "an untyped field"
   c::P   | "a parametric field"
   "An inner constructor should work, even with a docstring"
   Described(a, b, c) = begin
       new{typeof(c)}(a, b, c)
   end
   function Described(a, b)
       new{Nothing}(a, b, nothing)
   end
end

@test length(methods(Described).ms) == 2
@test length(methods(description).ms) == 12

d = Described(1, 1.0, nothing)
@test typeof(d) == typeof(Described(1, 1.0))

@test description(d, :a) == "an Int"
@test description(Described, Val{:a}) == "an Int"
@test description(Described, :a) == "an Int"
@test description(d, Val{:a}) == "an Int"
@test description(typeof(d), :b) == "an untyped field"
@test description(typeof(d), :c) == "a parametric field"
@test description(d) == ("an Int", "an untyped field", "a parametric field")

@test description(d, :d) == ""
@test description(d, Val{:d}) == ""
@test description(Described, Val{:d}) == ""
@test description(Described, :d) == ""

@inferred description(d, :a)
@inferred description(Described, Val{:a})
@inferred description(Described, :a)
@inferred description(d, Val{:a})
@inferred description(typeof(d), :b)
@inferred description(d, :c)
@inferred description(d, Val{:c})
@inferred description(Described, Val{:c})
@inferred description(Described, :c)
@inferred description(d)

ex = :(@some @arbitrary @macros struct TestMacros{T}
        a::T | u"1"
        b::T | u"2"
    end)
@test FieldMetadata.chained_macros(ex) == [Symbol("@some"), Symbol("@arbitrary"), Symbol("@macros")]

# range array
@paramrange struct WithRange <: AbstractTest
    a::Int | [1, 4]
    b::Int | [4, 9]
end

w = WithRange(2,5)
@test paramrange(w, :a) == [1, 4]
@test paramrange(w, :b) == [4, 9]
@test paramrange(w) == ([1, 4], [4, 9])


# combinations of metadata
@paramrange @description struct Combined{T} <: AbstractTest
    a::T | [1, 4] | "an Int with a range and a description"
    b::T | _      | "a Float with a range and a description"
end

c = Combined(3,5)
@test description(typeof(c), :a) == "an Int with a range and a description"
@test description(c, :b) == "a Float with a range and a description"
@test paramrange(typeof(c), :a) == [1, 4]
@test paramrange(c, :b) == [0, 1]
description(c, Val{:a})


# with Parameters.jl keywords
@paramrange @description @with_kw struct Keyword{T} <: AbstractTest
    a::T = 3 | [0, 100] | "an Int with a range and a description"
    b::T = 5 | [2, 9]   | "a Float with a range and a description"
end

k = Keyword()
@test paramrange(k, :a) == [0, 100]
@test description(k, :b) == "a Float with a range and a description"
@test k.a == 3
@test k.b == 5


# with missing keywords
@paramrange @description @with_kw struct MissingKeyword{T} <: AbstractTest
    a    = 3 | [0, 100] | "an Int with a range and a description"
    b::T     | [2, 9]   | "a Float with a range and a description"
    MissingKeyword{T}(a::T, b::T) where T = new{T}(a, b)
end

m = MissingKeyword(b = 99)
@test paramrange(m, :a) == [0, 100]
@test description(m, :b) == "a Float with a range and a description"
@test m.a == 3
@test m.b == 99
@test paramrange(m) == ([0, 100], [2, 9])

@metadata default nothing

@default @description @paramrange Described begin 
    a | 1 | "a description updated in a begin block" | [22,33]
    b | 2 | "another updated description"            | [-8,-9]
end

@test paramrange(d, :a) == [22,33]
@test paramrange(d, :b) == [-8,-9]
@test description(d, :a) == "a description updated in a begin block"
@test description(d, :b) == "another updated description"

# Now eval in all the values
def_a = 3
def_b = 4
desc_a = "interpolated string a"
desc_b = "interpolated string b"
vec_a = [0, 0]
vec_b = [1, 1]

@eval   @default   @description   @paramrange :($(typeof(d))) begin 
    a | $def_a   | $desc_a      | $vec_a
    b | $def_b   | $desc_b      | $vec_b
end

@test default(d, :a) == 3
@test default(d, :b) == 4
@test paramrange(d, :a) == [0, 0]
@test paramrange(d, :b) == [1, 1]
@test description(d, :a) == "interpolated string a"
@test description(d, :b) == "interpolated string b"

def_a = 44
@test default(d, :a) == 3

# docstrings
"The Docs"
@paramrange mutable struct Documented
    "Foo"
    a::Int     | [1,2]
    "Bar"
    b::Float64 | [3,4]
end

@test paramrange(Documented) == ([1,2], [3,4])

@test "The Docs\n" == Markdown.plain(REPL.doc(Documented))
@test "Foo\n" == Markdown.plain(REPL.fielddoc(Documented, :a))
@test "Bar\n" == Markdown.plain(REPL.fielddoc(Documented, :b))


# chaining macros

@chain columns @description @paramrange 

@columns Described begin
    a::T | "a new Int description"     | [99,100]
    b::T | "a new Float64 description" | [-3,-4]
end

@test description(Described) == ("a new Int description", "a new Float64 description", "a parametric field")
