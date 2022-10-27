

struct HaveDistinctPaths <: AbstractHabit end
function havedistinctpaths(X::AbstractVector{FsFile})
    v = path.(X)
    length(Set(v)) == length(v)  &&  return true



    return false
end
AttoHabits.checkhabit(::Type{HaveDistinctPaths}) = havedistinctpaths

