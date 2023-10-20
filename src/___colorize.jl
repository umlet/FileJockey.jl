module Colorize

using Crayons
using Crayons.Box





function colorize(s::AbstractString, COLORS...)
    !CONF.colors  &&  return s
    RET = s
    for COLOR in COLORS
        RET = COLOR(RET)
    end
    return RET
end

include("colorize.jl_exports")
end # module