__precompile__()

module MetaFields

export @metafield

"""
Generate a macro that constructs methods of the same name.
These methods return the metafield information provided for each
field of the struct.
```julia
@metafield range
@range struct Model
    a::Int = (1, 4)
    b::Int = (4, 9)
end

model = Model(3, 5)
range(model, Val{:a})
range(model, Val{:b})
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

function getparams(ex, funcname; update = false)
    func_exps = Expr[]
    typ = firsthead(ex, :type) do typ_ex
        return namify(typ_ex.args[2])
    end

    # Parse the block of lines inside the struct.
    # Function expressions are built for each field, and metadata removed.
    findhead(ex, :block) do block
        for arg in block.args
            if !(:head in fieldnames(arg))
                continue
            elseif arg.head == :(=) # probably using @with_kw
                # TODO make this ignore = in inner constructors
                call = arg.args[2]
                key = getkey(arg.args[1])
                val = call.args[3]
                val == :_ || addmethod!(func_exps, funcname, typ, key, val)
                arg.args[2] = call.args[2]
            elseif arg.head == :call
                arg.args[1] == :(|) || continue
                key = getkey(arg.args[2])
                val = arg.args[3]
                val == :_ || addmethod!(func_exps, funcname, typ, key, val)
                arg.head = arg.args[2].head
                arg.args = arg.args[2].args
            end
        end
    end
    if update
        Expr(:block, func_exps...)
    else
        Expr(:block, :(Base.@__doc__ $(esc(ex))), func_exps...)
    end
end

getkey(ex) = firsthead(y -> y.args[1], ex, :(::))

function addmethod!(func_exps, funcname, typ, key, val)
    func = esc(parse("function $funcname(x::Type{<:$typ}, y::Type{Val{:$key}}) :replace end"))
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
