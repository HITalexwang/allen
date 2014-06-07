#!/usr/bin/env julia
# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Unk-token pre-processing.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-06-07

include("../src/conllx.jl")

using ArgParse

using CoNLLX

argparse = ArgParseSettings()
@add_arg_table argparse begin
    "--input", "-i"
        help = "input source (default: STDIN)"
        default = "/dev/stdin"
    "--output", "-o"
        help = "output sink (default: STDOUT)"
        default = "/dev/stdout"
    "--cut-off", "-c"
        help = "frequency cut-off (default: 1)"
        arg_type = Uint
        range_tester = (x) -> x > 0
        default = uint(1)
    "--unk-tok", "-u"
        help = "token representation for UNKs (default: <UNK>)"
        arg_type = String
        default = "<UNK>"
    "vocab_tsv"
        help = "token/occurences pair TSV"
        required = true
end

pargs = parse_args(argparse)

vocab = Set{String}()
open(pargs["vocab_tsv"], "r") do vocab_f
    for line in eachline(vocab_f)
        tok, occs_s = split(line, '\t', 2)
        occs = uint(occs_s)
        if occs > pargs["cut-off"]
            push!(vocab, tok)
        end
    end
end

open(pargs["input"], "r") do input_f
    open(pargs["output"], "w") do output_f
        for sent in conllxparse(input_f)
            for tok in sent
                if !(tok.form in vocab)
                    tok.form = pargs["unk-tok"]
                end
            end
            print(output_f, sent)
            print(output_f, "\n\n")
        end
    end
end
