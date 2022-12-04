

mutable struct Conf
    quiet::Bool
    colors::Bool

    #batch_ensure_defaults::Vector{Type{<:AbstractBatchTrait}}

    function Conf()
        return new(
                    false,  # quiet
                    true,  # colors

                    #[AllEntriesAreStandard]
                    )
    end
end


CONF = Conf()

