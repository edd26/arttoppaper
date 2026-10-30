
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

scriptprefix = "2m5h"
script_subname = "alexander_duality_violation"
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


# all_datasets = vcat("all_pseudoart", artists_datasets)
# all_datasets = ["Jarema-cropped", "Pollock-cropped", "Kandinsky-cropped", "Rothko-cropped", "Malevich-cropped"]
all_datasets = [
    "Rothko-cropped2",
    "Richter-cropped2",
    "Kandinsky-cropped2",
    "Malevich-cropped2",
    "Jarema-cropped2",
]


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
    file = String[],
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

        norm_integrated_betti1 =
            integrated_betti1 / mean([integrated_betti1, integrated_betti2])
        norm_integrated_betti2 =
            integrated_betti2 / mean([integrated_betti1, integrated_betti2])

        betti_difference = integrated_betti1 - integrated_betti2
        norm_betti_difference =
            betti_difference / mean([integrated_betti1, integrated_betti2])

        push!(
            betti_difference_df,
            (
                d,
                f,
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
                f,
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
#

closest_to_0_4 = abs.(betti_difference_df.norm_difference .- 0.4) |> sortperm
betti_difference_df[closest_to_0_4, :]

csv_export_dir(args...) =
    projectdir("data", "exp_pro", "section2", "$(scriptprefix)_bettis_differences", args...)
csv_export_dir() |> ispath || csv_export_dir() |> mkdir
output_csv = csv_export_dir("$(scriptprefix)_bettis_differences.csv")
if !isfile(output_csv)
    @info "Saving csv file for original data"
    open(output_csv, "w") do io
        writedlm(io, [names(betti_difference_df)], ',')     # write column names as header
        writedlm(io, eachrow(betti_difference_df), ',')     # write the data rows
    end
end

output_csv_sorted = csv_export_dir("$(scriptprefix)_bettis_differences_sorted0-4.csv")
if !isfile(output_csv_sorted)
    @info "Saving csv file for sorted data"
    open(output_csv_sorted, "w") do io
        writedlm(io, [names(betti_difference_df)], ',')     # write column names as header
        writedlm(io, eachrow(betti_difference_df[closest_to_0_4, :]), ',')     # write the data rows
    end
end


betti_difference_df
#########3
#################
############
# ===-===-===-===-===-




unique_datasets =
    betti_difference_df.dataset |> unique .|> y -> split(y, "-")[1] .|> z -> "$z"

files = []
for ve in betti_difference_df.file .|> x -> split(x, "-")
    push!(
        files,
        @pipe [k for k in ve if k != "bottom"] |>
              [k for k in _ if k != "top"] |>
              [k for k in _ if k != "left"] |>
              [k for k in _ if k != "right"] |>
              [k for k in _ if !occursin("rand", k)] |>
              [k for k in _ if !occursin("rot", k)] |>
              join(_, "-")
    )
end
unique_files = @pipe files |> unique

filter(row->occursin("Kandinsky-9", row.file), betti_difference_df)


total_labels = length(unique_datasets)
total_files = length(unique_files)


groupped_category_labels = []
groupped_data_array = []

i = 1
label = unique_files[1]
for (i, label) in enumerate(unique_files)
    filtered_df = @pipe betti_difference_df |>
          filter(row -> occursin(label, row.file), _) |>
          filter(row -> row.config1 == "_BW", _)

    push!(groupped_category_labels, [i for _ in filtered_df.file])
    push!(groupped_data_array, filtered_df.norm_difference)
end

category_labels = reduce(vcat, groupped_category_labels)
data_array = reduce(vcat, groupped_data_array)

points_per_cm = 28.3465 * 1.5
plt_width = ceil(Int, 25.0 * points_per_cm)
plt_height = ceil(Int, 12.0 * points_per_cm)


f = Figure(size = (plt_width, plt_height))
fgl = GridLayout(f[1, 1])

# ---==---==---==
markers_for_legend1 = [
    MarkerElement(color = :grey, marker = '+', markersize = 25),
    MarkerElement(color = :grey, marker = 'x', markersize = 25),
]

Legend(
    fgl[1, :],
    [markers_for_legend1],
    [["cropped", "cropped and rotated"],],
    [""],
    tellheight = true,
    tellwidth = false,
    nbanks = 2,
    framevisible = false,
)

# ---==---==---==

ax_raincloud = CairoMakie.Axis(fgl[2, 1], xlabel = "dataset", ylabel = "ADV")

colors = [Makie.wong_colors(); Makie.wong_colors()]
# rainclouds!(
#     ax_raincloud,
#     category_labels,
#     data_array;
#     plot_boxplots = false,
#     color = colors[indexin(category_labels, unique(category_labels))],
# )
plot_shift = 0.1
boxplot!(
    ax_raincloud,
    category_labels .- plot_shift,
    data_array;
    color = colors[indexin(category_labels, unique(category_labels))],
)


marker_alpha = 0.5
scatter_kwargs = (markersize = 15, strokewidth = 0.4)
for (i, label) in enumerate(unique_files)
    filtered_df_stage1 = @pipe betti_difference_df |>
          filter(row -> occursin(label, row.file), _) |>
          filter(row -> row.config1 == "_BW", _)
    not_rotation_df = filter(row -> !occursin("rot", row.file), filtered_df_stage1)
    rotation_df = filter(row -> occursin("rot", row.file), filtered_df_stage1)

    scatter!(
        ax_raincloud,
        [i for _ in not_rotation_df.norm_difference] .+ plot_shift,
        not_rotation_df.norm_difference;
        color = (colors[i], marker_alpha),
        marker = '+',
        scatter_kwargs...,
    )
    scatter!(
        ax_raincloud,
        [i for _ in rotation_df.norm_difference] .+ plot_shift,
        rotation_df.norm_difference;
        color = (colors[i], marker_alpha),
        marker = 'x',
        scatter_kwargs...,
    )
end

# ax_raincloud.xticks = (1:total_labels, unique_datasets)
ax_raincloud.xticks = (1:total_files, unique_files)
ax_raincloud.xticklabelrotation = -pi / 16
ax_raincloud.yticks = -1:0.2:4

ylims!(ax_raincloud, low = 0, high = 1.5)

display(f)





# ===-===-===-
@info "Saving..."

joined_keys = join(all_datasets, "-")
version = "alexander_duality_violation"
out_img_name = "$(version)_$(joined_keys)"
thr = "threshold=$(CONFIG.PERSISTENCE_THRESHOLD)"

out_name = plot_2m5_dir("$(thr)_$(version)", out_img_name * ".png")
safesave(out_name, f, dpi = 300)

out_name = plot_2m5_dir("$(thr)_$(version)", "pdf", out_img_name * ".pdf")
safesave(out_name, f, dpi = 300)


## ===-===-
do_nothing = "ok"
