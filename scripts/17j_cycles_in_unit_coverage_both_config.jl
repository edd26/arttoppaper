
using DrWatson
@quickactivate "arttopopaper"

"17_load_data_for_cycle_analysis.jl" |> scriptsdir |> include
# ===-===-
using Ripserer
using Images
using Statistics
using DelimitedFiles
using ProgressBars
using DataStructures: OrderedDict
using CairoMakie
using StatsBase: countmap

using ImageDistances: hausdorff
import Base.Threads: @sync, @spawn

import .CONFIG: IMG_WIDTH, IMG_HEIGHT
import .CONFIG: STARTING_POINT, VIEWING_WIDTH, SPACE_WIDTH, SPACE_HEIGHT
import .CONFIG: PERSISTENCE_THRESHOLD

"CycleCoverageUtils.jl" |> srcdir |> include
"GazePointHeatMap_py.jl" |> srcdir |> include
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===- 8
cycles_scriptprefix = "17j"
image_export_dir(args...) = plotsdir(
    "section17",
    "$(cycles_scriptprefix)-cycles_coverage",
    "fixation_sequence=$(CONFIG.FIXATION_SEQUENCE)",
    args...,
)

function teststatistic(x)
    n = x.n_x * x.n_y / (x.n_x + x.n_y)
    sqrt(n) * x.δ
end
function resolve_with_max(max_values)
    if all(isnan.(max_values))
        return NaN
    elseif isnan(max_values[1])
        return max_values[2]
    elseif isnan(max_values[2])
        return max_values[1]
    else
        return max(max_values...)
    end
end
function resolve_with_sum(max_values)
    if all(isnan.(max_values))
        return NaN
    elseif isnan(max_values[1])
        return max_values[2]
    elseif isnan(max_values[2])
        return max_values[1]
    else
        return sum(max_values)
    end
end


function get_parameters_map_from_joined_filtration(parameter_map_BW, parameter_map_WB, func)
    merged_maps = cat(parameter_map_BW, parameter_map_WB, dims = 3)
    total_rows, total_cols = size(parameter_map_BW)
    parameter_map = zeros(total_rows, total_cols)
    for row = 1:total_rows, col = 1:total_cols
        max_values = merged_maps[row, col, :]

        if func == density || func == density_scaled
            parameter_map[row, col] = resolve_with_sum(max_values)
        elseif func == max_persistence || func == persistence
            parameter_map[row, col] = resolve_with_max(max_values)
        elseif func == cycles_perimeter
            parameter_map[row, col] = resolve_with_max(max_values)
        else
            ErrorException("Function not known") |> throw
        end

    end
    return parameter_map
end
function get_parameters_values_from_joined_filtration(
    parameters_values_BW,
    parameters_values_WB,
    func,
)
    parameters_values = Float64[]
    for (param_BW, param_WB) in zip(parameters_values_BW, parameters_values_WB)
        joined_values = [param_BW, param_WB]
        if func == density || func == density_scaled
            push!(parameters_values, resolve_with_sum(joined_values))
        elseif func == max_persistence || func == persistence
            push!(parameters_values, resolve_with_max(joined_values))
        elseif func == cycles_perimeter
            push!(parameters_values, resolve_with_max(joined_values))
        else
            ErrorException("Function not known") |> throw
        end
    end

    if typeof(parameters_values) != Vector{Float64}
        parameters_values = Vector{Float64}(parameters_values)
    end
    return parameters_values
end
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===- 8
# Load a sample image from art and pseudoart

parameters_vec =
    [max_persistence, density_scaled, cycles_perimeter, persistence, density, birth, death]
func_range = 1:3

dim_index = 2
total_images = 12
total_sessions = 2
total_views = 2

total_bins = 50
windows_range = 1:1
session_range = 1:1
view_range = [:both]

filtration_config = ["BW", "WB"]
# ===-===-
do_density = true
window_sizes = [51]# 101, 201, 401, 501,]
default_map_value = NaN


unique_cycles_count_in_windows = populate_dict!(
    OrderedDict(),
    [filtration_config, [k for k in window_sizes], dataset_names],
    final_structure = OrderedDict(),
)

all_homology_info = populate_dict!(
    Dict(),
    [filtration_config, [k for k in window_sizes], dataset_names],
    final_structure = OrderedDict(),
)
all_perimeter_info = deepcopy(all_homology_info)
# for c in filtration_config
#     for w in window_sizes
#         for d in dataset_names
#             for i in keys(unique_cycles_count_in_windows[window_sizes[1]][d])
#                 all_homology_info[c][w][d][i] = OrderedDict()
#             end
#         end
#     end
# end

# manual_histogram = populate_dict!(OrderedDict(), [[k for k in window_sizes], dataset_names], final_structure=OrderedDict())
cycles_on_image_canvas = populate_dict!(
    OrderedDict(),
    [filtration_config, [k for k in window_sizes], dataset_names],
    final_structure = OrderedDict(),
)

window_size = window_sizes[windows_range][1]

for data_config in filtration_config
    for window_size in window_sizes[windows_range]
        data_name = dataset_names[end]
        for data_name in dataset_names
            println("Working on data: $(data_name)")
            if data_name == "art"
                raw_img_name = "art"
            else
                raw_img_name = "pseudoart"
            end
            simple_img_dir(args...) = datadir(
                "exp_pro",
                "img_initial_preprocessing",
                "$(data_config)",
                raw_img_name,
                args...,
            )

            # ===-===-===-===-
            # 
            all_simple_samples = simple_img_dir() |> readdir |> filter_out_hidden

            img1_name = all_simple_samples[1:total_images][end]
            for (k, img1_name) in enumerate(all_simple_samples[1:total_images])
                println("\tWorking on image: $(img1_name)")

                # Load image
                img1 = img1_name |> simple_img_dir |> load
                img1_bw = Gray.(img1)
                scaled_img = floor.(Int, img1_bw .* 255)

                # ===-===-
                # Get cycles and their persistence
                alg = :homology
                reps = true
                cutoff = PERSISTENCE_THRESHOLD
                input_img = scaled_img
                homology_config = @dict alg reps cutoff input_img

                file_name = @pipe replace(img1_name, ".jpg" => "") |> "image_$(_)"
                homology_data, p = produce_or_load(
                    ripserer_computations_dir(data_name, file_name), # path
                    homology_config, # config
                    prefix = "homology_info", # file prefix
                    force = false, # force computations
                ) do homology_config

                    @unpack alg, reps, cutoff, input_img = homology_config
                    println("\tStarting homology computations...")
                    homolgy_result = ripserer(
                        Cubical(input_img),
                        cutoff = cutoff,
                        reps = reps,
                        alg = alg,
                    )
                    println("\tFinished homology computations. ")

                    Dict("homolgy_result" => homolgy_result)
                end # produce_or_load

                cycles = homology_data["homolgy_result"][dim_index]
                cycles_on_image = add_cycles_to_image(cycles, img1)

                # Create a plot with cycles
                unique_cycles_count_in_windows[data_config][window_size][data_name][img1_name] =
                    count_unique_cycles_in_windows(cycles_on_image, window_size)

                cycles_on_image_canvas[data_config][window_size][data_name][img1_name] =
                    cycles_on_image
                all_homology_info[data_config][window_size][data_name][img1_name] =
                    homology_data["homolgy_result"][dim_index]
                all_perimeter_info[data_config][window_size][data_name][img1_name] =
                    get_perimeter_sizes(cycles, img1)
            end # image name
        end # dataset
    end # window_size
end # filtration_config

# ===-===-
do_nothing = "ok"
