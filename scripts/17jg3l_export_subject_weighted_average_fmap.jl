using Base: Config

using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-

"17jg3_ECDF_generation_not_looking.jl" |> scriptsdir |> include

using HypothesisTests
using StatsBase: ecdf
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
scriptprefix = "17jg3l"
scriptname = "weighted_heatmap_export"
# ===-===-
# load df with measures

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

function generate_weighted_parameters(mean_hmp, parameter_map, map_height, map_width)
    weighted_map = zeros(Float64, map_height, map_width)

    for (position, hmap_value) in mean_hmp
        if hmap_value == 0
            continue
        end
        parameter_value = parameter_map[position...]
        weighted_map[position...] = hmap_value * parameter_value
        # push!(weighted_feature_map_values, )
    end
    return weighted_map
end

ld = "Art"
ld = "Pseudo-art"
for ld in loaded_datasets
    @info "\t" ld
    dataset_df = filter(row -> row.Exhibition == ld, all_measures_df)

    images_names = dataset_df.Image |> unique

    img_names_order = if ld == "Art"
        CONFIG.art_images_order
    else
        CONFIG.pseudoart_images_order
    end

    img_name = images_names[6]
    for img_name in images_names
        @info "\t\t" img_name
        img_df = filter(row -> row.Image == img_name, dataset_df) # there is no session information

        data_name_filter = if ld == "Art"
            lowercase(ld)
        elseif ld == "Pseudo-art"
            "pseudoart"
        else
            ld
        end

        image_related_parameters_df = @pipe parameters_df |>
                                            filter(row -> row.data_name == data_name_filter, _) |>
                                            filter(row -> row.export_name == img_name, _)

        img_file_name = @pipe split(img_name, r"[AF]")[2] |> parse(Int, _) |> img_names_order[_]
        image_related_feature_map_df = @pipe ECDF_from_feature_map_df |>
                                             filter(row -> row.data_name == data_name_filter, _) |>
                                             filter(row -> row.img_name == img_file_name, _)

        # looking_maps_df = image_related_feature_map_df[!, :mean_heatmap_in_window]


        # index = findfirst(x -> x .== "SKI089", img_df.ID)
        # input_row = img_df[index, :]
        for input_row in eachrow(img_df)
            @info "\t\t\t" input_row.ID

            # Filter by subject
            viewing_df = filter(row -> row.subject == lowercase(input_row.ID), image_related_feature_map_df)
            if isempty(viewing_df)
                @error "There is no viewing data for subject $(input_row.ID)"
                continue
            end

            average_params = Float64[]
            p = parameters_names[1]
            for p in parameters_names
                parameter_map = filter(row -> row.parameter == p, image_related_parameters_df)[:, :parameter_map][1]
                map_height, map_width = size(parameter_map)

                weighted_parameter_maps = Matrix{Float64}[]
                for session_index in 1:2
                    session_df =
                        @pipe filter(row -> row.parameter == p, viewing_df) |> filter(row -> row.session == session_index, _)

                    # findall(x->isnan(x), weighted_parameter_map_session1)
                    s_maps = if isempty(session_df.mean_heatmap_in_window)
                        # [[(c[1], c[2]) => 0 for c in CartesianIndices((1:map_height, 1:map_width))]...]
                        continue
                    else
                        session_df.mean_heatmap_in_window[1]
                    end
                    push!(weighted_parameter_maps, generate_weighted_parameters(s_maps, parameter_map, map_height, map_width))
                end

                # weighted_parameter_map_session2 = generate_weighted_parameters(s2_maps, parameter_map, map_height, map_width)
                mean_weighted_hmap = mean(weighted_parameter_maps)
                weighted_parameter = mean([x for x in mean_weighted_hmap[mean_weighted_hmap.!=0] if !isnan(x)])
                push!(average_params, weighted_parameter)
            end

            new_data = (input_row..., average_params...)
            push!(extended_measures_df, new_data)
        end
    end
end

# ===-===-
out_file_pieces = split(file_name, ".")
out_file = "$(scriptname)-$(out_file_pieces[1])-" * join(parameters_names, "-") * "." * out_file_pieces[2]
# out_file = join(out_file, ".")

out_path(args...) = datadir("exp_pro", "section17", "$(scriptprefix)-$(scriptname)", args...)
out_path() |> ispath || out_path() |> mkpath
out_file_full_path = out_file |> out_path

CSV.write(out_file_full_path, extended_measures_df)

CairoMakie.plot(
    extended_measures_df.Emotions,
    extended_measures_df.cycles_perimeter ./ (mean(extended_measures_df.cycles_perimeter)),
)

unique(extended_measures_df.Context)




# ===-===-
do_nothing = "ok"
