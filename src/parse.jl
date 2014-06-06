# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Convenience functions for syntactic parsing.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-07

# TODO: Each perceptron could have its own fidx dictionary, sparser?
# TODO: If so, then they would also need to be independently extended in size.

module Parse

export done, isequal, length, next, parse, start, train

require("structs.jl")
require("conllx.jl")
require("dep.jl")
require("hybrid.jl")
require("percep.jl")

using Structs
using CoNLLX
using DepGraph
using Hybrid
using Percep

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
import Base: isequal
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

function predict(conf, model, featids)
    legaltranss = collect(filter(t -> islegal(conf, t), model.transs))

    if length(legaltranss) == 1
        # There is only one possibly transition, use it.
        return legaltranss[1]
    end

    bestscore = -Inf
    besttrans = nothing
    for trans in legaltranss
        score = testeval(model, trans, conf, featids)
        if score > bestscore
            bestscore = score
            besttrans = trans
        end
    end

    return besttrans
end

function parse(sent, model, featids)
    conf = config(sent, model.coder)
    while !isterminal(conf)
        trans = predict(conf, model, featids)
        apply!(conf, trans)
    end

    return sentence(conf.graph, model.coder)
end

# TODO: Implement LAS as well.
export evaluate
function evaluate(model, goldsents)
    # Cache the feature id vector between parses.
    featids = Array(Uint, NUMFEATS)
    total = 0
    correct = 0
    for goldsent in goldsents
        predsent = parse(goldsent, model, featids)
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

function testeval(model, trans, conf, featids)
    # Short-hands.
    weights = model.percepbytrans[trans].weights
    bias = model.percepbytrans[trans].bias
    fidbyfstruct = model.fidbyfstruct

    # Apply the transition.
    undo = apply!(conf, trans)
    # Featurise the resulting configuration.
    featids = featurise!(featids, fidbyfstruct, conf)

    score = bias
    for featid in featids
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
    percep = model.percepbytrans[trans]
    fidbyfstruct = model.fidbyfstruct
    featids = cache.fidsbytrans[trans]

    # Apply the transition.
    undo = apply!(conf, trans)
    # Featurise the resulting configuration.
    featurise!(featids, fidbyfstruct, conf)

    # Revert to the original configuration.
    undo!(conf, undo)

    # Extend the weight vector if we observed new features.
    numfeats = length(fidbyfstruct)
    if length(percep.weights) < numfeats
        grow!(model, numfeats)
    end

    # Calculate feats' * weights + bias.
    spscore(featids, percep)
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

type TrainModel
    # XXX: I dislike this... how can we fix it?
    #   type(Symbol, Label)?
    transs
    percepbytrans::Dict{Any,AvgPerceptron}
    fidbyfstruct::Identifier{FeatStruct,Uint}
    coder::Coder
end

function TrainModel()
    transs = transitions()
    dic = Dict{Any,AvgPerceptron}()
    for trans in transs
        dic[trans] = AvgPerceptron()
    end
    TrainModel(transs, dic, Identifier(FeatStruct, Uint), Coder())
end

function grow!(model::TrainModel, size)
    for (_, p) in model.percepbytrans
        extend!(p, size)
    end
    model
end

function update!(m, goldtrans, goldfids, besttrans, bestfids)
    spupdate!(m.percepbytrans[goldtrans], goldfids, true)
    spupdate!(m.percepbytrans[besttrans], bestfids, false)
end

type Model
    transs
    percepbytrans::Dict{Any,Perceptron}
    fidbyfstruct::Identities{FeatStruct,Uint}
    coder::Coder
end

# Finalise a model in training to construct the resulting model.
function Model(m)
    dic = Dict{Any,Perceptron}()
    for (trans, p) in m.percepbytrans
        dic[trans] = Perceptron(p)
    end
    # TODO: Should be a deep copy of transs, fidbyfstruct and coder?
    #   This slows down the training though...
    Model(m.transs, dic, Identities(m.fidbyfstruct), m.coder)
end

import Base: length
function length(model::Union(TrainModel,Model))
    for (_, p) in model.percepbytrans
        # We intentionally short-circuit since all perceptrons have the same
        #   number of weights.
        return length(p.weights)
    end
end

type Cache
    fidsbytrans::Dict{Any,Vector{Uint}}
end

function cache(model)
    # Pre-allocate for each transition.
    fidsbytrans = Dict{Any,Vector{Uint}}()
    for trans in model.transs
        fidsbytrans[trans] = Array(Uint, NUMFEATS)
    end

    return Cache(fidsbytrans)
end

type Train
    epoch::Uint
    epochs::Uint
    sents::Sentences
    trainmodel::TrainModel
    cache::Cache
    earlyupdates::Bool
end

function train(sents; epochs=0, earlyupdates=false)
    tmodel = TrainModel()
    Train(0, epochs, sents, tmodel, cache(tmodel), earlyupdates)
end

import Base: start
start(::Train) = nothing

import Base: next
function next(itr::Train, nada)
    itr.epoch += 1

    # Short-hands.
    tmodel = itr.trainmodel
    cache = itr.cache

    # Shuffle the sentences before for each pass.
    shuffle!(itr.sents)
    for sent in itr.sents
        # Parse the sentence.
        conf = config(sent, tmodel.coder)
        while !isterminal(conf)
            goldtrans, besttrans = trainpred(itr, tmodel, conf)

            if !isequal(besttrans, goldtrans)
                goldfids = itr.cache.fidsbytrans[goldtrans]
                bestfids = itr.cache.fidsbytrans[besttrans]
                # Update the weight vectors.
                update!(tmodel, goldtrans, goldfids, besttrans, bestfids)

                if itr.earlyupdates
                    # Skip to the next sentence.
                    break
                end
            end

            # Proceed along the gold path.
            apply!(conf, goldtrans)
        end
    end

    return (Model(tmodel), nothing)
end

# Helper function to more naturally progress the iterator by masking the
#   internals of the iterator protocol.
next(itr::Train) = next(itr, nothing)[1]

import Base: done
done(itr::Train, nada) = itr.epochs != 0 && itr.epoch >= itr.epochs

end
