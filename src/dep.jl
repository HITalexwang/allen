# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Syntacto-semantic dependency graph and associated functions.
#
#   http://en.wikipedia.org/wiki/Dependency_grammar
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-03

module DepGraph

export Coder, Graph, NULLVERT, ROOTID, Vertex, coder, deledge!, dgraph, edge!, sentence

require("conllx.jl")

import Base: show

using CoNLLX

type Vertex
    id::Uint
    form::Uint
    postag::Uint
    head::Uint
    deprel::String
    dependents::Array{Uint}
    # Left and right valency (the number of left/right dependents).
    lvalency::Uint
    rvalency::Uint
    lmostdep::Vertex
    rmostdep::Vertex
    Vertex() = new()
end

function show(io::IO, v::Vertex)
    # TODO: Fix dependents.
    print(io, string("Vertex(id=$(v.id),form=$(v.form),postag=$(v.postag),",
        "head=$(v.head),deprel=$(v.deprel),dependents=TODO,",
        "valency=$(valency(v)),lvalency=$(v.lvalency),",
        "rvalency=$(v.rvalency))"))
end

function vertex(id, form, postag)
    v = Vertex()
    v.id = id
    v.form = form
    v.postag = postag
    v.head = NOHEAD
    v.deprel = NOVAL
    v.dependents = Uint[]
    v.lvalency = 0
    v.rvalency = 0
    v.lmostdep = NULLVERT
    v.rmostdep = NULLVERT
    return v
end

function vertex(id, form, postag, head, deprel)
    v = vertex(id, form, postag)
    v.head = head
    v.deprel = deprel
    return v
end

function vertex(t::Token, coder)
    vertex(t.id, encode(t.form, coder), encode(t.cpostag, coder),
        t.head, t.deprel)
end

function token(v::Vertex, coder)
    return Token(v.id, decode(v.form, coder), NOVAL, decode(v.postag, coder),
        NOVAL, NOVAL, v.head, v.deprel, NOHEAD, NOVAL)
end

const NULLID = 0
const ROOTID = 1

const NULLVERT = begin
    v = Vertex()
    v.id = NULLID
    # All codes are [1...], we can thus use 0 for form and postag.
    v.form = 0
    v.postag = 0
    v.head = NOHEAD
    v.deprel = NOVAL
    v.dependents = Array(Uint, 0)
    v.lvalency = 0
    v.rvalency = 0
    v.lmostdep = v
    v.rmostdep = v
end

ROOTTOK = Token(ROOTID, "<ROOT>", NOVAL, NOVAL, NOVAL, NOVAL, NOHEAD, NOVAL,
    NOHEAD, NOVAL)

typealias Graph Array{Vertex}

# We encode the vocabulary and PoS-tags as integers for faster featurisation.
type Coder
    enc::Dict{String, Uint}
    dec::Dict{Uint, String}
end

# TODO: What should we call this function really?
coder() = Coder(Dict{String, Uint}(), Dict{Uint, String}())

function encode(str, coder)
    code = get!(coder.enc, str, length(coder.enc) + 1)
    coder.dec[code] = str
    return code
end

function decode(code, coder)
    str = get(coder.dec, code, nothing)

    if str == nothing
        error("Unable to decode \"$code\"")
    end

    return str
end

function dgraph(sent::Sentence, coder)
    graph = Vertex[]
    push!(graph, vertex(ROOTTOK, coder))
    for tok in sent
        push!(graph, vertex(tok, coder))
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

function sentence(graph::Graph, coder)
    sent = Token[]
    for i in 2:length(graph)
        push!(sent, token(graph[i], coder))
    end

    return sent
end

# Add an unlabelled edge.
function edge!(graph::Graph, dependent::Vertex, head::Vertex)
    dependent.head = head.id
    push!(head.dependents, dependent.id)
    if dependent.id < head.id
        head.lvalency += 1
        # Is this the left-most child as-of-yet?
        if isequal(head.lmostdep, NULLVERT) || head.lmostdep.id > dependent.id
            head.lmostdep = dependent
        end
    else
        head.rvalency += 1
        # Is this the right-most child as-of-yet?
        if isequal(head.rmostdep, NULLVERT) || head.rmostdep.id < dependent.id
            head.rmostdep = dependent
        end
    end
end

# Add a labelled edge.
function edge!(graph::Graph, dependent::Vertex, head::Vertex, deprel)
    edge!(graph, dependent, head)
    dependent.deprel = deprel
end

function deledge!(graph::Graph, dependent::Vertex, head::Vertex)
    dependent.head = NOHEAD
    deleteat!(head.dependents, findfirst(head.dependents, dependent.id))
    if dependent.id < head.id
        head.lvalency -= 1
    else
        head.rvalency -= 1
    end
end

function deledge!(graph::Graph, dependent::Vertex, head::Vertex, deprel)
    deledge!(graph, dependent, head)
    dependent.deprel = NOVAL
end

function valency(vert::Vertex)
    return vert.lvalency + vert.rvalency
end

end
