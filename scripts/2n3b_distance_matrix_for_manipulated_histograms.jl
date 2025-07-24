
using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-
using PersistenceLandscapes
import TopologyPreprocessing: get_ordered_matrix

"config.jl" |> scriptsdir |> include
import .CONFIG: names_to_order, art_images_names, fake_images_names

# ===-===-===-
scriptprefix = "2n3b"

data_config = "BW"#  config_vec[1]

# ===-===-===-
"2n3_histogram_manipulation_grayscale_with_lansdcapes_for_paper.jl" |> scriptsdir |> include


# ===-===-===-
p_data = persistence_data[data_config]

# ===-===-===-
function get_sorted_images_names(p_data; selected_dim = 1, t = nothing)
    all_images = [k for k in keys(p_data["dim$(selected_dim)"][to_string(t)])]

    art_numbers = [parse(Int, just_name) for just_name in all_images[13:end]]
    art_sorting = sortperm(art_numbers)

    fake_numbers = [names_to_order[just_name] for just_name in all_images[1:12]]
    fake_sorting = sortperm(fake_numbers)

    return vcat(all_images[13:end][art_sorting], all_images[1:12][fake_sorting])
end
sorted_images_names = get_sorted_images_names(p_data)


all_landscapes_d0 = vcat(
    [
        vcat(
            [
                p_data["dim0"][t|>to_string][name]["landscapes"] for
                name in sorted_images_names
            ]...,
        ) for t in transformations_extended
    ]...,
)
all_landscapes_d1 = vcat(
    [
        vcat(
            [
                p_data["dim1"][t|>to_string][name]["landscapes"] for
                name in sorted_images_names
            ]...,
        ) for t in transformations_extended
    ]...,
)


# Plots preparation

hmap_kwargs = (xticklabelsize = 15, yticklabelsize = 15, aspect = 1)

colours_palette = Makie.wong_colors();
art_colour = colours_palette[3];
fake_colour = colours_palette[6];

total_landscapes = length(sorted_images_names)
matrices_dim0 = populate_dict!(
    OrderedDict,
    [[t |> to_string for t in transformations_extended]];
    final_structure = zeros(total_landscapes, total_landscapes),
)
matrices_dim1 = populate_dict!(
    OrderedDict,
    [[t |> to_string for t in transformations_extended]];
    final_structure = zeros(total_landscapes, total_landscapes),
)

for (t_index, t) in enumerate(transformations_extended)

    range_start = 24 * (t_index - 1)
    selected_range = (range_start+1):(range_start+24)
    distances_matrix_dim0 = matrices_dim0[t|>to_string]
    distances_matrix_dim1 = matrices_dim1[t|>to_string]

    p_value = 1

    for (output_mat_row, pland_index1) in enumerate(selected_range)

        @info "output row: $(output_mat_row) | pland index1: $(pland_index1)"


        pland_d0_1 = all_landscapes_d0[pland_index1]
        pland_d1_1 = all_landscapes_d1[pland_index1]

        output_mat_col = output_mat_row
        for pland_index2 = pland_index1:max(selected_range...)
            @info "\toutput col: $(output_mat_col) | pland index2: $(pland_index2)"

            pland_d0_2 = all_landscapes_d0[pland_index2]
            pland_d1_2 = all_landscapes_d1[pland_index2]

            distances_matrix_dim0[output_mat_row, output_mat_col] =
                distances_matrix_dim0[output_mat_col, output_mat_row] =
                    PersistenceLandscapes.computeDiscanceOfLandscapes(
                        pland_d0_1,
                        pland_d0_2,
                        p_value,
                    )
            distances_matrix_dim1[output_mat_row, output_mat_col] =
                distances_matrix_dim1[output_mat_col, output_mat_row] =
                    PersistenceLandscapes.computeDiscanceOfLandscapes(
                        pland_d1_1,
                        pland_d1_2,
                        p_value,
                    )
            output_mat_col += 1
        end
    end
end

## ===-===-
do_nothing = "ok"


tick_labels = get_images_labels(sorted_images_names; target_len = 10)