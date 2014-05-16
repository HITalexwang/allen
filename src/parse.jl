# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Convenience functions for syntactic parsing.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-07

module Parse

export done, isequal, next, parse, start, train

import Base: done, isequal, start, next

require("conllx.jl")
require("dep.jl")
require("hybrid.jl")

using CoNLLX
using DepGraph
using Hybrid

function parse(sent::Sentence, predict::Function, coder)
    conf = config(sent, coder)
    while !isterminal(conf)
        trans = predict(conf)
        apply!(conf, trans)
    end

    return sentence(conf.graph, coder)
end

# TODO: Is it a good idea to override these?
# TODO: This is really a parsing specifing `isequal` implementation.
function isequal(a::Token, b::Token)
    return (a.id == b.id && a.form == b.form && a.head == b.head
        && a.deprel == b.deprel)
end

function isequal(a::Sentence, b::Sentence)
    # TODO: Prettify using map etc.
    if length(a) != length(b)
        return false
    end

    for (ae, be) in zip(a, b)
        if !isequal(ae, be)
            return false
        end
    end

    return true
end

function evaluate(weights, featids, trans, conf)
    # Apply the transition.
    undo = apply!(conf, trans)

    # Featurise the resulting configuration.
    featrows = Int[]
    feats = featurise(conf)
    for feat in feats
        featid = get!(featids, feat, length(featids) + 1)
        push!(featrows, featid)
    end

    # Revert to the original configuration.
    undo!(conf, undo)

    numfeats = length(featids)

    feats = sparsevec(featrows,
        # TODO: USE spones... somehow...
        ones(Float64, length(featrows)), numfeats)

    # Extend the weight vector if we observed new features.
    if length(weights) != numfeats
        oldsize = length(weights)
        resize!(weights, numfeats)
        weights[oldsize + 1:end] = 0
    end

    score = (feats.' * weights)[1]

    return (score, feats)
end

function trainpred(weights, featids, transs, conf)
    goldtrans = oracle(conf)
    legaltranss = collect(filter(t -> islegal(conf, t), transs))

    if length(legaltranss) == 1
        besttrans = legaltranss[1]
        # There is only one possibly transition, use it.
        return (goldtrans, nothing, besttrans, nothing)
    end

    # TODO: Can this be made prettier and type stable?
    besttrans = nothing
    bestscore = -Inf
    bestfeats = nothing
    goldscore = nothing
    goldfeats = nothing

    for trans in legaltranss
        score, feats = evaluate(weights, featids, trans, conf)

        if !isequal(trans, goldtrans)
            # Add the margin.
            # TODO: Extract into an argument.
            score += 1
        else
            goldscore = score
            goldfeats = feats
        end

        if score > bestscore
            besttrans = trans
            bestscore = score
            bestfeats = feats
        end
    end

    return (goldtrans, goldfeats, besttrans, bestfeats)
end

const EARLYUPDATES = false

type Model
    # XXX: I dislike this... how can we fix it?
    #   type(Symbol, Label)?
    transs
    weights::Array{Float64, 1}
    featids::Dict{FeatStruct, Uint}
    coder::Coder
end

# TODO: Use sizehint for featids?
model() = Model(transitions(), Float64[], Dict{FeatStruct, Uint}(), coder())

type Train
    epoch::Uint
    epochs::Uint
    sents::Sentences
    model::Model
end

# TODO: I dislike the variable name `usemodel`.
function train(sents::Sentences; epochs=0, usemodel=nothing)
    if usemodel == nothing
        usemodel = model()
    end

    return Train(0, epochs, sents, usemodel)
end

start(::Train) = nothing

function next(itr::Train, nada)
    itr.epoch += 1

    # Short-hand.
    model = itr.model

    # Shuffle the sentences before for each pass.
    shuffle!(itr.sents)
    # TODO: Minibatches.
    for sent in itr.sents
        # Parse the sentence.
        conf = config(sent, model.coder)
        while !isterminal(conf)
            goldtrans, goldfeats, besttrans, bestfeats = trainpred(
                model.weights, model.featids, model.transs, conf)

            if !isequal(besttrans, goldtrans)
                # Update the weight vector (perceptron update).
                rows, _, vals = findnz(goldfeats)
                model.weights[rows] += vals
                rows, _, vals = findnz(bestfeats)
                model.weights[rows] -= vals
            end

            if EARLYUPDATES
                # Skip to the next sentence.
                break
            else
                # Proceed along the gold path.
                # TODO: Could use a dynamic oracle for exploration.
                apply!(conf, goldtrans)
            end
        end
    end

    return (model, nothing)
end

# Helper function to more naturally progress the iterator by masking the
#   internals of the iterator protocol.
next(itr::Train) = next(itr, nothing)[1]

done(itr::Train, nada) = itr.epochs != 0 && itr.epoch >= itr.epochs

end
