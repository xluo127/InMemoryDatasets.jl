function groupby!(ds::Dataset, cols::MultiColumnIndex; alg = HeapSortAlg(), rev = false, issorted::Bool = false, mapformats::Bool = true, stable = true)
    sort!(ds, cols, alg = alg, rev = rev, issorted = issorted, mapformats = mapformats, stable = stable)
    index(ds).grouped[] = true
    _modified(_attributes(ds))
    ds
end

groupby!(ds::Dataset, col::ColumnIndex; alg = HeapSortAlg(), rev = false, issorted::Bool = false, mapformats::Bool = true, stable = true) = groupby!(ds, [col]; alg = alg, rev = rev, issorted = issorted, mapformats = mapformats, stable = stable)

struct GroupBy
    parent::Dataset
    groupcols
    perm
    starts
    lastvalid
end

nrow(ds::GroupBy) = nrow(ds.parent)
ncol(ds::GroupBy) = ncol(ds.parent)
Base.names(ds::GroupBy, kwargs...) = names(ds.parent, kwargs...)
_names(ds::GroupBy) = _names(ds.parent)
_columns(ds::GroupBy) = _columns(ds.parent)
index(ds::GroupBy) = index(ds.parent)
Base.parent(ds::GroupBy) = ds.parent

function groupby(ds::Dataset, cols::MultiColumnIndex; alg = HeapSortAlg(), rev = false, mapformats::Bool = true, stable = true, issorted = false)
    # @assert !isgrouped(ds) "`groupby` is not yet implemented for already grouped data sets"
    colsidx = index(ds)[cols]
    if issorted
        selected_columns, ranges, last_valid_index = _find_starts_of_groups(ds::Dataset, colsidx, nrow(ds) < typemax(Int32) ? Val(Int32) : Val(Int64))
        return GroupBy(ds, colsidx, 1:nrow(ds), ranges, last_valid_index)
    else
        a = _sortperm(ds, cols, rev, a = alg, mapformats = mapformats, stable = stable)
        GroupBy(ds,colsidx, a[2], a[1], a[3])
    end
end

groupby(ds::Dataset, col::ColumnIndex; alg = HeapSortAlg(), rev = false, mapformats::Bool = true, stable = true, issorted = false) = groupby(ds, [col], alg = alg, rev = rev, mapformats = mapformats, stable = stable, issorted = issorted)

function _threaded_permute_for_groupby(x, perm)
    if DataAPI.refpool(x) !== nothing
        pa = x
        if pa isa PooledArray
            # we could use copy but it will be inefficient for small selected_rows
            res = PooledArray(PooledArrays.RefArray(_threaded_permute(pa.refs, perm)), DataAPI.invrefpool(pa), DataAPI.refpool(pa), PooledArrays.refcount(pa))
        else
            # for other pooled data(like Categorical arrays) we don't have optimised path
            res = pa[perm]
        end
    else
        res = _threaded_permute(x, perm)
    end
    res
end

# TODO we need to take care of situations where gds.parent is already grouped, thus the grouping cols from that mess with new grouping cols of gds
function combine(gds::Union{GroupBy, GatherBy}, @nospecialize(args...))
    idx_cpy::Index = Index(Dict{Symbol, Int}(), Symbol[], Dict{Int, Function}())
    ms = normalize_combine_multiple!(length(_groupcols(gds)),idx_cpy, index(gds.parent), args...)
    # the rule is that in combine, byrow must only be used for already aggregated columns
    # so, we should check every thing pass to byrow has been assigned in args before it
    # if this is not the case, throw ArgumentError and ask user to use modify instead
    newlookup, new_nm = _create_index_for_newds(gds.parent, ms, gds.groupcols)
    !(_is_byrow_valid(Index(newlookup, new_nm, Dict{Int, Function}()), ms)) && throw(ArgumentError("`byrow` must be used for aggregated columns, use `modify` otherwise"))
    # _check_mutliple_rows_for_each_group return the first transformation which causes multiple
    # rows or 0 if all transformations return scalar for each group
    # the transformation returning multiple rows must not be based on the previous columns in combine
    # result (which seems reasonable ??)
    _first_vector_res = _check_mutliple_rows_for_each_group(gds.parent, ms)

    _is_groupingcols_modifed(gds, ms) && throw(ArgumentError("`combine` cannot modify the grouping or sorting columns, use a different name for the computed column"))

    groupcols = gds.groupcols
    a = (_get_perms(gds), _group_starts(gds), gds.lastvalid)
    starts = a[2]
    ngroups = gds.lastvalid

    # we will use new_lengths later for assigning the grouping info of the new ds
    if _first_vector_res == 0
        new_lengths = ones(Int, ngroups)
        cumsum!(new_lengths, new_lengths)
        total_lengths = ngroups
    else
        CT = return_type(ms[_first_vector_res].second.first,
                 gds.parent[!, ms[_first_vector_res].first].val)
        special_res = Vector{CT}(undef, ngroups)
        new_lengths = Vector{Int}(undef, ngroups)
        # _columns(ds)[ms[_first_vector_res].first]
        _compute_the_mutli_row_trans!(special_res, new_lengths, _threaded_permute_for_groupby(_columns(gds.parent)[index(gds.parent)[ms[_first_vector_res].first]], a[1]), nrow(gds.parent), ms[_first_vector_res].second.first, _first_vector_res, starts, ngroups)
        # special_res, new_lengths = _compute_the_mutli_row_trans(ds, ms, _first_vector_res, starts, ngroups)
        cumsum!(new_lengths, new_lengths)
        total_lengths = new_lengths[end]
    end
    all_names = _names(gds.parent)

    newds_idx = Index(Dict{Symbol, Int}(), Symbol[], Dict{Int, Function}(), Int[], Bool[], false, [], Int[], 1)

    newds = Dataset([], newds_idx)
    newds_lookup = index(newds).lookup
    var_cnt = 1
    for j in 1:length(groupcols)
        addmissing = false
        _tmpres = allocatecol(gds.parent[!, groupcols[j]].val, total_lengths, addmissing = addmissing)
        if DataAPI.refpool(_tmpres) !== nothing
            _push_groups_to_res_pa!(_columns(newds), _tmpres, view(_columns(gds.parent)[groupcols[j]], a[1]), starts, new_lengths, total_lengths, j, groupcols, ngroups)
        else
            _push_groups_to_res!(_columns(newds), _tmpres, view(_columns(gds.parent)[groupcols[j]], a[1]), starts, new_lengths, total_lengths, j, groupcols, ngroups)
        end
        push!(index(newds), new_nm[var_cnt])
        setformat!(newds, new_nm[var_cnt] => get(index(gds.parent).format, groupcols[j], identity))
        var_cnt += 1
    end
    old_x = ms[1].first
    curr_x = _columns(gds.parent)[1]
    for i in 1:length(ms)
        # TODO this needs a little work, we should permute a column once and reuse it as many times as possible
        # this can be done by sorting the first argument of col=>fun=>dst between each byrow
        if i == 1
            curr_x = _threaded_permute_for_groupby(_columns(gds.parent)[index(gds.parent)[ms[i].first]], a[1])
        else
            if old_x !== ms[i].first
                if haskey(index(gds.parent).lookup, ms[i].first)
                    curr_x = _threaded_permute_for_groupby(_columns(gds.parent)[index(gds.parent)[ms[i].first]], a[1])
                    old_x = ms[i].first
                else
                    curr_x = view(_columns(gds.parent)[1], a[1])
                end
            end
        end

        if i == _first_vector_res
            _combine_f_barrier_special(special_res, view(gds.parent[!, ms[i].first].val, a[1]), newds, ms[i].first, ms[i].second.first, ms[i].second.second, newds_lookup, _first_vector_res,ngroups, new_lengths, total_lengths)
        else
            _combine_f_barrier(haskey(index(gds.parent).lookup, ms[i].first) ? curr_x : view(_columns(gds.parent)[1], a[1]), newds, ms[i].first, ms[i].second.first, ms[i].second.second, newds_lookup, starts, ngroups, new_lengths, total_lengths)
        end
        if !haskey(index(newds), ms[i].second.second)
            push!(index(newds), ms[i].second.second)
        end

    end
    # grouping information for the output dataset
    # append!(index(newds).sortedcols, index(newds)[index(gds.parent).names[groupcols]])
    # append!(index(newds).rev, index(gds.parent).rev)
    # append!(index(newds).perm, collect(1:total_lengths))
    # # index(newds).grouped[] = true
    # index(newds).ngroups[] = ngroups
    # append!(index(newds).starts, collect(1:total_lengths))
    # for i in 2:(length(new_lengths))
    #     index(newds).starts[i] = new_lengths[i - 1]+1
    # end
    newds
end


Base.summary(gds::GroupBy) =
        @sprintf("%d×%d View of Grouped Dataset, Grouped by: %s", size(gds.parent)..., join(_names(gds.parent)[gds.groupcols], " ,"))


function Base.show(io::IO, gds::GroupBy;

                   kwargs...)
     _show(io, view(gds.parent, gds.perm, :); title = summary(gds), kwargs...)
end

Base.show(io::IO, mime::MIME"text/plain", gds::GroupBy;
          kwargs...) =
    show(io, gds; title = summary(gds), kwargs...)


function ungroup!(ds::Dataset)
    if index(ds).grouped[]
        index(ds).grouped[] = false
        _modified(_attributes(ds))
    end
    ds
end

isgrouped(ds::Dataset)::Bool = index(ds).grouped[]
isgrouped(ds::SubDataset)::Bool = false

function group_starts(ds::Dataset)
    index(ds).starts[1:index(ds).ngroups[]]
end
function getindex_group(ds::Dataset, i::Integer)
    if !(1 <= i <= index(ds).ngroups[])
        throw(BoundsError(ds, i))
    end
    lo = index(ds).starts[i]
    i == index(ds).ngroups[] ? hi = nrow(ds) : hi = index(ds).starts[i+1] - 1
    lo:hi
end

function _ngroups(ds::GroupBy)
    ds.lastvalid
end
function _ngroups(ds::Dataset)
    index(ds).ngroups[]
end

function _ngroups(ds::GatherBy)
    ds.lastvalid
end

function _groupcols(ds::GroupBy)
    ds.groupcols
end
function _groupcols(ds::Dataset)
    if isgrouped(ds)
        index(ds).sortedcols
    else
        Int[]
    end
end

function _groupcols(ds::GatherBy)
    ds.groupcols
end

function _group_starts(ds::GroupBy)
    ds.starts
end
function _group_starts(ds::Dataset)
    index(ds).starts
end

function _group_starts(ds::GatherBy)
    if ds.starts === nothing
        a = compute_indices(ds.groups, ds.lastvalid, nrow(ds.parent) < typemax(Int32) ? Val(Int32) : Val(Int64))
        ds.starts = a[2]
        ds.perm = a[1]
        # we overwrite groups in parallel compute_indices
        ds.groups = nothing
        ds.starts
    else
        ds.starts
    end
end


function _get_perms(ds::Dataset)
    1:nrow(ds)
end
function _get_perms(ds::GroupBy)
    ds.perm
end
function _get_perms(ds::GatherBy)
    if ds.perm === nothing
        a = compute_indices(ds.groups, ds.lastvalid, nrow(ds.parent) < typemax(Int32) ? Val(Int32) : Val(Int64))
        ds.starts = a[2]
        ds.perm = a[1]
        # we overwrite groups in parallel compute_indices
        ds.groups = nothing
        ds.perm
    else
        ds.perm
    end
end
