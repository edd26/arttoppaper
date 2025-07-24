
using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-

"17jg3_ECDF_generation_not_looking.jl" |> scriptsdir |> include

using HypothesisTests
using StatsBase: ecdf

"ECDFPlotting.jl" |> srcdir |> include
"statistics_utils.jl" |> srcdir |> include

CairoMakie.set_theme!(fonts = (; regular = "Arial", bold = "Arial Bold"))

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
scriptprefix = "17jg3k2"

do_KW = false
do_mann_whitney = true
do_signed_rank = false
do_fdr_miller = false
# ===-===-
data_keys = ["art", "pseudoart"]
fig_width = 400
fig_height = 300
color_palette = Makie.wong_colors();
func = parameters_vec[1]
metric_keys = [:ECDF_lnl_mse]

colours_indidcators = [(3, 4), (5, 2), (1, 6)]

markers_list = [
    :pentagon,
    :circle,
    :rect,
    :diamond,
    :hexagon,
    :cross,
    :xcross,
    :utriangle,
    :dtriangle,
    :ltriangle,
    :rtriangle,
    :star4,
    :star5,
]
# ===-===-===-===-
# Test for general effect
func = density_scaled

selected_metric = metric_keys[1]
f2 = Figure(size = (2fig_width, 3fig_height));
for (func_index, func) in parameters_vec[func_range] |> enumerate
    @info "$(func)"
    func_related_df = filter(row -> row.parameter == "$(func)", ECDF_not_looking_error_df)

    metric_index = 1
    selected_metric = metric_keys[1]
    @info "\t$(selected_metric)"

    scatter_label = L"MSE(ECDF_{looking}-ECDF_{not\; looking})"
    me_label = L"ME(ECDF_{looking}-ECDF_{not\; looking})"


    all_vals =
        vcat(func_related_df[:, selected_metric]..., func_related_df[:, selected_metric]...)
    all_me = vcat(func_related_df[:, :ECDF_lnl_me]..., func_related_df[:, :ECDF_lnl_me]...)

    min_val = min([x for x in all_vals if !isnan(x)]...)
    max_val = max([x for x in all_vals if !isnan(x)]...)
    min_me = min([x for x in all_me if !isnan(x)]...)
    max_me = max([x for x in all_me if !isnan(x)]...)
    x_low = 1.2min_me
    x_high = 1.2max_me
    if max_val < 0.5
        y_high = 1.35 * max_val
    else
        y_high = 1.35 * max_val
    end
    bracket_y = 1.1max(all_vals...)
    if min_val < 1e3 && min_val > 0
        y_low = -0.03
    else
        if min_val > 0
            y_low = 0.8min_val
        else
            y_low = 1.2min_val
        end
    end

    art_related_df = filter(row -> row.data_name == "art", func_related_df)
    pseudoart_related_df = filter(row -> row.data_name == "pseudoart", func_related_df)

    measure_vals_art = art_related_df[:, selected_metric]
    measure_vals_pseudoart = pseudoart_related_df[:, selected_metric]

    vec1_val, vec2_val = colours_indidcators[func_index]
    med_art = median(measure_vals_art)
    med_pseudoart = median(measure_vals_pseudoart)


    stat_test_result = MannWhitneyUTest(measure_vals_art, measure_vals_pseudoart)
    @info "Median for art is: $(med_art) "
    @info "Median for pseudoart is: $(med_pseudoart) "
    @info stat_test_result

    fgl = CairoMakie.GridLayout(f2[func_index, 1])

    ax_scatter1 = CairoMakie.Axis(
        fgl[1, 1],
        ylabel = scatter_label,
        xlabel = L"ME(ECDF_{looking}-ECDF_{not\;looking})",
    )
    ax_scatter2 = CairoMakie.Axis(
        fgl[1, 2],
        ylabel = "",
        xlabel = L"ME(ECDF_{looking}-ECDF_{not\;looking})",
    )
    ax_boxplot = CairoMakie.Axis(fgl[1, 3], xtrimspine = true, ylabel = scatter_label)
    ax_estimate = CairoMakie.Axis(fgl[1, 4])

    for ax in [ax_scatter1, ax_scatter2]
        hidedecorations!(
            ax,
            label = false,
            ticklabels = false,
            ticks = false,
            grid = true,
            minorgrid = true,
            minorticks = true,
        )
    end
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

    for ax in [ax_scatter1, ax_scatter2, ax_boxplot]
        ax.rightspinevisible = false
        ax.topspinevisible = false
    end
    ax_boxplot.leftspinevisible = false

    hidespines!(ax_estimate)
    hidedecorations!(ax_estimate)

    #######################33
    ###
    measure_vals_both = [measure_vals_art, measure_vals_pseudoart]
    me_values = [art_related_df[:, :ECDF_lnl_me], pseudoart_related_df[:, :ECDF_lnl_me]]
    color_values = [vec1_val, vec2_val]
    # me_values = vcat(me_values...)

    categories = []
    color_indices = []
    for (k, vec) in measure_vals_both |> enumerate
        push!(categories, [k for v in vec])
        push!(color_indices, [color_values[k] for v in vec])
    end
    categories = vcat(categories...)
    color_indices = vcat(color_indices...)

    for (i, (ax, selected_data)) in
        enumerate(zip([ax_scatter1, ax_scatter2], ["art", "pseudoart"]))

        data_related_df = filter(row -> row.data_name == selected_data, func_related_df)


        for (k, img) in data_related_df.img_name |> unique |> enumerate
            img_related_df = filter(row -> row.img_name == img, data_related_df)
            x_data = img_related_df[:, :ECDF_lnl_me]
            y_data = img_related_df[:, selected_metric]

            CairoMakie.scatter!(
                ax,
                x_data,
                y_data,
                markersize = 8,
                marker = markers_list[k],
                color = (color_palette[color_values[i]], 0.4),
                # alpha = 0.5
            )
        end
    end

    values = vcat(measure_vals_both...)
    not_nan_positions = findall(x -> !isnan(x), values)

    CairoMakie.boxplot!(
        ax_boxplot,
        categories[not_nan_positions],
        values[not_nan_positions],
        whiskerwidth = 0.5,
        strokecolor = :black,
        strokewidth = 1,
        color = color_palette[color_indices][not_nan_positions],
    )

    violin_kwargs = (side = :right, strokecolor = :black, strokewidth = 1, alpha = 0.7)
    violin_alpha = 0.5
    for (k, values_vec) in enumerate(measure_vals_both)
        if length(measure_vals_both) > 2
            category_x_vals = [color_values[k] for m in values_vec]
        else
            category_x_vals = [1 for m in values_vec]
        end
        not_nan_positions2 = findall(x -> !isnan(x), values_vec)
        category_colour = [color_palette[color_values[k]] for m in values_vec]
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
    #####################
    xtick_start = min(categories...)
    xtick_end = max(categories...)
    ax_boxplot.xticks = ([xtick_start, xtick_end], ["Art", "Pseudo-art"])

    for ax in [ax_scatter1, ax_scatter2, ax_boxplot, ax_estimate]
        CairoMakie.ylims!(ax, low = y_low, high = y_high)
    end
    for ax in [ax_scatter1, ax_scatter2]
        CairoMakie.xlims!(ax, low = x_low, high = x_high)
    end
    f2

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

    param = replace("$(func)", "_" => " ")
    if metric_index == 1 && func_index == 1
        indicator = "A "
    elseif metric_index == 1 && func_index == 2
        indicator = "B "
    elseif metric_index == 1 && func_index == 3
        indicator = "C "
    else
        ErrorException("Unknow combination of metric index and func index!") |> throw
    end
    func_str = split("$(func)", "_")[1]
    Label(
        fgl[0, :],
        "$(indicator)",
        tellheight = true,
        tellwidth = false,
        fontsize = 18,
        justification = :left,
        halign = :left,
    )

    size_ga1 = 0.15
    CairoMakie.colsize!(fgl, 4, Relative(size_ga1))
end # func

colors = [color_palette[i] for i in vcat([[t[1], t[2]] for t in colours_indidcators]...)];

func_labels = Dict(
    "max_persistence" => ["Art,\nMax. Persistence", "Pseudo-art,\nMax. Persistence"],
    "persistence" => ["Art,\nAveragen persistence", "Pseudo-art,\nAveragePersistence"],
    "density_scaled" => ["Art,\nDensity", "Pseudo-art,\nDensity"],
    "cycles_perimeter" =>
        ["Art,\nCycle perimeter length", "Pseudo-art,\nCycle perimeter length"],
)

labels = vcat([func_labels["$(k)"] for k in parameters_vec[func_range]]...)
data_labels = [split(k, ",")[1] for k in labels][1:2]

elements = reshape([PolyElement(polycolor = colors[i]) for i = 1:length(labels)], (2, 3))

fgl3 = GridLayout(f2[end+1, :])
for (i, legend_title) in
    ["Max. Persistence", "Density", "Cycle perimeter length"] |> enumerate

    Legend(
        fgl3[1, i],
        elements[:, i],
        data_labels,
        legend_title,
        tellwidth = false,
        nbanks = 2,
        tellheight = true,
        framevisible = false,
    )
end
f2

# ===-===-===-
total_subjects = length(subjects_name[selected_data])
data_stuff = savename(@dict window_size total_subjects)
data_stuff = replace(data_stuff, ".jpg" => "")
name_label = "looking_vs_not_looking_3_metrics_ver2"
funcs = join(parameters_vec[func_range], "+")
out_name = "$(scriptprefix)_$(name_label)_$(data_stuff)_$(funcs )"
image_export_dir(args...) = plotsdir(
    "section17",
    "$(scriptprefix)-$(name_label)",
    "fixation_sequence=$(CONFIG.FIXATION_SEQUENCE)",
    args...,
)

folder_arg = ("$(funcs)",)
folder_name = "$(CONFIG.DATA_CONFIG)_window=$(window_size)_$(folder_arg...  )"
final_name1 = image_export_dir(folder_name, out_name * ".png")
safesave(final_name1, f2)
final_name2 = image_export_dir(folder_name, "pdf", out_name * ".pdf")
safesave(final_name2, f2)

# ===-===-
do_nothing = "ok"
