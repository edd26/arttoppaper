using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-===-
"14c_load_image_complexity_metrics.jl" |> scriptsdir |> include

# ===-===-===-===-
using CairoMakie

# ===-===-===-
# Load data
category_labels1 = FSlope_df[:, :set]
data_array1 = FSlope_df[:, "Fourier slope"]
data_array1 = abs.(data_array1)

category_labels2 = PHOG_df[:, :set]
data_array2 = PHOG_df[:, "Self-Similarity"]
data_array3 = PHOG_df[:, "Complexity"]
data_array4 = PHOG_df[:, "Anisotropy"]
data_array4 = abs.(data_array4)

category_labels3 = category_labels2
data_array5 = EdgeOrientation_df[:, "avg-shannon20-80"]
data_array6 = EdgeOrientation_df[:, "edge-density"]

category_labels4 = (@pipe land_areas_df |> filter(:dim => ==(0), _))[:, :dataset]
data_array7 = (@pipe land_areas_df |> filter(:dim => ==(0), _))[:, :pland_area]
data_array8 = (@pipe land_areas_df |> filter(:dim => ==(1), _))[:, :pland_area]

## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# Plot the data
use_print_size = true

total_metrics = size(all_data_df, 2) - 2
total_datasets = length(all_data_df.set |> unique)

total_cols = 2

if length(data_names_vec) < 4
    scaling_factor = 0.8
else
    scaling_factor = length(data_names_vec)
end

if use_print_size
    plt_width = 300 + 150 * total_datasets
    plt_height = 700
else
    plt_height = round(Int, 1700 * scaling_factor ÷ total_cols)
    plt_width = 100 + 150 * total_datasets
end

area_axis_args = (yscale = log10,)
# 
f = Figure(resolution = (plt_width, plt_height));
fgl = GridLayout(f[1, 1])
axis_vec = []

Box(
    fgl[4, 1],
    strokecolor = (:red, 0.7),
    linestyle = :solid,
    strokewidth = 4,
    color = :white,
    alignmode = Outside(),
    halign = :left,
)
Box(
    fgl[4, 2],
    strokecolor = (:red, 0.7),
    linestyle = :solid,
    strokewidth = 4,
    color = :white,
    alignmode = Outside(),
    halign = :left,
)
for k = 1:total_metrics
    if k <= 4
        col = 1
        row = k
    else
        col = 2
        row = k - 4
    end
    args = (yticklabelrotation = pi / 2, xtrimspine = true, area_axis_args...)

    push!(axis_vec, CairoMakie.Axis(fgl[row, col]; args...))
end

axis_fl,
axis_selfsim,
axis_complex,
axis_pland0,
axis_aniso,
axis_avg_shannon_20_80,
axis_edge_density,
axis_pland1 = axis_vec

colors = [Makie.wong_colors(8)...];

for (i, (ax, labels, data_arr, title)) in
    zip(
    [
        axis_fl,
        axis_selfsim,
        axis_complex,
        axis_pland0,
        axis_aniso,
        axis_avg_shannon_20_80,
        axis_edge_density,
        axis_pland1,
    ],
    [
        category_labels1,
        category_labels2,
        category_labels2,
        category_labels4,
        category_labels2,
        category_labels3,
        category_labels3,
        category_labels4,
    ],
    [
        data_array1,
        data_array2,
        data_array3,
        data_array7,
        data_array4,
        data_array5,
        data_array6,
        data_array8,
    ],
    [
        "Abs. Fourier slope",
        "Self-Similarity",
        "Complexity",
        "Persistence landscapes'\narea, dim 0",
        "Abs. Anisotropy",
        "Avg. Shannon20-80",
        "Edge density",
        "Persistence landscapes'\narea, dim 1",
    ],
) |> enumerate

    @info "Working on a metric: $(i)"

    y_label = title
    img_title = ""
    if i == total_metrics
        x_label = "Category"
    else
        x_label = ""
        hidexdecorations!(
            ax,
            label = true,
            ticklabels = false,
            ticks = false,
            grid = false,
            minorgrid = false,
            minorticks = false,
        )
    end
    or = :vertical
    ax.xgridvisible = false
    ax.ygridvisible = false
    ax.rightspinevisible = false
    ax.topspinevisible = false

    # ===-
    colours_vec = colors[indexin(category_labels1, unique(category_labels1)) .* 3]
    CairoMakie.rainclouds!(
        ax,
        labels,
        data_arr;
        # jitter_width=0.2,
        plot_boxplots = true,
        clouds = nothing,
        orientation = or,
        gap = 0.1,
        center_boxplot = false,
        boxplot_nudge = -0.15,
        boxplot_width = 0.4,
        markersize = 10,
        color = colours_vec,
    )
    f
    CairoMakie.xlims!(ax, low = 0.6, high = total_datasets + 0.4)
    ax.xticks = 1:total_datasets
    ax.ylabel = y_label

    CairoMakie.ylims!(ax, low = 0.0001, high = 1e8)

    f
    ax.yticklabelsize = 10
    ax.ylabelsize = 12

    hidexdecorations!(
        ax,
        label = true,
        ticklabels = true,
        ticks = false,
        grid = true,
        minorgrid = true,
        minorticks = true,
    )
end

overlapping_elements =
    data_array5[1:12] .< 1e6 .&&
    data_array5[1:12] .> 1e2 .&&
    data_array6[1:12] .< 1e6 .&&
    data_array6[1:12] .> 1e4

@info "The elements overlapping in their landscapes area are $(land_areas_df[1:12, :][overlapping_elements, :file])"

group_color =
    [PolyElement(color = color, strokecolor = :transparent) for color in colors[3:3:6]]

Legend(
    fgl[end+1, :],
    group_color,
    ["Artist", "Pseudo-art"],
    tellwidth = false,
    tellheight = true,
    nbanks = 2,
    framevisible = false,
)

rowgap!(fgl, 30)
colgap!(fgl, 10)
f
## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# Save image
@info "Saving..."

script_prefix = "14ca"
plot_14c_dir(args...) =
    plotsdir("section14", script_prefix * "-metrics-comparison", args...)

savename_val = @savename useddata

if use_print_size
    out_name0 =
        plot_14c_dir("print", "$(script_prefix)_metrics_comparison_$(savename_val).png")
    safesave(out_name0, f)

    out_name1 = plot_14c_dir(
        "print",
        "pdf",
        "$(script_prefix)_metrics_comparison_$(savename_val).pdf",
    )
    safesave(out_name1, f)

    @info "Saved."
else

    out_name0 = plot_14c_dir("metrics_comparison_$(savename_val).png")
    safesave(out_name0, f)

    out_name1 = plot_14c_dir("pdf", "metrics_comparison_$(savename_val).pdf")
    safesave(out_name1, f)

    @info "Saved."
end

## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# 
do_nothing = "ok"
