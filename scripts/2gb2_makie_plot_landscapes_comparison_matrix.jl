
using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-===-===-===-===-===-===-===-===-===-
"2g_get_persistence_landscapes_summary.jl" |> scriptsdir |> include

using Pipe
using CairoMakie
import .CONFIG: art_images_names, names_to_order, pseudoart_images_names

CairoMakie.set_theme!(fonts = (; regular = "Arial", bold = "Arial Bold"))

"MakiePlots.jl" |> srcdir |> include
# ===-===-===-===-===-===-===-===-===-
data_set_landscapes = Dict()

# ===-

data_keys = land_areas.dataset |> unique
if length(data_keys) > 2
    ErrorException("Can not do the test for more than 2 data keys") |> throw
end
group_key1, group_key2 = data_keys
# selected_data = group_key1

# ===-===-===-
lanscapes_df_dim0 = land_areas[land_areas.dim .== 0, :]
lanscapes_df_dim1 = land_areas[land_areas.dim .== 1, :]

# ===-===-===-
data_labels = [replace.(l, "_$(DATA_CONFIG)" => "") for l in lanscapes_df_dim0.file]

art_numbers = [parse(Int, just_name) for just_name in data_labels[1:12]]
art_sorting = sortperm(art_numbers)

pseudoart_numbers = [names_to_order[just_name] for just_name in data_labels[13:end]]
pseudoart_sorting = sortperm(pseudoart_numbers)

lanscapes_df_dim0 = vcat(
    lanscapes_df_dim0[1:12, :][art_sorting, :],
    lanscapes_df_dim0[13:end, :][pseudoart_sorting, :],
)

lanscapes_df_dim1 = vcat(
    lanscapes_df_dim1[1:12, :][art_sorting, :],
    lanscapes_df_dim1[13:end, :][pseudoart_sorting, :],
)
# ===-===-===-
dim0_lands = lanscapes_df_dim0.landscape
dim1_lands = lanscapes_df_dim1.landscape

# ==-===-
p_value = 1

total_landscapes = length(dim0_lands)
distances_matrix_dim0 = zeros(total_landscapes, total_landscapes)
distances_matrix_dim1 = zeros(total_landscapes, total_landscapes)

for row = 1:total_landscapes
    @info "row: $(row)"
    for col = row:total_landscapes
        @info "\tcol: $(col)"
        distances_matrix_dim0[row, col] =
            distances_matrix_dim0[col, row] =
                PersistenceLandscapes.computeDiscanceOfLandscapes(
                    dim0_lands[row],
                    dim0_lands[col],
                    p_value,
                )
        distances_matrix_dim1[row, col] =
            distances_matrix_dim1[col, row] =
                PersistenceLandscapes.computeDiscanceOfLandscapes(
                    dim1_lands[row],
                    dim1_lands[col],
                    p_value,
                )
    end
end

# ===-==-===-===-===-===-
data_labels = [replace.(l, "_$(DATA_CONFIG)" => "") for l in lanscapes_df_dim0.file]
tick_values = 1:total_landscapes

tick_labels = get_images_labels(data_labels; target_len = 10)

colours_palette = Makie.wong_colors();
art_colour = colours_palette[3];
pseudoart_colour = colours_palette[6];
empty_matrix = fill(NaN, total_landscapes, total_landscapes);

plt_height = 400
plt_width = 900
f = CairoMakie.Figure(size = (plt_width, plt_height))
fgl = CairoMakie.GridLayout(f[1, 1]);

hmap_kwargs = (xticklabelsize = 15, yticklabelsize = 15, aspect = 1)

ax_heatmap_dim0_labels = CairoMakie.Axis(
    fgl[1, 1];
    xticks = (tick_values[13:end], tick_labels[13:end]),
    yticks = (tick_values[13:end], tick_labels[13:end]),
    xticklabelcolor = pseudoart_colour,
    yticklabelcolor = pseudoart_colour,
    yaxisposition = :right,
    hmap_kwargs...,
)
CairoMakie.heatmap!(ax_heatmap_dim0_labels, empty_matrix)

ax_heatmap_dim0 = CairoMakie.Axis(
    fgl[1, 1];
    title = "Dimension 0",
    xticks = (tick_values[1:12], tick_labels[1:12]),
    yticks = (tick_values[1:12], tick_labels[1:12]),
    xticklabelcolor = art_colour,
    yticklabelcolor = art_colour,
    yaxisposition = :right,
    hmap_kwargs...,
)

ax_heatmap_dim1_labels = CairoMakie.Axis(
    fgl[1, 2];
    xticks = (tick_values[13:end], tick_labels[13:end]),
    yticks = (tick_values[13:end], tick_labels[13:end]),
    xticklabelcolor = pseudoart_colour,
    yticklabelcolor = pseudoart_colour,
    hmap_kwargs...,
)
CairoMakie.heatmap!(ax_heatmap_dim1_labels, empty_matrix)

ax_heatmap_dim1 = CairoMakie.Axis(
    fgl[1, 2];
    title = "Dimension 1",
    xticks = (tick_values[1:12], tick_labels[1:12]),
    yticks = (tick_values[1:12], tick_labels[1:12]),
    xticklabelcolor = art_colour,
    yticklabelcolor = art_colour,
    hmap_kwargs...,
)

diagonal = [CartesianIndex(k, k) for k = 1:total_landscapes]

for (ax, data) in
    zip([ax_heatmap_dim0, ax_heatmap_dim1], [distances_matrix_dim0, distances_matrix_dim1])
    data[diagonal] .= NaN
    global hm = CairoMakie.heatmap!(
        ax,
        log10.(data),
        colormap = cgrad(:redsblues, rev = true),
        colorrange = (2.8, 7.9),
    )
end

Colorbar(
    fgl[:, end+1],
    hm,
    label = L"log_{10}(area)",
    labelrotation = -pi / 2,
    ticks = 3:1:7,
)

hidexdecorations!(ax_heatmap_dim0)
hidexdecorations!(ax_heatmap_dim0_labels)
hidexdecorations!(ax_heatmap_dim1)
hidexdecorations!(ax_heatmap_dim1_labels)

hideydecorations!(ax_heatmap_dim1, ticks = false)
hideydecorations!(ax_heatmap_dim1_labels, ticks = false)

f
# ===-===-===-

@info "Saving."
# ===-===-===-
scriptprefix = "2gb2a"
plot_2gba_dir(args...) =
    plotsdir("section2", scriptprefix * "-land-matrix", "landscapes-matrix", args...)
# ===-===-===-
thr_folder = "threshold=$(PERSISTENCE_THRESHOLD)"

joined_keys = lowercase(DATA_CONFIG) * "_" * join(data_sets, "-")

out_name0 = plot_2gba_dir(joined_keys, thr_folder, "landscape_distance_matrix.png")
safesave(out_name0, f, dpi = 300)

out_name1 = plot_2gba_dir(joined_keys, thr_folder, "pdf", "landscape_distance_matrix.pdf")
safesave(out_name1, f, dpi = 300)

@info "Saved all files."

## ===-===-
do_nothing = "ok"
