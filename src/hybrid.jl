# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Hybrid from "Dynamic Programming Algorithms for Transition-Based Dependency
#   Parsers" by Kuhlmann et al. (2011).
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-06

# TODO: Is there a better way to signal the transition than using the types?
# TODO: Avoid creating undo objects if they are not needed? How?

module Hybrid

# TODO: Clean up the exports.
export FeatStruct, apply!, config, featurise, islegal, isterminal, oracle
export randoracle, transitions, undo!, NUMFEATS, featurise!

require("structs.jl")
require("conllx.jl")
require("dep.jl")

using Structs
using CoNLLX
using DepGraph

immutable Config
    stack::Vector{Vertex}
    buff::Vector{Vertex}
    graph::Graph
end

import Base: isequal
function isequal(a::Config, b::Config)
    (isequal(a.stack, b.stack) && isequal(a.buff, b.buff)
        && isequal(a.graph, b.graph))
end

import Base: show
function show(io::IO, c::Config)
    print(io, "Conf(",
        '[', join(map(v -> string(v.id), c.stack), ", "), ']',
        '|',
        '[', join(map(v -> string(v.id), reverse(c.buff)), ", "), ']',
        ')')
end

function config(sent::Sentence, coder)
    graph = dgraph(sent, coder, blind=true)
    return Config(graph[1:1], reverse(graph[2:end]), graph)
end

isterminal(c::Config) = isempty(c.buff) && length(c.stack) == 1

immutable Shift
    # Intentionally left blank.
end

function apply!(conf::Config, ::Shift)
    push!(conf.stack, pop!(conf.buff))
    return shiftundo
end

islegal(c::Config, ::Shift) = !isempty(c.buff)

import Base: isequal
isequal(::Shift, ::Shift) = true

import Base: hash
hash(::Shift) = 0x4711

immutable LeftArc
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

import Base: isequal
isequal(a::LeftArc, b::LeftArc) = a.deprel == b.deprel

import Base: hash
hash(a::LeftArc) = hash(a.deprel)

immutable RightArc
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

import Base: isequal
isequal(a::RightArc, b::RightArc) = a.deprel == b.deprel

import Base: hash
hash(a::RightArc) = hash(a.deprel)

immutable ShiftUndo
    # Intentionally left blank.
end

const shiftundo = ShiftUndo()

immutable LeftArcUndo
    dependent::Vertex
    deprel::String
    oldhead::Uint
    olddeprel::String
end

immutable RightArcUndo
    dependent::Vertex
    deprel::String
    oldhead::Uint
    olddeprel::String
end

undo!(conf::Config, ::ShiftUndo) = push!(conf.buff, pop!(conf.stack))

function undo!(conf::Config, undo::LeftArcUndo)
    head = conf.buff[end]
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

immutable FeatStruct
    id::Uint
    arg1::Uint
    arg2::Uint
    arg3::Uint
    arg4::Uint
    # XXX: Why is this slower than `fstruct`?
    #function FeatStruct(id, arg1, arg2=0, arg3=0, arg4=0)
    #    FeatStruct(id, arg1, arg2, arg3, arg4)
    #end
end

function fstruct(id, arg1, arg2=0, arg3=0, arg4=0)
    FeatStruct(id, arg1, arg2, arg3, arg4)
end

import Base: hash
function hash(a::FeatStruct)
    hash(a.id) $ hash(a.arg1) $ hash(a.arg2) $ hash(a.arg3) $ hash(a.arg4)
end

import Base: show
function show(io::IO, fs::FeatStruct)
    print(io, string("FeatStruct(id=$(fs.id), $(fs.arg1), $(fs.arg2), ",
        "$(fs.arg3), $(fs.arg4))"))
end

# Allows us to generate the highly repetitive and painful featurisation code.
#
# Generates a constant and a function:
#
#   * NUMFEATS
#   * featurise!(feats::Vector{feattype}, c::Config)
#
macro featurise(feattype, feattypef, initblk, featsblk)
    exret = Expr(:block)

    featurisef = esc(quote
        function featurise!(featids, fidbyfstruct, c::Config)
            # initblk
            # feature extraction code generated from featblk
        end
    end)

    # Nasty, the block holding the instructions of the featurise function.
    featurisefblk = featurisef.args[1].args[2].args[2]
    # Inject the initialisation block into the function.
    append!(featurisefblk.args, initblk.args)

    seenfeats = Set()
    featpos = uint(0)
    for ex in featsblk.args
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

        featpos += 1
        # Call to the feature structure function.
        fstructex = Expr(:call, feattypef, :($featpos), ex.args...)
        # Call to convert the feature structure into an id.
        idex = Expr(:call, id, :fidbyfstruct, fstructex)
        # Assign the id to its position in the output vector.
        assignex = Expr(:(=), :(featids[$featpos]), idex)
        push!(featurisefblk.args, assignex)
    end

    # Return the features.
    push!(featurisefblk.args, :(return featids))
    # Inject the function declaration into the returned expression.
    push!(exret.args, featurisef)

    # Define a constant for the total number of features.
    push!(exret.args, esc(:(const NUMFEATS = $featpos)))

    return exret
end

@featurise(FeatStruct, fstruct,
    begin
        # Short-hands.
        stack = c.stack
        buff = c.buff

        s0 = !isempty(stack) ? stack[end] : NULLVERT
        s1 = length(stack) > 1 ? stack[end-1] : NULLVERT
        s2 = length(stack) > 2 ? stack[end-2] : NULLVERT

        b0 = !isempty(buff) ? buff[end] : NULLVERT
        b1 = length(buff) > 1 ? buff[end-1] : NULLVERT

        s0_lm = lmostdep(s0)
        s1_lm = lmostdep(s1)
        b0_lm = lmostdep(b0)

        s0_rm = rmostdep(s0)
        s1_rm = rmostdep(s1)
    end,
    begin
        # Feature set used in "Training Deterministic Parsers with
        #   Non-Deterministic Oracles" by Goldberg et al. (2013) for
        #   the Hybrid model.

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
        (s1.postag, s1_rm.postag,    b0.postag)
        # Goldberg et al. used the same feature ID for the feature above
        #   and below, we correct this in the macro call.
        (s1.postag, s1_rm.postag,   s0.postag)
        (s1.postag, s1_lm.postag,   s0.postag)
        (s1.postag, s0.postag,      s0_lm.postag)
        (s1.postag, s0_rm.postag,   s0.postag)
        (s0.postag, s1_lm.postag,   s0.form)
        (s1.postag, s0.form,        s0_rm.postag)
        # Goldberg et al. used the same feature ID for the next feature as for
        #   the one two steps above, we correct this in the macro call.
        (s0.postag, s1_rm.postag,   s0.form)
        # Goldberg et al. used the same feature ID for the next feature as for
        #   the one two steps above, we correct this in the macro call.
        (s1.postag, s0.form,        s0_lm.postag)

        (s0.postag, s0_rm.postag,   b0.postag)
        # Goldberg et al. used the same feature ID for the feature above
        #   and below, we correct this in the macro call.
        (s0.postag, s0_rm.postag,   b1.postag)
        (s0.postag, s0_lm.postag,   b0.postag)
        (s0.postag, b0.postag,      b0_lm.postag)
        (s0.postag, s0_lm.postag,   b0.form)
        (s0.postag, b0.form,        b0_lm.postag)

        (s0.postag, b0.postag,  b0_lm.postag,   s0_rm.postag)
        # Golberg et al. has a typo in the ID for the following feature,
        #   however, the ID still remains unique and should have no classifier
        #   performance impact.
        (s0.postag, s1.postag,  s0_lm.postag,   s1_rm.postag)

        # Fifth order.
        (s2.postag, s1.postag,  s0.postag)
        # Goldberg et al. uses the following two duplicates that should have
        #   no impact on the classifier performance, we omit them.
        #(s1.postag, s0.postag,  b0.postag)
        #(s0.postag, b0.postag,  b1.postag)
    end
)
end
