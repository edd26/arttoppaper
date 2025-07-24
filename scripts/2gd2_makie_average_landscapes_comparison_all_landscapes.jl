
using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-===-===-===-===-===-===-===-===-===-
"2g_get_persistence_landscapes_summary.jl" |> scriptsdir |> include

using Pipe
using CairoMakie
CairoMakie.set_theme!(fonts = (; regular = "Arial", bold = "Arial Bold"))

"MakiePlots.jl" |> srcdir |> include
"LandscapesPlotting.jl" |> srcdir |> include
# ===-===-===-===-===-===-===-===-===-

lanscapes_df_dim_0 = land_areas[land_areas.dim .== 0, :]
lanscapes_df_dim_1 = land_areas[land_areas.dim .== 1, :]

data_keys = land_areas.dataset |> unique
if length(data_keys) > 2
    ErrorException("Can not do the test for more than 2 data keys") |> throw
end
group_key1, group_key2 = data_keys

lanscapes_df_dim_0_group1 = lanscapes_df_dim_0[lanscapes_df_dim_0.dataset .== group_key1, :]
lanscapes_df_dim_0_group2 = lanscapes_df_dim_0[lanscapes_df_dim_0.dataset .== group_key2, :]
lanscapes_df_dim_1_group1 = lanscapes_df_dim_1[lanscapes_df_dim_1.dataset .== group_key1, :]
lanscapes_df_dim_1_group2 = lanscapes_df_dim_1[lanscapes_df_dim_1.dataset .== group_key2, :]

# ==-===-===-===-===-===-===-===-
avg_land_dim0_group1, avg_land_dim0_group2, avg_land_dim1_group1, avg_land_dim1_group2 =
    map(
        x ->
            x.landscape |>
            VectorSpaceOfPersistenceLandscapes |>
            PersistenceLandscapes.real_average,
        [
            lanscapes_df_dim_0_group1,
            lanscapes_df_dim_0_group2,
            lanscapes_df_dim_1_group1,
            lanscapes_df_dim_1_group2,
        ],
    )

plt_height = 2 * 200
plt_width = 2 * 400
f1 = CairoMakie.Figure(size = (plt_width, plt_height));
fgl_0 = CairoMakie.GridLayout(f1[1, 1])
fgl1 = CairoMakie.GridLayout(fgl_0[1, 1])
fgl2 = CairoMakie.GridLayout(fgl_0[1, 2])
fgl3 = CairoMakie.GridLayout(fgl_0[2, 1])
fgl4 = CairoMakie.GridLayout(fgl_0[2, 2])

pland_kwargs = (
    ylabel = "A.U.",
    xtrimspine = true,
    rightspinevisible = false,
    topspinevisible = false,
    xticks = 0:50:256,
    yticks = 0:25:125,
    xlabel = "Filtration step",
)
ax_pland0_gr1 = CairoMakie.Axis(fgl1[1, 1]; title = "Art, dimension 0", pland_kwargs...)
# ax_pland0_gr2 = CairoMakie.Axis(fgl2[1, 1]; title="Artificially Generated, dimension 0", pland_kwargs...)
ax_pland0_gr2 =
    CairoMakie.Axis(fgl2[1, 1]; title = "Pseudo-art, dimension 0", pland_kwargs...)
ax_pland1_gr1 = CairoMakie.Axis(fgl3[1, 1]; title = "Art, dimension 1", pland_kwargs...)
# ax_pland1_gr2 = CairoMakie.Axis(fgl4[1, 1]; title="Artificially Generated, dimension 1", pland_kwargs...)
ax_pland1_gr2 =
    CairoMakie.Axis(fgl4[1, 1]; title = "Pseudo-art, dimension 1", pland_kwargs...)

fgl_vec = [fgl1, fgl2, fgl3, fgl4]
ax_vec = [ax_pland0_gr1, ax_pland0_gr2, ax_pland1_gr1, ax_pland1_gr2]
for ax in ax_vec
    CairoMakie.ylims!(ax, high = 135)
end

colour_vec_dim0 = [:linear_kgy_5_95_c69_n256, :linear_kgy_5_95_c69_n256]
colour_vec_dim1 = [:sun, :sun]

land_vec =
    [avg_land_dim0_group1, avg_land_dim0_group2, avg_land_dim1_group1, avg_land_dim1_group2]
colour_vec = vcat(colour_vec_dim0, colour_vec_dim1)

for (ax, fgl, pland, c) in zip(ax_vec, fgl_vec, land_vec, colour_vec)
    max_colour_range = size(pland.land, 1)
    custom_colors = [
        RGBf(c) for c in cgrad(c, max(2, max_colour_range), categorical = true, rev = false)
    ]
    first_layer_index = if pland == avg_land_dim0_group1 || pland == avg_land_dim0_group2
        2
    else
        1
    end

    plot_persistence_landscape!(
        ax,
        pland,
        custom_colors = custom_colors,
        starting_layer = first_layer_index,
    )
    pland_max_vals = max_colour_range

    if pland_max_vals < 10
        tick_step = 4
    elseif pland_max_vals < 51
        tick_step = 10
    elseif pland_max_vals < 100
        tick_step = 20
    elseif pland_max_vals < 501
        tick_step = 100
    elseif pland_max_vals < 1000
        tick_step = 200
    elseif pland_max_vals < 4000
        tick_step = 500
    elseif pland_max_vals < 7000
        tick_step = 1000
    elseif pland_max_vals < 13000
        tick_step = 2000
    else
        tick_step = 4000
    end

    if c == colour_vec_dim0[1]
        selected_dim = 0
    else
        selected_dim = 1
    end
    Colorbar(
        fgl[1, 2],
        limits = (0, pland_max_vals),
        ticks = 0:tick_step:pland_max_vals,
        ticklabelrotation = -pi / 4,
        labelrotation = -pi / 2,
        tickformat = yticks_formatter,
        colormap = cgrad(c, max(2, pland_max_vals), categorical = true, rev = false),
        vertical = true,
        label = "landscape layer",
    )

end

map(x -> hidexdecorations!(x, ticks = false, grid = false), [ax_pland0_gr1, ax_pland0_gr2])

colgap!(fgl_0, 10)
rowgap!(fgl_0, 30)

f1

# ===-===-===-===-===-===-===-===-===-===-===-===-
@info "Saving."

scriptprefix = "2gd2"
plot_2gd_dir(args...) =
    plotsdir("section2", scriptprefix * "-average-landscapes", "all_landscapes", args...)
# ===-===-===-
thr_folder = "threshold=$(PERSISTENCE_THRESHOLD)"

group_key = join(data_keys, "-")
joined_keys = lowercase(DATA_CONFIG) * "_" * group_key
out_name0 = plot_2gd_dir(
    thr_folder,
    joined_keys,
    "$(scriptprefix)_average_landscape_$(group_key).png",
)
safesave(out_name0, f1)

out_name1 = plot_2gd_dir(
    thr_folder,
    joined_keys,
    "pdf",
    "$(scriptprefix)_average_landscape_$(group_key).pdf",
)
safesave(out_name1, f1)

@info "Saved all files."

## ===-===-
do_nothing = "ok"
