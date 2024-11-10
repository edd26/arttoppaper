using DrWatson
@quickactivate "ArtTopology"

# ===-===-
using Ripserer
using Images
# using Plots
using Statistics
using DelimitedFiles
using Pipe
using ProgressBars
using DataStructures: OrderedDict
using CairoMakie
using StatsBase: countmap

using ImageDistances: hausdorff
import Base.Threads: @sync, @spawn

"17_load_data_for_cycle_analysis.jl" |> scriptsdir |> include
"CycleCoverageUtils.jl" |> srcdir |> include

# ===-===-===-
import .CONFIG: IMG_WIDTH, IMG_HEIGHT
import .CONFIG: homology_info_storage
import .CONFIG: PERSISTENCE_THRESHOLD

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===- 8
plot_scriptprefix = "17h4"
image_export_dir(args...) = plotsdir("section17", "$(plot_scriptprefix)-cycles_density_ecdf_multiple_widow_size", "fixation_sequence=$(CONFIG.FIXATION_SEQUENCE)", args...)

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===- 8
# Load a sample image from art and fake
dim_index = 2
total_images = 12

color_palette = Makie.wong_colors()
art_color = color_palette[3]
fake_color = color_palette[6]
# ===-===-
do_density = true
window_sizes = [21, 51, 101, 151, 201, 401]
windows_range = 1:length(window_sizes)
total_windows = length(windows_range)

# ===-===-===-
plt_width = 700
plt_height = total_windows * 150 + 100
f = CairoMakie.Figure(; size=(plt_width, plt_height))
fgl = CairoMakie.GridLayout(f[1, 1])

window_size = 101
for (w, window_size) = window_sizes[windows_range] |> enumerate
    println("Working on window size: $(window_size)")
    total_rows = IMG_HEIGHT
    total_cols = IMG_WIDTH

    if do_density
        x_label = "Cycles Density"
    else
        x_label = "Total Number of Cycles in Window"
    end
    y_label = "ECDF"


    ax_ecdf = CairoMakie.Axis(
        fgl[w, 1],
        xlabel=x_label,
        ylabel=y_label,
        title="Window size $(window_size)",
    )

    data_name = dataset_names[2]
    for data_name in dataset_names
        println("\tWorking on data: $(data_name)")
        if data_name == "art"
            raw_img_name = "Artysta"
        else
            raw_img_name = "wystawa_fejkowa"
        end
        simple_img_dir(args...) = datadir("exp_pro", "img_initial_preprocessing", "BW", raw_img_name, args...)

        # ===-===-===-===-
        all_simple_samples = simple_img_dir() |> readdir |> filter_out_hidden

        if data_name == "art"
            c = art_color
        else
            c = fake_color
        end

        img1_name = all_simple_samples[1:total_images][1]
        for (k, img1_name) = enumerate(all_simple_samples[1:total_images])
            println("\t\tWorking on image: $(img1_name)")

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
            persistances = [persistence(cycle) for cycle in homology_info[dim_index]]

            # Add the cycle information to the map
            cycles = homology_info[dim_index]
            cycles_on_image = add_cycles_to_image(cycles, img1)

            # Create a plot with cycles
            cycles_count_in_window = count_unique_cycles_in_windows(cycles_on_image, window_size,)

            refactored_items_count = [k for k in cycles_count_in_window if k != 0 && !isnan(k)]
            unique_cycles_density = refactored_items_count ./ window_size^2

            total_bins = max(25, length(unique(unique_cycles_density)))

            if do_density
                plot_data = unique_cycles_density
            else
                plot_data = refactored_items_count
            end

            CairoMakie.ecdfplot!(
                ax_ecdf,
                plot_data,
                color=c
            )
        end # image name
    end # dataset

    CairoMakie.xlims!(ax_ecdf, low=0, high=0.09)
    CairoMakie.ylims!(ax_ecdf, low=0, high=1.1)

    ax_ecdf.xlabel = x_label
    ax_ecdf.xticks = 0:0.01:1.1
    if w == total_windows
        ax_ecdf.ylabel = y_label
    else
        hidexdecorations!(
            ax_ecdf,
            label=true,
            ticklabels=true,
            ticks=false,
            grid=false,
            minorgrid=false,
            minorticks=false
        )
    end

end
group_color = [PolyElement(color=color, strokecolor=:transparent)
               for color in [art_color, fake_color]]

Legend(fgl[end+1, 1],
    group_color,
    ["Art", "Pseudo-art"],
    "Dataset",
    tellheiht=false,
    tellwidth=false,
    framevisible=false,
    nbanks=2,
    halign=:right,
)

CairoMakie.rowsize!(fgl, total_windows + 1, Relative(0.07))

f
# ===-===-===-
# Save image 
out_name = "$(plot_scriptprefix)_cycles_density_ecdf_multiple_widow_size"

if do_density
    folder_name = "normalised"
else
    folder_name = ""
end
final_name1 = image_export_dir(folder_name, out_name * ".png")
safesave(final_name1, f)

final_name_pdf = image_export_dir(folder_name, "pdf", out_name * ".pdf")
safesave(final_name_pdf, f)

# ===-===-
do_nothing = "ok"
