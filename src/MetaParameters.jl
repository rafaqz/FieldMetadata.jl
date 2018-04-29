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
macro metaparam(name)
    symname = QuoteNode(name)
    name = esc(name)
    return quote
        macro $name(ex)
            name = $symname
            return getparams(ex, name)
        end

        function $name(x, key::Symbol) 
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
        findhead(ex, :(=)) do x
            key = x.args[1].args[1]
            y = x.args[2]
            if :head in fieldnames(y) && y.head == :tuple
                tup = y
                val = tup.args[end]
                addmethod!(funcs, funcname, dtype, key, val)
                if length(tup.args) > 2 # remove last item in tuple
                    tup.args = tup.args[1:end-1]
                else # replace tuple with first item in tuple
                    x.args[2] = tup.args[1]
                end
            else
                val = y
                addmethod!(funcs, funcname, dtype, key, val)
                x.head = x.args[1].head
                x.args = x.args[1].args
            end
        end
    end
    Expr(:block, esc(ex), funcs...)
end

function addmethod!(funcs, funcname, dtype, key, val)
    func = esc(parse("function $funcname(x::$dtype, y::Type{Val{:$key}}) :replace end"))
    findhead(func, :block) do l
        l.args[2] = val
    end
    push!(funcs, func)
end

function findhead(f, ex, sym) 
    if :head in fieldnames(ex)
        ex.head == sym && f(ex)
        findhead.(f, ex.args, sym)
    end
end

function firsthead(f, ex, sym) 
    if :head in fieldnames(ex)
        if ex.head == sym 
            return f(ex)
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
