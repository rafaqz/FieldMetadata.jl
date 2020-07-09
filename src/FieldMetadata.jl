module FieldMetadata

export @metadata, @chain


struct MetadataError <: Exception
    var::String
end

Base.showerror(io::IO, e::MetadataError) = print(io, e.var)

"""
    @metadata name default [type=Any]

Generate a macro that constructs methods of the same name.
These methods return the metadata information provided for each
field of the struct.

If no method is definjed for a type or field, the default value 
is used. If a type is passed to the macro, the type of metadata will be checked 
when it is loaded with the method. The default type is `Any`.

```julia
@metadata def_range (0, 0) Tuple
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
macro metadata(name, default, checktyp=Any)
    symname = QuoteNode(name)
    default = esc(default)
    name = esc(name)
    checktyp = esc(checktyp)
    return quote
        macro $name(expr)
            name = $symname
            return funcs_from_unknown(expr, name, $checktyp)
        end

        macro $name(typ, expr)
            name = $symname
            return funcs_from_block(typ, expr, name, $checktyp)
        end

        # Single field methods
        $name(x, key) = $default
        $name(x::Type, key::Type) = $default
        $name(::X, key::Symbol) where X = $name(X, Val{key})
        $name(::X, key::Type) where X = $name(X, key)
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
    macros = reverse(chained_macros(ex))
    return quote
        macro $(esc(name))(ex)
            for mac in $macros
                ex = Expr(:macrocall, mac, LineNumberNode(80, "FieldMetadata.jl"), ex)
            end
            esc(ex)
        end
        macro $(esc(name))(typ, ex)
            for mac in $macros
                ex = Expr(:macrocall, mac, LineNumberNode(87, "FieldMetadata.jl"), typ, ex)
            end
            esc(ex)
        end
    end
end

Base.@pure fieldname_vals(::Type{X}) where X = ([Val{fn} for fn in fieldnames(X)]...,)

function funcs_from_unknown(expr::Expr, name::Symbol, checktyp; update=false)
    macros = chained_macros(expr)
    typ = firsthead(x -> namify(x.args[2]), expr, :struct)
    # If there is no struct this is a begin block with chained macros
    if typ === nothing 
        typ = if length(macros) > 0
            findexpr = expr
            for i in 1:length(macros) - 1
                findexpr = findexpr.args[3]
            end
            findexpr.args[3]
        else
            error("incorrect arguments for @$name")
        end
        update = true
    end
    func_exprs = Expr[]
    # Getting the block is the same whatever the format
    firsthead(expr, :block) do block
        parseblock!(block, func_exprs, name, typ, checktyp)
    end
    if length(macros) == 0
        if update 
            Expr(:block, func_exprs...)
        else
            Expr(:block, :(Base.@__doc__ $(esc(expr))), func_exprs...)
        end
    else
        Expr(:block, esc(expr), func_exprs...)
    end
end

function funcs_from_block(objtyp::Union{Symbol,Expr}, expr::Expr, name::Symbol, checktyp)
    macros = chained_macros(objtyp)
    # if !(objtyp isa Symbol) && objtyp.head == :call
        # ojbtyp = eval(typ)
    # end
    func_exprs = Expr[]
    firsthead(expr, :block) do block
        parseblock!(block, func_exprs, name, objtyp, checktyp)
    end
    if length(macros) == 0
        Expr(:block, func_exprs...)
    else
        Expr(:block, esc(typ), esc(ex), func_exprs...)
    end
end

# Parse the block: and Function expressions are built for each line, 
# and one layer of metadata is removed. Both arguments are modified.  
function parseblock!(block::Expr, exprs::Vector, method::Symbol, typ::Union{Symbol,Expr}, checktyp)
    for (i, line) in enumerate(block.args)
        :head in fieldnames(typeof(line)) || continue
        # Allow Parameters.jl to coexist
        if line.head == :(=)
            # The fieldname is the first arg
            fn = line.args[1]
            # Make sure this is a field
            if fn isa Symbol || fn.head == :(::)
                key = getkey(fn)
                # Then make sure its a call to |
                expr = line.args[2]
                if expr.head == :call && expr.args[1] == :(|)
                    process_equals_line!(exprs, line, expr, key, method, typ, checktyp)
                end
            end
        elseif line.head == :call && line.args[1] == :(|)
            process_bar_line!(exprs, block.args, method, typ, checktyp, i)
        end
    end
end

function process_equals_line!(exprs, parent, expr, key, method, typ, checktyp)
    child = expr.args[2]
    if child isa Expr && child.head == :call && child.args[1] == :(|)
        process_equals_line!(exprs, expr, child, key, method, typ, checktyp)
    else
        val = expr.args[3]
        val == :_ || addmethod!(exprs, method, typ, checktyp, key, val)
        # Replace the rest of the line after the = call
        parent.args[2] = child
    end
end

# exprs, line and block may all be mutated
function process_bar_line!(exprs, args, method, typ, checktyp, i)
    expr = args[i]
    if expr.head == :call && expr.args[1] == :(|) 
        child = expr.args[2]
        if child isa Symbol 
            key = child
            val = expr.args[3]
            val == :_ || addmethod!(exprs, method, typ, checktyp, key, val)
            args[i] = key
        elseif child.head != :call
            # Replace the line with the field
            key = getkey(child)
            val = expr.args[3]
            val == :_ || addmethod!(exprs, method, typ, checktyp, key, val)
            expr.head = child.head
            expr.args = child.args
        else
            process_bar_line!(exprs, expr.args, method, typ, checktyp, 2) 
        end
    else
        error("expression is not a | : `$expr`")
    end
end


function addmethod!(exprs, method, typ, checktyp, key, value)
    func = quote
        function $method(::Type{<:$typ}, ::Type{Val{$(QuoteNode(key))}}) 
            value = $value 
            value isa $checktyp || FieldMetadata.metadata_error($typ, $checktyp, $(QuoteNode(key)), value)
            value
        end
    end
    push!(exprs, esc(func))
end

@noinline metadata_error(typ, checktyp, key, value) = 
    throw(MetadataError("$value of type $(typeof(value)) is not in $checktyp for key $key in $typ"))

# Field could be just the name `a`
getkey(ex::Symbol) = ex
# Or the name and type `a::T`, or somethng else
getkey(ex::Expr) =
    firsthead(y -> y.args[1], ex, :(::))

chained_macros(ex) = chained_macros!(Symbol[], ex)
chained_macros!(macros, ex::Expr) = begin
    if ex.head == :macrocall
        push!(macros, ex.args[1])
        length(ex.args) > 2 && chained_macros!(macros, ex.args[3])
    end
    macros
end
chained_macros!(macros, ex::Symbol) = Symbol[]

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



# FieldMetadata api
@metadata default nothing
@metadata units 1
@metadata prior nothing
@metadata label "" AbstractString 
@metadata description "" AbstractString 
@metadata limits (0.0, 1.0) Tuple
@metadata bounds (0.0, 1.0) Tuple
@metadata logscaled false Bool
@metadata flattenable true Bool
@metadata plottable true Bool
@metadata selectable Nothing

# Set the default label to be the field name
label(x::Type, ::Type{Val{F}}) where F = F

end # module
