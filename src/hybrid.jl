# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Hybrid from "Dynamic Programming Algorithms for Transition-Based Dependency
#   Parsers" by Kuhlmann et al. (2011).
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-06

# TODO: Is there a better way to signal the transition than using the types?
# TODO: Avoid creating undo objects if they are not needed? How?

module Hybrid

# TODO: How do we write a long export statement?
export FeatStruct, apply!, config, featurise, islegal, isterminal, oracle, randoracle, transitions, undo!

import Base: hash, isequal, show

using DepGraph
using CoNLLX

type Config
    stack::Array{Vertex}
    buff::Array{Vertex}
    graph::Graph
end

function show(io::IO, c::Config)
    print(io, "Conf(",
        '[', join(map(v -> string(v.id), c.stack), ", "), ']',
        '|',
        '[', join(map(v -> string(v.id), reverse(c.buff)), ", "), ']',
        ')')
end

function config(sent::Sentence, coder)
    graph = dgraph(sent, coder)
    return Config(graph[1:1], reverse(graph[2:end]), graph)
end

isterminal(c::Config) = isempty(c.buff) && length(c.stack) == 1

type Shift
    # Intentionally left blank.
end

function apply!(conf::Config, ::Shift)
    push!(conf.stack, pop!(conf.buff))
    return shiftundo
end

islegal(c::Config, ::Shift) = !isempty(c.buff)

isequal(::Shift, ::Shift) = true

type LeftArc
    deprel::String
end

function apply!(conf::Config, trans::LeftArc)
    head = conf.buff[end]
    dependent = pop!(conf.stack)

    undo = LeftArcUndo(dependent, trans.deprel, dependent.head,
        dependent.deprel)

    if trans.deprel == NOVAL
        edge!(conf.graph, dependent, head)
    else
        edge!(conf.graph, dependent, head, trans.deprel)
    end

    return undo
end

function islegal(c::Config, ::LeftArc)
    return !isempty(c.stack) && !isempty(c.buff) && c.stack[end].id != ROOTID
end

isequal(a::LeftArc, b::LeftArc) = a.deprel == b.deprel

type RightArc
    deprel::String
end

function apply!(conf::Config, trans::RightArc)
    dependent = pop!(conf.stack)
    head = conf.stack[end]

    undo = RightArcUndo(dependent, trans.deprel, dependent.head,
        dependent.deprel)

    if trans.deprel == NOVAL
        edge!(conf.graph, dependent, head)
    else
        edge!(conf.graph, dependent, head, trans.deprel)
    end

    return undo
end

islegal(c::Config, ::RightArc) = length(c.stack) > 1

isequal(a::RightArc, b::RightArc) = a.deprel == b.deprel

type ShiftUndo
    # Intentionally left blank.
end

const shiftundo = ShiftUndo()

type LeftArcUndo
    dependent::Vertex
    deprel::String
    oldhead::Uint
    olddeprel::String
end

type RightArcUndo
    dependent::Vertex
    deprel::String
    oldhead::Uint
    olddeprel::String
end

undo!(conf::Config, ::ShiftUndo) = push!(conf.buff, pop!(conf.stack))

function undo!(conf::Config, undo::LeftArcUndo)
    head = config.buff[end]
    dependent = undo.dependent

    deledge!(conf.graph, dependent, head)

    # Preserve any previous gold annotations.
    dependent.head = undo.oldhead
    dependent.deprel = undo.olddeprel

    push!(conf.stack, dependent)
end

function undo!(conf::Config, undo::RightArcUndo)
    head = conf.stack[end]
    dependent = undo.dependent

    deledge!(conf.graph, dependent, head)

    # Preserve any previous gold annotations.
    dependent.head = undo.oldhead
    dependent.deprel = undo.olddeprel

    push!(conf.stack, dependent)
end

# TODO: Variant with all deprels!
function oracle(conf::Config)
    if !isempty(conf.stack) && !isempty(conf.buff)
        s0 = conf.stack[end]
        b0 = conf.buff[end]
        if s0.head == b0.id
            return LeftArc(NOVAL)
            #return LeftArc(s0.deprel)
        end
    end

    if length(conf.stack) < 2
        return Shift()
    end

    s0 = conf.stack[end]
    s1 = conf.stack[end-1]
    # Require that a head is attached and that ther are no dependents
    #   remaining in the buffer.
    if s0.head == s1.id && !any(v -> v.head == s0.id, conf.buff)
        return RightArc(NOVAL)
        #return RightArc(s0.deprel)
    end

    return Shift()
end

# TODO: Variant with all deprels!
function transitions()
    return (Shift(), LeftArc(NOVAL), RightArc(NOVAL))
end

# Return a random legal transition (useful for debugging).
function randoracle(c::Config)
    legal = filter(t -> islegal(c, t), collect(transitions()))
    return legal[rand(1:end)]
end

type FeatStruct
    id::Uint
    arg1::Uint
    arg2::Uint
    arg3::Uint
    arg4::Uint
end

function hash(a::FeatStruct)
    hash(a.id) $ hash(a.arg1) $ hash(a.arg2) $ hash(a.arg3) $ hash(a.arg4)
end

function isequal(a::FeatStruct, b::FeatStruct)
    (a.id == b.id && a.arg1 == b.arg1 && a.arg2 == b.arg2 && a.arg3 == b.arg3
        && a.arg4 == b.arg4)
end

function fstruct(id, arg1, arg2=0, arg3=0, arg4=0)
    FeatStruct(id, arg1, arg2, arg3, arg4)
end

# Allows us to generate the highly repetitive and painful featurisation code.
macro featinject(feattype, fstructf, feats)
    exret = Expr(:block)

    seenfeats = Set()
    featid = uint(0)
    for ex in feats.args
        # Ignore embedded line information.
        if ex.head == :line
            continue
        end
        # We assume that the non-id feature arguments are given as tuples.
        if ex.head != :tuple
            warn("ignoring expression $ex")
            continue
        end

        @assert !in(ex, seenfeats) "feature template duplicate: $ex"
        push!(seenfeats, ex)

        featid += 1
        # Call to the feature structure function.
        fstructex = Expr(:call, fstructf, :($featid), ex.args...)
        # Assignment into the feature vector.
        #   := won't work, and below is the best hack I can come up with.
        assignex = Expr(symbol("="), :(fvec[$featid]), fstructex)
        push!(exret.args, assignex)
    end

    # Fixed-size feature allocation prior to the feature extraction.
    allocex = Expr(symbol("="), :fvec, :(Array($feattype, $featid)))
    unshift!(exret.args, allocex)
    # Return the feature vector.
    push!(exret.args, :(return fvec))

    return exret
end

# TODO: Use a co-routine, slower?
# Feature set used in "Training Deterministic Parsers with Non-Deterministic
#   Oracles" by Goldberg et al. (2013).
# TODO: Can we boost speed by eliminating some struct accesses using locals?
# TODO: Enable inbounds later on?
function featurise(c::Config)
    # Short-hands.
    stack = c.stack
    buff = c.buff

    s0 = !isempty(stack) ? stack[end] : NULLVERT
    s1 = length(stack) > 1 ? stack[end-1] : NULLVERT
    s2 = length(stack) > 2 ? stack[end-2] : NULLVERT

    b0 = !isempty(buff) ? buff[end] : NULLVERT
    b1 = length(buff) > 1 ? buff[end-1] : NULLVERT

    # Slight macro abuse to inject the feature templates.
    @featinject FeatStruct fstruct begin
        # First order.
        (s0.form, )
        (s0.postag, )
        (s0.form,   s0.postag)
        (s1.form, )
        (s1.postag, )
        (s1.form,   s1.postag)
        (b0.form, )
        (b0.postag, )
        (b0.form,   b0.postag)
        (b1.form, )
        (b1.postag, )
        (b1.form,   b1.postag)

        # Second order.
        (s0.form,   s1.form)
        (s0.postag, s1.postag)
        (s0.postag, b0.postag)

        (s0.form,   s0.postag,  s1.postag)
        (s0.postag, s1.form,    s1.postag)
        (s0.form,   s1.form,    s1.postag)
        (s0.form,   s0.postag,  s1.form)
        # Goldberg et al. repeats an earlier feature template here. This is
        #   most likely an error, we correct it in order to conform with
        #   the next template group.
        #(s0.form,   s0.postag,  s1.postag)
        (s1.form,   s1.postag,  b0.postag)

        (s0.form,   b0.form)
        # Goldberg et al. repeats a template here, we omit it.
        #(s0.postag, b0.postag)
        (s0.postag, b1.postag)

        (s0.postag, b0.form,    b0.postag)
        (s0.form,   b0.form,    b0.postag)
        (s0.form,   s0.postag,  b0.form)
        (b0.form,   b0.postag,  b1.postag)

        # Third order.
        (s0.postag, b0.postag,  b1.postag)
        (s1.postag, s0.postag,  b0.postag)
        (s0.form,   b0.postag,  b1.postag)
        (s1.postag, s0.form,    b0.postag)

        # Fourth order.
        (s1.postag, s1.rmostdep.postag, b0.postag)
        # Goldberg et al. used the same feature ID for the feature above
        #   and below, we correct this in the macro call.
        (s1.postag, s1.rmostdep.postag, s0.postag)
        (s1.postag, s1.lmostdep.postag, s0.postag)
        (s1.postag, s0.postag,          s0.lmostdep.postag)
        (s1.postag, s0.rmostdep.postag, s0.postag)
        (s0.postag, s1.lmostdep.postag, s0.form)
        (s1.postag, s0.form,            s0.rmostdep.postag)
        # Goldberg et al. used the same feature ID for the next feature as for
        #   the one two steps above, we correct this in the macro call.
        (s0.postag, s1.rmostdep.postag, s0.form)
        # Goldberg et al. used the same feature ID for the next feature as for
        #   the one two steps above, we correct this in the macro call.
        (s1.postag, s0.form,            s0.lmostdep.postag)

        (s0.postag, s0.rmostdep.postag, b0.postag)
        # Goldberg et al. used the same feature ID for the feature above
        #   and below, we correct this in the macro call.
        (s0.postag, s0.rmostdep.postag, b1.postag)
        (s0.postag, s0.lmostdep.postag, b0.postag)
        (s0.postag, b0.postag,          b0.lmostdep.postag)
        (s0.postag, s0.lmostdep.postag, b0.form)
        (s0.postag, b0.form,            b0.lmostdep.postag)

        (s0.postag, b0.postag,  b0.lmostdep.postag, s0.rmostdep.postag)
        # Golberg et al. has a typo in the ID for the following feature,
        #   however, the ID still remains unique and should have no classifier
        #   performance impact.
        (s0.postag, s1.postag,  s0.lmostdep.postag, s1.rmostdep.postag)

        # Fifth order.
        (s2.postag, s1.postag,  s0.postag)
        # Goldberg et al. uses the following two duplicates that should have
        #   no impact on the classifier performance, we omit them.
        #(s1.postag, s0.postag,  b0.postag)
        #(s0.postag, b0.postag,  b1.postag)
    end
end

end
