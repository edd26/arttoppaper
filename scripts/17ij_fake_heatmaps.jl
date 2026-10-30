
using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-

"17i_cycles_in_unit_coverage.jl" |> scriptsdir |> include

using HypothesisTests
using StatsBase: ecdf
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
scriptprefix = "17ij"

# ===-===-===-===-
pvalues_info_storage(args...) = datadir(
    "exp_pro",
    "section17",
    "$(scriptprefix)-rmse",
    "fixation_sequence=$(CONFIG.FIXATION_SEQUENCE)",
    args...,
)


function get_art_export_name(img_name)
    to_replace_with =
        split(img_name, ".jpg")[1] |> (z -> replace(z, "_$(CONFIG.DATA_CONFIG)" => ""))
    return "A" * to_replace_with
end

function get_pseudoart_export_name(img_name)
    to_replace_with =
        split(img_name, ".jpg")[1] |>
        (z -> replace(z, "_$(CONFIG.DATA_CONFIG)" => "")) |>
        y -> "$(CONFIG.pseudoart_name_to_order[y])"
    return "F" * to_replace_with
end
# ===-===-===-===-
selected_window = 51
homology_info = all_homology_info[selected_window]
perimeter_info = all_perimeter_info[selected_window]

# ===-===-
total_subjects = length(subjects_name["art"])
windows = "windows_" * join(["$(k)" for k in window_sizes], "_")

selected_data = [l for l in keys(unique_cycles_count_in_windows[window_size])][2]
img_name = [l for l in keys(unique_cycles_count_in_windows[window_size][selected_data])][5]
func = parameters_vec[1]

force_computaions = false
parameters_df = DataFrame(
    :data_name => String[],
    :img_name => String[],
    :export_name => String[],
    :parameter => String[],
    :window_size => Int[],
    :parameters_values => Vector{Float64}[],
    :parameter_map => Matrix{Float64}[],
)

for func in parameters_vec[func_range]
    @info "Working on: $(func)"

    for window_size in window_sizes[windows_range]
        @info "\tWorking on: $(window_size)"
        # selected_data = [k for k in keys(unique_cycles_count_in_windows[window_size])][1]
        for selected_data in [k for k in keys(unique_cycles_count_in_windows[window_size])]
            @info "\t\tWorking on: $(selected_data)"
            export_name_generator = if selected_data == "art"
                get_art_export_name
            elseif selected_data == "pseudoart"
                get_pseudoart_export_name
            else
                x -> x
            end

            et_df = dataset_df_dict[selected_data]
            for img_name in [
                k for k in keys(unique_cycles_count_in_windows[window_size][selected_data])
            ]
                @info "\t\t\tWorking on: $(img_name)"

                img_cycles = cycles_on_image_canvas[window_size][selected_data][img_name]

                parameter_map, parameters_values = get_parameters_map(
                    func,
                    img_cycles,
                    window_size,
                    homology_info[selected_data][img_name],
                    perimeter_info[selected_data][img_name];
                    default_map_value=default_map_value,
                )
                if typeof(parameters_values) != Vector{Float64}
                    parameters_values = Vector{Float64}(parameters_values)
                end

                push!(
                    parameters_df,
                    (
                        selected_data,
                        img_name,
                        export_name_generator(img_name),
                        "$(func)",
                        window_size,
                        parameters_values,
                        parameter_map,
                    ),
                )
            end # img_nam
        end # selected_data
    end # window_size
end # func

# ===-===-
# load df with measures

# names(parameters_df.parameter |> unique)

file_name = "kot_net_dim_flowall_avg.csv"
file_full_path = datadir("exp_pro", file_name)

all_measures_df = file_full_path |> CSV.File |> DataFrame

# Create empty DataFrame with matching structure
schema = Tables.schema(all_measures_df)
empty_df = DataFrame([n => t[] for (n, t) in zip(schema.names, schema.types)]...)

parameters_names = parameters_df.parameter |> unique

extended_measures_df =
    hcat(empty_df, DataFrame([p => Float64[] for p in parameters_names]...))

loaded_datasets = all_measures_df.Exhibition |> unique


ld = "Art"
ld = "Pseudo-art"
for ld in loaded_datasets
    @info "\t" ld
    dataset_df = filter(row -> row.Exhibition == ld, all_measures_df)

    images_names = dataset_df.Image |> unique

    img_name = images_names[1]
    for img_name in images_names
        @info "\t\t" img_name
        img_df = filter(row -> row.Image == img_name, dataset_df)

        data_name_filter = if ld == "Art"
            lowercase(ld)
        elseif ld == "Pseudo-art"
            "pseudoart"
        else
            ld
        end

        image_related_df = @pipe parameters_df |>
                                 filter(row -> row.data_name == data_name_filter, _) |>
                                 filter(row -> row.export_name == img_name, _)

        average_params = [
            # n=>mean(p) for
            mean(p) for (n, p) in
            zip(image_related_df.parameter, image_related_df.parameters_values)
        ]

        # r = img_df[1, :]
        for r in eachrow(img_df)
            new_data = (r..., average_params...)
            @info "\t\t\t" length(new_data)
            push!(extended_measures_df, new_data)
        end
    end
end

# ===-===-
out_file = split(file_name, ".")
out_file[1] *= "-" * join(parameters_names, "-")
out_file = join(out_file, ".")

out_path(args...) = datadir("exp_pro", "section17", args...)
out_path() |> ispath || out_path() |> mkpath
out_file_full_path = out_file |> out_path

CSV.write(out_file_full_path, extended_measures_df)





# ===-===-
do_nothing = "ok"
