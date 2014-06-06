#!/usr/bin/env julia
# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Sanity checking for the parsing modules.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-07

include("../hdr.jl")

require("conllx.jl")
require("dep.jl")
require("hybrid.jl")
require("parse.jl")

using CoNLLX
using DepGraph
using Hybrid
using Parse

# Parse using an oracle and ensure that we get the gold annotations back.
open(talpath, "r") do data_f
    coder = Coder()
    sentnum = 0
    for goldsent in conllxparse(data_f, useproj=true)
        sentnum += 1
        try
            predsent = parse(goldsent, oracle, coder)
            @test isequal(predsent, goldsent)
        catch e
            println("Sentence: $sentnum")
            println(goldsent)
            rethrow(e)
        end
    end
end

# Parse using a random oracle and ensure that we do not crash.
open(talpath, "r") do data_f
    coder = Coder()
    for goldsent in conllxparse(data_f, useproj=true)
        parse(goldsent, randoracle, coder)
    end
end

# Verify that each transition undo action is valid.
open(debugpath, "r") do debug_f
    transs = transitions()
    coder = Coder()
    for goldsent in conllxparse(debug_f, useproj=true)
        conf = config(goldsent, coder)
        # Walk some steps along the gold path to test different regions.
        for _ in rand(0:length(goldsent))
            if !isterminal(conf)
                apply!(conf, oracle(conf))
            end
        end

        for trans in transs
            if !islegal(conf, trans)
                continue
            end

            before = deepcopy(conf)
            undo = apply!(conf, trans)
            undo!(conf, undo)
            @test isequal(conf, before)
        end
    end
end

open(debugpath, "r") do debug_f
    goldsents = collect(Sentence, conllxparse(debug_f, useproj=true))

    # Can we memorise a very simple sentence?
    let
        sent = goldsents[1:1]
        scores = Any[]
        for model in train(sent, epochs=7)
            push!(scores, evaluate(model, sent))
        end
        @test_approx_eq scores[end] 1.0
    end

    # Can we memorise a few short sentences?
    let
        scores = Any[]
        for model in train(goldsents, epochs=42)
            push!(scores, evaluate(model, goldsents))
        end
        @test_approx_eq scores[end] 1.0
    end
end
