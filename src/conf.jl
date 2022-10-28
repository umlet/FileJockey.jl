

mutable struct Conf
    batch_ensure_defaults::Vector{Type{<:AbstractBatchTrait}}
    function Conf()
        return new([AllEntriesAreStandard])
    end
end

CONF = Conf()