import Base: Symbol

struct Transformation
    alg::Any
    args::NamedTuple
end

Symbol(a::Transformation) = Symbol(a.alg)
function to_string(t::Transformation)
    str = "$(Symbol(t))"
    if !isnothing(t) && !isempty(t.args)
        for (arg, val) in zip([a for a in keys(t.args)], t.args)
            str *= "-$(arg)=$(val)"
        end
    end
    return str
end
to_string(t::Nothing) = "$(Symbol(t))"
execute(t::Transformation) = t.alg(; t.args...)

# ===-
struct DataSet
    name::String
    datadir::Function
    datadir_args::Tuple
    files_names::Vector{String}

    function DataSet(name::String, images_dir::Function, args::Tuple)
        files_names = images_dir(args...) |> readdir |> filter_out_hidden |> sort
        new(name, images_dir, args, files_names)
    end
end

pseudoart_data = DataSet("pseudoart", datadir, ("exp_raw", "pseudoart"))
art_data = DataSet("Artysta", datadir, ("exp_raw", "Artysta"))

all_datasets = [pseudoart_data, art_data]
# ---0
arguments_nice_translation = Dict(
    :dst_minval => "Min. range",
    :dst_maxval => "Max. range",
    :gamma => "Gamma",
    :slope => "Slope",
    :t => "t",
)
