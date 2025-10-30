
using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-
using DataStructures: OrderedDict
using DelimitedFiles
using Images
using PersistenceLandscapes
using CairoMakie
using Pipe
using Statistics
using Ripserer
using CairoMakie
using DataFrames: DataFrame
using Pipe

using HypothesisTests

using MakieExtra

import Base.Threads: @spawn, @sync

CairoMakie.set_theme!(fonts = (; regular = "Arial", bold = "Arial Bold"))
# ===-===-===-
"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include
"DataStructuresUtils.jl" |> srcdir |> include
"LandscapesPlotting.jl" |> srcdir |> include
"MakiePlots.jl" |> srcdir |> include

"ExtendedDatasetUtils.jl" |> srcdir |> include

# import .CONFIG: preproc_img_dir_set, SELECTED_DIM, PERSISTENCE_THRESHOLD, DATA_CONFIG
# import .CONFIG: ripserer_computations_dir

@info "Arguments processed."
# ====================================================
all_x_values = 0:255
all_x_index = 1:256
extension = ".jpg"
selected_config = CONFIG.DATA_CONFIG

all_datasets = vcat("all_pseudoart", artists_datasets)

# all_datasets =
persistence_data =
    populate_dict!(Dict(), [all_datasets, ["BW", "WB"]], final_structure = OrderedDict())


for d in all_datasets
    @info "Working on $(d)..."

    for selected_config in ["BW", "WB"]
        @info "\tWorking on $(d)..."

        simple_img_dir(args...) =
            datadir("exp_pro", "img_initial_preprocessing", CONFIG.DATA_CONFIG, d, args...)

        files_list = simple_img_dir() |> readdir |> filter_out_hidden |> sort
        files_list = filter(x -> occursin(CONFIG.DATA_CONFIG, x), files_list)
        artist_bw_files_names = @pipe files_list |> ["$(k[1])" for k in split.(_, ".")]

        files_selection = artist_bw_files_names

        for file in files_selection
            loading_name = if selected_config == "BW"
                file
            else
                replace(file, "BW" => "WB")
            end
            @info "\t\tWorking on file $(loading_name)"
            births_dict, deaths_dict = load_bd_data(loading_name, d)

            persistence_data[d][selected_config][loading_name] = Dict()
            for selected_dim in ["dim0", "dim1"]
                persistence_data[d][selected_config][loading_name][selected_dim] = Dict()
                @info "\t\t\tWorking on $(selected_dim)..."

                births = births_dict[selected_dim]
                deaths = deaths_dict[selected_dim]
                # ===-

                # get betti curve from barcodes
                x_range = 0:255

                betticurve_pt1 =
                    [(births .<= x .&& deaths .> x) |> sum for x in x_range[1:255]]

                betticurve = if selected_dim == 1
                    vcat(betticurve_pt1, [0])
                else
                    vcat(betticurve_pt1, [(births .<= 255 .&& deaths .>= 255) |> sum])
                end

                # ===-===-
                bettis = Dict(:x => x_range, :y => betticurve)
                resampled_betti = zeros(Int, length(all_x_values))
                resampled_betti[bettis[:x] .+ 1] .= bettis[:y]

                for x in all_x_index[2:end]
                    if resampled_betti[x] == 0
                        resampled_betti[x] = resampled_betti[x-1]
                    end
                end
                persistence_data[d][selected_config][loading_name][selected_dim]["betti"] =
                    Dict(:x => x_range, :y => betticurve)
                persistence_data[d][selected_config][loading_name][selected_dim]["resampled_bettis"] =
                    Dict(:x => x_range, :y => resampled_betti)

            end #file
        end # dconfig
    end # selected_dim
end # d selected_ config

# ===-===-===-===-===-

datasets_combinations = [
    # artists_datasets,
    all_datasets[all_datasets .!= "art".&&all_datasets .!= "pseudoart"],
    all_datasets[all_datasets .!= "pseudoart"],
    ["art", "pseudoart"],
]
art_labels_vec = ["all_art", "all_art", "art"]
non_art_labels_vec = ["all_pseudoart", "all_pseudoart", "pseudoart"]

# ===-===-===-===-===- ===-===-===-===-===-===-===-===-===-===- ===-===-===-===-===-
# Average betti

average_bettis = populate_dict!(
    Dict(),
    [all_datasets, ["BW", "WB"], ["dim0", "dim1"]],
    final_structure = zeros(1, length(all_x_index)),
)
median_bettis = populate_dict!(
    Dict(),
    [all_datasets, ["BW", "WB"], ["dim0", "dim1"]],
    final_structure = zeros(1, length(all_x_index)),
)
std_bettis = populate_dict!(
    Dict(),
    [all_datasets, ["BW", "WB"], ["dim0", "dim1"]],
    final_structure = zeros(1, length(all_x_index)),
)


# persistence_data["pseudoart"]["WB"][files[1]]

# dataset = "Jarema"
# persistence_dataset = persistence_data[dataset]

for (dataset, persistence_dataset) in persistence_data

    selected_config = "BW"
    persistence_config = persistence_dataset[selected_config]
    for (selected_config, persistence_config) in persistence_dataset
        files = [k for k in keys(persistence_config)]

        selected_dim = "dim0"
        for (selected_dim) in ["dim0", "dim1"]
            img_bettis = hcat(
                [
                    persistence_config[f][selected_dim]["resampled_bettis"][:y] for
                    f in files
                ]...,
            )

            average_bettis[dataset][selected_config][selected_dim] =
                mean(img_bettis, dims = 2)
            median_bettis[dataset][selected_config][selected_dim] =
                median(img_bettis, dims = 2)
            std_bettis[dataset][selected_config][selected_dim] = std(img_bettis, dims = 2)
        end
    end # selected_config
end # datset

## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# Create plots

betti_colours = get_bettis_color_palete(min_dim = 0);

art_colours = cgrad(
    [RGB([98, 197, 84] / 255...), RGB([91, 121, 177] / 255...), :purple],
    12,
    categorical = true,
)[1:12]
pseudoart_colours = cgrad(
    [RGB([150, 49, 49] / 255...), RGB([224, 154, 58] / 255...), :yellow],
    12,
    categorical = true,
    rev = true,
)[1:12]
colour_group = cgrad(:RdBu_9, 6 * 2 + 3, categorical = true)
colour_group = cgrad(:Paired_12, 12, categorical = true)

colurs_selection = OrderedDict(
    "art" => OrderedDict("dim0" => art_colours[1], "dim1" => art_colours[end-3]),
    "pseudoart" =>
        OrderedDict("dim0" => pseudoart_colours[end], "dim1" => pseudoart_colours[2]),
    "all_pseudoart" =>
        OrderedDict("dim0" => pseudoart_colours[end], "dim1" => pseudoart_colours[2]),
    # "Jarema" => OrderedDict("dim0" => colour_group[1], "dim1" => colour_group[end-0]),
    # "Malewicz" => OrderedDict("dim0" => colour_group[2], "dim1" => colour_group[end-1]),
    # "Pollock" => OrderedDict("dim0" => colour_group[3], "dim1" => colour_group[end-2]),
    # "Kandinsky" => OrderedDict("dim0" => colour_group[4], "dim1" => colour_group[end-3]),
    # "Richter" => OrderedDict("dim0" => colour_group[5], "dim1" => colour_group[end-4]),
    # "Rothko" => OrderedDict("dim0" => colour_group[6], "dim1" => colour_group[end-5]),
    "Jarema" => OrderedDict("dim0" => colour_group[1], "dim1" => colour_group[2]),
    "Malewicz" => OrderedDict("dim0" => colour_group[3], "dim1" => colour_group[4]),
    "Pollock" => OrderedDict("dim0" => colour_group[5], "dim1" => colour_group[6]),
    "Kandinsky" => OrderedDict("dim0" => colour_group[7], "dim1" => colour_group[8]),
    "Richter" => OrderedDict("dim0" => colour_group[9], "dim1" => colour_group[10]),
    "Rothko" => OrderedDict("dim0" => colour_group[11], "dim1" => colour_group[12]),
)

selected_datasets = all_datasets[all_datasets .!= "pseudoart"]

low_y = 0
high_y = 0
y_step = 0
y_range = 0:0:0

points_per_cm = 28.3465 * 1.6
final_width = 15.03 * points_per_cm
final_height = 22.86 * points_per_cm

for selected_config in ["BW", "WB"]

    f = CairoMakie.Figure(size = (final_width, final_height))
    fgl = CairoMakie.GridLayout(f[1, 1])

    supporting_low_y = -10
    supporting_high_y = 5000
    supporting_y_range = 0:1000:supporting_high_y

    d = 1
    selected_dim = "dim0"
    for (d, selected_dim) in ["dim0", "dim1"] |> enumerate
        if selected_dim == "dim1"
            y_label = L"$\beta_{1}$"
        else
            y_label = L"$\beta_{0}$"
        end

        if selected_dim == "dim1"
            low_y = -100
            high_y = 25000
            y_range = 0:5000:high_y
            y_label = L"$\beta_{1}$"
        else
            low_y = -100
            high_y = 32000
            y_range = 0:5000:high_y
            y_label = L"$\beta_{0}$"
        end

        dim_label = replace(selected_dim, "dim" => "dim.")

        i = 7
        selected_data = all_datasets[i]
        #for (i, selected_data) in ["art", "pseudoart"] |> enumerate
        for (i, selected_data) in selected_datasets |> enumerate

            data_label = if selected_data == "art"
                @pipe selected_data |> replace(_, "_" => " ") |> uppercasefirst
            elseif selected_data == "all_pseudoart"
                @pipe selected_data |> replace(_, "_" => " ") |> uppercasefirst
            elseif selected_data == "pseudoart"
                @pipe selected_data |> replace(_, "_" => " ") |> uppercasefirst
            else
                selected_data
            end

            axis_kwargs = (
                title = "$(selected_config), $(dim_label), $(data_label)",
                xtrimspine = true,
                ytrimspine = true,
                rightspinevisible = false,
                topspinevisible = false,
                xticks = 0:50:256,
                #  yticks=0:25:100,
                ylabel = y_label,
                ytickformat = yticks_formatter,
            )
            ax1 = CairoMakie.Axis(
                fgl[i, d];
                xlabel = "Filtration step",
                yticks = y_range,
                axis_kwargs...,
            )

            # Plot average beetis
            bettis_mean = average_bettis[selected_data][selected_config][selected_dim][:, 1]
            bettis_median =
                median_bettis[selected_data][selected_config][selected_dim][:, 1]
            band_low =
                bettis_mean .-
                std_bettis[selected_data][selected_config][selected_dim][:, 1]
            band_high =
                bettis_mean .+
                std_bettis[selected_data][selected_config][selected_dim][:, 1]

            band_low = [max(x, 0) for x in band_low]
            band_high = [max(x, 0) for x in band_high]


            c = colurs_selection[selected_data][selected_dim]

            selected_axis = if false #selected_data == "Rothko"
                grey_colour = RGBf(0.9, 0.9, 0.9)
                ax1.bottomspinecolor=grey_colour
                ax1.leftspinecolor=grey_colour
                ax1.xtickcolor=grey_colour
                ax1.ytickcolor=grey_colour
                ax1.xtickcolor=grey_colour
                ax1.xgridcolor=:white
                ax1.ygridcolor=:white
                ax1.xticklabelcolor = grey_colour
                ax1.yticklabelcolor = grey_colour
                ax1.title = ""

                inset = MakieExtra.Axis(
                    fgl[i, d];
                    width = Relative(0.9),
                    height = Relative(0.9),
                    halign = 0.4,
                    valign = 0.1,
                    backgroundcolor = (:white, 1.0),
                    yticks = supporting_y_range,
                    axis_kwargs...,
                )
                translate!(inset.blockscene, 30, 20, 100)
                zoom_lines!(ax1, inset)
                f

                CairoMakie.ylims!(inset, low = supporting_low_y, high = supporting_high_y)
                CairoMakie.xlims!(inset, low = -1, high = 256)
                f
                inset
            else
                ax1
            end
            f
            band!(selected_axis, all_x_values, band_low, band_high, color = (c, 0.3))
            lines!(selected_axis, all_x_values, bettis_mean, linewidth = 4, color = (c))
            lines!(
                selected_axis,
                all_x_values,
                bettis_median,
                linewidth = 2,
                linestyle = (:dot, :dense),
                color = (c),
            )

            # if selected_data == "Rothko"
            #     translate!(selected_axis.blockscene, 30, 20, 100)
            # end
            f


            # Plot individual curves
            for (k, (name, params_dict)) in
                enumerate(persistence_data[selected_data][selected_config])

                bettis_vector = params_dict[selected_dim]["resampled_bettis"][:y]
                data_label = selected_data

                line_alpha = 0.5
                linestyle = (:solid, :dense)
                lines!(
                    ax1,
                    all_x_values,
                    bettis_vector,
                    linestyle = linestyle,
                    linewidth = 1,
                    color = (c, line_alpha),
                )

            end # name
            if i == length(selected_datasets)
                ax1.xlabel = "Filtration step"
            else
                ax1.xlabel = ""
                hidexdecorations!(ax1, ticks = false, grid = false)
            end
            CairoMakie.ylims!(ax1, low = low_y, high = high_y)
            CairoMakie.xlims!(ax1, low = -1, high = 256)
        end # dim

    end # dataset

    f

    group_color = reduce(
        vcat,
        [
            [
                PolyElement(
                    color = colurs_selection[d]["dim0"],
                    strokecolor = :transparent,
                )
                PolyElement(
                    color = colurs_selection[d]["dim1"],
                    strokecolor = :transparent,
                )
            ] for d in all_datasets[all_datasets .!= "pseudoart"]
        ],
    )




    group_labels = reduce(
        vcat,
        [
            [
                "$(@pipe d |> replace(_, "_" => " ") |> uppercasefirst), dim. 0",
                "$(@pipe d |> replace(_, "_" => " ") |> uppercasefirst), dim. 1",
            ] for d in all_datasets[all_datasets .!= "pseudoart"]
        ],
    )

    group_lines = [
        LineElement(color = :gray, linestyle = :solid, linewidth = 4)
        LineElement(color = :gray, linestyle = (:dot, :dense), linewidth = 2)
        LineElement(color = :gray, linestyle = :solid, linewidth = 1)
        PolyElement(color = (:gray, 0.3), strokecolor = :gray)
    ]

    Legend(
        fgl[end+1, :],
        group_color,
        group_labels,
        "",
        nbanks = 4,
        tellheight = true,
        framevisible = false,
        orientation = :horizontal,
    )
    Legend(
        fgl[end+1, :],
        group_lines,
        ["Average curve", "Median curve", "Individual curve", "Standard deviation"],
        "",
        nbanks = 1,
        tellheight = true,
        framevisible = false,
        orientation = :horizontal,
    )

    display(f)

    # ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
    @info "Saving."
    scriptprefix = "2m5f"
    script_subname = "average_and_individual_betti_curves_all_data"
    plot_2m2_dir(args...) =
        plotsdir("section2", scriptprefix * "-$(script_subname)", args...)

    # ===-===-===-
    joined_keys = join(selected_datasets, "-")
    out_img_name = "$(script_subname)_$(selected_config)_$(joined_keys)"
    thr = "threshold=$(CONFIG.PERSISTENCE_THRESHOLD)"

    out_name = plot_2m2_dir("$(selected_config)_$(thr)", out_img_name * ".png")
    safesave(out_name, f, dpi = 300)

    # ===-===-
    # PDF export
    out_name = plot_2m2_dir("$(selected_config)_$(thr)", "pdf", out_img_name * ".pdf")
    safesave(out_name, f, dpi = 300)

    @info "Saved all files."

end
# ===-===-===-===-===- ===-===-===-===-===-===-===-===-===-===- ===-===-===-===-===-


## ===-===-
do_nothing = "ok"
