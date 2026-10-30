
using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
"17im_feature_maps_extraction.jl" |> scriptsdir |> include

using HypothesisTests
using StatsBase: ecdf
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
scriptprefix = "17imb"

# ===-===-===-===-

parameters_df
# ===-===-
# load df with measures

art_img_name = "2_$(CONFIG.DATA_CONFIG).jpg"
pseudoart_name = "net_5013_5_$(CONFIG.DATA_CONFIG).jpg"

art_filtered_df = filter(row -> row.img_name == art_img_name, parameters_df)

hmap1 = art_filtered_df[1, :parameter_map]



# ==========

import .CONFIG:
    IMG_WIDTH,
    IMG_HEIGHT,
    SPACE_WIDTH,
    SPACE_HEIGHT,
    STARTING_POINT,
    VIEWING_WIDTH,
    VIEWING_HEIGHT


img_number = 1
view_and_img_df =
    @pipe dataset_df_dict[selected_data] |>
          filter(row -> row.Session == 1, _) |>
          filter(row -> row.Subject == "bro201", _) |>
          filter(
              row ->
                  row.Stimulus == "$(img_number)s2.jpg" ||
                      row.Stimulus == "$(img_number).jpg",
              _,
          )


subject_looking, mean_heatmap_in_window =
    get_heatmap_windows(
        view_and_img_df,
        window_size,
        SPACE_WIDTH,
        SPACE_HEIGHT,
        STARTING_POINT,
        VIEWING_WIDTH,
        IMG_HEIGHT,
        IMG_WIDTH,
    )

function reconstruct_hmap(mean_heatmap_in_window)
    max_y, max_x = map(
        x -> max(reduce(vcat, [[k[x]] for (k,) in mean_heatmap_in_window])...),
        [1, 2]
    )
    reconstructed_heatmap = zeros(max_x, max_y)

    for (k, v) in mean_heatmap_in_window
        reconstructed_heatmap[k[2], k[1]] = v
    end
    return reconstructed_heatmap
end

reconstructed_heatmap = reconstruct_hmap(mean_heatmap_in_window)


artificial_hmap_art1 = "net_5013_5-high-cycle-size.png"
art_heatmap_dir(args...) = datadir("exp_pro", "artificial-heatmaps", args...)

channelview_img = artificial_hmap_art1 |> art_heatmap_dir |> load |> channelview
col_index = 1
heatmap_map = channelview_img[col_index, :, :] .|> Gray
# non_nan_map = [x for x in heatmap_map if !isnan(x)]
# if isempty(non_nan_map)
#     max_in_area = 1
# else
#     max_in_area = max(non_nan_map...)
# end
# heatmap_image = imresize(
#                     Gray.(heatmap_map ./ max_in_area),
#                     (IMG_HEIGHT, IMG_WIDTH)
#                 ) |>
#                 Matrix{Float64} .|>
#                 (y -> y * max_in_area)
mean_heatmap_in_window = mean_heatmap_in_windows(heatmap_map, window_size,)

reconstructed_heatmap = reconstruct_hmap(mean_heatmap_in_window)


# ====-===-===-
# 


using CairoMakie

CairoMakie.heatmap(hmap1)
f = CairoMakie.Figure(size=(1200, 600))
fgl = CairoMakie.GridLayout(f[1, 1])

ax1 = CairoMakie.Axis(fgl[1, 1])
ax2 = CairoMakie.Axis(fgl[1, 2])
ax3 = CairoMakie.Axis(fgl[1, 3])

image!(ax1,)
heatmap!(ax2, hmap1)
heatmap!(ax3, reconstructed_heatmap)
f


full_path(args...) = plotsdir("section17", "17imb-simple-heatmaps", args...)
safesave(full_path("art-img1-simple-heatmap.png"), f)



# ===-===-
do_nothing = "ok"
