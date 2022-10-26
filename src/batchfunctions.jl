
struct HaveDistinctPaths <: AbstractHabit end
function havedistinctpaths(X::AbstractVector{FsFile})
    v = path.(X)
    return length(Set(v)) == length(v)
end
AttoHabits.checkhabit(::Type{HaveDistinctPaths}) = havedistinctpaths

