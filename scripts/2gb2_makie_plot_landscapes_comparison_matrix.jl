using DrWatson
@quickactivate "ArtTopology"

# ===-===-===-===-===-===-===-===-===-===-===-===-
"2g_get_persistence_landscapes_summary.jl" |> scriptsdir |> include

using CairoMakie
import .CONFIG: art_images_names, names_to_order, fake_images_names
using Pipe
# ===-===-===-===-===-===-===-===-===-

data_set_landscapes = Dict()
# ===-

data_keys = land_areas.dataset |> unique
if length(data_keys) > 2
    ErrorException("Can not do the test for more than 2 data keys") |> throw
end
group_key1, group_key2 = data_keys
selected_data = group_key1


# ===-===-===-
lanscapes_df_dim0 = land_areas[land_areas.dim.==0, :]
lanscapes_df_dim1 = land_areas[land_areas.dim.==1, :]

# ===-===-===-
data_labels = [replace.(l, "_$(DATA_CONFIG)" => "") for l in lanscapes_df_dim0.file]

art_numbers = [parse(Int, just_name) for just_name in data_labels[1:12]]
art_sorting = sortperm(art_numbers)

fake_numbers = [names_to_order[just_name] for just_name in data_labels[13:end]]
fake_sorting = sortperm(fake_numbers)

lanscapes_df_dim0 = vcat(
    lanscapes_df_dim0[1:12, :][art_sorting, :],
    lanscapes_df_dim0[13:end, :][fake_sorting, :])

lanscapes_df_dim1 = vcat(
    lanscapes_df_dim1[1:12, :][art_sorting, :],
    lanscapes_df_dim1[13:end, :][fake_sorting, :])
# ===-===-===-
dim0_lands = lanscapes_df_dim0.landscape
dim1_lands = lanscapes_df_dim1.landscape

# ==-===-
p_value = 1

total_landscapes = length(dim0_lands)
distances_matrix_dim0 = zeros(total_landscapes, total_landscapes)
distances_matrix_dim1 = zeros(total_landscapes, total_landscapes)

for row in 1:total_landscapes
    @info "row: $(row)"
    for col in row:total_landscapes
        @info "\tcol: $(col)"
        distances_matrix_dim0[row, col] =
            distances_matrix_dim0[col, row] =
                PersistenceLandscapes.computeDiscanceOfLandscapes(
                    dim0_lands[row],
                    dim0_lands[col],
                    p_value
                )
        distances_matrix_dim1[row, col] =
            distances_matrix_dim1[col, row] =
                PersistenceLandscapes.computeDiscanceOfLandscapes(
                    dim1_lands[row],
                    dim1_lands[col],
                    p_value
                )
    end
end

# ===-==-===-===-===-===-
data_labels = [replace.(l, "_$(DATA_CONFIG)" => "") for l in lanscapes_df_dim0.file]

art_names = [art_images_names[parse(Int, just_name)] for just_name in data_labels[1:12]]
fake_names = [@pipe names_to_order[just_name] |> fake_images_names[_] for just_name in data_labels[13:end]]


tick_values = 1:total_landscapes
tick_labels = String[]

target_len = 10
for (k, l) in art_names |> enumerate
    @info l
    while length(l) > target_len
        l = chop(l)
    end
    push!(tick_labels, "$(k): " * l * "...")
end
for (k, l) in fake_names |> enumerate
    @info l
    while length(l) > target_len
        l = chop(l)
    end
    push!(tick_labels, "$(k): " * l * "...")
end

colours_palette = Makie.wong_colors();
art_colour = colours_palette[3];
fake_colour = colours_palette[6];
empty_matrix = fill(NaN, total_landscapes, total_landscapes);

plt_height = 400
plt_width = 900
f = CairoMakie.Figure(size=(plt_width, plt_height,))
fgl = CairoMakie.GridLayout(f[1, 1]);

hmap_kwargs = (
    xticklabelsize=15,
    yticklabelsize=15,
    aspect=1
)

ax_heatmap_dim0_labels = CairoMakie.Axis(
    fgl[1, 1];
    xticks=(tick_values[13:end], tick_labels[13:end]),
    yticks=(tick_values[13:end], tick_labels[13:end]),
    xticklabelcolor=fake_colour,
    yticklabelcolor=fake_colour,
    yaxisposition=:right,
    hmap_kwargs...
)
CairoMakie.heatmap!(ax_heatmap_dim0_labels, empty_matrix)

ax_heatmap_dim0 = CairoMakie.Axis(
    fgl[1, 1];
    title="Dimension 0",
    xticks=(tick_values[1:12], tick_labels[1:12]),
    yticks=(tick_values[1:12], tick_labels[1:12]),
    xticklabelcolor=art_colour,
    yticklabelcolor=art_colour,
    yaxisposition=:right,
    hmap_kwargs...
)

ax_heatmap_dim1_labels = CairoMakie.Axis(
    fgl[1, 2];
    xticks=(tick_values[13:end], tick_labels[13:end]),
    yticks=(tick_values[13:end], tick_labels[13:end]),
    xticklabelcolor=fake_colour,
    yticklabelcolor=fake_colour,
    hmap_kwargs...
)
CairoMakie.heatmap!(ax_heatmap_dim1_labels, empty_matrix)

ax_heatmap_dim1 = CairoMakie.Axis(
    fgl[1, 2];
    title="Dimension 1",
    xticks=(tick_values[1:12], tick_labels[1:12]),
    yticks=(tick_values[1:12], tick_labels[1:12]),
    xticklabelcolor=art_colour,
    yticklabelcolor=art_colour,
    hmap_kwargs...
)

diagonal = [CartesianIndex(k, k) for k in 1:total_landscapes]

for (ax, data) in zip([ax_heatmap_dim0, ax_heatmap_dim1], [distances_matrix_dim0, distances_matrix_dim1])
    data[diagonal] .= NaN
    global hm = CairoMakie.heatmap!(
        ax,
        log10.(data),
        colormap=cgrad(:redsblues, rev=true),
        colorrange=(2.8, 7.9),
    )
end

Colorbar(fgl[:, end+1], hm, label=L"log_{10}(area)", labelrotation=-pi / 2, ticks=3:1:7)

hidexdecorations!(ax_heatmap_dim0)
hidexdecorations!(ax_heatmap_dim0_labels)
hidexdecorations!(ax_heatmap_dim1)
hidexdecorations!(ax_heatmap_dim1_labels)

hideydecorations!(ax_heatmap_dim1, ticks=false)
hideydecorations!(ax_heatmap_dim1_labels, ticks=false)

f
# ===-===-===-

@info "Saving."
# ===-===-===-
scriptprefix = "2gb2a"
plot_2gba_dir(args...) = plotsdir("section2", scriptprefix * "-land-matrix", "landscapes-matrix", args...)
# ===-===-===-
thr_folder = "threshold=$(PERSISTENCE_THRESHOLD)"

joined_keys = lowercase(DATA_CONFIG) * "_" * join(data_sets, "-")

out_name0 = plot_2gba_dir(joined_keys, thr_folder, "landscape_distance_matrix.png")
safesave(out_name0, f)

out_name1 = plot_2gba_dir(joined_keys, thr_folder, "pdf", "landscape_distance_matrix.pdf")
safesave(out_name1, f)

@info "Saved all files."

## ===-===-
do_nothing = "ok"
