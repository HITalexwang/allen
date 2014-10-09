#!/usr/bin/env julia
# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Sanity checking for the perceptron module.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-27

include("../hdr.jl")

require("percep.jl")

using Percep

olapath = "$respath/ola/fruit_data.tsv"

# Labels.
const APPLE     = "apple"
const ORANGE    = "orange"
const LEMON     = "lemon"
const LBLS      = (APPLE, ORANGE, LEMON)

# As per fruit_types.txt
const LBLBYID = [
    1   => APPLE,
    2   => ORANGE,
    3   => APPLE,
    4   => APPLE,
    5   => APPLE,
    6   => ORANGE,
    7   => ORANGE,
    8   => ORANGE,
    9   => LEMON,
    10  => LEMON,
]

const NUMFEATS = 3

type Sample
    label::String
    fvec::Vector{Float64}
end

function readdata(data_f)
    samples = Sample[]
    for line in eachline(data_f)
        idstr, fvecstr = split(rstrip(line, '\n'), '\t', 2)
        lbl = LBLBYID[int(idstr)]
        @assert lbl in LBLS
        fvec = map(float, split(fvecstr, '\t'))
        @assert length(fvec) == NUMFEATS
        push!(samples, Sample(lbl, map(float, split(fvecstr, '\t'))))
    end
    return samples
end

open(olapath, "r") do data_f
    samples = readdata(data_f)

    # Binary classification.
    let
        # Only use the oranges and lemons (they are linearly separable).
        data = collect(filter(s -> s.label in (ORANGE, LEMON), samples))
        percep = AvgPerceptron(NUMFEATS)

        wsum = zeros(size(percep.weights))
        bsum = 0
        count = 0

        errors = true
        while errors
            errors = false
            shuffle!(data)

            for sample in data
                islemon = classify(sample.fvec, percep)
                wsum += percep.weights
                bsum += percep.bias
                count += 1

                if isequal(sample.label, LEMON) && !islemon
                    update!(percep, sample.fvec, true)
                    errors = true
                elseif isequal(sample.label, ORANGE) && islemon
                    update!(percep, sample.fvec, false)
                    errors = true
                end
            end
        end

        @test count == percep.count
        vanilla = Perceptron(percep)
        # Compare with the averages, epsilon to account for rounding errors.
        wavg = wsum / count
        @test_approx_eq wavg vanilla.weights
        bavg = bsum / count
        @test_approx_eq bavg vanilla.bias
        for sample in data
            classify(sample.fvec, vanilla)
        end
    end
end
