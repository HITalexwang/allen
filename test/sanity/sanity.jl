#!/usr/bin/env julia
# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Sanity testing driver script.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-05-07

# TODO: If Julia had a bit faster of a start-up it would probably be cleaner to
#   create a hdr.jl boiler-plate with the imports.

import Base.source_path

srcpath = source_path()
srcdir = dirname(srcpath)
srcname = basename(srcpath)

push!(LOAD_PATH, string(srcdir, "/../../src"))

for fname in readdir(srcdir)
    # Ignore non-Julia files and the driver script itself.
    if !endswith(fname, ".jl") || fname == srcname
        continue
    end

    # Run the sanity script.
    include("$fname")
end
