module Bertini

export bertini

import HomotopyContinuation2
const HC2 = HomotopyContinuation2
using DelimitedFiles

function read_solution_file(filename)
    A = readdlm(filename)
    n = A[1, 1]
    nvars = size(A, 2)
    map(2:nvars:size(A, 1)) do i
        map(i:i+nvars-1) do k
            A[k, 1] + im * A[k, 2]
        end
    end
end

function write_solution_file(filename, S::Vector{<:Vector{<:Number}})
    open(filename, "w") do f
        write(f, "$(length(S))\n")
        for s in S
            write(f, "\n")
            writedlm(f, [real.(s) imag.(s)], ' ')
        end
    end
end

function write_parameters_file(filename, p::Vector{<:Number})
    open(filename, "w") do f
        write(f, "$(length(p))\n\n")
        writedlm(f, [real.(p) imag.(p)], ' ')
    end
end


"""
    bertini(
        f::HC2.ModelKit.System,
        S = nothing;
        hom_variable_group = false,
        variable_groups = [f.variables],
        parameters = f.parameters,
        file_path = mktempdir(),
        start_parameters = isempty(parameters) ? nothing :
                           UndefKeywordError(:start_parameters),
        final_parameters = isempty(parameters) ? nothing :
                           UndefKeywordError(:final_parameters),
        bertini_path = "",
        TrackType = 0,
        optionalconfig...,
    )

Run bertini.
"""
function bertini(
    f::HC2.ModelKit.System,
    S = nothing;
    hom_variable_group = false,
    variable_groups = [f.variables],
    parameters = f.parameters,
    file_path = mktempdir(),
    start_parameters = isempty(parameters) ? nothing :
                       UndefKeywordError(:start_parameters),
    final_parameters = isempty(parameters) ? nothing :
                       UndefKeywordError(:final_parameters),
    bertini_path = "",
    TrackType = 0,
    optionalconfig...,
)
    oldpath = pwd()
    cd(file_path)
    println("File path: $(file_path)")

    input = ["CONFIG", "TrackType:$TrackType;"]
    for (k, v) in optionalconfig
        push!(input, "$k: $v;")
    end
    if !isempty(parameters)
        push!(input, "PARAMETERHOMOTOPY: 2;")
    end

    push!(input, "END;")

    push!(input, "INPUT")

    for vars in variable_groups
        vargroup = hom_variable_group ? "hom_variable_group " :
                   "variable_group "
        vargroup *= join(vars, ",") * ";"
        push!(input, vargroup)
    end

    if !isempty(f.parameters)
        push!(input, "parameter " * join(f.parameters, ",") * ";")
    end

    n = length(f)
    push!(input, "function " * join(map(i -> "f$i", 1:n), ",") * ";")

    for (i, fi) in enumerate(f)
        push!(input, "f$i = $(fi);")
    end
    push!(input, "END")

    writedlm("input", input, '\n')

    if !isempty(parameters)
        if S === nothing
            throw(ArgumentError("start solutions not given."))
        end
        write_solution_file(joinpath(file_path, "start"), S)
        write_parameters_file(
            joinpath(file_path, "start_parameters"),
            start_parameters,
        )
        write_parameters_file(
            joinpath(file_path, "final_parameters"),
            final_parameters,
        )
    end

    @time run(`bertini input`)

    finite_solutions = read_solution_file("finite_solutions")
    runtime = open(joinpath(file_path, "output")) do f
        while true
            x = readline(f)
            if eof(f)
                return parse(Float64, split(x, " = ")[2][1:end-1])
            end
        end
    end

    return Dict(
        :file_path => file_path,
        :finite_solutions => finite_solutions,
        :runtime => runtime,
    )
end

end # module
