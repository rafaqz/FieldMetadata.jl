using Revise
using MetaFields
using Parameters
using Base.Test

abstract type AbstractTest end
@metafield paramrange [0, 1]
@metafield description "default"

@description mutable struct Described
   a::Int     | "an Int"  
   b::Float64 | "a Float"
   c          | "an untyped field"
   "An inner constructor should work, even with a docstring"
   Described(a, b, c) = begin
       new(a, b, c)
   end
end

d = Described(1, 1.0, nothing)
@test description(d, :a) == "an Int"  
@test description(Described, Val{:a}) == "an Int"  
@test description(Described, :a) == "an Int"  
@test description(d, Val{:a}) == "an Int"  
@test description(typeof(d), :b) == "a Float"  
@test description(typeof(d), :c) == "an untyped field"  
@test description(d) == ("an Int", "a Float", "an untyped field")

@test description(d, :d) == "default"  
@test description(d, Val{:d}) == "default"  
@test description(Described, Val{:d}) == "default"  
@test description(Described, :d) == "default"  

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


# range array
@paramrange struct WithRange <: AbstractTest
    a::Int | [1, 4]
    b::Int | [4, 9]
end

w = WithRange(2,5)
@test paramrange(w, :a) == [1, 4]
@test paramrange(w, :b) == [4, 9]
@test paramrange(w) == ([1, 4], [4, 9])


# combinations of metafields
@description @paramrange struct Combined{T} <: AbstractTest
    a::T | [1, 4]  | "an Int with a range and a description"
    b::T | _       | "a Float with a range and a description"
end

c = Combined(3,5)
@test description(typeof(c), :a) == "an Int with a range and a description"  
@test description(c, :b) == "a Float with a range and a description"  
@test paramrange(typeof(c), :a) == [1, 4]
@test paramrange(c, :b) == [0, 1]
description(c, Val{:a})


# with Parameters.jl keywords
@description @paramrange @with_kw struct Keyword{T} <: AbstractTest
    a::T = 3 | [0, 100] | "an Int with a range and a description"
    b::T = 5 | [2, 9]   | "a Float with a range and a description"
end

k = Keyword()
@test paramrange(k, :a) == [0, 100]
@test description(k, :b) == "a Float with a range and a description"
@test k.a == 3
@test k.b == 5


# with missing keywords
@description @paramrange @with_kw struct MissingKeyword{T} <: AbstractTest
    a::T = 3 | [0, 100] | "an Int with a range and a description"
    b::T     | [2, 9]   | "a Float with a range and a description"
end

m = MissingKeyword(b = 99)
@test paramrange(m, :a) == [0, 100]
@test description(m, :b) == "a Float with a range and a description"
@test m.a == 3
@test m.b == 99
@test paramrange(m) == ([0, 100], [2, 9])

# docstrings
"The Docs"
@paramrange mutable struct Documented
    "Foo"
    a::Int     | [1,2]
    "Bar"
    b::Float64 | [3,4]
end

@test paramrange(Documented) == ([1,2], [3,4])

if VERSION<v"0.7-"
    @test "The Docs\n" == Markdown.plain(Base.Docs.doc(Documented))
    @test "Foo\n" == Markdown.plain(Base.Docs.fielddoc(Documented, :a))
    @test "Bar\n" == Markdown.plain(Base.Docs.fielddoc(Documented, :b))
else
    @eval using REPL
    @test "The Docs\n" == Markdown.plain(REPL.doc(Documented))
    @test "Foo\n" == Markdown.plain(REPL.fielddoc(Documented, :a))
    @test "Bar\n" == Markdown.plain(REPL.fielddoc(Documented, :b))
end

@redescription mutable struct Described
   a::Int     | "a new Int description"  
   b::Float64 | "a new Float64 description"
end
@test description(d, :a) == "a new Int description"  
@test description(d, :b) == "a new Float64 description"  
@inferred description(d, :a)
@inferred description(d, :b)
