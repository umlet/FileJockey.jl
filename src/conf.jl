

mutable struct Conf
    batch_ensure_defaults::Vector{AbstractBatchTrait}
    function Conf()
        return new([AllEntriesAreStandard])
    end
end

CONF = Conf()