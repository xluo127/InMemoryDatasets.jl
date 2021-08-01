struct MultiCol
    x
end
function byrow(@nospecialize(f); @nospecialize(args...))
    br = [:($f, $args)]
    br[1].head = :BYROW
    br
end

function _check_ind_and_add!(outidx::Index, val)
    if !haskey(outidx, val)
        push!(outidx, val)
    end
end

# col => fun => dst, the job is to create col => fun => :dst
function normalize_modify!(outidx::Index, idx::Index,
                            @nospecialize(sel::Pair{<:ColumnIndex,
                                                    <:Pair{<:Union{Base.Callable},
                                                        <:Union{Symbol, AbstractString}}})
                                                        )
    src, (fun, dst) = sel
    _check_ind_and_add!(outidx, Symbol(dst))
    return outidx[src] => fun => Symbol(dst)
end
# col => fun => dst, the job is to create col => fun => :dst
function normalize_modify!(outidx::Index, idx::Index,
                            @nospecialize(sel::Pair{<:ColumnIndex,
                                                    <:Pair{<:Union{Base.Callable},
                                                        <:Vector{<:Union{Symbol, AbstractString}}}})
                                                        )
    src, (fun, dst) = sel
    for i in 1:length(dst)
        _check_ind_and_add!(outidx, Symbol(dst[i]))
    end
    return outidx[src] => fun => MultiCol(Symbol.(dst))
end
# col => fun, the job is to create col => fun => :colname
function normalize_modify!(outidx::Index, idx::Index,
                            @nospecialize(sel::Pair{<:ColumnIndex,
                                                    <:Union{Base.Callable}}))

    src, fun = sel
    return outidx[src] => fun => _names(outidx)[outidx[src]]
end

# col => byrow
function normalize_modify!(outidx::Index, idx::Index,
                            @nospecialize(sel::Pair{<:ColumnIndex,
                                                    <:Vector{Expr}}))
    colsidx = outidx[sel.first]
    if sel.second[1].head == :BYROW
        # TODO needs a better name for destination
        # _check_ind_and_add!(outidx, Symbol("row_", funname(sel.second.args[1])))
        return outidx[colsidx] => sel.second[1] => _names(outidx)[colsidx]
    end
    throw(ArgumentError("only byrow is accepted when using expressions"))
end
function normalize_modify!(outidx::Index, idx::Index,
                            @nospecialize(sel::Pair{<:ColumnIndex,
                                                    <:Expr}))
    colsidx = outidx[sel.first]
    if sel.second.head == :BYROW
        # TODO needs a better name for destination
        # _check_ind_and_add!(outidx, Symbol("row_", funname(sel.second.args[1])))
        return outidx[colsidx] => sel.second => _names(outidx)[colsidx]
    end
    throw(ArgumentError("only byrow is accepted when using expressions"))
end
# col => byrow => dst
function normalize_modify!(outidx::Index, idx::Index,
                            @nospecialize(sel::Pair{<:ColumnIndex,
                                        <:Pair{<:Vector{Expr},
                                            <:Union{Symbol, AbstractString}}}))
    colsidx = outidx[sel.first]
    if sel.second.first[1].head == :BYROW
        # TODO needs a better name for destination
        _check_ind_and_add!(outidx, Symbol(sel.second.second))
        return outidx[colsidx] => sel.second.first[1] => Symbol(sel.second.second)
    end
    throw(ArgumentError("only byrow is accepted when using expressions"))
end
function normalize_modify!(outidx::Index, idx::Index,
                            @nospecialize(sel::Pair{<:ColumnIndex,
                                        <:Pair{<:Expr,
                                            <:Union{Symbol, AbstractString}}}))
    colsidx = outidx[sel.first]
    if sel.second.first.head == :BYROW
        # TODO needs a better name for destination
        _check_ind_and_add!(outidx, Symbol(sel.second.second))
        return outidx[colsidx] => sel.second.first => Symbol(sel.second.second)
    end
    throw(ArgumentError("only byrow is accepted when using expressions"))
end

# cols => fun, the job is to create [col1 => fun => :col1name, col2 => fun => :col2name ...]
function normalize_modify!(outidx::Index, idx::Index,
                            @nospecialize(sel::Pair{<:MultiColumnIndex,
                                                    <:Vector{Expr}}))
    colsidx = outidx[sel.first]
    if sel.second isa AbstractVector && sel.second[1] isa Expr
        if sel.second[1].head == :BYROW
            # TODO needs a better name for destination
            _check_ind_and_add!(outidx, Symbol("row_", funname(sel.second[1].args[1])))
            return outidx[colsidx] => sel.second[1] => Symbol("row_", funname(sel.second[1].args[1]))
        end
    end
    # res = Any[normalize_modify!(outidx, idx, colsidx[1] => sel.second)]
    # for i in 2:length(colsidx)
    #     push!(res, normalize_modify!(outidx, idx, colsidx[i] => sel.second))
    # end
    # return res
end
function normalize_modify!(outidx::Index, idx::Index,
                            @nospecialize(sel::Pair{<:MultiColumnIndex,
                                                    <:Union{Base.Callable, Expr}}))
    colsidx = outidx[sel.first]
    if sel.second isa Expr
        if sel.second.head == :BYROW
            # TODO needs a better name for destination
            _check_ind_and_add!(outidx, Symbol("row_", funname(sel.second.args[1])))
            return outidx[colsidx] => sel.second => Symbol("row_", funname(sel.second.args[1]))
        end
    end
    res = Any[normalize_modify!(outidx, idx, colsidx[1] => sel.second)]
    for i in 2:length(colsidx)
        push!(res, normalize_modify!(outidx, idx, colsidx[i] => sel.second))
    end
    return res
end
# cols => funs which will be normalize as col1=>fun1, col2=>fun2, ...
function normalize_modify!(outidx::Index, idx::Index,
                            @nospecialize(sel::Pair{<:MultiColumnIndex,
                                                    <:Vector{<:Base.Callable}}))
    colsidx = outidx[sel.first]
    if !(length(colsidx) == length(sel.second))
        throw(ArgumentError("The input number of columns and the length of the number of functions should match"))
    end
    res = Any[normalize_modify!(outidx, idx, colsidx[1] => sel.second[1])]
    for i in 2:length(colsidx)
        push!(res, normalize_modify!(outidx, idx, colsidx[i] => sel.second[i]))
    end
    return res
end
# special case cols => byrow(...) => :name
function normalize_modify!(outidx::Index, idx::Index,
    @nospecialize(sel::Pair{<:MultiColumnIndex,
                            <:Pair{<:Vector{Expr},
                                <:Union{Symbol, AbstractString}}}))
    colsidx = outidx[sel.first]
    if sel.second.first[1].head == :BYROW
        _check_ind_and_add!(outidx, Symbol(sel.second.second))
        return outidx[colsidx] => sel.second.first[1] => Symbol(sel.second.second)
    else
        throw(ArgumentError("only byrow operation is supported for cols => fun => :name"))
    end
end
function normalize_modify!(outidx::Index, idx::Index,
    @nospecialize(sel::Pair{<:MultiColumnIndex,
                            <:Pair{<:Expr,
                                <:Union{Symbol, AbstractString}}}))
    colsidx = outidx[sel.first]
    if sel.second.first.head == :BYROW
        _check_ind_and_add!(outidx, Symbol(sel.second.second))
        return outidx[colsidx] => sel.second.first => Symbol(sel.second.second)
    else
        throw(ArgumentError("only byrow operation is supported for cols => fun => :name"))
    end
end

# cols .=> fun .=> dsts, the job is to create col1 => fun => :dst1, col2 => fun => :dst2, ...
function normalize_modify!(outidx::Index, idx::Index,
                            @nospecialize(sel::Pair{<:MultiColumnIndex,
                                                    <:Pair{<:Union{Base.Callable,Vector{Expr}},
                                                        <:AbstractVector{<:Union{Symbol, AbstractString}}}}))
    colsidx = outidx[sel.first]
    if !(length(colsidx) == length(sel.second.second))
        throw(ArgumentError("The input number of columns and the length of the output names should match"))
    end
    res = Any[normalize_modify!(outidx, idx, colsidx[1] => sel.second.first => sel.second.second[1])]
    for i in 2:length(colsidx)
        push!(res, normalize_modify!(outidx, idx, colsidx[i] => sel.second.first => sel.second.second[i]))
    end
    return res
end
# cols .=> fun .=> dsts, the job is to create col1 => fun => :dst1, col2 => fun => :dst2, ...
function normalize_modify!(outidx::Index, idx::Index,
                            @nospecialize(sel::Pair{<:MultiColumnIndex,
                                                    <:Pair{<:Expr,
                                                        <:AbstractVector{<:Union{Symbol, AbstractString}}}}))
    colsidx = outidx[sel.first]
    if !(length(colsidx) == length(sel.second.second))
        throw(ArgumentError("The input number of columns and the length of the output names should match"))
    end
    res = Any[normalize_modify!(outidx, idx, colsidx[1] => sel.second.first => sel.second.second)]
    for i in 2:length(colsidx)
        push!(res, normalize_modify!(outidx, idx, colsidx[i] => sel.second.first => sel.second.second[i]))
    end
    return res
end

function normalize_modify!(outidx::Index, idx::Index, arg::AbstractVector)
    res = Any[]
    for i in 1:length(arg)
        _res = normalize_modify!(outidx::Index, idx::Index, arg[i])
        if _res isa AbstractVector
            for j in 1:length(_res)
                push!(res, _res[j])
            end
        else
            push!(res, _res)
        end
    end
    return res
end

function normalize_modify_multiple!(outidx::Index, idx::Index, @nospecialize(args...))
    res = Any[]
    for i in 1:length(args)
        _res = normalize_modify!(outidx, idx, args[i])
        if typeof(_res) <: Pair
            push!(res, _res)
        else
            for j in 1:length(_res)
                push!(res, _res[j])
            end
        end
    end
    res
end

modify(ds::Dataset) = copy(ds)
function modify(origninal_ds::Dataset, @nospecialize(args...))
    ds = copy(origninal_ds)
    idx_cpy::Index = Index(copy(index(ds).lookup), copy(index(ds).names), Dict{Int, Function}())
    if isgrouped(ds)
        norm_var = normalize_modify_multiple!(idx_cpy, index(ds), args...)
        all_new_var = map(x -> x.second.second, norm_var)
        var_index = idx_cpy[unique(all_new_var)]
        if any(index(ds).sortedcols .∈ Ref(var_index))
            throw(ArgumentError("the grouping variables cannot be modified, first use `ungroup!(ds)` to ungroup the data set"))
        end
        _modify_grouped(ds, norm_var)
    else
        _modify(ds, normalize_modify_multiple!(idx_cpy, index(ds), args...))
    end
end
modify!(ds::Dataset) = ds
function modify!(ds::Dataset, @nospecialize(args...))
    idx_cpy = Index(copy(index(ds).lookup), copy(index(ds).names), copy(index(ds).format))
    if isgrouped(ds)
        norm_var = normalize_modify_multiple!(idx_cpy, index(ds), args...)
        all_new_var = map(x -> x.second.second, norm_var)
        var_index = idx_cpy[unique(all_new_var)]
        any(index(ds).sortedcols .∈ Ref(var_index)) && throw(ArgumentError("the grouping variables cannot be modified, first use `ungroup!(ds)` to ungroup the data set"))
        _modify_grouped(ds, norm_var)
    else
        _modify(ds, normalize_modify_multiple!(idx_cpy, index(ds), args...))
    end
end

# size() is better option for checking if the result is scalar,
# it works for numbers and it won't work for strings and symbols
function _is_scalar(_res, sz)
     resize_col = false
    try
        size(_res)
        if size(_res) == () || size(_res,1) != sz
            # fill!(Tables.allocatecolumn(typeof(_res), nrow(ds)),
            #                           _res)
            # _res = repeat([_res], nrow(ds))
            resize_col = true
        end
    catch e
        if (e isa MethodError)
            # fill!(Tables.allocatecolumn(typeof(_res), nrow(ds)),
                                      # _res)
            # _res = repeat([_res], nrow(ds))
            resize_col = true
       end

    end
    return resize_col
end

function _resize_result!(ds, _res, newcol)
    resize_col = _is_scalar(_res, nrow(ds))
    if resize_col
        ds[!, newcol] = fill!(Tables.allocatecolumn(typeof(_res), nrow(ds)), _res)
    else
        ds[!, newcol] = _res
    end
end


function _modify_single_var!(ds, _f, x, dst)
    _res = _f(x)
    _resize_result!(ds, _res, dst)
end

function _modify_multiple_out!(ds, _f, x, dst)
    _res = _f(x)
    if _res isa Tuple
        for j in 1:length(dst)
            _resize_result!(ds, _res[j], dst[j])
        end
    else
        throw(ArgumentError("the function must return results as a tuple which each element of it corresponds to a new column"))
    end
end

function _modify_f_barrier(ds, msfirst, mssecond, mslast)
    if (mssecond isa Base.Callable) && !(mslast isa MultiCol)
        _modify_single_var!(ds, mssecond, _columns(ds)[msfirst], mslast)
    elseif (mssecond isa Expr) && mssecond.head == :BYROW
        try
            ds[!, mslast] = byrow(ds, mssecond.args[1], msfirst; mssecond.args[2]...)
        catch e
            if e isa MethodError
                throw(ArgumentError("output of `byrow` operation must be a vector"))
            end
            rethrow(e)
        end
    elseif  (mssecond isa Base.Callable) && (mslast isa MultiCol)
        _modify_multiple_out!(ds, mssecond, _columns(ds)[msfirst], mslast.x)
    else
        @error "not yet know how to handle this situation $(msfirst => mssecond => mslast)"
    end
end

function _modify(ds, ms)
    needs_reset_grouping = false
    for i in 1:length(ms)
        _modify_f_barrier(ds, ms[i].first, ms[i].second.first, ms[i].second.second)
    end
    return ds
end

function _check_the_output_type(ds::Dataset, ms)
    CT = return_type(ms.second.first, ds[!, ms.first].val)
    # TODO check other possibilities:
    # the result can be
    # * AbstractVector{T} where T
    # * Vector{T}
    # * not a Vector
    CT == Union{} && throw(ArgumentError("compiler cannot assess the return type of calling `$(ms.second.first)` on `:$(_names(ds)[ms.first])`, you may want to try using `byrow`"))
    if CT <: AbstractVector
        if hasproperty(CT, :var)
            T = Union{Missing, CT.var.ub}
        else
            T = Union{Missing, eltype(CT)}
        end
    else
        T = Union{Missing, CT}
    end
    T
end

# FIXME notyet complete
# fill _res for grouped data: col => f => :newcol
function _modify_grouped_fill_one_col!(_res, x, _f, starts, ngroups, nrows)
    Threads.@threads for g in 1:ngroups
        lo = starts[g]
        g == ngroups ? hi = nrows : hi = starts[g + 1] - 1
        _tmp_res = _f(view(x, lo:hi))
        resize_col = _is_scalar(_tmp_res, length(lo:hi))
        if resize_col
            fill!(view(_res, lo:hi), _tmp_res)
        else
            copy!(view(_res, lo:hi), _tmp_res)
        end
    end
    _res
end


function _modify_grouped_f_barrier(ds, msfirst, mssecond, mslast)
    if (mssecond isa Base.Callable) && !(mslast isa MultiCol)
        T = _check_the_output_type(ds, msfirst=>mssecond=>mslast)
        _res = Tables.allocatecolumn(T, nrow(ds))
        _modify_grouped_fill_one_col!(_res, _columns(ds)[msfirst], mssecond, index(ds).starts, index(ds).ngroups[], nrow(ds))
        ds[!, mslast] = _res
    elseif (mssecond isa Expr)  && mssecond.head == :BYROW
        ds[!, mslast] = byrow(ds, mssecond.args[1], msfirst; mssecond.args[2]...)
    elseif (mssecond isa Base.Callable) && (mslast isa MultiCol)

        throw(ArgumentError("multi column output is not supported for grouped data set"))
    else
                # if something ends here, we should implement new functionality for it
        @error "not yet know how to handle the situation $(msfirst => mssecond => mslast)"
    end
end

function _modify_grouped(ds, ms)
    needs_reset_grouping = false
    for i in 1:length(ms)
        _modify_grouped_f_barrier(ds, ms[i].first, ms[i].second.first, ms[i].second.second)
    end
    return ds
end
