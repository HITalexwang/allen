# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Sanity checking for the parsing modules.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-07

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

# Parse using an oracle and ensure that we get the gold annotations back.
open(datapath, "r") do data_f
    codes = coder()
    sentnum = 0
    for goldsent in conllxparse(data_f, useproj=true)
        sentnum += 1
        try
            predsent = parse(goldsent, oracle, codes)
            @test isequal(predsent, goldsent)
        catch e
            println("Sentence: $sentnum")
            println(goldsent)
            rethrow(e)
        end
    end
end

# Parse using a random oracle and ensure that we do not crash.
open(datapath, "r") do data_f
    codes = coder()
    for goldsent in conllxparse(data_f, useproj=true)
        parse(goldsent, randoracle, codes)
    end
end
