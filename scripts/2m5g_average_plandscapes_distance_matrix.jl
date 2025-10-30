
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

import Base.Threads: @spawn, @sync

CairoMakie.set_theme!(fonts = (; regular = "Arial", bold = "Arial Bold"))
# ===-===-===-
"2m5_betti_curves_average_with_individual_ver2_all_fake.jl" |> scriptsdir |> include

# "config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include
"DataStructuresUtils.jl" |> srcdir |> include
"LandscapesPlotting.jl" |> srcdir |> include
"MakiePlots.jl" |> srcdir |> include

"ExtendedDatasetUtils.jl" |> srcdir |> include

import .CONFIG: preproc_img_dir_set, SELECTED_DIM, PERSISTENCE_THRESHOLD, DATA_CONFIG
import .CONFIG: ripserer_computations_dir

@info "Arguments processed."
# ====================================================
selected_config = CONFIG.DATA_CONFIG
all_x_values = 0:255
all_x_index = 1:256
extension = ".jpg"

## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# Average landscape
land_dim0, land_dim1 =
    map(x -> MyPair[] |> PersistenceBarcodes |> PersistenceLandscape, ["dim0", "dim1"])

selected_datasets = artists_datasets
# Artists
landscape_data = populate_dict!(
    Dict(),
    [selected_datasets, ["dim0", "dim1"]],
    final_structure = OrderedDict(),
)

for d in selected_datasets
    @info "Working on $(d)..."
    for selected_dim in ["dim0", "dim1"]
        @info "\tWorking on $(selected_dim)..."

        simple_img_dir(args...) =
            datadir("exp_pro", "img_initial_preprocessing", CONFIG.DATA_CONFIG, d, args...)

        files_list = simple_img_dir() |> readdir |> filter_out_hidden |> sort
        files_list = filter(x -> occursin(CONFIG.DATA_CONFIG, x), files_list)
        artist_bw_files_names = @pipe files_list |> ["$(k[1])" for k in split.(_, ".")]

        files_selection = if d == "Richter"
            [f for f in artist_bw_files_names if !occursin("lbbw_ks_richter_claudius_ii", f)]
        else
            artist_bw_files_names
        end

        landscape_data[d][selected_dim] =
            get_landscapes_sum(files_selection, d, selected_dim = selected_dim)
        # average_landscape_dim0 = landscape_sum / length(artist_bw_files_names)
    end
end

land_vec = populate_dict!(
    Dict(),
    [
        selected_datasets,
        # ["BW", "WB"],
        ["dim0", "dim1"],
    ],
    final_structure = OrderedDict(),
)

total_artists = length(selected_datasets)
for d in selected_datasets
    for selected_dim in ["dim0", "dim1"]
        land_vec[d][selected_dim] =
            landscape_data[d][selected_dim] / sum(total_img_per_artist[d])
    end # selected_dim
end # d


# ===-===-===-
distances_matrix_dim0 = zeros(total_artists, total_artists)
distances_matrix_dim1 = zeros(total_artists, total_artists)

p_value = 1

for (row, (d, pland1)) in enumerate(landscape_data)
    @info "row: $(row)"
    for (col, (d, pland2)) in enumerate(landscape_data)
        @info "\tcol: $(col)"


        distances_matrix_dim0[row, col] =
            distances_matrix_dim0[col, row] =
                PersistenceLandscapes.computeDiscanceOfLandscapes(
                    pland1["dim0"],
                    pland2["dim0"],
                    p_value,
                )
        distances_matrix_dim1[row, col] =
            distances_matrix_dim1[col, row] =
                PersistenceLandscapes.computeDiscanceOfLandscapes(
                    pland1["dim1"],
                    pland2["dim1"],
                    p_value,
                )
    end
end



# ===-===-
@info "Starting plotting..."

# ===-==-===-===-===-===-
data_labels = selected_datasets
tick_values = 1:total_artists

tick_labels = [
    "$(k). $(d)" for
    (k, d) in enumerate(replace(data_labels, "art" => "Art", "pseudoart"=>"Pseudo-art"))
]

colours_palette = Makie.wong_colors();
art_colour = colours_palette[3];
pseudoart_colour = colours_palette[6];
empty_matrix = fill(NaN, total_artists, total_artists);

plt_height = 400
plt_width = 900
f = CairoMakie.Figure(size = (plt_width, plt_height))
fgl = CairoMakie.GridLayout(f[1, 1]);

hmap_kwargs = (xticklabelsize = 15, yticklabelsize = 15, aspect = 1)

ax_heatmap_dim0 = CairoMakie.Axis(
    fgl[1, 1];
    title = "Dimension 0",
    xticks = (tick_values, tick_labels),
    yticks = (tick_values, tick_labels),
    # xticklabelcolor = art_colour,
    # yticklabelcolor = art_colour,
    yaxisposition = :right,
    hmap_kwargs...,
)

# ax_heatmap_dim1_labels = CairoMakie.Axis(
#     fgl[1, 2];
#     xticks = (tick_values, tick_labels),
#     yticks = (tick_values, tick_labels),
#     # xticklabelcolor = pseudoart_colour,
#     # yticklabelcolor = pseudoart_colour,
#     hmap_kwargs...,
# )
# CairoMakie.heatmap!(ax_heatmap_dim1_labels, empty_matrix)

ax_heatmap_dim1 = CairoMakie.Axis(
    fgl[1, 2];
    title = "Dimension 1",
    xticks = (tick_values, tick_labels),
    yticks = (tick_values, tick_labels),
    xticklabelcolor = art_colour,
    yticklabelcolor = art_colour,
    hmap_kwargs...,
)

diagonal = [CartesianIndex(k, k) for k = 1:total_artists]


min([x for x in log10.(distances_matrix_dim0) if !isnan(x)]...)
min([x for x in log10.(distances_matrix_dim1) if !isnan(x)]...)

max_distance =
    max(
        max([x for x in log10.(distances_matrix_dim0) if !isnan(x)]...),
        max([x for x in log10.(distances_matrix_dim1) if !isnan(x)]...),
    ) * 10 |>
    (y->ceil(Int, y)) |>
    (z->z/10)

for (ax, data) in
    zip([ax_heatmap_dim0, ax_heatmap_dim1], [distances_matrix_dim0, distances_matrix_dim1])
    data[diagonal] .= NaN
    global hm = CairoMakie.heatmap!(
        ax,
        log10.(data),
        colormap = cgrad(:redsblues, rev = true),
        colorrange = (2.8, max_distance),
    )
end

Colorbar(
    fgl[:, end+1],
    hm,
    label = L"log_{10}(area)",
    labelrotation = -pi / 2,
    ticks = 3:1:max_distance,
)
f

hidexdecorations!(ax_heatmap_dim0)
hidexdecorations!(ax_heatmap_dim1)

hideydecorations!(ax_heatmap_dim1, ticks = false)

f


# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
@info "Saving..."
scriptprefix = "2m5g"
script_subname = "average_landscapes_distance_matrix"
plot_2m5_dir(args...) = plotsdir("section2", scriptprefix * "-$(script_subname)", args...)

# ===-===-===-

joined_keys = join(selected_datasets, "-")
out_img_name = "$(script_subname)_$(selected_config)_$(joined_keys)"
thr = "threshold=$(PERSISTENCE_THRESHOLD)"

out_name = plot_2m5_dir("$(selected_config)_$(thr)", out_img_name * ".png")
safesave(out_name, f, dpi = 300)

# ===-===-
# PDF export
out_name = plot_2m5_dir("$(selected_config)_$(thr)", "pdf", out_img_name * ".pdf")
safesave(out_name, f, dpi = 300)

@info "Saved all files."

## ===-===-
do_nothing = "ok"
