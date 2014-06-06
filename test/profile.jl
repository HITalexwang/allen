#!/usr/bin/env julia
# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Profiler driver script.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-11

include("hdr.jl")

require("conllx.jl")
require("dep.jl")
require("hybrid.jl")
require("parse.jl")

using CoNLLX
using DepGraph
using Hybrid
using Parse

reportpath = "$repodir/wrk/profile.txt"

open(talpath, "r") do data_f
    sents = collect(Sentence, conllxparse(data_f, useproj=true))
    Profile.init(2^24, 0.001)

    # "Warm up" the code by performing an initial pass.
    next(train(sents, epochs=1))

    @profile begin
        for _ in train(sents, epochs=2)
            nothing
        end
    end

    open(reportpath, "w") do report_f
        Profile.print(report_f)
    end
end
