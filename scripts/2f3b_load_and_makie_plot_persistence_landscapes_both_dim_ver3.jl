using DrWatson
@quickactivate "ArtTopology"

# ===-===-===-
using DataStructures: OrderedDict
using DelimitedFiles
using Images
using PersistenceLandscapes
using Makie
using CairoMakie
using TopologyPreprocessing
using Pipe
using Ripserer

import Base.Threads: @spawn, @sync
# ===-===-===-
"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include
"DataStructuresUtils.jl" |> srcdir |> include
"LandscapesPlotting.jl" |> srcdir |> include
"MakiePlots.jl" |> srcdir |> include

import .CONFIG: dipha_bd_info_export_folder, export_for_dipha_folder, preproc_img_dir, SELECTED_DIM, PERSISTENCE_THRESHOLD, DATA_CONFIG
import .CONFIG: homology_info_storage

@info "Arguments processed."
# ===-===-===-
readrows(file_name) = DelimitedFiles.readdlm(file_name, ',', Float64, '\n')

# ===-===-===-
persistence_data = populate_dict!(Dict(),
    [["BW", "WB"], ["dim0", "dim1"]],
    final_structure=OrderedDict()
)

if CONFIG.DATA_SET == "fake"
    data_folder = "wystawa_fejkowa"
else
    data_folder = CONFIG.DATA_SET
end

selected_dim = 1
for data_config = ["BW", "WB"]

    files_list = dipha_bd_info_export_folder("$(data_config)", data_folder, "dim=$(selected_dim)") |> readdir |> filter_out_hidden |> sort
    files_list = filter(x -> occursin("$(data_config)", x), files_list)
    bw_files_names = @pipe [k for k in filter_out_by_threshold(files_list, PERSISTENCE_THRESHOLD)] |>
                           [k[1] for k in split.(_, ".")] |>
                           [k[1] for k in split.(_, "_dim=")]

    for file in bw_files_names
        @info "Working on file $(file)"

        name = split(file, "_dim=")[1]

        extension = ""
        if CONFIG.DATA_SET == "Artysta"
            raw_img_name = "Artysta"
            extension = ".jpg"
        elseif CONFIG.DATA_SET == "fake"
            raw_img_name = "wystawa_fejkowa"
            extension = ".jpg"
        elseif CONFIG.DATA_SET == "SimpleExamples"
            raw_img_name = "SimpleExamples"
            extension = ".png"
        elseif CONFIG.DATA_SET == "illusions"
            raw_img_name = "illusions"
            extension = ".jpg"
        else
            ErrorException("raw img name not set") |> throw
        end
        simple_img_dir(args...) = datadir("exp_pro", "img_initial_preprocessing", "$(data_config)", raw_img_name, args...)


        # Load image
        img1 = name * extension |> simple_img_dir |> load
        scaled_img = floor.(Int, Gray.(img1) .* 255)
        scaled_img_WB = abs.(scaled_img .- 255)

        selected_dim = 0
        input_img = scaled_img
        for (data_config, input_img) = zip(["BW", "WB",], [scaled_img, scaled_img_WB])
            # for data_config = ["WB", "BW"]

            if data_config == "BW"
                loading_name = name
            else
                loading_name = replace(name, "BW" => "WB")
            end

            @info data_config
            # ===-===-
            # Get cycles and their persistence
            alg = :homology
            reps = true
            cutoff = PERSISTENCE_THRESHOLD
            homology_config = @dict alg reps cutoff input_img

            homology_data, p = produce_or_load(
                homology_info_storage("homology_computation", CONFIG.DATA_SET, "image_$(replace(loading_name, ".jpg"=>""))"), # path
                homology_config, # config
                prefix="homology_info", # file prefix
                # force=true # force computations
            ) do homology_config
                @unpack alg, reps, cutoff, input_img = homology_config
                println("\tStarting homology computations...")
                homolgy_result = ripserer(Cubical(input_img), cutoff=cutoff, reps=reps, alg=alg)
                println("\tFinished homology computations. ")
                # Last line is the dictionary with the results
                Dict("homolgy_result" => homolgy_result)
            end # produce_or_load

            homology_info = homology_data["homolgy_result"]

            for (dim_index, selected_dim) in enumerate([0, 1])
                births = [barcode[1] for barcode in homology_info[dim_index]]
                deaths = [barcode[2] for barcode in homology_info[dim_index]]
                persistances = [persistence(barcode) for barcode in homology_info[dim_index] if !isinf(persistence(barcode))]

                # handle infs bars
                births = replace(births, Inf => 255)
                deaths = replace(deaths, Inf => 255)
                all_infs = findall(x -> isinf(x), [persistence(barcode) for barcode in homology_info[dim_index]])
                persistances = vcat(persistances, [255 for _ in 1:length(all_infs)]...)

                # ===-
                bd_data = [hcat(births, deaths)]
                persistances = deaths - births
                barcodes = [MyPair(b, d) for (b, d) in zip(births, deaths)] |> PersistenceBarcodes

                # get betti curve from barcodes
                x_range = 0:255

                if selected_dim == 1
                    betticurve_pt1 = [
                        (births .<= x .&& deaths .> x) |> sum
                        for x in x_range[1:255]]
                    betticurve = vcat(betticurve_pt1, [0])
                else
                    betticurve_pt1 = [
                        (births .<= x .&& deaths .> x) |> sum
                        for x in x_range[1:255]]
                    betticurve = vcat(betticurve_pt1, [
                        (births .<= 255 .&& deaths .>= 255) |> sum
                    ])
                end

                bettis = Dict(
                    :x => x_range,
                    :y => betticurve
                )

                persistence_data[data_config]["dim$(selected_dim)"][loading_name] = Dict()
                persistence_data[data_config]["dim$(selected_dim)"][loading_name]["landscapes"] = PersistenceLandscape(barcodes)
                persistence_data[data_config]["dim$(selected_dim)"][loading_name]["barcodes"] = bd_data
                persistence_data[data_config]["dim$(selected_dim)"][loading_name]["betti"] = bettis
            end # selected_dim
        end # config
    end #file
end


## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# Do the plotting
selected_dim = 1

data_config = CONFIG.DATA_CONFIG

files_list = dipha_bd_info_export_folder(data_config, data_folder, "dim=$(selected_dim)") |> readdir |> filter_out_hidden |> sort
files_list = filter(x -> occursin("$(data_config)", x), files_list)
files_names = @pipe [k for k in filter_out_by_threshold(files_list, PERSISTENCE_THRESHOLD)] |>
                    [k[1] for k in split.(_, ".")] |>
                    [k[1] for k in split.(_, "_dim=")]

figures_collection = Dict()
@info files_names

if data_config == "WB"
    sort_by_death = true
else
    sort_by_death = false
end
# ===-===-
selected_fontsize = 9
basic_height = 255
basic_width = 290 - 10

max_x_val = 255
max_land_height = √2 * 255 * 0.5

scaling_factor = 1

for name in files_names
    @info "Name: $(name)"

    if occursin("Heatmaps", preproc_img_dir(data_config, data_folder)) || (occursin("textures", preproc_img_dir(data_config, data_folder)) && !occursin("natural", preproc_img_dir(data_config, data_folder))) || occursin("Simple", preproc_img_dir(data_config, data_folder))
        extension = ".png"
    elseif CONFIG.DATA_SET == "SimpleExamples"
        if occursin("example", name)
            extension = ".jpg"
        else
            extension = ".png"
        end
    elseif name == "triangle_BW"
        extension = ".png"
    elseif occursin("IMG_", name) || occursin("border", name)
        extension = ".png"
    else
        extension = ".jpg"
    end

    input_img_name = name * extension
    if !occursin(data_config, name)
        input_img_name = name * "_$(data_config)" * extension
    else
        input_img_name = name * extension
    end


    loaded_img = preproc_img_dir(data_config, data_folder, input_img_name) |> load |> channelview
    if loaded_img |> size |> length == 3
        loaded_img = loaded_img[1, :, :]
    end

    # ===-
    plt_width = basic_width * scaling_factor
    plt_height = basic_height * scaling_factor

    f = CairoMakie.Figure(size=(plt_width, plt_height,))

    fgl = CairoMakie.GridLayout(f[1, 1])

    ax_barcode0 = CairoMakie.Axis(
        fgl[3, 2],
        xlabel="Pixel intensity",
        ytickformat=yticks_formatter
    )
    ax_barcode1 = CairoMakie.Axis(
        fgl[3, 3],
        xlabel="Pixel intensity",
        ytickformat=yticks_formatter
    )

    ax_pland0 = CairoMakie.Axis(fgl[2, 2])
    ax_pland1 = CairoMakie.Axis(fgl[2, 3])

    for ax in [ax_barcode0, ax_barcode1, ax_pland0, ax_pland1]
        ax.xlabelsize = selected_fontsize
        ax.ylabelsize = selected_fontsize
        ax.xticklabelsize = selected_fontsize - 2
        ax.yticklabelsize = selected_fontsize - 2
        ax.titlesize = selected_fontsize
    end
    # ===-===- 
    for (metric_index, label) in zip([2, 3], ["A.U.", "Cycle index"])
        Label(fgl[metric_index, 1], label, rotation=pi / 2, tellheight=false, fontsize=selected_fontsize)
    end

    # ===-===-
    pland_max_vals = []
    color_vectors = [[:green, :black], [:yellow, :black]]
    color_vectors = [:linear_kgy_5_95_c69_n256, :sun,]
    for (ax, local_dim, colour_vec) in zip([ax_pland0, ax_pland1], ["dim0", "dim1"], color_vectors)
        max_colour_range = size(persistence_data[data_config][local_dim][name]["landscapes"].land, 1)
        custom_colors = [RGBf(c) for c in cgrad(colour_vec, max(2, max_colour_range), categorical=true, rev=false,)]
        plot_persistence_landscape!(
            ax,
            persistence_data[data_config][local_dim][name]["landscapes"],
            custom_colors=custom_colors
        )
        push!(pland_max_vals, max_colour_range)
    end

    for k in 1:2
        if pland_max_vals[k] < 10
            tick_step = 4
        elseif pland_max_vals[k] < 51
            tick_step = 10
        elseif pland_max_vals[k] < 100
            tick_step = 20
        elseif pland_max_vals[k] < 501
            tick_step = 100
        elseif pland_max_vals[k] < 1000
            tick_step = 200
        elseif pland_max_vals[k] < 4000
            tick_step = 500
        elseif pland_max_vals[k] < 7000
            tick_step = 1000
        elseif pland_max_vals[k] < 13000
            tick_step = 2000
        else
            tick_step = 4000
        end
        Colorbar(
            fgl[1, k+1], # +1 for the lable on the left
            limits=(0, pland_max_vals[k]),
            ticks=0:tick_step:pland_max_vals[k],
            ticklabelrotation=pi / 4,
            tickformat=yticks_formatter,
            colormap=cgrad(color_vectors[k], max(2, pland_max_vals[k]), categorical=true, rev=false),
            vertical=false,
            label="landscape layer",
            labelsize=selected_fontsize - 2,
            ticklabelsize=selected_fontsize - 2,
            size=7
        )
    end
    f

    colours = get_bettis_color_palete(min_dim=0)

    if data_config == "WB"
        persistence_dim0 = persistence_data[data_config]["dim0"][name]["barcodes"][1]
        persistence_dim1 = persistence_data[data_config]["dim1"][name]["barcodes"][1]

        persistence_dim0 = persistence_dim0[sortperm(persistence_dim0[:, 2]), :]
        persistence_dim1 = persistence_dim1[sortperm(persistence_dim1[:, 2]), :]
        sort_by_death = true
    else
        persistence_dim0 = persistence_data[data_config]["dim0"][name]["barcodes"][1]
        persistence_dim1 = persistence_data[data_config]["dim1"][name]["barcodes"][1]

        persistence_dim0 = persistence_dim0[sortperm(persistence_dim0[:, 1]), :]
        persistence_dim1 = persistence_dim1[sortperm(persistence_dim1[:, 1]), :]
        sort_by_death = false
    end

    mplot_barcodes!(ax_barcode0, persistence_dim0, colour=colours[1], rev=sort_by_death)
    mplot_barcodes!(ax_barcode1, persistence_dim1, colour=colours[2], rev=sort_by_death)

    # ===-===-
    for (ax, local_dim) in zip([ax_pland0, ax_pland1], ["dim0", "dim1"])
        CairoMakie.xlims!(ax, low=0, high=255,)
        CairoMakie.ylims!(ax, low=0, high=max_land_height,)
        ax.xticks = 0:50:255
        ax.yticks = 0:50:max_land_height
        ax.xticklabelrotation = pi / 4
        ax.yticklabelrotation = pi / 4

        hidexdecorations!(ax,
            label=true,
            ticklabels=true,
            ticks=true,
            grid=false,
            minorgrid=false,
            minorticks=false
        )
    end
    for (ax, label) in zip([ax_barcode0, ax_barcode1], ["0", "1"])
        CairoMakie.xlims!(ax, low=0, high=255,)
        ax.xticks = 0:50:255
        ax.xticklabelrotation = pi / 4
        ax.yticklabelrotation = pi / 4
    end


    if data_config == "BW"
        bare_name = split(name, "BW")[1]
    else
        bare_name = split(name, "WB")[1]
    end

    total_barcodes_BW_d1 = size(persistence_data["BW"]["dim1"][bare_name*"BW"]["barcodes"][1], 1)
    total_barcodes_WB_d1 = size(persistence_data["WB"]["dim1"][bare_name*"WB"]["barcodes"][1], 1)
    total_barcodes_BW_d0 = size(persistence_data["BW"]["dim0"][bare_name*"BW"]["barcodes"][1], 1)
    total_barcodes_WB_d0 = size(persistence_data["WB"]["dim0"][bare_name*"WB"]["barcodes"][1], 1)
    max_total_barcodes = max(total_barcodes_BW_d0, total_barcodes_WB_d0, total_barcodes_BW_d1, total_barcodes_WB_d1)

    CairoMakie.ylims!(ax_barcode0, high=1.1max_total_barcodes, low=-10)
    CairoMakie.ylims!(ax_barcode1, high=1.1max_total_barcodes, low=-10)

    CairoMakie.rowgap!(fgl, 8)
    CairoMakie.colgap!(fgl, 5)

    CairoMakie.rowsize!(fgl, 1, Relative(0.03))
    CairoMakie.rowsize!(fgl, 2, Relative(0.30))
    CairoMakie.rowsize!(fgl, 3, Relative(0.75))

    CairoMakie.colsize!(fgl, 1, Relative(0.01))
    CairoMakie.colsize!(fgl, 2, Relative(0.52))
    CairoMakie.colsize!(fgl, 3, Relative(0.52))

    f
    figures_collection[name] = f
end
# end

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
@info "Saving."
scriptprefix = "2f3b2"
plot_2f_dir(args...) = plotsdir("section2", scriptprefix * "-landscapes-without-img", "persistance-landscapes-both-dim", args...)

# ===-===-===-
for (file, img_plot) in figures_collection
    @info "File: $(file)"
    out_img_name = "$(split(file, ".csv")[1]).png"
    thr = "threshold=$(PERSISTENCE_THRESHOLD)"

    if sort_by_death
        out_name = plot_2f_dir(data_config, CONFIG.DATA_SET, thr * "_death_sorted", out_img_name)
    else
        out_name = plot_2f_dir(data_config, CONFIG.DATA_SET, thr, out_img_name)
    end
    safesave(out_name, img_plot)

    # ===-===-
    # PDF export
    out_img_name = "$(split(file, ".csv")[1]).pdf"

    if sort_by_death
        out_name = plot_2f_dir(data_config, CONFIG.DATA_SET, thr * "_death_sorted", "pdf", out_img_name)
    else
        out_name = plot_2f_dir(data_config, CONFIG.DATA_SET, thr, "pdf", out_img_name)
    end
    safesave(out_name, img_plot)
end
# end # data_config

@info "Saved all files in " plot_2f_dir(data_config, CONFIG.DATA_SET,)
## ===-===-
do_nothing = "ok"
