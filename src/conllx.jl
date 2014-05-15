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

export NOHEAD, NOVAL, Sentence, Sentences, Token, conllxparse

import Base: done, next, show, start

type Token
    # [2,|Sentence|+1] sentence-internal unique token identifier.
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
    # [1,|Sentence|+1] id of the head of the token, 0 for no head.
    head::Uint
    # Dependency relation to the head.
    deprel::String
    # [1,|Sentence|+1] id of the projective head of the token, 0 for no phead.
    phead::Uint
    # Dependency relation to the projective head.
    pdeprel::String
end

const NOHEAD = 0
const NOVAL = "_"

function show(io::IO, t::Token)
    head, phead = map(i -> i == NOHEAD ? NOVAL : string(i - 1),
        (t.head, t.phead))

    print(io, string("$(t.id-1)\t$(t.form)\t$(t.lemma)\t$(t.cpostag)\t",
        "$(t.postag)\t$(t.feats)\t$head\t$(t.deprel)\t$phead\t",
        "$(t.pdeprel)"))
end

function useproj!(t::Token)
    t.head = t.phead
    t.deprel = t.pdeprel
end

function blind!(t::Token)
    t.head, t.phead = (NOHEAD, NOHEAD)
    t.deprel, t.pdeprel = (NOVAL, NOVAL)
end

typealias Sentence Array{Token}
typealias Sentences Array{Sentence}

# Not the friendliest of expressions, but it will do the trick.
const CONLLXREGEX = Regex(string("^([0-9]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t",
    "([^\t]+)\t([^\t]+)\t([0-9]+)\t([^\t]+)\t([0-9]+|_)\t([^\t]+)\n\$"))

# Parsing implemented using the iterator protocol.
type CoNLLXParse
    stream::IO
    useproj::Bool
    blind::Bool
    linenum::Uint
end

function conllxparse(stream::IO; blind=false, useproj=false)
    return CoNLLXParse(stream, useproj, blind, 0)
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
            if !isempty(sent)
                return (sent, nothing)
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

        # Bump the ids internally to allow it to double as an index (necessary
        #   due to Julia being 1-indexed).
        id += 1
        head += 1

        # The projective head is optional.
        if phead_str != NOVAL
            # Convert and bump the id.
            phead = int(phead_str) + 1
        else
            phead = NOHEAD
        end

        tok = Token(id, form, lemma, cpostag, postag, feats, head, deprel,
            phead, pdeprel)

        # Override the potentially non-projective head/deprel with their
        #   projective counterparts.
        if itr.useproj
            useproj!(tok)
        end

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

end
