# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Sanity checking for the dependency graph module.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-07

# TODO: A bit too much duplication from CoNLL-X...
# TODO: Currently only execution, no tests.

require("conllx.jl")
require("dep.jl")

import Base.source_path
using Base.Test

using CoNLLX
using DepGraph

respath = string(dirname(source_path()), "/../../res/")
debugpath = string(respath, "debug.conllx")

# Coding/Decoding.
let
    coder = Coder()
    str = "foo"
    @test isequal(decode(encode(str, coder), coder), str)
end

# Sentence to dependency graph conversion.
open(debugpath, "r") do debug_f
    coder = Coder()
    for sent in conllxparse(debug_f)
        dgraph(sent, coder)
    end
end

# Equality checks.
let
    a = Vertex(1, 2, 3, NOHEAD, NOVAL)
    b = Vertex(4, 5, 6, NOHEAD, NOVAL)
    @test !isequal(a, b)
end
open(debugpath, "r") do debug_f
    # Adding and removing edges.
    coder = Coder()
    sents = collect(Sentence, conllxparse(debug_f, blind=true))
    sent = sents[1]

    graph = dgraph(sent, coder)
    head = graph[1]
    dep = graph[3]
    headbefore = deepcopy(head)
    depbefore = deepcopy(dep)

    edge!(graph, dep, head)
    @test !isequal(head, headbefore)
    @test !isequal(dep, depbefore)

    deledge!(graph, dep, head)
    @test isequal(head, headbefore)
    @test isequal(dep, depbefore)
end
open(debugpath, "r") do debug_f
    # Order independence for dependents.
    coder = Coder()
    sents = collect(Sentence, conllxparse(debug_f, blind=true))
    sent = sents[1]

    let
        g1 = dgraph(sent, coder)
        edge!(g1, g1[end], g1[1])
        edge!(g1, g1[end - 1], g1[1])

        g2 = dgraph(sent, coder)
        edge!(g2, g2[end - 1], g2[1])
        edge!(g2, g2[end], g2[1])

        @test isequal(g1[1], g2[1])
    end
    let
        g1 = dgraph(sent, coder)
        edge!(g1, g1[1], g1[end])
        edge!(g1, g1[2], g1[end])

        g2 = dgraph(sent, coder)
        edge!(g2, g2[1], g2[end])
        edge!(g2, g2[2], g2[end])

        @test isequal(g2[end], g2[end])
    end
end
