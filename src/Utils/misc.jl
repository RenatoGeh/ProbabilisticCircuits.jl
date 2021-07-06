export to_long_mi, logsumexp_cuda,
    pop_cuda!, push_cuda!, all_empty, length_cuda,
    generate_all, generate_data_all, kfold

using DataFrames
using CUDA: CUDA

###################
# Misc.
####################

function to_long_mi(m::Matrix{Float64}, min_int, max_int)::Matrix{Int64}
    δmi = maximum(m) - minimum(m)
    δint = max_int - min_int
    return @. round(Int64, m * δint / δmi + min_int)
end

# TODO: get rid of all copies
@inline function logsumexp_cuda(x,y) 
    Δ = ifelse(x == y, zero(x), CUDA.abs(x - y))
    max(x, y) + CUDA.log1p(CUDA.exp(-Δ))
end

###################
# Rudimentary CUDA-compatible stack data structure
####################

# sadly making `i` varargs doesn't work; kernel won't compile

function pop_cuda!(stack, i)
    if @inbounds stack[i,1] == zero(eltype(stack))
        return zero(eltype(stack))
    else
        @inbounds stack[i,1] -= one(eltype(stack))
        @inbounds return stack[i,stack[i,1]+2]
    end
end

function pop_cuda!(stack, i, j)
    if @inbounds stack[i,j,1] == zero(eltype(stack))
        return zero(eltype(stack))
    else
        @inbounds stack[i,j,1] -= one(eltype(stack))
        @inbounds return stack[i,j,stack[i,j,1]+2]
    end
end

function push_cuda!(stack, v, i)
    @inbounds stack[i,1] += one(eltype(stack))
    @inbounds CUDA.@cuassert 1+stack[i,1] <= size(stack, ndims(stack)) "CUDA stack overflow"
    @inbounds stack[i,1+stack[i,1]] = v
    return nothing
end

function push_cuda!(stack, v, i, j)
    @inbounds stack[i, j,1] += one(eltype(stack))
    @inbounds CUDA.@cuassert 1+stack[i, j,1] <= size(stack, ndims(stack)) "CUDA stack overflow"
    @inbounds stack[i, j,1+stack[i, j,1]] = v
    return nothing
end

all_empty(stack::AbstractArray{T,2}) where T = 
    all(x -> iszero(x), stack[:,1])

all_empty(stack::AbstractArray{T,3}) where T = 
    all(x -> iszero(x), stack[:,:,1])


length_cuda(stack, i...) = stack[i...,1]


###################
# One-Hot Encoding
####################

"""
One-hot encode data (2-D Array) based on categories (1-D Array)
Each row of the return value is a concatenation of one-hot encoding of elements of the same row in data
Assumption: both input arrays have elements of same type
"""
function one_hot_encode(X::Array{T, 2}, categories::Array{T,1}) where {T<:Any}
    X_dash = zeros(Bool, size(X)[1], length(categories)*size(X)[2])
    for i = 1:size(X)[1], j = 1:size(X)[2]
            X_dash[i, (j-1)*length(categories) + findfirst(==(X[i,j]), categories)] = 1
    end  
    X_dash
end

###################
# Testing Utils
####################

"""
Given some missing values generates all possible fillings
"""
function generate_all(row::Vector)
    miss_count = count(ismissing, row)
    lits = length(row)
    result = Bool.(zeros(1 << miss_count, lits))

    if miss_count == 0
        result[1, :] = copy(row)
    else
        for mask = 0: (1<<miss_count) - 1
            cur = missings(Bool, lits)
            cur .= row
            cur[ismissing.(row)] = transpose(parse.(Bool, split(bitstring(mask)[end-miss_count+1:end], "")))
            result[mask+1,:] = cur
        end
    end
    DataFrame(result)
end

"""
Generates all possible binary configurations of size N
"""
function generate_data_all(N::Int)
    data_all = transpose(parse.(Bool, split(bitstring(0)[end-N+1:end], "")));
    for mask = 1: (1<<N) - 1
        data_all = vcat(data_all,
            transpose(parse.(Bool, split(bitstring(mask)[end-N+1:end], "")))
        );
    end
    DataFrame(data_all)
end

#####################
# K-fold partitioning
#####################

"Returns a(n index) partitioning a la k-fold."
function kfold(n::Int, p::Int)::Vector{Tuple{UnitRange, Vector{Int}}}
    F = Vector{Tuple{UnitRange, Vector{Int}}}(undef, p)
    j = s = 1
    k = n÷p
    for i ∈ 1:n%p
        if s > 1
            I = collect(1:s-1)
            if s+k < n append!(I, s+k+1:n) end
        else I = collect(s+k+1:n) end
        F[j] = (s:s+k, I)
        s += k+1
        j += 1
    end
    k = n÷p-1
    for i ∈ 1:p-n%p
        if s > 1
            I = collect(1:s-1)
            if s+k < n append!(I, s+k+1:n) end
        else I = collect(s+k+1:n) end
        F[j] = (s:s+k, I)
        s += k+1
        j += 1
    end
    return F
end
