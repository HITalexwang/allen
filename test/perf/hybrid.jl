#!/usr/bin/env julia
# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Performance testing for the parsing modules.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-12

include("../hdr.jl")

require("conllx.jl")
require("dep.jl")
require("hybrid.jl")

using CoNLLX
using DepGraph
using Hybrid

# Featurise along the gold path and measure the time consumption.
open(talpath, "r") do data_f
    sents = collect(Sentence, conllxparse(data_f, useproj=true))
    coder = Coder()

    feats = Array(FeatStruct, NUMFEATS)
    numcalls = 0
    duration = 0
    for sent in sents
        conf = config(sent, coder)
        while !isterminal(conf)
            before = time()
            featurise!(feats, conf)
            duration += time() - before
            numcalls += 1

            trans = oracle(conf)
            apply!(conf, trans)
        end
    end

    throughput = numcalls / duration
    @printf("Featurisation throughput: %.1f configuration(s) per second\n",
        throughput)
end
