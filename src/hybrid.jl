# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Hybrid from "Dynamic Programming Algorithms for Transition-Based Dependency
#   Parsers" by Kuhlmann et al. (2011).
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-06

# TODO: Is there a better way to signal the transition than using the types?
# TODO: Avoid creating undo objects if they are not needed? How?

module Hybrid

export apply!, config, featurise, islegal, isterminal, oracle, randoracle

import Base: show

using DepGraph
using CoNLLX

type Config
    stack::Array{Vertex}
    buff::Array{Vertex}
    graph::Graph
end

function show(io::IO, c::Config)
    print(io, "Conf(",
        '[', join(map(v -> string(v.id), conf.stack), ", "), ']',
        '|',
        '[', join(map(v -> string(v.id), reverse(conf.buff)), ", "), ']',
        ')')
end

function config(sent::Sentence)
    graph = dgraph(sent)
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

type LeftArc
    deprel::String
end

function apply!(conf::Config, trans::LeftArc)
    head = conf.buff[end]
    dependent = pop!(conf.stack)

    if trans.deprel == NOVAL
        edge!(conf.graph, dependent, head)
    else
        edge!(conf.graph, dependent, head, trans.deprel)
    end

    return LeftArcUndo(dependent, trans.deprel)
end

function islegal(c::Config, ::LeftArc)
    return !isempty(c.stack) && !isempty(c.buff) && c.stack[1].id != ROOTID
end

type RightArc
    deprel::String
end

function apply!(conf::Config, trans::RightArc)
    dependent = pop!(conf.stack)
    head = conf.stack[end]

    if trans.deprel == NOVAL
        edge!(conf.graph, dependent, head)
    else
        edge!(conf.graph, dependent, head, trans.deprel)
    end

    return RightArcUndo(dependent, trans.deprel)
end

islegal(c::Config, ::RightArc) = length(c.stack) > 1

type ShiftUndo
    # Intentionally left blank.
end

const shiftundo = ShiftUndo()

type LeftArcUndo
    dependent::Vertex
    deprel::String
end

type RightArcUndo
    dependent::Vertex
    deprel::String
end

undo!(conf::Config, undo::ShiftUndo) = push!(conf.buff, !pop(conf.stack))

function undo!(conf::Config, undo::LeftArcUndo)
    deledge!(conf.graph, undo.dependent, conf.buff[end])
    push!(conf.buff, undo.dependent)
end

function undo!(undo::RightArcUndo)
    deledge!(conf.graph, undo.dependent, conf.stack[end])
    push!(conf.stack, undo.dependent)
end

function oracle(conf::Config)
    if !isempty(conf.stack) && !isempty(conf.buff)
        s_0 = conf.stack[end]
        b_0 = conf.buff[end]
        if s_0.head == b_0.id
            return LeftArc(s_0.deprel)
        end
    end

    if length(conf.stack) < 2
        return Shift()
    end
        
    s_0 = conf.stack[end]
    s_1 = conf.stack[end-1]
    # Require that a head is attached and that ther are no dependents
    #   remaining in the buffer.
    if s_0.head == s_1.id && !any(v -> v.head == s_0.id, conf.buff)
        return RightArc(s_0.deprel)
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

const NULLVERT = Vertex(NULLID, "<NULL>", NOVAL, NOHEAD, NOVAL, Uint[], 0, 0)

# TODO: Expand to the full feature set.
# TODO: Use an iterator instead.
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

    for (name, tok) in (
        ("s0", s0),
        ("s1", s1),
        ("s2", s2),
        ("b0", b0),
        ("b1", b1),
        )
        push!(feats, string(name, ".form|", tok.form))
    end

    return feats
end

end
