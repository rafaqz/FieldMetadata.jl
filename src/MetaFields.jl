__precompile__()

module MetaFields


export @metafield, @chain

"""
Generate a macro that constructs methods of the same name.
These methods return the metafield information provided for each
field of the struct.

```julia
@metafield def_range (0, 0)
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
macro metafield(name, default)
    symname = QuoteNode(name)
    default = esc(default)
    rename = esc(parse("re$name"))
    name = esc(name)
    return quote
        macro $name(ex)
            name = $symname
            return getparams(ex, name)
        end

        macro $rename(ex)
            name = $symname
            return getparams(ex, name; update = true)
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

Base.@pure fieldname_vals(::Type{X}) where X = ([Val{fn} for fn in fieldnames(X)]...)

"""
Chain together any macros. Useful for combining @metafield macros.

### Example
```julia
@chain columns @label @units @default_kw

@columns struct Foo
  bar::Int | 7 | u"g" | "grams of bar"
end
```
"""
macro chain(name, ex)
    macros = []
    findhead(x -> push!(macros, x.args[1]), ex, :macrocall)
    return quote
        macro $(esc(name))(ex)
            macros = $macros
            for mac in reverse(macros)
                ex = Expr(:macrocall, mac, ex)
            end
            esc(ex)
        end
    end
end

function getparams(ex, funcname; update = false)
    func_exps = Expr[]
    typ = firsthead(ex, :type) do typ_ex
        namify(typ_ex.args[2])
    end

    # Parse the block of lines inside the struct.
    # Function expressions are built for each field, and metadata removed.
    firsthead(ex, :block) do block
        for (i, line) in enumerate(block.args)
            :head in fieldnames(line) || continue
            if line.head == :(=) # probably using @with_kw
                # Ignore inner constructors
                !(:head in fieldnames(line.args[1])) || line.args[1].head == :call && continue
                call = line.args[2]
                key = getkey(line.args[1])
                val = call.args[3]
                val == :_ || addmethod!(func_exps, funcname, typ, key, val)
                line.args[2] = call.args[2]
            elseif line.head == :call
                line.args[1] == :(|) || continue
                val = line.args[3]
                key = getkey(line.args[2])
                if :head in fieldnames(line.args[2])
                    line.head = line.args[2].head
                    line.args = line.args[2].args
                else
                    val == :_ || addmethod!(func_exps, funcname, typ, key, val)
                    block.args[i] = line.args[2]
                end
                val == :_ || addmethod!(func_exps, funcname, typ, key, val)
            end
        end
    end
    if update
        Expr(:block, func_exps...)
    else
        Expr(:block, :(Base.@__doc__ $(esc(ex))), func_exps...)
    end
end

getkey(ex::Expr) = firsthead(y -> y.args[1], ex, :(::))
getkey(ex::Symbol) = ex

function addmethod!(func_exps, funcname, typ, key, val)
    # TODO make this less ugly
    func = esc(parse("function $funcname(::Type{<:$typ}, ::Type{Val{:$key}}) :replace end"))
    findhead(func, :block) do l
        l.args[2] = val
    end
    push!(func_exps, func)
end

function findhead(f, ex, sym) 
    found = false
    if :head in fieldnames(ex)
        if ex.head == sym
            f(ex)
            found = true
        end
        found |= any(findhead.(f, ex.args, sym))
    end
    return found
end

function firsthead(f, ex, sym) 
    if :head in fieldnames(ex)
        if ex.head == sym 
            out = f(ex)
            return out
        else
            for arg in ex.args
                x = firsthead(f, arg, sym)
                x == nothing || return x
            end
        end
    end
    return nothing
end

namify(x::Symbol) = x
namify(x::Expr) = namify(x.args[1])

end # module
