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

open(debugpath, "r") do debug_f
    codes = coder()
    for sent in conllxparse(debug_f)
        dgraph(sent, codes)
    end
end
