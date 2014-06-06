# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Header providing several conveniences for the testing scripts.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-06-06

import Base.source_path

using Base.Test

srcpath = source_path()
srcdir  = dirname(srcpath)

repodir     = "$srcdir/../"
respath     = "$repodir/res/"
debugpath   = "$respath/debug.conllx"
talpath     = "$respath/talbanken/train.conllx"

# Inject the main source directory.
push!(LOAD_PATH, "$srcdir/../src")
