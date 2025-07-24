
using DrWatson
@quickactivate "arttopopaper"

# ===-===-
"17_load_data_for_cycle_analysis.jl" |> scriptsdir |> include

using Ripserer
using CairoMakie
using Pipe
using Images
using DataStructures: OrderedDict
using ProgressBars

CairoMakie.set_theme!(fonts = (; regular = "Arial", bold = "Arial Bold"))

import .CONFIG:
    IMG_WIDTH,
    IMG_HEIGHT,
    SPACE_WIDTH,
    SPACE_HEIGHT,
    STARTING_POINT,
    VIEWING_WIDTH,
    VIEWING_HEIGHT

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===- 8
plot_scriptprefix = "17g"
image_export_dir(args...) =
    plotsdir("section17", "$(plot_scriptprefix)-cycles_colured_by_persistence", args...)

# ===-===-===-===-===-===-===-===-===-===-===-
export_print = true
dim_index = 2

for data_name in dataset_names
    println("Working on data: $(data_name)")
    if data_name == "art"
        raw_img_name = "art"
    elseif data_name == "pseudoart"
        raw_img_name = "pseudoart"
    elseif data_name == "SimpleExamples"
        raw_img_name = "SimpleExamples"
    elseif data_name == "illusions"
        raw_img_name = "illusions"
    end
    simple_img_dir(args...) = datadir(
        "exp_pro",
        "img_initial_preprocessing",
        "$(CONFIG.DATA_CONFIG)",
        raw_img_name,
        args...,
    )

    # ===-===-===-===-
    # Testing on simpe examples
    all_simple_samples = simple_img_dir() |> readdir |> filter_out_hidden

    for img1_name in all_simple_samples
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
            ripserer_computations_dir(data_name, "image_$(replace(img1_name, ".jpg"=>""))"), # path
            homology_config, # config
            prefix = "homology_info", # file prefix
            force = false, # force computations
        ) do homology_config

            @unpack alg, reps, cutoff, input_img = homology_config
            println("\tStarting homology computations...")
            homolgy_result =
                ripserer(Cubical(input_img), cutoff = cutoff, reps = reps, alg = alg)
            println("\tFinished homology computations. ")

            Dict("homolgy_result" => homolgy_result)
        end # produce_or_load

        homology_info = homology_data["homolgy_result"]
        persistances = [persistence(barcode) for barcode in homology_info[dim_index]]

        # Do the plotting
        cycles = homology_info[dim_index]# [persistances.<20]
        cycles_on_image_canvas = get_cycles_on_image_canvas(img1, cycles)


        # ===-===-
        # Do the plotting

        img_height, img_width, = size(img1)
        size_ratio = img_width / img_height
        if export_print
            unit_pixel = 28 * 2
            height_in_cm = 10
            plt_height = unit_pixel * height_in_cm
            plt_width = plt_height * size_ratio
            plt_height += 50
        else
            plt_height = img_height ÷ 2
            plt_width = img_width ÷ 2 + 100
        end
        f = CairoMakie.Figure(; size = (plt_width, plt_height))
        fgl = CairoMakie.GridLayout(f[1, 1])

        # Get axis
        ax_isoline = CairoMakie.Axis(fgl[1, 1], aspect = AxisAspect(img_width / img_height))
        # Plot hatmap
        CairoMakie.image!(
            ax_isoline,
            scaled_img[end:-1:1, :]',
            alpha = 0.4,
            interpolate = false,
        )

        if !all(isnan.(cycles_on_image_canvas))
            cycles_plt = CairoMakie.heatmap!(
                ax_isoline,
                cycles_on_image_canvas[end:-1:1, :]',
                colormap = cgrad(:roma, rev = true),
                alpha = 1.0,
                interpolate = false,
                colorrange = (0, 255),
            )

            Colorbar(
                fgl[2, 1],
                cycles_plt,
                label = "Persistence",
                ticks = 0:50:255,
                vertical = false,
                flipaxis = false,
                ticklabelrotation = pi / 4,
            )

        else
            @warn "There are no cycles in dimension 1"
        end
        f

        for ax in [ax_isoline]
            hidedecorations!(ax)
            hidespines!(ax)
        end
        f

        # Save image 
        trimmed_img_name =
            @pipe img1_name |> replace(_, ".jpg" => "") |> replace(_, ".png" => "")
        out_name = "$(plot_scriptprefix)_persistence_coloured_cycles_$(data_name)_$(trimmed_img_name)"

        if export_print
            final_name2 = image_export_dir(
                "$(CONFIG.DATA_CONFIG)_$(data_name)",
                "print",
                out_name * ".png",
            )
            safesave(final_name2, f)

            @info "Exported as " final_name2
        else

            final_name1 =
                image_export_dir("$(CONFIG.DATA_CONFIG)_$(data_name)", out_name * ".png")
            safesave(final_name1, f)

            @info "Exported as " final_name1
        end
        # end # session, view
    end # image name
end # dataset

# ===-===-
do_nothing = "ok"
