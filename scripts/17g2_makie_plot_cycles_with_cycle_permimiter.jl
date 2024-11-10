using DrWatson
@quickactivate "ArtTopology"

# ===-===-

using Ripserer
using CairoMakie
using Pipe
using Images
using DataStructures: OrderedDict
using ProgressBars

"17_load_data_for_cycle_analysis.jl" |> scriptsdir |> include
"CycleCoverageUtils.jl" |> srcdir |> include

import .CONFIG: IMG_WIDTH, IMG_HEIGHT, SPACE_WIDTH, SPACE_HEIGHT, STARTING_POINT, VIEWING_WIDTH, VIEWING_HEIGHT
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===- 8
plot_scriptprefix = "17g2"
image_export_dir(args...) = plotsdir("section17", "$(plot_scriptprefix)-cycles_colured_by_perimeter", "$(CONFIG.DATA_CONFIG)_fixation_sequence=$(CONFIG.FIXATION_SEQUENCE)", args...)
##########

dim_index = 2
selected_dim = 1
total_images = 12

dataset_df = [raw_fake_ET_df, raw_art_ET_df]

hdistances = OrderedDict()
distance_coloured_cycles = OrderedDict()

# ===-===-===-===-===-===-===-===-===-===-===-
total_images = 12
dim_index = 2
HMAP_THRESHOLD = 50

data_name = dataset_names[1]

for data_name in dataset_names
    println("Working on data: $(data_name)")
    if data_name == "art"
        raw_img_name = "Artysta"
    elseif data_name == "fake"
        raw_img_name = "wystawa_fejkowa"
    end
    simple_img_dir(args...) = datadir("exp_pro", "img_initial_preprocessing", "$(CONFIG.DATA_CONFIG)", raw_img_name, args...)

    # ===-===-===-===-
    # Testing on simpe examples
    all_simple_samples = simple_img_dir() |> readdir |> filter_out_hidden

    img1_name = all_simple_samples[1]
    for img1_name = all_simple_samples
        println("\tWorking on image: $(img1_name)")

        # Load image
        img1 = img1_name |> simple_img_dir |> load
        scaled_img = floor.(Int, Gray.(img1) .* 255)

        # ===-===-
        # Get cycles and their persistence
        alg = :homology
        reps = true
        cutoff = 5
        input_img = scaled_img
        homology_config = @dict alg reps cutoff input_img

        homology_data, p = produce_or_load(
            homology_info_storage("homology_computation", data_name, "image_$(replace(img1_name, ".jpg"=>""))"), # path
            homology_config, # config
            prefix="homology_info", # file prefix
            force=false # force computations
        ) do homology_config

            @unpack alg, reps, cutoff, input_img = homology_config
            println("\tStarting homology computations...")
            homolgy_result = ripserer(Cubical(input_img), cutoff=cutoff, reps=reps, alg=alg)
            println("\tFinished homology computations. ")

            Dict("homolgy_result" => homolgy_result)
        end # produce_or_load

        homology_info = homology_data["homolgy_result"]
        cycles = homology_info[dim_index]
        perimeters = get_perimeter_sizes(cycles, img1)
        max_length = max(perimeters...)
        bar_step = floor(Int, 0.01max_length) * 10

        # Do the plotting
        cycles_on_image_canvas = fill(NaN, size(img1))
        for (k, cycle) in ProgressBar(enumerate(cycles), unit="Cycle", unit_scale=true)
            cycle_coordinates = get_cycle_boundary(cycle, img1)
            cycle_perimeter = length(cycle_coordinates)

            cycles_on_image_canvas[cycle_coordinates] .= cycle_perimeter
        end # cycle

        # ===-===-
        # Do the plotting
        plt_height, plt_width = size(img1)
        f = CairoMakie.Figure(; size=(plt_width ÷ 2, plt_height ÷ 2 + 100))
        fgl = CairoMakie.GridLayout(f[1, 1])

        # Get axis
        ax_isoline = CairoMakie.Axis(
            fgl[1, 1],
            aspect=AxisAspect(plt_width / plt_height),
        )
        # Plot hatmap
        CairoMakie.image!(
            ax_isoline,
            scaled_img[end:-1:1, :]',
            alpha=0.4,
            interpolate=false
        )

        if !all(isnan.(cycles_on_image_canvas))
            cycles_plt = CairoMakie.heatmap!(
                ax_isoline,
                cycles_on_image_canvas[end:-1:1, :]',
                colormap=cgrad(:roma, rev=true),
                alpha=1.0,
                interpolate=false,
                colorrange=(0, max_length),
            )

            Colorbar(
                fgl[2, 1],
                cycles_plt,
                label="Perimiter",
                ticks=0:bar_step:max_length,
                vertical=false,
                flipaxis=false,
            )
        else
            @warn "There are no cycles in dimension 1"
        end
        f

        for ax in [ax_isoline,]
            hidedecorations!(ax)
            hidespines!(ax)
        end
        f

        # Save image 
        trimmed_img_name = @pipe img1_name |> replace(_, ".jpg" => "") |> replace(_, ".png" => "")
        out_name = "$(plot_scriptprefix)_perimeter_coloured_cycles_$(data_name)_$(trimmed_img_name)"

        final_name1 = image_export_dir("$(CONFIG.DATA_CONFIG)_$(data_name)", out_name * ".png")
        safesave(final_name1, f)

    end # image name
end # dataset

# ===-===-
do_nothing = "ok"
