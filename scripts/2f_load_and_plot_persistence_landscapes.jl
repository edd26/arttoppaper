using DrWatson
@quickactivate "ArtTopology"

# ===-===-===-
using DataStructures: OrderedDict
using DelimitedFiles
using Images
using PersistenceLandscapes
using StatsPlots
using TopologyPreprocessing
import Base.Threads: @spawn, @sync
# ===-===-===-
"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include

import .CONFIG: dipha_bd_info_export_folder_set, export_for_dipha_folder_set, preproc_img_dir_set, SELECTED_DIM, PERSISTENCE_THRESHOLD

@info "Arguments processed."
# ===-===-===-
readrows(file_name) = DelimitedFiles.readdlm(file_name, ',', Float64, '\n')

# ===-===-===-
files_list = dipha_bd_info_export_folder_set("dim=$(SELECTED_DIM)") |> readdir |> filter_out_hidden |> sort
filtered_list = filter_out_by_threshold(files_list, PERSISTENCE_THRESHOLD)
file = filtered_list[1]

# ===-===-===-
# Create individual plots
all_plots = OrderedDict()
only_landscapes = OrderedDict()

basic_height = 1070
basic_width = 1680

# file = filtered_list[end-3]
## ===-===-===-===-===-===-===-===-===-===-
# for file in filtered_list
@sync for file in filtered_list

    if occursin("Heatmaps", preproc_img_dir_set()) || (occursin("textures", preproc_img_dir_set()) && !occursin("natural", preproc_img_dir_set())) || occursin("Simple", preproc_img_dir_set())
        input_img_name = "$(split(file, "_dim=$(SELECTED_DIM)")[1]).png"
        # elseif CONFIG.DATA_SET
    else
        input_img_name = "$(split(file, "_dim=$(SELECTED_DIM)")[1]).jpg"
    end

    for dataconf in ["BW", "RGB"]
        if occursin("BW", input_img_name)
            input_img_name = replace(input_img_name, "_BW" => "")
        end
    end

    # ===-
    eye_track_img = input_img_name |> preproc_img_dir_set |> load |> channelview

    if length(size(eye_track_img)) >= 3
        eye_track_img = Gray.(eye_track_img)[1, :, :]
    end

    if isempty(eye_track_img)
        continue
        @info "Skipping, because empty " input_img_name
    else
        @info "Now on " file
    end

    # ===-
    data_matrix = zeros(1, 3)

    try
        data_matrix = dipha_bd_info_export_folder_set("dim=$(SELECTED_DIM)", file) |> readrows
    catch
        @warn "Failed to read csv file " file
    end
    births = data_matrix[:, 2]
    deaths = data_matrix[:, 3]

    persistances = deaths - births
    bd_data = [data_matrix[:, 2:3]]
    barcodes = [MyPair(b, d) for (b, d) in zip(births, deaths)] |> PersistenceBarcodes
    landscape = PersistenceLandscape(barcodes)
    max_land_height = √2 * 255 * 0.5

    landscape_plt = plot_persistence_landscape(
        landscape,
        legend=false,
        xlims=(0, 255),
        ylims=(0, max_land_height),
        yticks=0:20:max_land_height,
        xticks=0:20:255,
        title=split(file, ".csv")[1],
    )

    barcodes_of_img = plot(
        heatmap(
            eye_track_img,
            xticks=false,
            yticks=false,
            c=:grays,
            cbar=false,
            # title=img_file
        ),
        plot(
            plot(landscape_plt,
                title=""
            ),
            plot_barcodes(bd_data,
                xlims=(0, 255),
                min_dim=SELECTED_DIM,
                size=(1680 / 2, 2 * 1070 * 0.9)
            ),
            layout=grid(2, 1, heights=[0.4, 0.6]),
        ),
        plot_title=input_img_name,
        layout=grid(1, 2, widths=[0.5, 0.5]),
        size=(basic_width, basic_height)
    )
    all_plots[file] = barcodes_of_img
    only_landscapes[file] = landscape_plt
end

## ===-===-
do_nothing = "ok"