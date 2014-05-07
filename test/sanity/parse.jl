# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Sanity checking for the parsing modules.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-07

# TODO: A bit too much duplication from CoNLL-X...

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
debugpath = string(respath, "debug.conllx")

open(debugpath, "r") do debug_f
    goldsents = collect(conllxparse(debug_f, useproj=true))
    for goldsent in goldsents
        predsent = parse(goldsent, oracle)
        @test isequal(predsent, goldsent)
    end
end
