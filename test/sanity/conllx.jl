# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Sanity checking for the CoNLL-X format parsing module.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-07

require("conllx.jl")

import Base.source_path
using Base.Test

using CoNLLX

respath = string(dirname(source_path()), "/../../res/")
debugpath = string(respath, "debug.conllx")

# Check that reading in and then writing the data causes no corruption.
lines = String[]
open(debugpath, "r") do debug_f
    for line in eachline(debug_f)
        if line[1] == '#'
            continue
        end

        push!(lines, line)
    end
end

before = join(lines, "")

parsed = collect(conllxparse(IOBuffer(before)))
buff = IOBuffer()
print(buff, parsed)
seekstart(buff)
after = strip(readall(buff))

@test after == strip(before)
