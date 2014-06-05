# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Averaged perceptron implementation for sparse/dense feature vectors.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-27

# TODO: Could use repeated(1) for binary features, but since it would be in a
#   tight loop we will use separate code-paths for now.
# TODO: What would you really call the variable `value`?

module Percep

export extend!, classify, spclassify, score, spscore, spupdate!, update!
export Perceptron, AvgPerceptron

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

score(fvec, p) = spscore(1:length(fvec), fvec, p)

spclassify(fidxs, p) = _spclassify(fidxs, p)
spclassify(fidxs, fvals, p) = _spclassify(fidxs, fvals, p)

classify(fvec, p) = spclassify(1:length(fvec), fvec, p)

type AvgPerceptron
    weights::Vector{Float64}
    bias::Float64
    weightsacc::Vector{Float64}
    biasacc::Float64
    count::Int
end

AvgPerceptron() = AvgPerceptron(Float64[], 0, Float64[], 0, 0)

function extend!(p, size)
    oldsize = length(p.weights)
    resize!(p.weights, size)
    resize!(p.weightsacc, size)
    # Initialise the new weights.
    p.weights[oldsize+1:end] = 0
    p.weightsacc[oldsize+1:end] = 0
    return p
end

function AvgPerceptron(size)
    p = AvgPerceptron()
    extend!(p, size)
end

# Convert an averaged perceptron to a its final vanilla perceptron stage.
function Perceptron(p)
    div = p.count
    Perceptron(p.weights - p.weightsacc / div, p.bias - p.biasacc / div)
end

function spscore(fidxs, p::AvgPerceptron)
    p.count += 1
    return _spscore(fidxs, p)
end

function spscore(fidxs, fvals, p::AvgPerceptron)
    p.count += 1
    return _spscore(fidxs, fvals, p)
end

function spclassify(fidxs, p::AvgPerceptron)
    p.count += 1
    return _spclassify(fidxs, p)
end

function spclassify(fidxs, fvals, p::AvgPerceptron)
    p.count += 1
    return _spclassify(fidxs, fvals, p)
end

function spupdate!(p, fidxs, value)
    for fidx in fidxs
        p.weights[fidx] += value
        p.weightsacc[fidx] += p.count * value
    end
    p.bias += value
    p.biasacc += p.count * value
end

function spupdate!(p, fidxs, fvals, value)
    for (fidx, fval) in zip(fidxs, fvals)
        p.weights[fidx] += value * fval
        p.weightsacc[fidx] += p.count * value * fval
    end
    p.bias += value
    p.biasacc += p.count * value
end

spupdate!(p, fidxs, value::Bool) = spupdate!(p, fidxs, value ? 1 : -1)
function spupdate!(p, fidxs, fvals, value::Bool)
    spupdate!(p, fidxs, fvals, value ? 1 : -1)
end

update!(p, fvec, value) = spupdate!(p, 1:length(fvec), fvec, value)

end
