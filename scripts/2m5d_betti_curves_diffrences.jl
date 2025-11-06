
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

import Base.Threads: @spawn, @sync
import Dates: now

CairoMakie.set_theme!(fonts=(; regular="Arial", bold="Arial Bold"))
# ===-===-===-
"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include
"DataStructuresUtils.jl" |> srcdir |> include
"LandscapesPlotting.jl" |> srcdir |> include
"MakiePlots.jl" |> srcdir |> include

"ExtendedDatasetUtils.jl" |> srcdir |> include

# import .CONFIG: preproc_img_dir_set, SELECTED_DIM, PERSISTENCE_THRESHOLD, DATA_CONFIG
# import .CONFIG: ripserer_computations_dir

scriptprefix = "2m5d"
script_subname = "histograms_betti_area_difference"
plot_2m5_dir(args...) = plotsdir("section2", scriptprefix * "-$(script_subname)", args...)

log_2m5d_dir(args...) = projectdir("log", "section2", "$(scriptprefix)-$(script_subname)", args...)
log_2m5d_dir() |> ispath || log_2m5d_dir() |> mkpath

@info "Arguments processed."
# ====================================================
all_x_values = 0:255
all_x_index = 1:256
extension = ".jpg"
selected_config = CONFIG.DATA_CONFIG

all_datasets = vcat("all_pseudoart", artists_datasets)

# all_datasets =
persistence_data =
    populate_dict!(Dict(), [all_datasets, ["BW", "WB"]], final_structure=OrderedDict())


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
    dataset=String[],
    integrated_betti1=Float64[],
    integrated_betti2=Float64[],
    norm_integrated_betti1=Float64[],
    norm_integrated_betti2=Float64[],
    config1=String[],
    dim1=String[],
    config2=String[],
    dim2=String[],
    difference=Float64[],
    norm_difference=Float64[],
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

datasets_combinations = vcat(
    [
        all_datasets[all_datasets.!="art".&&all_datasets.!="pseudoart"],
        all_datasets[all_datasets.!="pseudoart"],
        ["art", "pseudoart"],
        ["art", "all_pseudoart"],
    ], [
        [d, "all_pseudoart"] for d in artists_datasets[artists_datasets.!="pseudoart"]
    ]
)
non_art_labels_vec = vcat([
        "all_pseudoart",
        "all_pseudoart",
        "pseudoart",],
    "all_pseudoart",
    [
        "all_pseudoart" for _ in artists_datasets[artists_datasets.!="art".&&artists_datasets.!="pseudoart"]
    ])



k = 5
selected_datasets = datasets_combinations[k]
non_art_label = non_art_labels_vec[k]

selected_first_config = bw
selected_second_config = wb
first_config = bw
second_config = wb
first_selected_dim = "dim0"
second_selected_dim = "dim1"
do_saving = true


for (selected_first_config, selected_second_config) in zip([bw, wb], [wb, bw])
    @info "selected_first_config = $(selected_first_config)"
    config_filtered_differences_df =
        filter(row -> row.config1 == selected_first_config, betti_difference_df)

    for (selected_datasets, non_art_label) in zip(datasets_combinations, non_art_labels_vec)
        # @info "Selected datasets: " selected_datasets

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


        plot_labels = if length(selected_datasets) == 2
            if "art" in selected_datasets && "pseudoart" in selected_datasets
                ["Art (Kot)", "Pseudo-Art (Exhibition)"]
            elseif "art" in selected_datasets && "all_pseudoart" in selected_datasets
                ["Art (Kot)", "All Pseudo-Art"]
            else
                [selected_datasets[1], "All Pseudo-Art"]
            end
        else
            ["All Art", "All Pseudo-Art"]
        end

        f2 = Figure()
        fgl = CairoMakie.GridLayout(f2[1, 1])

        # axis_label = L"$\frac{area(\beta^{WB}_{dim-1}) - area(\beta^{BW}_{dim1}) }{ mean ( area(\beta^{WB}_{dim-1}), area(\beta^{BW}_{dim1})) }$.}$"
        o1 = replace(selected_first_config, "_" => "")
        o2 = replace(selected_second_config, "_" => "")
        axis_label = L"\frac{area(\beta^{%$o1}_{dim0}) - area(\beta^{%$o2}_{dim1}) }{ mean ( area(\beta^{%$o1}_{dim0}), area(\beta^{%$o1}_{dim1})) }"

        data1 = artists_differences
        data2 = pseudoart_differences
        f, l, stat_test_result = get_boxplots_and_violins_plot(
            artists_differences,
            pseudoart_differences,
            f2,
            fgl,
            selected_datasets;
            leged_title="",# replace(title_sufix, "_" => " "),
            y_low=-0.2,
            y_high=2.5,
            ylabel=axis_label,
            plot_labels=plot_labels
            # selected_test=MannWhitneyUTest
        )
        display(f)

        io = IOBuffer()
        println(io, "===-===-===-===-===-===-===-===-===-===-===-===-===-===-")
        println(io, now())
        println(io, "Datasets: ", plot_labels)
        println(io, "")
        println(io, stat_test_result)
        println(io, "")

        joined_keys = join(selected_datasets, "-")
        version =
            "normalised_" *
            split(replace(replace(replace(title_sufix, " " => "_"), "(" => ""), ")" => ""), "/")[1]
        out_img_name = "$(version)_$(joined_keys)"
        logfile = log_2m5d_dir(out_img_name * ".txt")
        open(logfile, "a") do fio
            write(fio, String(take!(io)))
        end

        # ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
        if do_saving
            @info "Saving..."

            # ===-===-===-

            out_img_name = "$(version)_$(joined_keys)"
            thr = "threshold=$(CONFIG.PERSISTENCE_THRESHOLD)"

            out_name =
                plot_2m5_dir("$(thr)_$(version)", out_img_name * ".png")
            safesave(out_name, f, dpi=300)

            out_name = plot_2m5_dir(
                "$(thr)_$(version)",
                "pdf",
                out_img_name * ".pdf",
            )
            safesave(out_name, f, dpi=300)
        end

    end # selected_dataset 
end # selected_first_config

## ===-===-
do_nothing = "ok"
