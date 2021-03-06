module InteropBlockArrays

using Base: tail
using LinearAlgebra: Diagonal

using BlockArrays
using BlockArrays: cumulsizes

import ..SparseXX: asfmulable, spshared
using ..SparseXX: ChainedFMulShared, DiagonalLike

blktype(B) = blktype(typeof(B))
blktype(::Type{<:BlockArray{T, N, R}}) where {T, N, R} = R

isdiagofblocks(::DiagonalLike) = false
isdiagofblocks(D::Diagonal) = D.diag isa AbstractBlockVector

function asfmulable(rhs::Tuple{DiagonalLike,AbstractBlockMatrix}...)
    @assert length(rhs) > 0

    nbs = nblocks(rhs[1][2]) :: NTuple{2,Integer}
    for (i, (D, S)) in enumerate(rhs)
        if isdiagofblocks(D) && nblocks(D.diag, 1) != nbs[1]
            throw(ArgumentError("""
            Block size of `S` of $i-th argument does not match.
            nblocks(S1, 1) = $(nbs[1])
            nblocks(D$i.diag, 1) = $(nblocks(D.diag, 1))
            """))
        end
        if nblocks(S) != nbs
            throw(ArgumentError("""
            Block size of `S` of $i-th argument does not match.
            nblocks(S1) = $nbs
            nblocks(S$i) = $(nblocks(S))
            """))
        end
    end

    terms = []
    yranges = []
    xranges = []
    ycs = cumulsizes(rhs[1][2], 1)
    xcs = cumulsizes(rhs[1][2], 2)
    for i in 1:nbs[1],
        j in 1:nbs[2]

        yr = ycs[i]:ycs[i+1]-1
        xr = xcs[j]:xcs[j+1]-1
        push!(yranges, yr)
        push!(xranges, xr)

        tij = map(rhs) do (D, S)
            if isdiagofblocks(D)
                Di = D.diag[Block(i)]
                D isa BlockArray && @assert D.diag.blocks[i] === Di
            elseif D isa Diagonal
                Di = Diagonal(view(D.diag, yr))
            else
                Di = D
            end
            Sij = S[Block(i, j)]
            S isa BlockArray && @assert S.blocks[i, j] === Sij
            (Di, Sij)
        end
        push!(terms, tij)
    end

    return ChainedFMulShared(Tuple.((terms, yranges, xranges))...)
end

spshared(A::BlockArray) =
    mortar(map(spshared, A.blocks), blocksizes(A))

end  # module
