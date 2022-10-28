

mutable struct Conf
    quiet::Bool
    batch_ensure_defaults::Vector{Type{<:AbstractBatchTrait}}

    function Conf()
        return new(
                    false,
                    [AllEntriesAreStandard]
                    )
    end
end

CONF = Conf()