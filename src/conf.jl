

mutable struct Conf
    quiet::Bool
    colors::Bool

    function Conf()
        return new(
                    false,  # quiet
                    true,  # colors
                    )
    end
end


CONF = Conf()

