

mutable struct Conf
    batch_ensure_defaults::Vector{AbstactBatchTrait}
    function Conf()
        return new([AllEntriesAreStandard])
    end
end

CONF = Conf()