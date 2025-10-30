
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

selected_datasets =
    artists_datasets[artists_datasets .!= "pseudoart".&&artists_datasets .!= "art"]
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

# ===-===-
@info "Starting plotting..."
total_artists = total_plots = length(artists_datasets)
plt_height = total_plots * 200
plt_width = 2 * 400
f1 = CairoMakie.Figure(size = (plt_width, plt_height));
fgl_0 = CairoMakie.GridLayout(f1[1, 1])
# fgl_0 = CairoMakie.GridLayout(f1[1, 1])
# fgl_vec = GridLayout[]
# for (i, d) in enumerate(artists_datasets)
#     for col = 1:2
#         push!(fgl_vec, CairoMakie.GridLayout(fgl_0[i, col]))
#     end
# end
fgl1 = CairoMakie.GridLayout(fgl_0[1, 1])
fgl2 = CairoMakie.GridLayout(fgl_0[1, 2])
fgl3 = CairoMakie.GridLayout(fgl_0[2, 1])
fgl4 = CairoMakie.GridLayout(fgl_0[2, 2])
fgl5 = CairoMakie.GridLayout(fgl_0[3, 1])
fgl6 = CairoMakie.GridLayout(fgl_0[3, 2])
fgl7 = CairoMakie.GridLayout(fgl_0[4, 1])
fgl8 = CairoMakie.GridLayout(fgl_0[4, 2])
fgl9 = CairoMakie.GridLayout(fgl_0[5, 1])
fgl10 = CairoMakie.GridLayout(fgl_0[5, 2])

# ax_vec = []
# fgl_mat = reshape(fgl_vec, (2, total_artists))
# fgl_vec[1] == fgl_mat[1, 1]
# fgl_vec[1] == fgl_mat[1, 2]
# fgl_vec[2] == fgl_mat[2, 1]

# for (i, d) in enumerate(artists_datasets)
#     fgl_land0 = fgl_mat[1, i]
#     fgl_land1 = fgl_mat[2, i]
#     push!(ax_vec, 
#     CairoMakie.Axis(fgl_vec[1]; title = "$(d), dimension 0", pland_kwargs...)
#     )
#     push!(ax_vec, CairoMakie.Axis(fgl_land1, title = "$(d), dimension 1", pland_kwargs...))
# end


pland_kwargs = (
    ylabel = "A.U.",
    xtrimspine = true,
    rightspinevisible = false,
    topspinevisible = false,
    xticks = 0:50:256,
    yticks = 0:25:125,
    xlabel = "Filtration step",
)
ax_vec = []

for (d, f_vec) in zip(
    artists_datasets,
    [[fgl1, fgl2], [fgl3, fgl4], [fgl5, fgl6], [fgl7, fgl8], [fgl9, fgl10]],
)
    push!(
        ax_vec,
        CairoMakie.Axis(f_vec[1][1, 1]; title = "$(d), dimension 0", pland_kwargs...),
    )
    push!(
        ax_vec,
        CairoMakie.Axis(f_vec[2][1, 1]; title = "$(d), dimension 1", pland_kwargs...),
    )
end

fgl_vec = [fgl1, fgl2, fgl3, fgl4, fgl5, fgl6, fgl7, fgl8, fgl9, fgl10]
for ax in ax_vec
    CairoMakie.ylims!(ax, high = 135)
end

# colours
colour_vec = repeat([:linear_kgy_5_95_c69_n256, :sun], total_artists)
colour_vec_fraction = repeat([:seaborn_crest_gradient, :matter], total_artists)

for (ax, local_fgl, pland, c, cf) in
    zip(ax_vec, fgl_vec, land_vec, colour_vec, colour_vec_fraction)
    max_colour_range = size(pland.land, 1)

    custom_colors = if max_colour_range > 100

        vcat(
            [RGBf(c) for c in cgrad(cf, 100, categorical = true, rev = true)],
            [
                RGBf(c) for
                c in cgrad(c, max_colour_range - 100, categorical = true, rev = false)
            ],
        )

    else
        [RGBf(c) for c in cgrad(c, max(2, max_colour_range), categorical = true, rev = false)]
    end

    first_layer_index = if pland.dimension == 0
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
    elseif pland_max_vals < 20000
        tick_step = 4000
    elseif pland_max_vals < 30000
        tick_step = 8000
    elseif pland_max_vals < 60000
        tick_step = 16000
    else
        tick_step = 20000
    end

    if c == colour_vec_dim0[1]
        selected_dim = 0
    else
        selected_dim = 1
    end


    if max_colour_range > 100
        # f = Figure() # << d
        # local_fgl = GridLayout(f[1, 1])# << d
        cbar_fgl = CairoMakie.GridLayout(local_fgl[1, 2])

        Colorbar(
            cbar_fgl[2, 1],
            limits = (0, 100),
            ticks = 0:100:100,
            ticklabelrotation = -pi / 4,
            labelrotation = -pi / 2,
            tickformat = yticks_formatter,
            colormap = cgrad(cf, 100, categorical = true, rev = true),
            vertical = true,
            # label="landscape layer",
        )
        # f# << d

        Colorbar(
            cbar_fgl[1, 1],
            limits = (101, pland_max_vals),
            ticks = 101:tick_step:pland_max_vals,
            ticklabelrotation = -pi / 4,
            labelrotation = -pi / 2,
            tickformat = yticks_formatter,
            colormap = cgrad(c, pland_max_vals - 100, categorical = true, rev = false),
            vertical = true,
            label = "landscape layer",
        )
        CairoMakie.rowsize!(cbar_fgl, 1, Relative(1 - 0.15))
        rowgap!(cbar_fgl, 5)
        # f
    else
        Colorbar(
            local_fgl[1, 2],
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

end

map(x -> hidexdecorations!(x, ticks = false, grid = false), [ax_pland0_gr1, ax_pland0_gr2])

colgap!(fgl_0, 10)
rowgap!(fgl_0, 30)

display(f1)


# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
@info "Saving..."
scriptprefix = "2m5b"
script_subname = "average_landscapes_all_art"
plot_2m5_dir(args...) = plotsdir("section2", scriptprefix * "-$(script_subname)", args...)

# ===-===-===-

joined_keys = lowercase(DATA_CONFIG) * "_" * join(artists_datasets, "-")
out_img_name = "$(script_subname)_$(selected_config)_$(joined_keys)"
thr = "threshold=$(PERSISTENCE_THRESHOLD)"

out_name = plot_2m5_dir("$(selected_config)_$(thr)", out_img_name * ".png")
safesave(out_name, f1, dpi = 300)

# ===-===-
# PDF export
# out_name = plot_2m5_dir("$(selected_config)_$(thr)", "pdf", out_img_name * ".pdf")
# safesave(out_name, f1, dpi=300)

@info "Saved all files."

## ===-===-
do_nothing = "ok"
