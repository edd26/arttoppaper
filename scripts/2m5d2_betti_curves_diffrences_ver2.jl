
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
using LaTeXStrings

using HypothesisTests

import Base.Threads: @spawn, @sync
import Dates: now

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

scriptprefix = "2m5d2-v2"
script_subname = "histograms_betti_area_difference"
plot_2m5_dir(args...) = plotsdir("section2", scriptprefix * "-$(script_subname)", args...)

log_2m5d_dir(args...) =
    projectdir("log", "section2", "$(scriptprefix)-$(script_subname)", args...)
log_2m5d_dir() |> ispath || log_2m5d_dir() |> mkpath

@info "Arguments processed."
# ====================================================
all_x_values = 0:255
all_x_index = 1:256
extension = ".jpg"
selected_config = CONFIG.DATA_CONFIG

all_datasets = vcat("all_pseudoart", "art-cropped", artists_datasets)[2:7:end]

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

                persistence_data[d][selected_config][loading_name][selected_dim]["betti"] =
                    Dict(:x => x_range, :y => betticurve)
            end #file
        end # dconfig
    end # selected_dim
end # d selected_ config

# =====

betti_difference_df = DataFrame(
    dataset = String[],
    integrated_betti1 = Float64[],
    integrated_betti2 = Float64[],
    norm_integrated_betti1 = Float64[],
    norm_integrated_betti2 = Float64[],
    config1 = String[],
    dim1 = String[],
    config2 = String[],
    dim2 = String[],
    difference = Float64[],
    norm_difference = Float64[],
)

bw = "_BW"
wb = "_WB"
# 


for d in all_datasets
    bw_part = persistence_data[d]["BW"]
    wb_part = persistence_data[d]["WB"]
    fnames_bw = [f for f in bw_part |> keys] |> sort
    fnames_wb = [f for f in wb_part |> keys] |> sort

    fnames =
        vcat([split(f, bw)[1] for f in fnames_bw], [split(f, wb)[1] for f in fnames_wb]) |> unique

    if length(fnames) != length(fnames_bw) || length(fnames) != length(fnames_wb)
        ErrorException(
            "List of merged files names does not match length of original matrix",
        ) |> throw
    end


    # f = fnames[1]
    first_config = bw
    second_config = wb
    first_selected_dim = "dim0"
    second_selected_dim = "dim1"

    for f in fnames
        β1 = bw_part[f*first_config][first_selected_dim]["betti"][:y]
        β2 = wb_part[f*second_config][second_selected_dim]["betti"][:y]

        integrated_betti1 = sum(β1)
        integrated_betti2 = sum(β2)

        norm_integrated_betti1 = sum(β1) / mean([integrated_betti1, integrated_betti2])
        norm_integrated_betti2 = sum(β2) / mean([integrated_betti1, integrated_betti2])

        betti_difference = integrated_betti1 - integrated_betti2
        norm_betti_difference =
            betti_difference / mean([integrated_betti1, integrated_betti2])

        push!(
            betti_difference_df,
            (
                d,
                integrated_betti1,
                integrated_betti2,
                norm_integrated_betti1,
                norm_integrated_betti2,
                first_config,
                first_selected_dim,
                second_config,
                second_selected_dim,
                betti_difference,
                norm_betti_difference,
            ),
        )
    end

    first_config = wb
    second_config = bw
    first_selected_dim = "dim0"
    second_selected_dim = "dim1"
    for f in fnames
        β1 = wb_part[f*first_config][first_selected_dim]["betti"][:y]
        β2 = bw_part[f*second_config][second_selected_dim]["betti"][:y]

        integrated_betti1 = sum(β1)
        integrated_betti2 = sum(β2)

        norm_integrated_betti1 = sum(β1) / mean([integrated_betti1, integrated_betti2])
        norm_integrated_betti2 = sum(β2) / mean([integrated_betti1, integrated_betti2])

        betti_difference = integrated_betti1 - integrated_betti2
        norm_betti_difference =
            betti_difference / mean([integrated_betti1, integrated_betti2])

        push!(
            betti_difference_df,
            (
                d,
                integrated_betti1,
                integrated_betti2,
                norm_integrated_betti1,
                norm_integrated_betti2,
                first_config,
                first_selected_dim,
                second_config,
                second_selected_dim,
                betti_difference,
                norm_betti_difference,
            ),
        )
    end

end # 
#############
#################

#########3
#################
############
# ===-===-===-===-===-

datasets_combinations = [["art-cropped", "pseudoart"],]
datasets_combinations = [["art", "art-cropped"],]
vcat([["art", "pseudoart"], all_datasets[all_datasets .!= "pseudoart"]],)
non_art_labels_vec = vcat(["pseudoart", "all_pseudoart"],)
non_art_labels_vec = ["art-cropped"]



k = 1
selected_datasets = datasets_combinations[k]
non_art_label = non_art_labels_vec[k]

selected_first_config = bw
selected_second_config = wb
first_config = bw
second_config = wb
first_selected_dim = "dim0"
second_selected_dim = "dim1"
do_saving = true

# colours1 = cgrad(selected_colourscheme, 5, categorical=true)
# colours1 = cgrad(:heat, 5, categorical=true)
# color_palettes =
#     [[colours1[3:2:end], colours1[2:2:end]]
#         [colours2[3:2:end], colours2[2:2:end]]]


#selected_colourscheme = :berlin10
# selected_colourscheme = :lipari
colours1 = cgrad(:berlin10, 12, categorical = true)
colours2 = cgrad(:lipari, 11, categorical = true)
color_palettes = [
    [[colours1[2], colours2[8]], [colours2[3], colours1[10]]],
    [[colours1[4], colours2[7]], [colours2[2], colours1[9]]],
    # [colours2[2:5:end], colours1[3:5:end]]
]
# selected_colourscheme = :managua10
# colours = cgrad(selected_colourscheme, 10, categorical=true, rev=true)
# color_palettes = [
#     colours[2:6:end],
#     colours[3:4:end],
# ]

points_per_cm = 28.3465 * 1.5
plt_width = ceil(Int, 20.0 * points_per_cm)
plt_height = ceil(Int, 10.0 * points_per_cm)

k = 1
selected_datasets = datasets_combinations[k]
non_art_label = non_art_labels_vec[k]
for (k, (selected_datasets, non_art_label)) in
    enumerate(zip(datasets_combinations, non_art_labels_vec))
    f2 = Figure(size = (plt_width, plt_height))

    fgl = CairoMakie.GridLayout(f2[1, 1])
    # @info "Selected datasets: " selected_datasets
    plot_labels = if length(selected_datasets) == 2
        if "art" in selected_datasets && "pseudoart" in selected_datasets
            ["Art\n(Kot)", "Pseudo-art\n(Exhibition)"]
        elseif "art" in selected_datasets && "all_pseudoart" in selected_datasets
            ["Art (Kot)", "All Pseudo-art"]
        elseif "art-cropped" in selected_datasets && "pseudoart" in selected_datasets
            ["Art-cropped (Kot)", "Pseudo-art"]
        elseif "art-cropped" in selected_datasets && "art" in selected_datasets
            ["Art (Kot)", "Art-cropped (Kot)"]
        else
            [selected_datasets[1], "All Pseudo-art"]
        end
    else
        ["All Art", "All Pseudo-art"]
    end

    for func_index = 1:2:3
        indicator = if func_index == 1
            "a)"
        elseif func_index == 3
            "b)"
        end
        # else
        #     if func_index == 1
        #         "c)"
        #     elseif func_index == 3
        #         "d)"
        #     end
        # end
        Label(
            fgl[1, func_index],
            "$(indicator)",
            tellheight = false,
            tellwidth = true,
            fontsize = 18,
            justification = :left,
            halign = :left,
            valign = :top,
        )
    end

    legend_labels_items = LaTeXStrings.LaTeXString[]
    for (i, (selected_first_config, selected_second_config)) in
        enumerate(zip([bw, wb], [wb, bw]))
        @info "selected_first_config = $(selected_first_config)"

        fgl_local = CairoMakie.GridLayout(fgl[1, 2i])

        config_filtered_differences_df =
            filter(row -> row.config1 == selected_first_config, betti_difference_df)


        filtered_differences_df = filter(
            row -> any(selected_datasets .== row.dataset),
            config_filtered_differences_df,
        )

        pseudoart_differences =
            filter(row -> row.dataset == non_art_label, filtered_differences_df).norm_difference
        artists_differences =
            filter(row -> row.dataset != non_art_label, filtered_differences_df).norm_difference

        title_sufix = @pipe map(
                  x -> join(x, "_"),
                  [
                      [selected_first_config, first_selected_dim],
                      [selected_second_config, second_selected_dim],
                  ],
              ) |>
              (y -> "area(Betti" .* y .* ")") |>
              join(_, " - ") |>
              z -> "(" * z .* ")/average Betti"


        # axis_label = L"$\frac{area(\beta^{WB}_{dim-1}) - area(\beta^{BW}_{dim1}) }{ mean ( area(\beta^{WB}_{dim-1}), area(\beta^{BW}_{dim1})) }$.}$"
        o1 = replace(selected_first_config, "_" => "")
        o2 = replace(selected_second_config, "_" => "")
        # axis_label =
        #     L"\frac{2 \times area(\beta^{%$o1}_{dim0}) - area(\beta^{%$o2}_{dim1}) }{  area(\beta^{%$o1}_{dim0})+ area(\beta^{%$o1}_{dim1}) }"
        axis_label = L"ADV_{%$o1}"
        push!(
            legend_labels_items,
            L"comparison $\beta^{%$o1}_{dim0}$ and $\beta^{%$o2}_{dim1}$",
        )


        data1 = artists_differences
        data2 = pseudoart_differences
        l, stat_test_result = get_boxplots_and_violins_plot(
            artists_differences,
            pseudoart_differences,
            fgl_local,
            selected_datasets;
            leged_title = "",# replace(title_sufix, "_" => " "),
            y_low = -0.2,
            y_high = 2.5,
            ylabel = axis_label,
            plot_labels = plot_labels,
            add_legend = false,
            add_stat_results = false,
            color_palette = color_palettes[k][i],
            # selected_test=MannWhitneyUTest
        )

        io = IOBuffer()
        println(io, "===-===-===-===-===-===-===-===-===-===-===-===-===-===-")
        println(io, now())
        println(io, "Datasets: ", plot_labels)
        println(io, "")
        println(io, stat_test_result)
        println(io, "")
        println(io, "Mean for: ")
        println(io, "\n- artistic data is $(data1 |> mean)")
        println(io, "\n- non-artistic data is $(data2 |> mean)")
        println(io, "")
        println(io, "Std for: ")
        println(io, "\n- artistic data is $(data1 |> std)")
        println(io, "\n- non-artistic data is $(data2 |> std)")
        println(io, "")
        println(io, "Median for: ")
        println(io, "\n- artistic data is $(data1 |> median)")
        println(io, "\n- non-artistic data is $(data2 |> median)")
        println(io, "")

        joined_keys = join(selected_datasets, "-")
        version =
            "normalised_" * (@pipe replace(title_sufix, " " => "_") |>
                   replace(_, "(" => "") |>
                   replace(_, ")" => "") |>
                   split(_, "/")[1])
        out_img_name = "$(version)_$(joined_keys)"
        logfile = log_2m5d_dir(out_img_name * ".txt")
        open(logfile, "a") do fio
            write(fio, String(take!(io)))
        end

    end
    fgl3 = GridLayout(fgl[2, :])

    elements1, elements2 = map(
        palette -> [PolyElement(polycolor = palette[i]) for i = 1:length(plot_labels)],
        color_palettes[k],
    )
    legend_colours = [[elements1[1], elements2[1]], [elements1[2], elements2[2]]]

    legend_labels = [
        [legend_labels_items[1], legend_labels_items[2]],
        [legend_labels_items[1], legend_labels_items[2]],
    ]

    Legend(
        fgl3[1, 1],
        legend_colours,
        legend_labels,
        plot_labels,
        tellwidth = false,
        nbanks = 2,
        tellheight = true,
        framevisible = false,
        titleposition = :left,
        orientation = :horizontal,
        # titlefont=:regular
    )

    CairoMakie.colsize!(fgl, 1, 0)
    CairoMakie.colsize!(fgl, 3, 0)

    display(f2)
    # ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
    if do_saving
        @info "Saving..."

        # ===-===-===-

        joined_keys = join(selected_datasets, "-")
        version = "normalised_betti_area_difference"
        # *
        # (@pipe replace(title_sufix, " " => "_") |>
        #        replace(_, "(" => "") |>
        #        replace(_, ")" => "") |>
        #        split(_, "/")[1])
        out_img_name = "$(version)_$(joined_keys)"
        thr = "threshold=$(CONFIG.PERSISTENCE_THRESHOLD)"

        out_name = plot_2m5_dir("$(thr)_$(version)", out_img_name * ".png")
        safesave(out_name, f2, dpi = 300)

        out_name = plot_2m5_dir("$(thr)_$(version)", "pdf", out_img_name * ".pdf")
        safesave(out_name, f2, dpi = 300)

    end # selected_dataset 
end # selected_first_config

## ===-===-
do_nothing = "ok"
