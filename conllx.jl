#!/usr/bin/env julia
# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Parse CoNLL-X (also known as CoNLL 2006) style dependency data.
#
# Data format description:
#
#   http://nextens.uvt.nl/depparse-wiki/DataFormat
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-01

module CoNLLX

import Base.done
import Base.next
import Base.show
import Base.start

# TODO: Serialise, de-serialize test!
# TODO: Makefile sanity...

type Token
    # [1,|Sentence|] sentence-internal unique token identifier.
    id::Uint
    # Token form, the actual text.
    form::String
    # Lemma of the token form.
    lemma::String
    # Coarse part-of-speech.
    cpostag::String
    # Fine-grained part-of-speech.
    postag::String
    # Set of syntactic and/or morphological features.
    feats::String # TODO: Should be an ordered set, is there one in Julia?
    # [0,|Sentence|] id of the head of the token.
    head::Int
    # Dependency relation to the head.
    deprel::String
    # [0,|Sentence|] id of the projective head of the token.
    phead::Int
    # Dependency relation to the projective head.
    pdeprel::String
end

function show(io::IO, t::Token)
    print(io, string("$(t.id)\t$(t.form)\t$(t.lemma)\t$(t.cpostag)\t",
        "$(t.postag)\t$(t.feats)\t$(t.head)\t$(t.deprel)\t$(t.phead)\t",
        "$(t.pdeprel)"))
end

function blind!(t::Token)
    t.head, t.phead = (0, 0)
    t.deprel, t.pdeprel = ("_", "_")
end

typealias Sentence Array{Token}
typealias Sentences Array{Sentence}

# TODO: Sentence from another Sentence with blind argument.
# TODO: Sentences from another Sentences with blind argument.

# Not the friendliest of expressions, but it will do the trick.
const CONLLXREGEX = Regex(string("^([0-9]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t",
    "([^\t]+)\t([^\t]+)\t([0-9]+)\t([^\t]+)\t([0-9]+|_)\t([^\t]+)\n\$"))

# Parsing implemented using the iterator protocol.
type CoNLLXParse
    stream::IO
    blind::Bool
    linenum::Int
end

function conllxparse(stream::IO; blind=false)
    CoNLLXParse(stream, blind, 0)
end

start(::CoNLLXParse) = nothing

function next(itr::CoNLLXParse, nada)
    sent = Token[]

    for line in eachline(itr.stream)
        itr.linenum += 1

        # Ignore comments (this is a format extension).
        if line[1] == '#'
            continue
        end

        # Empty lines are used as sentence separators.
        if line[1] == '\n'
            if length(sent) > 1
                return (sent, nothing)
                sent = Token[]
            end
            continue
        end

        soup = match(CONLLXREGEX, line)
        if soup == nothing
            warn(string("failed to parse:$(itr.linenum) \"",
                rstrip(line, '\n'), "\""))
            continue
        end

        (id_str, form, lemma, cpostag, postag, feats, head_str, deprel,
            phead_str, pdeprel) = soup.captures
        id, head = map(int, (id_str, head_str))

        # The projective head is optional.
        if phead_str != "_"
            phead = int(phead)
        else
            phead = 0
        end

        tok = Token(id, form, lemma, cpostag, postag, feats, head, deprel,
            phead, pdeprel)

        # Remove (blind) any gold annotations.
        if itr.blind
            blind!(tok)
        end

        push!(sent, tok)
    end

    # Yield what we have observed before EOF (could be an empty Sentence).
    return (sent, nothing)
end

done(itr::CoNLLXParse, nada) = eof(itr.stream)

#for a in conllxparse(open("res/debug.conllx"))
#    println(a)
#end

#a = collect(conllxparse(open("res/debug.conllx")))
#a = collect(conllxparse(open("res/talbanken/train.conllx")))

end
