# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Performance testing for the CoNLL-X format module.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-09

require("conllx.jl")

import Base.source_path
using Base.Test

using CoNLLX

respath = string(dirname(source_path()), "/../../res/")
datapath = string(respath, "talbanken/train.conllx")

open(datapath, "r") do data_f
    sentcnt = 0
    before = time()
    for _ in conllxparse(data_f)
        sentcnt += 1
    end
    duration = time() - before
    throughput = sentcnt / duration
    @printf("Data reader throughput: %.1f sentence(s) per second\n",
        throughput)
end
