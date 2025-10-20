
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

using HypothesisTests: MannWhitneyUTest, pvalue

import Base.Threads: @spawn, @sync

CairoMakie.set_theme!(fonts = (; regular = "Arial", bold = "Arial Bold"))
# ===-===-===-
"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include
"DataStructuresUtils.jl" |> srcdir |> include
"LandscapesPlotting.jl" |> srcdir |> include
"MakiePlots.jl" |> srcdir |> include

"ExtendedDatasetUtils.jl" |> srcdir |> include

import .CONFIG: preproc_img_dir_set, SELECTED_DIM, PERSISTENCE_THRESHOLD, DATA_CONFIG
import .CONFIG: ripserer_computations_dir

@info "Arguments processed."
# ===-===-===-
readrows(file_name) = DelimitedFiles.readdlm(file_name, ',', Float64, '\n')
# ====================================================
selected_config = CONFIG.DATA_CONFIG
all_x_values = 0:255
all_x_index = 1:256
extension = ".jpg"

# ===-===-===-

all_datasets = vcat("all_pseudoart", artists_datasets)
# all_datasets = ["art", "pseudoart"]
persistence_data =
    populate_dict!(Dict(), [all_datasets, ["BW", "WB"]], final_structure = OrderedDict())

selected_config = CONFIG.DATA_CONFIG
all_x_values = 0:255
all_x_index = 1:256
extension = ".jpg"

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

function get_comparison_plot(fname_bw, fname_wb, d)

    range1 = 2:255
    range2 = 1:254
    range1 = 1:255
    range2 = 1:255
    bw_dim1_minus_wb_dim0 =
        persistence_data[d]["BW"][fname_bw]["dim1"]["betti"][:y][range1] -
        (persistence_data[d]["WB"][fname_wb]["dim0"]["betti"][:y]|>reverse)[range2]
    wb_dim1_minus_bw_dim0 =
        persistence_data[d]["WB"][fname_wb]["dim1"]["betti"][:y][range1] -
        (persistence_data[d]["BW"][fname_bw]["dim0"]["betti"][:y]|>reverse)[range2]


    f = Figure()
    fgl = GridLayout(f[1, 1])
    ax_bw_dim0 = CairoMakie.Axis(fgl[1, 1], title = "bw, dim0, reverse")
    ax_bw_dim1 = CairoMakie.Axis(fgl[1, 2], title = "bw, dim1")
    ax_wb_dim0 = CairoMakie.Axis(fgl[2, 2], title = "wb, dim0, reverse")
    ax_wb_dim1 = CairoMakie.Axis(fgl[2, 1], title = "wb, dim1")

    ax_bw_dim1_minus_wb_dim0 =
        CairoMakie.Axis(fgl[3, 2], title = "bw dim1 - reverse(wb dim0)")
    ax_wb_dim0_minus_bw_dim1 =
        CairoMakie.Axis(fgl[3, 1], title = "wb dim1 - reverse(bw dim0)")

    CairoMakie.plot!(
        ax_bw_dim0,
        persistence_data[d]["BW"][fname_bw]["dim0"]["betti"][:y] |> reverse,
        color = :green,
    )
    CairoMakie.plot!(
        ax_bw_dim1,
        persistence_data[d]["BW"][fname_bw]["dim1"]["betti"][:y],
        color = :yellow,
    )
    CairoMakie.plot!(
        ax_wb_dim0,
        persistence_data[d]["WB"][fname_wb]["dim0"]["betti"][:y] |> reverse,
        color = :green,
    )
    CairoMakie.plot!(
        ax_wb_dim1,
        persistence_data[d]["WB"][fname_wb]["dim1"]["betti"][:y],
        color = :yellow,
    )

    CairoMakie.plot!(ax_bw_dim1_minus_wb_dim0, bw_dim1_minus_wb_dim0, color = :orange)
    CairoMakie.plot!(ax_wb_dim0_minus_bw_dim1, wb_dim1_minus_bw_dim0, color = :orange)
    return f
end

selected_data = all_datasets[1]
fnames_bw = [f for f in persistence_data[selected_data]["BW"] |> keys] |> sort
fnames_wb = [f for f in persistence_data[selected_data]["WB"] |> keys] |> sort

k = 2
get_comparison_plot(fnames_bw[k], fnames_wb[k], selected_data)

k = 4
fnames_bw[k]
get_comparison_plot(fnames_bw[k], fnames_wb[k], selected_data)

# area(BW dim 0) <- x
# area(WB dim 1) <- y

L"$\Delta \rho_r = 1 / \binom{N}{1}$"

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


first_selected_dim = "dim0"
second_selected_dim = "dim1"

bw = "_BW"
wb = "_WB"
first_config = bw
second_config = wb


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


    f = fnames[1]
    for f in fnames
        β1 = bw_part[f*first_config][first_selected_dim]["betti"][:y]
        β2 = wb_part[f*second_config][second_selected_dim]["betti"][:y]

        integrated_betti1 = sum(β1)
        integrated_betti2 = sum(β2)

        norm_integrated_betti1 = sum(β1) / mean([integrated_betti1, integrated_betti2])
        norm_integrated_betti2 = sum(β2) / mean([integrated_betti1, integrated_betti2])

        betti_difference = integrated_betti1 - integrated_betti2
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

    # first_selected_dim = "dim1"
    # first_config = bw
    # second_selected_dim = "dim0"
    # second_config = wb
    # for f = fnames
    #     betti_difference = sum(wb_part[f*first_config][first_selected_dim]["betti"][:y]) - sum(bw_part[f*second_config][second_selected_dim]["betti"][:y])
    #     push!(
    #         betti_difference_df,
    #         (d,
    #             first_config,
    #             first_selected_dim,
    #             second_config,
    #             second_selected_dim,
    #             betti_difference
    #         )
    #     )
    # end

end # 



###############################
pseudoart_differences =
    filter(row -> row.dataset == all_datasets[1], betti_difference_df).norm_difference
artists_differences =
    filter(row -> row.dataset != all_datasets[1], betti_difference_df).norm_difference

title_sufix = @pipe map(
          x -> join(x, "_"),
          [[first_config, first_selected_dim], [second_config, second_selected_dim]],
      ) |>
      (y -> "area" .* y) |>
      join(_, " - ")

f3 = Figure()
fgl = GridLayout(f3[1, 1])
ax_pseudo = CairoMakie.Axis(
    fgl[1, 1],
    title = "Normalised Betti curve area difference, " * title_sufix,
)
# ax_art = CairoMakie.Axis(fgl[2, 1], title="Art")
plot_labels = if length(all_datasets) == 2
    ["Art", "Pseudo-art"]
else
    ["All Art", "All Pseudoart"]
end
hist!(
    ax_pseudo,
    artists_differences;
    normalization = :pdf,
    label = plot_labels[1],
    bins = 100,
)
hist!(
    ax_pseudo,
    pseudoart_differences;
    normalization = :pdf,
    label = plot_labels[2],
    bins = 100,
)
axislegend(ax_pseudo)
f3


#########3
f2 = Figure()
fgl = CairoMakie.GridLayout(f2[1, 1])

# measure_vals_both = [artists_differences, pseudoart_differences]
function get_boxplots_and_violins_plot(
    data1,
    data2,
    f,
    fgl::GridLayout,
    all_datasets;
    leged_title = "",
    y_low = 0.0,
)
    plot_labels = if length(all_datasets) == 2
        ["Art", "Pseudo-art"]
    else
        ["All Art", "All Pseudo-art"]
    end
    # measure_vals_both = [artists_differences, pseudoart_differences]
    measure_vals_both = [data1, data2]
    color_palette = cgrad(:heat, 3, categorical = true)[2:end]# Makie.wong_colors();
    color_values =
        reduce(vcat, [[color_palette[k] for _ in measure_vals_both[k]] for k = 1:2]);

    categories = []
    color_indices = []
    for (k, vec) in measure_vals_both |> enumerate
        push!(categories, [k for v in vec])
        push!(color_indices, [color_values[k] for v in vec])
    end
    categories = vcat(categories...)
    color_indices = vcat(color_indices...)

    values = vcat(measure_vals_both...)
    min_val = min([x for x in values if !isnan(x)]...)
    max_val = max([x for x in values if !isnan(x)]...)
    if max_val < 0.5
        y_high = 1.35 * max_val
    else
        y_high = 1.35 * max_val
    end
    bracket_y = 1.1max(values...)
    # if min_val < 1e2 && min_val > 0
    #     y_low = -0.03
    # elseif min_val < 1e-1
    #     # y_low = -0.1
    #     y_low = -0.2
    # else
    #     if min_val > 0
    #         y_low = 0.1min_val
    #     else
    #         y_low = 1.2min_val
    #     end
    # end
    # === plot
    # y_low = -00.01
    ax_boxplot = CairoMakie.Axis(fgl[1, 1], xtrimspine = true)#, ylabel = scatter_label)
    ax_estimate = CairoMakie.Axis(fgl[1, 2])

    hidexdecorations!(
        ax_boxplot,
        label = false,
        ticklabels = false,
        ticks = false,
        grid = true,
        minorgrid = true,
        minorticks = true,
    )
    hideydecorations!(ax_boxplot)

    for ax in [ax_boxplot]
        ax.rightspinevisible = false
        ax.topspinevisible = false
    end
    ax_boxplot.leftspinevisible = false
    hidespines!(ax_estimate)
    hidedecorations!(ax_estimate)

    # ==
    CairoMakie.boxplot!(
        ax_boxplot,
        categories,
        values,
        whiskerwidth = 0.5,
        strokecolor = :black,
        strokewidth = 1,
        color = color_values,
    )

    violin_kwargs = (side = :right, strokecolor = :black, strokewidth = 1)
    violin_alpha = 0.5
    for (k, values_vec) in enumerate(measure_vals_both)
        if length(measure_vals_both) > 2
            category_x_vals = [color_values[k] for m in values_vec]
        else
            category_x_vals = [1 for m in values_vec]
        end
        not_nan_positions2 = findall(x -> !isnan(x), values_vec)
        category_colour = [color_values[categories .== k]][1]
        if length(values_vec) > 0
            CairoMakie.violin!(
                ax_estimate,
                category_x_vals[not_nan_positions2],
                values_vec[not_nan_positions2];
                color = (category_colour[k], violin_alpha),
                violin_kwargs...,
            )
        end
    end

    elements = [PolyElement(polycolor = color_palette[i]) for i = 1:length(plot_labels)]

    fgl3 = GridLayout(f[2, :])
    legend_title = leged_title

    i=1
    l1 = Legend(
        fgl3[1, i],
        elements[:, i],
        plot_labels,
        legend_title,
        tellwidth = false,
        nbanks = 2,
        tellheight = true,
        framevisible = false,
    )

    ##
    xtick_start = min(categories...)
    xtick_end = max(categories...)
    ax_boxplot.xticks = ([xtick_start, xtick_end], plot_labels)

    for ax in [ax_boxplot, ax_estimate]
        CairoMakie.ylims!(ax, low = y_low, high = y_high)
    end

    stat_test_result = MannWhitneyUTest(data1, data2)
    if pvalue(stat_test_result) < 0.05
        if pvalue(stat_test_result) < 0.001
            p_marker = "***"
        elseif pvalue(stat_test_result) < 0.01
            p_marker = "**"
        elseif pvalue(stat_test_result) < 0.05
            p_marker = "*"
        end#
        CairoMakie.bracket!(
            ax_boxplot,
            xtick_start,
            bracket_y,
            xtick_end,
            bracket_y,
            offset = 0,
            text = p_marker,
            style = :square,
            fontsize = 30,
            textoffset = -1,
        )
    else
        p_marker = ""
    end # p-plot


    return f2, l1
end

f2 = Figure()
fgl = CairoMakie.GridLayout(f2[1, 1])

f, l = get_boxplots_and_violins_plot(
    artists_differences,
    pseudoart_differences,
    f2,
    fgl,
    all_datasets;
    # ["art", "pseudo-art"];
    leged_title = "Normalised Betti curve difference",
    y_low = -0.2,
)

f
## <<< 


MannWhitneyUTest(pseudoart_differences, artists_differences)

# normalised difference of areas:
# - [] all artist with Lida vs all pseudoart
# - [] all artist without Lida vs all pseudoart
# - [] Lida vs selected pseudoart

# 
# area under the landscape dim0, dim1, same filtration for both, both filtrations
# - [x] all artist with Lida vs all pseudoart
# - [x] all artist without Lida vs all pseudoart
# - [x] Lida vs selected pseudoart

# Scatterplot normalised integrated_betti1 integrated_betti2

#
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
@info "Saving..."
scriptprefix = "2m5c"
script_subname = "histograms_betti_area_difference"
plot_2m5_dir(args...) = plotsdir("section2", scriptprefix * "-$(script_subname)", args...)

# ===-===-===-

joined_keys = lowercase(DATA_CONFIG) * "_" * join(all_datasets, "-")
out_img_name = "$(script_subname)_$(selected_config)_$(joined_keys)"
thr = "threshold=$(PERSISTENCE_THRESHOLD)"

f3 = 1
for (k, f) in enumerate([f2, f3][1:1])

    out_name =
        plot_2m5_dir("version$(k)", "$(selected_config)_$(thr)", out_img_name * ".png")
    safesave(out_name, f, dpi = 300)

    out_name = plot_2m5_dir(
        "version$(k)",
        "$(selected_config)_$(thr)",
        "pdf",
        out_img_name * ".pdf",
    )
    safesave(out_name, f, dpi = 300)

end

## ===-===-
do_nothing = "ok"

# Dumpster:
##########################
pseudoart_differences =
    filter(row -> row.dataset == "all_pseudoart", betti_difference_df).difference
artists_differences =
    filter(row -> row.dataset != "all_pseudoart", betti_difference_df).difference

f = Figure()
fgl = GridLayout(f[1, 1])
ax_pseudo = CairoMakie.Axis(fgl[1, 1], title = "Difference in Betti curve area ")
ax_art = CairoMakie.Axis(fgl[2, 1], title = "Art")
hist!(ax_pseudo, pseudoart_differences; normalization = :pdf, label = "pseudoart")
hist!(ax_art, artists_differences; normalization = :pdf, label = "all art")
axislegend(ax_pseudo)
axislegend(ax_art)
f

# pseudoart_differences =
#     filter(row -> row.dataset == "all_pseudoart", betti_difference_df).difference
# artists_differences =
#     filter(row -> row.dataset != "all_pseudoart", betti_difference_df).difference

# y_values_vecs = [pseudoart_differences, artists_differences]
# y_values = reduce(vcat, y_values_vecs)
# x_values = reduce(vcat, [[k for _ in y_values_vecs[k]] for k = 1:2])
# colours_vec = @pipe copy(x_values) |> replace(_, 1 => :blue) |> replace(_, 2 => :orange)



# f = Figure()
# fgl = GridLayout(f[1, 1])
# ax_violin = CairoMakie.Axis(fgl[1, 1], title = "Pseudoart")
# # ax_art = CairoMakie.Axis(fgl[2, 1], title="Art")
# Makie.violin!(ax_violin, x_values, y_values; color = colours_vec)
# ax_violin.xticks = ([1, 2], ["pseudoart", "art"])
# f



# pseudoart_df = filter(row -> row.dataset == "all_pseudoart", betti_difference_df)
# art_df = filter(row -> row.dataset != "all_pseudoart", betti_difference_df)

# f2a = Figure()
# fgl = GridLayout(f2a[1, 1])
# ax_area_plot = CairoMakie.Axis(fgl[1, 1], title = "")
# # ax_art = CairoMakie.Axis(fgl[2, 1], title="Art")
# scatter!(
#     ax_area_plot,
#     pseudoart_df.norm_integrated_betti1,
#     pseudoart_df.norm_integrated_betti2,
#     ;
#     label = "pseudoart",
#     color = (:blue, 0.6),
# )
# scatter!(
#     ax_area_plot,
#     art_df.norm_integrated_betti1,
#     art_df.norm_integrated_betti2,
#     ;
#     label = "all art",
#     color = (:orange, 0.6),
# )
# axislegend(ax_area_plot)
# f2a

