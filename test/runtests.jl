using MetaParameters
using Parameters
using Base.Test

abstract type AbstractTest end
@metaparam paramrange [0,1]
@metaparam description ""

@description mutable struct Described
   a::Int     | "an Int with a description"  
   b::Float64 | "a Float with a description"
end

d = Described(1, 1.0)
@test description(d, :a) == "an Int with a description"  
@test description(d, :b) == "a Float with a description"  
@test description(d, :c) == ""  

@paramrange struct WithRange <: AbstractTest
    a::Int | [1, 4]
    b::Int | [4, 9]
end

w = WithRange(2,5)
@test paramrange(w, :a) == [1, 4]
@test paramrange(w, :b) == [4, 9]

@description @paramrange struct Combined{T} <: AbstractTest
    a::T | [1, 4]  | "an Int with a range and a description"
    b::T | _       | "a Float with a range and a description"
end

c = Combined(3,5)
@test description(c, :a) == "an Int with a range and a description"  
@test description(c, :b) == "a Float with a range and a description"  
@test paramrange(c, :a) == [1, 4]
@test_throws MethodError paramrange(c, :b)

@description @paramrange @with_kw struct Keyword{T} <: AbstractTest
    a::T = 3 | [0, 100] | "an Int with a range and a description"
    b::T = 5 | [2, 9]   | "a Float with a range and a description"
end

k = Keyword()
@test paramrange(k, :a) == [0, 100]
@test description(k, :b) == "a Float with a range and a description"
@test k.a == 3
@test k.b == 5

@description @paramrange @with_kw struct MissingKeyword{T} <: AbstractTest
    a::T = 3 | [0, 100] | "an Int with a range and a description"
    b::T     | [2, 9]   | "a Float with a range and a description"
end

m = MissingKeyword(b = 99)
@test paramrange(m, :a) == [0, 100]
@test description(m, :b) == "a Float with a range and a description"
@test m.a == 3
@test m.b == 99
