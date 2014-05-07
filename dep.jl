#!/usr/bin/env julia
# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Syntacto-semantic dependency graph and associated functions.
#
#   http://en.wikipedia.org/wiki/Dependency_grammar
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-03

module DepGraph

import Base: show

import CoNLLX: NOHEAD, NOVAL, Sentence, Token

type Vertex
    id::Uint
    form::String
    postag::String
    head::Uint
    deprel::String
    dependents::Array{Uint}
    # Left and right valency (the number of left/right dependents).
    lvalency::Uint
    rvalency::Uint
end

function show(io::IO, v::Vertex)
    # TODO: Fix dependents.
    print(io, string("Vertex(id=$(v.id),form=$(v.form),postag=$(v.postag),",
        "head=$(v.head),deprel=$(v.deprel),dependents=TODO,",
        "valency=$(valency(v)),lvalency=$(v.lvalency),",
        "rvalency=$(v.rvalency))"))
end

function vertex(t::Token)
    return Vertex(t.id, t.form, t.cpostag, t.head, t.deprel, Uint[], 0, 0)
end

function token(v::Vertex)
    return Token(v.id, v.form, NOVAL, v.postag, NOVAL, NOVAL, v.head,
        v.deprel, NOHEAD, NOVAL)
end

const ROOTID = 1

root() = Vertex(ROOTID, "ROOT", NOVAL, NOHEAD, NOVAL, Uint[], 0, 0)

typealias Graph Array{Vertex}

function dgraph(sent::Sentence)
    graph = Vertex[]
    push!(graph, root())
    for tok in sent
        push!(graph, vertex(tok))
    end

    # Add existing information (if any).
    for i in 2:length(graph)
        vert = graph[i]
        if vert.head != NOHEAD
            if vert.deprel == NOVAL
                edge!(graph, vert, graph[vert.head])
            else
                edge!(graph, vert, graph[vert.head], vert.deprel)
            end
        end
    end

    return graph
end

function sentence(graph::Graph)
    sent = Token[]
    for i in 2:length(graph)
        push!(sent, token(graph[i]))
    end

    return sent
end

# Add an unlabelled edge.
function edge!(graph::Graph, dependent::Vertex, head::Vertex)
    dependent.head = head.id
    push!(head.dependents, dependent.id)
    if dependent.id < head.id
        head.lvalency += 1
    else
        head.rvalency += 1
    end
end

# Add a labelled edge.
function edge!(graph::Graph, dependent::Vertex, head::Vertex, deprel)
    edge!(graph, dependent, head)
    dependent.deprel = deprel
end

function valency(vert::Vertex, right=false, left=false)
    if left & !right
        return vert.lvalency
    elseif right & !left
        return vert.rvalency
    else
        return vert.lvalency + vert.rvalency
    end
end

#import CoNLLX.conllxparse
#a = collect(conllxparse(open("res/debug.conllx")))
#a = collect(conllxparse(open("res/debug.conllx")))
#a = collect(conllxparse(open("foo.conllx")))

#b = dgraph(a[1])
#println(b)
#c = sentence(b)
#println(c)

end
