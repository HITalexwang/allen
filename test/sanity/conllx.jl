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

parsed = collect(Sentence, conllxparse(IOBuffer(before)))
buff = IOBuffer()
print(buff, parsed)
seekstart(buff)
after = strip(readall(buff))

cmp = strip(before)
if after != cmp
    before_f = tempname()
    after_f = tempname()
    try
        run(`echo $cmp` |> before_f)
        run(`echo $after` |> after_f)
        run(ignorestatus(`diff -u $before_f $after_f`))
    finally
        rm(after_f)
        rm(before_f)
    end
    @assert false
end
