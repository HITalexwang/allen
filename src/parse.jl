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

function predict(conf, model, fstructs)
    legaltranss = collect(filter(t -> islegal(conf, t), model.transs))

    if length(legaltranss) == 1
        # There is only one possibly transition, use it.
        return legaltranss[1]
    end

    bestscore = -Inf
    besttrans = nothing
    for trans in legaltranss
        score = testeval(model, trans, conf, fstructs)
        if score > bestscore
            bestscore = score
            besttrans = trans
        end
    end

    return besttrans
end

function parse(sent, model, fstructs)
    conf = config(sent, model.coder)
    while !isterminal(conf)
        trans = predict(conf, model, fstructs)
        apply!(conf, trans)
    end

    return sentence(conf.graph, model.coder)
end

# TODO: Implement LAS as well.
export evaluate
function evaluate(model, goldsents)
    fstructs = Array(FeatStruct, NUMFEATS)
    total = 0
    correct = 0
    for goldsent in goldsents
        predsent = parse(goldsent, model, fstructs)
        for (goldtok, predtok) in zip(goldsent, predsent)
            total += 1
            if predtok.head == goldtok.head
                correct += 1
            end
        end
    end

    if correct < 1
        return 0.0
    else
        return correct / total
    end
end

function testeval(model, trans, conf, fstructs)
    # Short-hands.
    weights = model.weights
    fidbyfstruct = model.fidbyfstruct

    # Apply the transition.
    undo = apply!(conf, trans)
    # Featurise the resulting configuration.
    fstructs = featurise!(fstructs, conf)

    score = 0.0
    for featstruct in fstructs
        featid = get(fidbyfstruct, featstruct, 0)
        # Only consider previously observed features.
        if featid > 0
            score += weights[featid]
        end
    end

    # Revert to the original configuration.
    undo!(conf, undo)

    return score
end

function traineval(cache, model, trans, conf)
    # Short-hands.
    weights = model.weights
    fidbyfstruct = model.fidbyfstruct
    fstructs = cache.fstructsbytrans[trans]
    featids = cache.fidsbytrans[trans]

    # Apply the transition.
    undo = apply!(conf, trans)
    # Featurise the resulting configuration.
    featurise!(fstructs, conf)
    for (featidx, featstruct) in enumerate(fstructs)
        featid = get!(fidbyfstruct, featstruct, length(fidbyfstruct) + 1)
        featids[featidx] = featid
    end

    # Revert to the original configuration.
    undo!(conf, undo)

    # Extend the weight vector if we observed new features.
    numfeats = length(fidbyfstruct)
    if length(weights) < numfeats
        oldsize = length(weights)
        resize!(weights, numfeats)
        # Initialise the new feature weights.
        weights[oldsize + 1:end] = 0
    end

    # Calculate feats' * weights.
    score = 0.0
    for featid in featids
        score += weights[featid]
    end

    return score
end


function trainpred(train, model, conf)
    goldtrans = oracle(conf)
    legaltranss = collect(filter(t -> islegal(conf, t), model.transs))

    if length(legaltranss) == 1
        besttrans = legaltranss[1]
        # There is only one possibly transition, no need to evaluate.
        return (goldtrans, besttrans)
    end

    # TODO: Can this be made prettier and type stable?
    besttrans = nothing
    bestscore = -Inf
    for trans in legaltranss
        score = traineval(train.cache, model, trans, conf)

        if !isequal(trans, goldtrans)
            # Add the margin.
            # TODO: Extract into an argument.
            score += 1
        end

        if score > bestscore
            bestscore = score
            besttrans = trans
        end
    end

    return (goldtrans, besttrans)
end

type Model
    # XXX: I dislike this... how can we fix it?
    #   type(Symbol, Label)?
    transs
    weights::Vector{Float64}
    fidbyfstruct::Dict{FeatStruct, Uint}
    coder::Coder
end

Model() = Model(transitions(), Float64[], Dict{FeatStruct, Uint}(), Coder())

type Cache
    fstructsbytrans::Dict{Any,Vector{FeatStruct}}
    fidsbytrans::Dict{Any,Vector{Uint}}
end

function cache(model)
    # Pre-allocate for each transition.
    fstructsbytrans = Dict{Any,Vector{FeatStruct}}()
    fidsbytrans = Dict{Any,Vector{Uint}}()
    for trans in model.transs
        fstructsbytrans[trans] = Array(FeatStruct, NUMFEATS)
        fidsbytrans[trans] = Array(Uint, NUMFEATS)
    end

    return Cache(fstructsbytrans, fidsbytrans)
end

type Train
    epoch::Uint
    epochs::Uint
    sents::Sentences
    model::Model
    cache::Cache
    earlyupdates::Bool
end

function train(sents::Sentences; epochs=0, model=nothing, earlyupdates=false)
    if model == nothing
        model = Model()
    end

    return Train(0, epochs, sents, model, cache(model), earlyupdates)
end

start(::Train) = nothing

function next(itr::Train, nada)
    itr.epoch += 1

    # Short-hand.
    model = itr.model

    # Shuffle the sentences before for each pass.
    shuffle!(itr.sents)
    for sent in itr.sents
        # Parse the sentence.
        conf = config(sent, model.coder)
        while !isterminal(conf)
            goldtrans, besttrans = trainpred(itr, model, conf)

            if !isequal(besttrans, goldtrans)
                goldfids = itr.cache.fidsbytrans[goldtrans]
                bestfids = itr.cache.fidsbytrans[besttrans]
                # Update the weight vector (perceptron update).
                model.weights[goldfids] .+= 1
                model.weights[bestfids] .-= 1

                if itr.earlyupdates
                    # Skip to the next sentence.
                    break
                end
            end

            # Proceed along the gold path.
            apply!(conf, goldtrans)
        end
    end

    return (model, nothing)
end

# Helper function to more naturally progress the iterator by masking the
#   internals of the iterator protocol.
next(itr::Train) = next(itr, nothing)[1]

done(itr::Train, nada) = itr.epochs != 0 && itr.epoch >= itr.epochs

end
