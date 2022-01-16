
function refine!(line::InterpLine, u::AbstractFieldFunction, pml::PMLGeometry)

    ζ = line.ζ

    extra_points = InterpPoint[]
    points = Base.Iterators.Stateful(line.points)
    prev_point = popfirst!(points)

    field_fnc(ν) = u(NamedTuple{(:u, :∂u_∂tν, :∂u_∂tζ, :∂2u_∂tν2, :∂2u_∂tν∂tζ, :∂3u_∂tν3)}, PMLCoordinates(ν,ζ), pml)

    U_field = field_fnc(0.0 + 0.0im)
    U = U_field.u
    while !isempty(points)
        next_point = peek(points)

        ν = (prev_point.ν + next_point.ν)/2
        tν0 = eval_hermite_patch(prev_point, next_point, ν).tν

        tν, field, converged = corrector(field_fnc, U, ν, tν0; N_iter_max=10, householder_order=3)
        if !converged error() end
        push!(extra_points, InterpPoint(ν, tν, ∂tν_∂ν(field,U_field), ∂tν_∂ζ(field,U_field, ν)))
        prev_point = popfirst!(points)
    end

    # This costs nlogn, but could be done in n, by inserting into new array as we go along
    append!(line.points, extra_points)
    sort!(line.points, by=p->p.ν)
end

function refine_in_ζ!(region::ContinuousInterpolation, u::AbstractFieldFunction, pml::PMLGeometry)
    ν_max = last(first(region.lines).points).ν

    function create_line(ζ)
        ν_vec = Float64[]
        tν_vec = ComplexF64[]
        ∂tν_∂ν_vec = ComplexF64[]
        ∂tν_∂ζ_vec = ComplexF64[]
        optimal_pml_transformation_solve(u, pml, ν_max, ζ, ν_vec, tν_vec, ∂tν_∂ν_vec, ∂tν_∂ζ_vec; silent_failure=true)
        # Add in point at ν=1? Try to work out if it's unbounded or not
        return InterpLine(ζ, ν_vec, tν_vec, ∂tν_∂ν_vec, ∂tν_∂ζ_vec)
    end

    extra_lines = InterpLine[]
    lines = Base.Iterators.Stateful(region.lines)
    prev_line = popfirst!(lines)

    while !isempty(lines)
        next_line = peek(lines)
        ζ = (prev_line.ζ + next_line.ζ)/2
        push!(extra_lines, create_line(ζ))
        prev_line = popfirst!(lines)
    end

    # This costs nlogn, but could be done in n, by inserting into new array as we go along
    append!(region.lines, extra_lines)
    sort!(region.lines, by=p->p.ζ)

end
