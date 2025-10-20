
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
"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include
"DataStructuresUtils.jl" |> srcdir |> include
"LandscapesPlotting.jl" |> srcdir |> include
"MakiePlots.jl" |> srcdir |> include

"ExtendedDatasetUtils.jl" |> srcdir |> include

# "HeatmapsUtils.jl" |> srcdir |> include

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

## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# Average landscape
land_dim0, land_dim1 =
    map(x -> MyPair[] |> PersistenceBarcodes |> PersistenceLandscape, ["dim0", "dim1"])

# Artists
landscape_data = populate_dict!(
    Dict(),
    [vcat(set2, "all_pseudoart"), ["dim0", "dim1"]],
    final_structure = OrderedDict(),
)

for d in artists_datasets
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

# All pseudoart
sum_pt1 = get_landscapes_sum(bw_files_names[1:2200], "all_pseudoart", selected_dim = "dim0")
sum_pt2 =
    get_landscapes_sum(bw_files_names[2201:end], "all_pseudoart", selected_dim = "dim0")
landscape_data["all_pseudoart"]["dim0"] = (sum_pt1 + sum_pt2)

sum_pt1 = get_landscapes_sum(bw_files_names[1:2200], "all_pseudoart", selected_dim = "dim1")
sum_pt2 =
    get_landscapes_sum(bw_files_names[2201:end], "all_pseudoart", selected_dim = "dim1")
landscape_data["all_pseudoart"]["dim1"] = (sum_pt1 + sum_pt2)


avg_pland_all_pseudo_dim0 = landscape_data["all_pseudoart"]["dim0"] / 4500
avg_pland_all_pseudo_dim1 = landscape_data["all_pseudoart"]["dim1"] / 4500

avg_pland_all_artist_dim0 =
    reduce(+, [landscape_data[d]["dim0"] for d in artists_datasets]) / sum([v for (k, v) in total_img_per_artist])
avg_pland_all_artist_dim1 =
    reduce(+, [landscape_data[d]["dim1"] for d in artists_datasets]) / sum([v for (k, v) in total_img_per_artist])

land_vec = [
    avg_pland_all_pseudo_dim0,
    avg_pland_all_artist_dim0,
    avg_pland_all_pseudo_dim1,
    avg_pland_all_artist_dim1,
]

# ===-===-
@info "Starting plotting..."
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
ax_pland0_gr1 =
    CairoMakie.Axis(fgl1[1, 1]; title = "All pseudoart, dimension 0", pland_kwargs...)
ax_pland0_gr2 =
    CairoMakie.Axis(fgl2[1, 1]; title = "All artists, dimension 0", pland_kwargs...)

ax_pland1_gr1 =
    CairoMakie.Axis(fgl3[1, 1]; title = "All pseudoart, dimension 1", pland_kwargs...)
ax_pland1_gr2 =
    CairoMakie.Axis(fgl4[1, 1]; title = "All artists, dimension 1", pland_kwargs...)

fgl_vec = [fgl1, fgl2, fgl3, fgl4]
ax_vec = [ax_pland0_gr1, ax_pland0_gr2, ax_pland1_gr1, ax_pland1_gr2]
for ax in ax_vec
    CairoMakie.ylims!(ax, high = 135)
end

colour_vec_dim0 = [:linear_kgy_5_95_c69_n256, :linear_kgy_5_95_c69_n256]
# colour_vec_dim0 = [:tarn, :tarn]
colour_vec_dim1 = [:sun, :sun]
# colour_vec_dim1 = [:matter, :matter]
colour_vec = vcat(colour_vec_dim0, colour_vec_dim1)
colour_vec_fraction = [:deep, :deep, :blues, :blues]
colour_vec_fraction = [:seaborn_crest_gradient, :seaborn_crest_gradient, :matter, :matter]

i = 2
ax = ax_vec[i]
local_fgl = fgl_vec[i]
pland = land_vec[i]
c = colour_vec[i]

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
scriptprefix = "2m5"
script_subname = "average_landscapes_pseudo_vs_art"
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
