using DrWatson
@quickactivate "ArtTopology"

"17_load_data_for_cycle_analysis.jl" |> scriptsdir |> include

# ===-===-
using Ripserer
using Images
# using Plots
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
import .CONFIG: homology_info_storage

"CycleCoverageUtils.jl" |> srcdir |> include
"GazePointHeatMap_py.jl" |> srcdir |> include
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===- 8
plot_scriptprefix = "17i"
image_export_dir(args...) = plotsdir("section17", "$(plot_scriptprefix)-cycles_coverage", "fixation_sequence=$(CONFIG.FIXATION_SEQUENCE)", args...)

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===- 8
# Load a sample image from art and pseudoart
PERSISTENCE_THRESHOLD = 5

parameters_vec = [max_persistence, density_scaled, cycles_perimeter, persistence, density, birth, death]
func_range = 1:3

dim_index = 2
total_images = 12
total_sessions = 2
total_views = 2

total_bins = 50
windows_range = 1:1
session_range = 1:1
view_range = [:both]

default_map_value = NaN
# ===-===-
do_density = true
window_sizes = [51,]# 101, 201, 401, 501,]

unique_cycles_count_in_windows = populate_dict!(OrderedDict(),
    [
        [k for k in window_sizes],
        dataset_names
    ],
    final_structure=OrderedDict()
)

all_homology_info = populate_dict!(Dict(),
    [
        [k for k in window_sizes],
        [d for d in keys(unique_cycles_count_in_windows[window_sizes[1]])],
    ],
    final_structure=OrderedDict()
)
all_perimeter_info = deepcopy(all_homology_info)

for w in window_sizes
    for d in keys(unique_cycles_count_in_windows[window_sizes[1]])
        for i in keys(unique_cycles_count_in_windows[window_sizes[1]][d])
            all_homology_info[w][d][i] = OrderedDict()
        end
    end
end

# manual_histogram = populate_dict!(OrderedDict(), [[k for k in window_sizes], dataset_names], final_structure=OrderedDict())
cycles_on_image_canvas = populate_dict!(OrderedDict(), [[k for k in window_sizes], dataset_names], final_structure=OrderedDict())

window_size = window_sizes[windows_range][1]

for window_size = window_sizes[windows_range]
    data_name = dataset_names[end]
    for data_name in dataset_names
        println("Working on data: $(data_name)")
        if data_name == "art"
            raw_img_name = "art"
        else
            raw_img_name = "pseudoart"
        end
        simple_img_dir(args...) = datadir("exp_pro", "img_initial_preprocessing", "$(CONFIG.DATA_CONFIG)", raw_img_name, args...)

        # ===-===-===-===-
        # 
        all_simple_samples = simple_img_dir() |> readdir |> filter_out_hidden

        img1_name = all_simple_samples[1:total_images][1]
        for (k, img1_name) = enumerate(all_simple_samples[1:total_images])
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
                homology_info_storage("homology_computation", data_name, file_name), # path
                homology_config, # config
                prefix="homology_info", # file prefix
                force=false # force computations
            ) do homology_config
                # do things
                @unpack alg, reps, cutoff, input_img = homology_config
                println("\tStarting homology computations...")
                homolgy_result = ripserer(Cubical(input_img), cutoff=cutoff, reps=reps, alg=alg)
                println("\tFinished homology computations. ")
                # Last line is the dictionary with the results
                Dict("homolgy_result" => homolgy_result)
            end # produce_or_load

            cycles = homology_data["homolgy_result"][dim_index]
            cycles_on_image = add_cycles_to_image(cycles, img1)

            # Create a plot with cycles
            unique_cycles_count_in_windows[window_size][data_name][img1_name] =
                count_unique_cycles_in_windows(cycles_on_image, window_size,)

            cycles_on_image_canvas[window_size][data_name][img1_name] = cycles_on_image
            all_perimeter_info[window_size][data_name][img1_name] = get_perimeter_sizes(cycles, img1)
            all_homology_info[window_size][data_name][img1_name] = homology_data["homolgy_result"][dim_index]
        end # image name
    end # dataset
end

# ===-===-
do_nothing = "ok"
