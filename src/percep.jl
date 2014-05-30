# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Averaged perceptron implementation for sparse/dense feature vectors.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-27

# TODO: Could use repeated(1) for binary features, but since it would be in a
#   tight loop we will use separate code-paths for now.
# TODO: What would you really call the variable `value`?

module Percep

export classify, spclassify, spupdate!, update!
export Perceptron, AvgPerceptron
export MulticlassPerceptron, MulticlassAvgPerceptron

type Perceptron
    weights::Vector{Float64}
    bias::Float64
end

function _spscore(fidxs, fvals, p)
    score = p.bias
    for (fidx, fval) in zip(fidxs, fvals)
        score += p.weights[fidx] * fval
    end
    return score
end

function _spscore(fidxs, p)
    score = p.bias
    for fidx in fidxs
        score += p.weights[fidx]
    end
    return score
end

_spclassify(fidxs, p) = _spscore(fidxs, p) > 0
_spclassify(fidxs, fvals, p) = _spscore(fidxs, fvals, p) > 0

spscore(fidxs, p) = _spscore(fidxs, p)
spscore(fidxs, fvals, p) = _spscore(fidxs, fvals, p)

spclassify(fidxs, p) = _spclassify(fidxs, p)
spclassify(fidxs, fvals, p) = _spclassify(fidxs, fvals, p)

classify(fvec, p) = spclassify(1:length(fvec), fvec, p)

function _spupdate!(p, fidxs, value)
    for fidx in fidxs
        p.weights[fidx] += value
    end
    p.bias += value
end

function _spupdate!(p, fidxs, fvals, value)
    for (fidx, fval) in zip(fidxs, fvals)
        p.weights[fidx] += value * fval
    end
    p.bias += value
end

spupdate!(p, fidxs, value) = _spupdate!(p, fidxs, value)
spupdate!(p, fidxs, value::Bool) = spupdate!(p, fidxs, value ? 1 : -1)
spupdate!(p, fidxs, fvals, value) = _spupdate!(p, fidxs, fvals, value)
function spupdate!(p, fidxs, fvals, value::Bool)
    spupdate!(p, fidxs, fvals, value ? 1 : -1)
end

update!(p, fvec, value) = spupdate!(p, 1:length(fvec), fvec, value)

type AvgPerceptron
    weights::Vector{Float64}
    bias::Float64
    weightssum::Vector{Float64}
    biassum::Float64
    samplecount::Uint
    wlastupdate::Vector{Uint}
    blastupdate::Uint
end

AvgPerceptron() = AvgPerceptron(Float64[], 0, Float64[], 0, 0, Uint[], 0)

function extend!(p, size)
    oldsize = length(p.weights)
    resize!(p.weights, size)
    resize!(p.weightssum, size)
    resize!(p.wlastupdate, size)
    # Initialise the new weights.
    p.weights[oldsize+1:end] = 0
    p.weightssum[oldsize+1:end] = 0
    p.wlastupdate[oldsize+1:end] = p.samplecount
    return p
end

function AvgPerceptron(size)
    p = AvgPerceptron()
    extend!(p, size)
end

# Convert an averaged perceptron to a its final vanilla perceptron stage.
function Perceptron(p)
    w = copy(p.weightssum)
    b = p.biassum

    # Add the factors since the last update.
    for fidx in 1:length(w)
        wfact = p.samplecount - p.wlastupdate[fidx]
        w[fidx] += wfact * p.weights[fidx]
    end
    bfact = p.samplecount - p.blastupdate
    b += bfact * p.bias

    w ./= p.samplecount
    b /= p.samplecount

    Perceptron(w, b)
end

function spclassify(fidxs, p::AvgPerceptron)
    p.samplecount += 1
    return _spclassify(fidxs, p)
end

function spclassify(fidxs, fvals, p::AvgPerceptron)
    p.samplecount += 1
    return _spclassify(fidxs, fvals, p)
end

function spupdate!(p::AvgPerceptron, fidxs, value::Bool)
    spupdate!(p, fidxs, value ? 1 : -1)
end

function sumsupdate!(p, fidxs)
    for fidx in fidxs
        wfact = p.samplecount - p.wlastupdate[fidx]
        p.wlastupdate[fidx] = p.samplecount
        # TODO: Potential overflow? But I am not alone in doing this...
        p.weightssum[fidx] += wfact * p.weights[fidx]
    end

    bfact = p.samplecount - p.blastupdate
    p.blastupdate = p.samplecount
    p.biassum += bfact * p.bias
end

function spupdate!(p::AvgPerceptron, fidxs, value)
    sumsupdate!(p, fidxs)
    _spupdate!(p, fidxs, value)
end

function spupdate!(p::AvgPerceptron, fidxs, fvals, value)
    sumsupdate!(p, fidxs)
    _spupdate!(p, fidxs, fvals, value)
end

function update!(p::AvgPerceptron, fvec, value)
    spupdate!(p, 1:length(fvec), fvec, value)
end

function spupdate!(p::AvgPerceptron, fidxs, value::Bool)
    spupdate!(p, fidxs, value ? 1 : -1)
end

function spupdate!(p::AvgPerceptron, fidxs, fvals, value::Bool)
    spupdate!(p, fidxs, fvals, value ? 1 : -1)
end

function update!(p::AvgPerceptron, fvec, value::Bool)
    update!(p::AvgPerceptron, fvec, value ? 1 : -1)
end

end
