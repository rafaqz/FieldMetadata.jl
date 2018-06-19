__precompile__()

module MetaParameters

export @metaparam

"""
Generate a macro that constructs methods of the same name -
these method return the metaparameter information provided for each
field of the struct passed to the macro.
```julia
@metaparam range
@range struct Model
    a::Int = (1, 4)
    b::Int = (4, 9)
end

model = Model(3, 5)
range(model, Val{:a})
range(model, Val{:b})
"""
macro metaparam(name, default)
    symname = QuoteNode(name)
    default = esc(default)
    name = esc(name)
    return quote
        macro $name(ex)
            name = $symname
            return getparams(ex, name)
        end

        @inline function $name(x, key) 
            $default
        end

        @inline function $name(x, key::Symbol) 
            $name(typeof(x), Val{key}) 
        end

        @inline function $name(x::Type, key::Symbol) 
            $name(x, Val{key}) 
        end
    end
end

function getparams(ex, funcname)
    funcs = Expr[]
    dtype = firsthead(ex, :type) do typ
        return namify(typ.args[2])
    end

    findhead(ex, :block) do block
        for arg in block.args
            if arg.head == :(=) # probably using @with_kw
                call = arg.args[2]
                # :head in fieldnames(call) && call[2].head == :call || continue 
                # call.args[1] == :(|) || continue
                key = getkey(arg.args[1])
                val = call.args[3]
                val == :_ || addmethod!(funcs, funcname, dtype, key, val)
                arg.args[2] = call.args[2]
            elseif arg.head == :call
                arg.args[1] == :(|) || continue
                key = getkey(arg.args[2])
                val = arg.args[3]
                val == :_ || addmethod!(funcs, funcname, dtype, key, val)
                arg.head = arg.args[2].head
                arg.args = arg.args[2].args
            end
        end
    end
    Expr(:block, esc(ex), funcs...)
end

getkey(ex) = firsthead(y -> y.args[1], ex, :(::))

function addmethod!(funcs, funcname, dtype, key, val)
    func = esc(parse("function $funcname(x::Type{<:$dtype}, y::Type{Val{:$key}}) :replace end"))
    findhead(func, :block) do l
        l.args[2] = val
    end
    push!(funcs, func)
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
