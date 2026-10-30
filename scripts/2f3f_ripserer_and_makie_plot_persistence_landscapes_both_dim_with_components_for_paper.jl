#=
Load csv with bd info and plot distribution

=#

using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-
using DataStructures: OrderedDict
using DelimitedFiles
using Images
using PersistenceLandscapes
using Makie
using CairoMakie
# using TopologyPreprocessing
using Pipe
using Ripserer

import Base.Threads: @spawn, @sync

CairoMakie.set_theme!(fonts = (; regular = "Arial", bold = "Arial Bold"))
# ===-===-===-
"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include
"DataStructuresUtils.jl" |> srcdir |> include
"LandscapesPlotting.jl" |> srcdir |> include
"MakiePlots.jl" |> srcdir |> include

import .CONFIG:
    dipha_bd_info_export_folder,
    dipha_bd_info_export_folder_set,
    export_for_dipha_folder_set,
    preproc_img_dir,
    SELECTED_DIM,
    PERSISTENCE_THRESHOLD,
    DATA_SET,
    DATA_CONFIG

@info "Arguments processed."
# ===-===-===-
readrows(file_name) = DelimitedFiles.readdlm(file_name, ',', Float64, '\n')


data_folder = DATA_SET
# ===-===-===-
last_of_filtration = 6
filtration_step = 1
selected_dim = 1
raw_img_name = DATA_SET

alg = :homology
reps = true

simple_img_dir(args...) =
    datadir("exp_pro", "img_initial_preprocessing", CONFIG.DATA_CONFIG, raw_img_name, args...)

files_list = simple_img_dir() |> readdir |> filter_out_hidden |> sort
files_list = filter(x -> occursin("$(CONFIG.DATA_CONFIG)", x), files_list)
extension = isempty(files_list) ? ".png" : splitext(first(files_list))[2]
files_names = [split(splitext(f)[1], "_dim=")[1] for f in files_list]

@assert !isempty(files_names)

# files_list = dipha_bd_info_export_folder("BW", data_folder, "dim=$(selected_dim)") |> readdir |> filter_out_hidden |> sort
# files_list = filter(x -> occursin("$(CONFIG.DATA_CONFIG)", x), files_list)
# files_names = @pipe [k for k in filter_out_by_threshold(files_list, PERSISTENCE_THRESHOLD)] |>
#                     [k[1] for k in split.(_, ".")] |>
#                     [k[1] for k in split.(_, "_dim=")]

persistence_data = populate_dict!(
    Dict(),
    [["BW", "WB"], ["dim0", "dim1"]],
    final_structure = OrderedDict(),
)

# file = files_names[end-2]
for file in files_names
    name = split(file, "_dim=")[1]

    @info "Working on file $(file)"

    # Load image
    img1 = name * extension |> simple_img_dir |> load
    scaled_img = floor.(Int, Gray.(img1) .* last_of_filtration)
    scaled_img_WB = abs.(scaled_img .- last_of_filtration)

    selected_dim = 0
    input_img = scaled_img
    for (data_config, input_img) in zip(["BW", "WB"], [scaled_img, scaled_img_WB])

        if data_config == "BW"
            loading_name = name
        else
            loading_name = replace(name, "BW" => "WB")
        end

        # ===-===-
        # Get cycles and their persistence

        println("\tStarting homology computations...")
        homology_info = ripserer(Cubical(input_img), cutoff = 0, reps = reps, alg = alg)
        println("\tFinished homology computations. ")

        # ===
        selected_dim = 0
        dim_index = 1
        for (dim_index, selected_dim) in enumerate([0, 1])
            births = [barcode[1] for barcode in homology_info[dim_index]]
            deaths = [barcode[2] for barcode in homology_info[dim_index]]
            deaths = replace(x -> isinf(x) ? last_of_filtration : x, deaths)

            persistances_orig =
                [persistence(barcode) for barcode in homology_info[dim_index]]
            persistances =
                replace(x -> isinf(x) ? last_of_filtration : x, persistances_orig)

            # ===-
            bd_data = [hcat(births, deaths)]
            persistances = deaths - births
            barcodes =
                [MyPair(b, d) for (b, d) in zip(births, deaths)] |> PersistenceBarcodes

            x_range = 0:last_of_filtration
            betticurve_pt1 = [
                (births .<= x .&& deaths .> x) |> sum for x in x_range[1:last_of_filtration]
            ]

            # add (0,0 ) at the beginning
            x_range = vcat([0], x_range)
            betticurve = vcat([0], betticurve_pt1)
            betticurve = vcat(betticurve, [0])

            bettis = Dict(:x => x_range, :y => betticurve)

            persistence_data[data_config]["dim$(selected_dim)"][loading_name] = Dict()
            persistence_data[data_config]["dim$(selected_dim)"][loading_name]["landscapes"] =
                PersistenceLandscape(barcodes)
            persistence_data[data_config]["dim$(selected_dim)"][loading_name]["barcodes"] =
                bd_data
            persistence_data[data_config]["dim$(selected_dim)"][loading_name]["betti"] =
                bettis
        end # selected_dim
    end # config
    # end #file


    ## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
    # Do the plotting

    # scaling_factor = 1
    plt_width = 840
    plt_height = 800

    max_x_val = last_of_filtration
    max_land_height = √2 * last_of_filtration * 0.5


    @info "Name: $(name)"
    name_bw = name
    name_wb = replace(name, "BW" => "WB")
    data_config = "BW"
    d_index = 1

    f = CairoMakie.Figure(size = (plt_width, plt_height))
    fgl_all = CairoMakie.GridLayout(f[1, 1])
    for (d_index, data_config) in enumerate(["BW", "WB"])
        fgl = CairoMakie.GridLayout(fgl_all[d_index, 1])

        if data_config == "WB"
            sort_by_death = true
        else
            sort_by_death = false
        end

        if data_config == "WB"
            used_name = replace(name, "BW" => "WB")
        else
            used_name = name
        end

        input_img_name = used_name * extension
        if !occursin(data_config, used_name)
            input_img_name = used_name * "_$(data_config)" * extension
        else
            input_img_name = used_name * extension
        end

        loaded_img =
            preproc_img_dir(data_config, data_folder, input_img_name) |> load |> channelview
        if loaded_img |> size |> length == 3
            loaded_img = loaded_img[1, :, :]
        end

        # ===-===- 
        persistence_dim0 = Int[]
        persistence_dim1 = Int[]
        if sort_by_death
            @info "Sorting by death"
            persistence_dim0 =
                persistence_data[data_config]["dim0"][used_name]["barcodes"][1]
            persistence_dim1 =
                persistence_data[data_config]["dim1"][used_name]["barcodes"][1]

            persistence_dim0 = persistence_dim0[sortperm(persistence_dim0[:, 2]), :]
            persistence_dim1 = persistence_dim1[sortperm(persistence_dim1[:, 2]), :]
        else
            persistence_dim0 =
                persistence_data[data_config]["dim0"][used_name]["barcodes"][1]
            persistence_dim1 =
                persistence_data[data_config]["dim1"][used_name]["barcodes"][1]

            persistence_dim0 = persistence_dim0[sortperm(persistence_dim0[:, 1]), :]
            persistence_dim1 = persistence_dim1[sortperm(persistence_dim1[:, 1]), :]
        end
        # ===-

        ax_betti0 = CairoMakie.Axis(fgl[3, 2], ylabel = "Betti number")
        ax_betti1 = CairoMakie.Axis(fgl[3, 3])

        ax_barcode0 = CairoMakie.Axis(fgl[2, 2], ylabel = "barcode index")#, ytickformat=values -> ["1e$(log10(value))" for value in values])
        ax_barcode1 = CairoMakie.Axis(fgl[2, 3])#, ytickformat=values -> ["1e$(log10(value))" for value in values])

        ax_pland0 = CairoMakie.Axis(fgl[1, 2])
        ax_pland1 = CairoMakie.Axis(fgl[1, 3])


        ax_img = CairoMakie.Axis(fgl[:, 1], aspect = AxisAspect(1))

        # ===-===- 
        # add lablels 
        for (metric_index, metric) in
            ["Persistence\nlansdcape", "Barcodes", "Betti curve"] |> enumerate
            # Box(fgl[metric_index, 4], color=:gray90)
            Label(
                fgl[metric_index, 4],
                metric,
                rotation = -pi / 2,
                tellheight = false,
                halign = :left,
                font = :bold,
            )
        end

        # ===-===-
        image!(ax_img, loaded_img', interpolate = false)
        ax_img.yreversed = true

        color_vectors = [[:green, :black], [:yellow, :black]]
        for (ax, local_dim, colour_vec) in
            zip([ax_pland0, ax_pland1], ["dim0", "dim1"], color_vectors)
            max_colour_range = size(
                persistence_data[data_config][local_dim][used_name]["landscapes"].land,
                1,
            )
            custom_colors = [
                RGBf(c) for c in cgrad(
                    colour_vec,
                    max(2, max_colour_range),
                    categorical = true,
                    rev = false,
                )
            ]
            plot_persistence_landscape!(
                ax,
                persistence_data[data_config][local_dim][used_name]["landscapes"],
                custom_colors = custom_colors,
            )
        end

        colours = get_bettis_color_palete(min_dim = 0)
        f

        mplot_barcodes!(
            ax_barcode0,
            persistence_dim0,
            colour = colours[1],
            rev = sort_by_death,
        )
        mplot_barcodes!(
            ax_barcode1,
            persistence_dim1,
            colour = colours[2],
            rev = sort_by_death,
        )

        mplot_bettis!(
            ax_betti0,
            persistence_data[data_config]["dim0"][used_name]["betti"],
            colour = colours[1],
            step = :post,
        )
        mplot_bettis!(
            ax_betti1,
            persistence_data[data_config]["dim1"][used_name]["betti"],
            colour = colours[2],
            step = :post,
        )

        for (pers, ax_bars) in
            zip([persistence_dim0, persistence_dim1], [ax_barcode0, ax_barcode1])
            total_bars = size(pers, 1)
            tick_step = 1
            if total_bars <= 8
                tick_step = 1
            elseif total_bars <= 16
                tick_step = 2
            else
                tick_step = 5
            end
            ax_bars.yticks = 1:tick_step:(total_bars+1)
        end
        f

        for (pers, ax_betti) in
            zip([persistence_dim0, persistence_dim1], [ax_betti0, ax_betti1])
            total_bars = size(pers, 1)
            tick_step = 1
            if total_bars <= 8
                tick_step = 1
            elseif total_bars <= 16
                tick_step = 2
            else
                tick_step = 5
            end
            ax_betti.yticks = 1:tick_step:(total_bars+1)
        end
        f

        hidedecorations!(
            ax_img,
            label = true,
            ticklabels = true,
            ticks = true,
            grid = true,
            minorgrid = true,
            minorticks = true,
        )

        # hidespines!(ax_img, :t, :r, :l, :b)

        hidespines!(ax_pland0, :t, :r, :l)
        hidespines!(ax_pland1, :t, :r, :l)

        hidespines!(ax_barcode0, :t, :b, :r)
        hidespines!(ax_barcode1, :t, :b, :r)

        hidespines!(ax_betti0, :t, :r)
        hidespines!(ax_betti1, :t, :r)

        for (ax, local_dim) in zip([ax_pland0, ax_pland1], ["dim0", "dim1"])
            # CairoMakie.xlims!(ax, low=0, high=last_of_filtration,)
            CairoMakie.ylims!(ax, low = 0, high = max_land_height)
            ax.xticks = 0:filtration_step:last_of_filtration
            ax.yticks = 0:filtration_step:max_land_height
            ax.title = "Dimension $(split(local_dim, "dim")[2])"

            hidexdecorations!(
                ax,
                label = true,
                ticklabels = true,
                ticks = true,
                grid = false,
                minorgrid = false,
                minorticks = false,
            )
        end
        for (ax, label) in zip([ax_barcode0, ax_barcode1], ["0", "1"])
            # CairoMakie.xlims!(ax, low=0, high=last_of_filtration,)
            ax.xticks = 0:filtration_step:last_of_filtration
            # ax.title = "Barcodes, dim $(label)"
            hidexdecorations!(
                ax,
                label = true,
                ticklabels = true,
                ticks = true,
                grid = false,
                minorgrid = false,
                minorticks = false,
            )
        end

        for ax in [ax_pland0, ax_pland1]
            hideydecorations!(
                ax,
                label = true,
                ticklabels = true,
                ticks = true,
                grid = false,
                minorgrid = false,
                minorticks = false,
            )
        end

        # ===-===-
        for (pers, ax_betti) in
            zip([persistence_dim0, persistence_dim1], [ax_betti0, ax_betti1])
            total_bars = size(pers, 1)
            # CairoMakie.xlims!(ax_betti, low=0, high=last_of_filtration + 1,)
            CairoMakie.ylims!(ax_betti, low = 0, high = total_bars + 1)
            ax_betti.xticks = 0:filtration_step:last_of_filtration
            ax_betti.xticklabelrotation = -pi / 2

            # ax_betti.yticks = 0:filtration_step:last_of_filtration
        end

        # ===-===-
        CairoMakie.rowgap!(fgl, 10)
        CairoMakie.colgap!(fgl, 20)

        CairoMakie.rowsize!(fgl, 1, Relative(0.3))
        CairoMakie.colsize!(fgl, 1, Relative(0.5))
        CairoMakie.colsize!(fgl, 2, Relative(0.22))
        CairoMakie.colsize!(fgl, 3, Relative(0.22))
        CairoMakie.colsize!(fgl, 4, Relative(0.02))

    end

    f
    # ===-===-===-===-===-===-===-===-===-===-


    # # ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
    @info "Saving."
    scriptprefix = "2f3f"
    plot_2f_dir(args...) = plotsdir(
        "section2",
        scriptprefix * "-landscapes",
        "persistance-landscapes-both-dim",
        args...,
    )

    # # ===-===-===-
    # for (file, f) in figures_collection
    file = name
    @info "File: $(file)"
    out_img_name = "$(split(file, ".csv")[1]).png"
    thr = "threshold=$(PERSISTENCE_THRESHOLD)"

    out_name = plot_2f_dir(DATA_SET, thr, out_img_name)
    safesave(out_name, f, dpi = 300)

    # ===-===-
    # PDF export
    out_img_name2 = "$(split(file, ".csv")[1]).pdf"

    out_name = plot_2f_dir(DATA_SET, thr, "pdf", out_img_name2)
    safesave(out_name, f, dpi = 300)
end

@info "Saved all files."
## ===-===-
do_nothing = "ok"
