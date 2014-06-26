# vim:set ft=julia ts=4 sw=4 sts=4 autoindent:

# Fairly generic data structures.
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2014-06-06

module Structs

export Identifier, Identities, id

immutable Identifier{T,U<:Integer}
    d::Dict{T,U}
end

Identifier(T::Type=Any,U::Type=UInt) = Identifier(Dict{T,U}())

import Base: length
length(c::Identifier) = length(c.d)

id(c::Identifier, o) = get!(c.d, o, length(c) + 1)

immutable Identities{T,U<:Integer}
    d::Dict{T,U}
    default::U
end

function Identities{T,U<:Integer}(c::Identifier{T,U})
    Identities(c.d, zero(U))
end

function Identities{T,U<:Integer}(c::Identifier{T,U}, default::U)
    Identities(c.d, default)
end

import Base: length
length(c::Identities) = length(c.d)

id(c::Identities, o) = get(c.d, o, c.default)

end
