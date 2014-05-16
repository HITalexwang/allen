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

repopath = string(dirname(source_path()), "/..")
datapath = string(repopath, "/res/talbanken/train.conllx")
reportpath = string(repopath, "/wrk/profile.txt")

function run(sents)
    for _ in train(sents, epochs=2)
        nothing
    end
end

open(datapath, "r") do data_f
    sents = collect(Sentence, conllxparse(data_f, useproj=true))
    Profile.init(2^24, 0.001)
    @profile run(sents)
    open(reportpath, "w") do report_f
        Profile.print(report_f)
    end
end
