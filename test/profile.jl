# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Profiler driver script.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-11

import Base.source_path

srcpath = source_path()
srcdir = dirname(srcpath)

push!(LOAD_PATH, string(srcdir, "/../src"))

require("conllx.jl")
require("dep.jl")
require("hybrid.jl")
require("parse.jl")

using Base.Test

using CoNLLX
using DepGraph
using Hybrid
using Parse

respath = string(dirname(source_path()), "/../res/")
datapath = string(respath, "talbanken/train.conllx")

open(datapath, "r") do data_f
    sents = collect(Sentence, conllxparse(data_f, useproj=true))
    Profile.init(2^24, 0.001)
    @profile train(sents, 1)
    Profile.print()
end
