# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Syntacto-semantic dependency graph and associated functions.
#
#   http://en.wikipedia.org/wiki/Dependency_grammar
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-03

module DepGraph

# Dependency graph.
export
    Vertex, Graph, dgraph, sentence,
    edge!, deledge!,
    lmostdep, rmostdep,
    NULLVERT, ROOTID

# String to ID encoder/decoder.
export Coder, encode, decode

require("conllx.jl")

using Base.Collections
using Base.Order

using CoNLLX

type Vertex
    id::Uint
    form::Uint
    postag::Uint
    head::Uint
    deprel::String
    # TODO: Should be an ordered set.
    ldependents::Vector{Vertex}
    rdependents::Vector{Vertex}
    function Vertex(id, form, postag)
        new(id, form, postag, NOHEAD, NOVAL, Vertex[], Vertex[])
    end
end

function Vertex(id, form, postag, head, deprel)
    v = Vertex(id, form, postag)
    v.head = head
    v.deprel = deprel
    return v
end

function Vertex(t::Token, coder)
    Vertex(t.id, encode(t.form, coder), encode(t.cpostag, coder),
        t.head, t.deprel)
end

import CoNLLX: Token
function Token(v::Vertex, coder)
    return Token(v.id, decode(v.form, coder), NOVAL, decode(v.postag, coder),
        NOVAL, NOVAL, v.head, v.deprel, NOHEAD, NOVAL)
end

import Base: isequal
function isequal(a::Vertex, b::Vertex)
    (a.id == b.id && a.form == b.form && a.postag == b.postag
        && a.head == b.head && isequal(a.deprel, b.deprel)
        && length(a.ldependents) == length(b.ldependents)
        && length(a.rdependents) == length(b.rdependents)
        # Only check the IDs to avoid infinite recursion.
        && all([ae.id == be.id
            for (ae, be) in zip(a.ldependents, b.ldependents)])
        && all([ae.id == be.id
            for (ae, be) in zip(a.rdependents, b.rdependents)]))
end

import Base: show
function show(io::IO, v::Vertex)
    ldeps = join([d.id for d in v.ldependents], ", ")
    rdeps = join([d.id for d in v.rdependents], ", ")
    print(io, string("Vertex(id=$(v.id),form=$(v.form),postag=$(v.postag),",
        "head=$(v.head),deprel=$(v.deprel),ldependents=[$ldeps],",
        "rdependents=[$rdeps])"))
end

const NULLID = 0
const ROOTID = 1
# All codes are [1...], we can thus use 0 for the form and postag.
const NULLFORM = 0
const NULLPOS = 0
# Vertex to represent the absence of a vertex.
const NULLVERT = Vertex(NULLID, NULLFORM, NULLPOS)

ROOTTOK = Token(ROOTID, "<ROOT>", NOVAL, NOVAL, NOVAL, NOVAL, NOHEAD, NOVAL,
    NOHEAD, NOVAL)

typealias Graph Vector{Vertex}

import Base: isequal
function isequal(a::Graph, b::Graph)
    length(a) == length(b) && all([isequal(ae, be) for (ae, be) in zip(a, b)])
end

# We encode the vocabulary and PoS-tags as integers for faster featurisation.
type Coder
    enc::Dict{String, Uint}
    dec::Dict{Uint, String}
end

Coder() = Coder(Dict{String, Uint}(), Dict{Uint, String}())

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

# TODO: Rename as Graph?
function dgraph(sent::Sentence, coder; blind=false)
    graph = Vertex[]
    push!(graph, Vertex(ROOTTOK, coder))
    for tok in sent
        push!(graph, Vertex(tok, coder))
    end

    # Do not add any edges (for training).
    if blind
        return graph
    end

    # Add existing information (if any).
    for i in 2:length(graph)
        vert = graph[i]
        if vert.head != NOHEAD
            head = graph[vert.head]
            if vert.deprel == NOVAL
                edge!(graph, vert, head)
            else
                edge!(graph, vert, head, vert.deprel)
            end
        end
    end

    return graph
end

function sentence(graph::Graph, coder)
    sent = Token[]
    for i in 2:length(graph)
        push!(sent, Token(graph[i], coder))
    end

    return sent
end

# Ordering for the left/right dependents.
const LDEP_ORD = By(v->v.id)
const RDEP_ORD = ReverseOrdering(LDEP_ORD)

lmostdep(v) = !isempty(v.ldependents) ? v.ldependents[1] : NULLVERT
rmostdep(v) = !isempty(v.rdependents) ? v.rdependents[1] : NULLVERT

function adddep(head, dependent)
    if dependent.id < head.id
        heappush!(head.ldependents, dependent, LDEP_ORD)
    else
        heappush!(head.rdependents, dependent, RDEP_ORD)
    end
end

# TODO: More efficient to use a binary tree? O(n) + O(n)?
function rmdep(head, dependent)
    if dependent.id < head.id
        ldeps = head.ldependents
        deleteat!(ldeps, findfirst(ldeps, dependent))
        heapify!(ldeps, LDEP_ORD)
    else
        rdeps = head.rdependents
        deleteat!(rdeps, findfirst(rdeps, dependent))
        heapify!(rdeps, RDEP_ORD)
    end
end

# Add an unlabelled edge.
function edge!(graph::Graph, dependent::Vertex, head::Vertex)
    dependent.head = head.id
    adddep(head, dependent)
end

# Add a labelled edge.
function edge!(graph::Graph, dependent::Vertex, head::Vertex, deprel)
    edge!(graph, dependent, head)
    dependent.deprel = deprel
end

function deledge!(graph::Graph, dependent::Vertex, head::Vertex)
    dependent.head = NOHEAD
    dependent.deprel = NOVAL
    rmdep(head, dependent)
end

end
