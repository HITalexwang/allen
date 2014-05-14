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
export apply!, config, featurise, islegal, isterminal, oracle, randoracle, transitions, undo!

import Base: isequal, show

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
    deledge!(conf.graph, undo.dependent, conf.buff[end])
    undo.dependent.head = undo.oldhead
    undo.dependent.deprel = undo.olddeprel
    push!(conf.stack, undo.dependent)
end

function undo!(conf::Config, undo::RightArcUndo)
    deledge!(conf.graph, undo.dependent, conf.stack[end])
    undo.dependent.head = undo.oldhead
    undo.dependent.deprel = undo.olddeprel
    push!(conf.stack, undo.dependent)
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

const NULLID = 0
@assert NULLID != ROOTID

# All codes are [1...], we can thus use 0 for the null vertex codes.
const NULLVERT = Vertex(NULLID, 0, 0, NOHEAD, NOVAL, Array(Uint, 0), 0, 0)

# TODO: Use a co-routine.
# Feature set used in "Training Deterministic Parsers with Non-Deterministic
#   Oracles" by Goldberg et al. (2013).
# XXX: Mention bug-fix, mail Goldberg.
# TODO: How does redshift make this so damn fast?
function featurise(c::Config)
    feats = String[]

    # Short-hands.
    stack = c.stack
    buff = c.buff

    s0 = !isempty(stack) ? stack[end] : NULLVERT
    s1 = length(stack) > 1 ? stack[end-1] : NULLVERT
    s2 = length(stack) > 2 ? stack[end-2] : NULLVERT

    b0 = !isempty(buff) ? buff[end] : NULLVERT
    b1 = length(buff) > 1 ? buff[end-1] : NULLVERT

    # Single tokens.
    for (name, tok) in (
        ("s0", s0),
        ("s1", s1),
        ("b0", b0),
        ("b1", b1),
        )
        push!(feats, string(name, ".form", "=>", tok.form))
        push!(feats, string(name, ".postag", "=>", tok.postag))
        push!(feats, string(name, ".form", "|", name, ".postag",
            "=>", tok.form, "|", tok.postag))
    end

    # Pairs of tokens.
    for (aname, atok, bname, btok, cname, ctok) in (
        ("s0", s0, "s1", s1, "b0", b0),
        ("s0", s0, "b0", b0, "b1", b1),
        )
        # a.form,   b.form
        push!(feats, string(aname, ".form", "|", bname, ".form",
            "=>", atok.form, "|", btok.form))
        # a.pos,    b.pos
        push!(feats, string(aname, ".postag", "|", bname, ".postag",
            "=>", atok.postag, "|", btok.postag))
        # a.pos,    c.pos
        push!(feats, string(aname, ".postag", "|", cname, ".postag",
            "=>", atok.postag, "|", ctok.postag))

        # a.form,   a.pos,  b.pos
        push!(feats, string(aname, ".form", "|", aname, ".postag", "|",
            bname, ".postag",
            "=>", atok.form, "|", atok.postag, "|", btok.postag))
        # a.pos,    b.form, b.pos
        push!(feats, string(aname, ".postag", "|", bname, ".form", "|",
            bname, ".postag",
            "=>", atok.postag, "|", btok.form, "|", btok.postag))
        # a.form,   b.form, b.pos
        push!(feats, string(aname, ".form", "|", bname, ".form", "|",
            bname, ".postag",
            "=>", atok.form, "|", btok.form, "|", btok.postag))
        # a.form,   a.pos,  b.form
        push!(feats, string(aname, ".form", "|", aname, ".postag", "|",
            bname, ".form",
            "=>", atok.form, "|", atok.postag, "|", btok.form))
        # Goldberg et al. (2013) repeats the first feature template here
        #   for a=s0 and b=s1. This is most likely an error and we correct it.
        # b.form,   b.pos,  c.pos
        push!(feats, string(bname, ".form", "|", bname, ".postag", "|",
            cname, ".postag",
            "=>", btok.form, "|", btok.postag, "|", ctok.postag))
    end

    # Triplets of tokens.
    # TODO:

    # Quadruplets of tokens.
    # TODO:

    # Quintuplets of tokens.
    # TODO:

    return feats
end

end
