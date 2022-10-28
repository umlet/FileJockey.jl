

mutable struct Conf
    batch_ensure_defaults::Vector
    function Conf()
        return new([AllEntriesAreStandard])
    end
end

CONF = Conf()