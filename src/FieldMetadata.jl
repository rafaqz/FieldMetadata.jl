module FieldMetadata


export @metadata, @chain

"""
Generate a macro that constructs methods of the same name.
These methods return the metadata information provided for each
field of the struct.

```julia
@tag def_range (0, 0)
@def_range struct Model
    a::Int | (1, 4)
    b::Int | (4, 9)
end

model = Model(3, 5)
def_range(model, Val{:a})
(1, 4)

def_range(model)
((1, 4), (4, 9))
```
"""
macro metadata(name, default)
    symname = QuoteNode(name)
    default = esc(default)
    rename = esc(Meta.parse("re$name"))
    name = esc(name)
    return quote
        macro $name(ex)
            name = $symname
            return add_field_funcs(ex, name)
        end

        macro $rename(ex)
            name = $symname
            return add_field_funcs(ex, name; update=true)
        end

        # Single field methods
        $name(x, key) = $default
        $name(x::Type, key::Type) = $default
        $name(::X, key::Symbol) where X = $name(X, Val{key})
        $name(x::X, key::Type) where X = $name(X, key)
        $name(::Type{X}, key::Symbol) where X = $name(X, Val{key})

        # All field methods
        $name(::X) where X = $name(X)
        $name(x::Type{X}) where X = $name(X, fieldname_vals(X))
        $name(::Type{X}, keys::Tuple) where X =
            ($name(X, keys[1]), $name(X, Base.tail(keys))...)
        $name(::Type{X}, keys::Tuple{}) where X = tuple()
    end
end

"""
Chain together any macros. Useful for combining @metadata macros.

### Example
```julia
@chain columns @label @units @default_kw

@columns struct Foo
  bar::Int | 7 | u"g" | "grams of bar"
end
```
"""
macro chain(name, ex)
    macros = chained_macros(ex)
    return quote
        macro $(esc(name))(ex)
            macros = $macros
            for mac in reverse(macros)
                ex = Expr(:macrocall, mac, LineNumberNode(74, "FieldMetadata.jl"), ex)
            end
            esc(ex)
        end
    end
end

Base.@pure fieldname_vals(::Type{X}) where X = ([Val{fn} for fn in fieldnames(X)]...,)

function add_field_funcs(ex, name; update=false)
    macros = chained_macros(ex)

    typ = firsthead(x -> namify(x.args[2]), ex, :struct)
    func_exps = Expr[]

    # Parse the block of lines inside the struct.
    # Function expressions are built for each field, and metadata removed.
    firsthead(ex, :block) do block
        for (i, line) in enumerate(block.args)
            :head in fieldnames(typeof(line)) || continue
            if line.head == :(=) # probably using @with_kw
                # Ignore inner constructors
                !(:head in fieldnames(typeof(line.args[1]))) || line.args[1].head == :call && continue
                call = line.args[2]
                key = getkey(line.args[1])
                val = call.args[3]
                val == :_ || addmethod!(func_exps, name, typ, key, val)
                line.args[2] = call.args[2]
            elseif line.head == :call
                line.args[1] == :(|) || continue
                val = line.args[3]
                key = getkey(line.args[2])
                if :head in fieldnames(typeof(line.args[2]))
                    line.head = line.args[2].head
                    line.args = line.args[2].args
                else
                    val == :_ || addmethod!(func_exps, name, typ, key, val)
                    block.args[i] = line.args[2]
                end
                val == :_ || addmethod!(func_exps, name, typ, key, val)
            end
        end
    end
    if update && length(macros) == 0
        Expr(:block, func_exps...)
    else
        Expr(:block, :(Base.@__doc__ $(esc(ex))), func_exps...)
    end
end

getkey(ex::Expr) = firsthead(y -> y.args[1], ex, :(::))
getkey(ex::Symbol) = ex

function addmethod!(func_exps, name, typ, key, value)
    func = esc(:(function $name(::Type{<:$typ}, ::Type{Val{$(QuoteNode(key))}}) $value end))
    push!(func_exps, func)
end

chained_macros(ex) = chained_macros!(Symbol[], ex)

chained_macros!(macros, ex) = macros
chained_macros!(macros, ex::Expr) = begin
    if ex.head == :macrocall
        push!(macros, ex.args[1])
        length(ex.args) > 2 && chained_macros!(macros, ex.args[3])
    end
    macros
end

findhead(f, ex::Expr, sym) = begin
    found = false
    if ex.head == sym
        f(ex)
        found = true
    end
    found |= any(findhead.(f, ex.args, sym))
end
findhead(f, ex, sym) = false

firsthead(f, ex::Expr, sym) =
    if ex.head == sym
        out = f(ex)
        return out
    else
        for arg in ex.args
            x = firsthead(f, arg, sym)
            x == nothing || return x
        end
        return nothing
    end
firsthead(f, ex, sym) = nothing

namify(x) = x
namify(x::Expr) = namify(x.args[1])



# FieldMetadata placeholders
@metadata default nothing
@metadata units nothing
@metadata prior nothing
@metadata description ""
@metadata limits (0.0, 1.0)
@metadata label ""

# Set the default label to be the field name
label(x::Type, ::Type{Val{F}}) where F = F

end # module
