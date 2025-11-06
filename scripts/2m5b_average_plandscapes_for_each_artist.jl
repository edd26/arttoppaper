
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
            datadir("exp_pro", "img_initial_preprocessing", "BW", d, args...)

        files_list = simple_img_dir() |> readdir |> filter_out_hidden |> sort
        files_list = filter(x -> occursin(CONFIG.DATA_CONFIG, x), files_list)
        artist_bw_files_names = @pipe files_list |> ["$(k[1])" for k in split.(_, ".")]

        final_artist_bw_files_names = if selected_config == "BW"
            artist_bw_files_names
        else
            replace.(artist_bw_files_names, "BW" => "WB")
        end

        files_selection = if d == "Richter"
            [
                f for f in final_artist_bw_files_names if
                !occursin("lbbw_ks_richter_claudius_ii", f)
            ]
        else
            final_artist_bw_files_names
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
points_per_cm = 28.3465 * 1.5
plt_width = ceil(Int, 20.6 * points_per_cm)
plt_height = ceil(Int, 26.3 * points_per_cm)

f1 = CairoMakie.Figure(size = (plt_width, plt_height));
fgl_0 = CairoMakie.GridLayout(f1[1, 1])

fgl_artists =
    [d=>CairoMakie.GridLayout(fgl_0[i, 1]) for (i, d) in enumerate(selected_datasets)] |> OrderedDict

pland_kwargs = (
    ylabel = "A.U.",
    xtrimspine = true,
    rightspinevisible = false,
    topspinevisible = false,
    xticks = 0:50:256,
    yticks = 0:25:125,
    xlabel = "Filtration step",
)

ax_vec = populate_dict!(
    Dict(),
    [selected_datasets, ["dim0", "dim1"]],
    final_structure = OrderedDict(),
)
for (d, fgl_a) in fgl_artists
    for (dim_index, sdim) in enumerate(["dim0", "dim1"])
        ax_vec[d][sdim] =
            ax = CairoMakie.Axis(
                fgl_a[1, (dim_index-1)*2+1];
                title = "$(d), $(replace(sdim, "dim"=>"dim. "))",
                pland_kwargs...,
            )
        CairoMakie.ylims!(ax, high = 135)
    end
end

# colours
bottom_colour = Dict("dim0" => :linear_kgy_5_95_c69_n256, "dim1" => :sun)
top_colour = Dict("dim0" => :seaborn_crest_gradient, "dim1" => :matter)

total_layers = 5

selected_dim = "dim0"
dim_index = 1
d = selected_datasets[6]
local_fgl = fgl_artists[d]

# for (ax, local_fgl, pland, c, cf) in
for (d, local_fgl) in fgl_artists
    # for (local_fgl, pland, c, cf) in zip(fgl_artists, land_vec, colour_vec, colour_vec_fraction)
    # zip(ax_vec, fgl_vec, land_vec, colour_vec, colour_vec_fraction)

    for (dim_index, selected_dim) in enumerate(["dim0", "dim1"])

        pland = land_vec[d][selected_dim]
        total_landsacpe_layers = size(pland.land, 1)

        bcolour = bottom_colour[selected_dim]
        tcolour = top_colour[selected_dim]

        custom_colors = if total_landsacpe_layers > total_layers
            vcat(
                vcat(
                    [
                        [
                            RGBf(c) for
                            c in cgrad(tcolour, 100, categorical = true, rev = true)
                        ] for _ = 1:total_layers
                    ]...,
                ),
                [
                    RGBf(c) for c in cgrad(
                        bcolour,
                        total_landsacpe_layers - total_layers,
                        categorical = true,
                        rev = false,
                    )
                ],
            ) |> Vector{RGB{Float32}}

        else
            [
                RGBf(c) for c in cgrad(
                    bcolour,
                    max(2, total_landsacpe_layers),
                    categorical = true,
                    rev = false,
                )
            ]
        end

        first_layer_index = if selected_dim == "dim0"
            2
        else
            1
        end

        plot_persistence_landscape!(
            ax_vec[d][selected_dim],
            pland,
            custom_colors = custom_colors,
            starting_layer = first_layer_index,
        )

        f1
        pland_max_vals = total_landsacpe_layers
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
        elseif pland_max_vals < 10000
            tick_step = 2000
        elseif pland_max_vals < 13000
            tick_step = 3000
        elseif pland_max_vals < 20000
            tick_step = 4000
        elseif pland_max_vals < 30000
            tick_step = 8000
        elseif pland_max_vals < 60000
            tick_step = 16000
        elseif pland_max_vals < 100000
            tick_step = 20000
        elseif pland_max_vals < 130000
            tick_step = 25000
        elseif pland_max_vals < 160000
            tick_step = 30000
        else
            tick_step = 50000
        end
        f1

        # if c == colour_vec_dim0[1]
        #     selected_dim = 0
        # else
        #     selected_dim = 1
        # end


        cbar_fgl = CairoMakie.GridLayout(local_fgl[1, 2*dim_index], tellwidth = true)

        if total_landsacpe_layers > 100
            # f = Figure() # << d
            # local_fgl = GridLayout(f[1, 1])# << d
            cbar_kwargs = (
                # ticklabelrotation = -pi / 6,
                # labelrotation = -pi / 2,
                tickformat = yticks_formatter,
                colormap = cgrad(tcolour, 100, categorical = true, rev = true),
                vertical = true,
                ticklabelsize = 12,
            )

            range_starts = reverse(0:100:(100*total_layers))
            range_stops = reverse(100:100:(100*(total_layers+1)))
            for (k, (r_start, r_stop)) in enumerate(zip(range_starts, range_stops))
                step = if k==1
                    100
                else
                    101
                end
                Colorbar(
                    cbar_fgl[k+1, 1];
                    limits = (r_start, r_stop),
                    ticks = r_start:step:r_stop,
                    cbar_kwargs...,
                    # label="landscape layer",
                )
            end
            # f# << d

            bottom_lower_limit = (total_layers * 100 + 1)
            Colorbar(
                cbar_fgl[1, 1],
                limits = (bottom_lower_limit, pland_max_vals),
                ticks = 0:tick_step:pland_max_vals,
                # ticklabelrotation = -pi / 6,
                # labelrotation = -pi / 2,
                tickformat = yticks_formatter,
                colormap = cgrad(
                    bcolour,
                    pland_max_vals - 100,
                    categorical = true,
                    rev = false,
                ),
                vertical = true,
                # label = "landscape layer",
                ticklabelsize = 12,
            )
            CairoMakie.rowsize!(cbar_fgl, 1, Relative(1 - 0.50))
            f1
            rowgap!(cbar_fgl, 0)
        else
            Colorbar(
                cbar_fgl[1, 1],
                limits = (0, pland_max_vals),
                ticks = 0:tick_step:pland_max_vals,
                # ticklabelrotation = -pi / 4,
                labelrotation = -pi / 2,
                tickformat = yticks_formatter,
                colormap = cgrad(
                    bcolour,
                    max(2, pland_max_vals),
                    categorical = true,
                    rev = false,
                ),
                vertical = true,
                # label = "landscape layer",
                ticklabelsize = 12,
            )
        end # if
        Label(
            cbar_fgl[:, 2],
            "landscape layer",
            rotation = -pi / 2,
            tellheight = false,
            tellwidth = true,
            halign = :left,
            # font = :bold,
        )
        colgap!(cbar_fgl, 5)

    end # (dim_index, selected_dim)

    f1
end

# map(x -> hidexdecorations!(x, ticks = false, grid = false), [ax_pland0_gr1, ax_pland0_gr2])

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
