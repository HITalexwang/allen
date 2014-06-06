#!/usr/bin/env julia
# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Performance testing for the CoNLL-X format module.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-09

include("../hdr.jl")

require("conllx.jl")

import Base.source_path
using Base.Test

using CoNLLX

open(talpath, "r") do data_f
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
