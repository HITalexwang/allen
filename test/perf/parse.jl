# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Performance testing for the parsing modules.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-09

require("conllx.jl")
require("dep.jl")
require("hybrid.jl")
require("parse.jl")

import Base.source_path
using Base.Test

using CoNLLX
using DepGraph
using Hybrid
using Parse

respath = string(dirname(source_path()), "/../../res/")
datapath = string(respath, "talbanken/train.conllx")

open(datapath, "r") do data_f
    sents = collect(Sentence, conllxparse(data_f, useproj=true))
    trainitr = train(sents, epochs=1)
    for pass in 1:2
        before = time()
        next(trainitr)
        duration = time() - before
        throughput = length(sents) / duration
        print("Unlabelled training throughput ")
        @printf("(pass: %d): %.1f ", pass, throughput)
        println("sentence(s) per second")
    end
end
