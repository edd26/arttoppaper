
using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-
using Images
using CairoMakie
using Pipe

CairoMakie.set_theme!(fonts = (; regular = "Arial", bold = "Arial Bold"))

"2f3h_load_and_makie_plot_persistence_landscapes_with_cycles_visualisation.jl" |>
scriptsdir |>
include
# ===-===-===-
"LandscapesPlotting.jl" |> srcdir |> include
"MakiePlots.jl" |> srcdir |> include
"HeatmapsUtils.jl" |> srcdir |> include

## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# Do the plotting
selected_dim = 1
script_prefix = "2f3ha"
script_name = "RGB_channels_topology_with_cycles"


if CONFIG.DATA_CONFIG == "WB" || CONFIG.DATA_CONFIG == "RGB_rev"
    sort_by_death = true
else
    sort_by_death = false
end
# ===-===-
points_per_cm = 28.3465 * 3

plt_width = 17.6 * points_per_cm
plt_height = 9.3 * points_per_cm
max_x_val = 255
max_land_height = √2 * 255 * 0.5

extension = ".jpg"

for name in files_names
    @info "Name: $(name)"

    input_img_name = name * extension
    if !occursin(DATA_CONFIG, name) && DATA_CONFIG != "RGB" && DATA_CONFIG != "RGB_rev"
        input_img_name = name * "_$(DATA_CONFIG)" * extension
    else
        input_img_name = name * extension
    end

    loaded_img = name * extension |> simple_img_dir |> load |> channelview
    if loaded_img |> size |> length == 3
        loaded_img = loaded_img[1, :, :]
    end


    # Get cycles on canvas
    dim_index = 2
    cycles = all_homology_info[DATA_CONFIG][name][dim_index]# [persistances.<20]
    cycles_on_image_canvas = get_cycles_on_image_canvas(loaded_img, cycles)

    # ===-
    f = CairoMakie.Figure(size = (plt_width, plt_height))

    fgl = CairoMakie.GridLayout(f[1, 1])

    ax_barcode0 =
        CairoMakie.Axis(fgl[3, 3], xlabel = "Pixel intensity", ylabel = "Cycle index")
    ax_barcode1 = CairoMakie.Axis(fgl[3, 4], xlabel = "Pixel intensity")

    ax_pland0 = CairoMakie.Axis(fgl[2, 3], ylabel = "A.U.")
    ax_pland1 = CairoMakie.Axis(fgl[2, 4])

    isolines_with_colormap = true
    if isolines_with_colormap

        ax_empty = CairoMakie.Axis(fgl[4, 3:4])
        hidedecorations!(ax_empty)
        hidespines!(ax_empty)
    end

    ax_img = CairoMakie.Axis(fgl[:, 1], aspect = AxisAspect(1434 / 2048))
    ax_cycles = CairoMakie.Axis(fgl[:, 2], aspect = AxisAspect(1434 / 2048))
    # ===-===- 
    # add lablels 
    # for (metricindex, metric) in ["Persistence\nlansdcape", "Barcodes", "Betti curve"] |> enumerate
    for (metric_index, metric) in zip([2, 3], ["Persistence landscape", "Barcodes"])
        Box(fgl[metric_index, 5], color = :gray90)
        Label(fgl[metric_index, 5], metric, rotation = -pi / 2, tellheight = false)
    end

    # ===-===-
    img_to_plot = if DATA_CONFIG == "RGB"
        file_colour = split(name, "_")[end]

        zero_slice = zero(loaded_img')

        if file_colour == "R"
            RGB.(loaded_img', zero_slice, zero_slice)

        elseif file_colour == "G"
            RGB.(zero_slice, loaded_img', zero_slice)
        elseif file_colour == "B"
            RGB.(zero_slice, zero_slice, loaded_img')
        else
            "Not recognised colour" |> ErrorException |> throw
        end
    else
        loaded_img'
    end
    image!(ax_img, img_to_plot, interpolate = false)
    ax_img.yreversed = true

    # Plot hatmap
    CairoMakie.image!(ax_cycles, loaded_img[end:-1:1, :]', alpha = 0.4, interpolate = false)

    if !all(isnan.(cycles_on_image_canvas))
        cycles_plt = CairoMakie.heatmap!(
            ax_cycles,
            cycles_on_image_canvas[end:-1:1, :]',
            colormap = cgrad(:roma, rev = true),
            alpha = 1.0,
            interpolate = false,
            colorrange = (0, 255),
        )
        if isolines_with_colormap
            Colorbar(
                fgl[4, 3:4],
                cycles_plt,
                label = "Cycle Persistence",
                ticks = 0:50:255,
                vertical = false,
                flipaxis = false,
                ticklabelrotation = pi / 4,
            )
        end
    else
        @warn "There are no cycles in dimension 1"
    end

    pland_max_vals = []
    color_vectors = [[:green, :black], [:yellow, :black]]
    color_vectors = [:linear_kgy_5_95_c69_n256, :sun]
    for (ax, local_dim, colour_vec) in
        zip([ax_pland0, ax_pland1], ["dim0", "dim1"], color_vectors)
        max_colour_range =
            size(persistence_data[data_config][local_dim][name]["landscapes"].land, 1)
        custom_colors = [
            RGBf(c) for c in
            cgrad(colour_vec, max(2, max_colour_range), categorical = true, rev = false)
        ]
        plot_persistence_landscape!(
            ax,
            persistence_data[data_config][local_dim][name]["landscapes"],
            custom_colors = custom_colors,
        )
        push!(pland_max_vals, max_colour_range)
    end

    for k = 1:2
        if pland_max_vals[k] < 500
            tick_step = 100
        else
            tick_step = 500
        end
        Colorbar(
            fgl[1, k+2],
            limits = (0, pland_max_vals[k]),
            ticks = 0:tick_step:pland_max_vals[k],
            ticklabelrotation = pi / 4,
            colormap = cgrad(
                color_vectors[k],
                max(2, pland_max_vals[k]),
                categorical = true,
                rev = false,
            ),
            vertical = false,
            label = "landscape layer, dimension $(k-1)",
        )
    end

    f

    colours = get_bettis_color_palete(min_dim = 0)

    if sort_by_death
        persistence_dim0 = persistence_data[data_config]["dim0"][name]["barcodes"][1]
        persistence_dim1 = persistence_data[data_config]["dim1"][name]["barcodes"][1]

        persistence_dim0 = persistence_dim0[sortperm(persistence_dim0[:, 2]), :]
        persistence_dim1 = persistence_dim1[sortperm(persistence_dim1[:, 2]), :]
    else
        persistence_dim0 = persistence_data[data_config]["dim0"][name]["barcodes"][1]
        persistence_dim1 = persistence_data[data_config]["dim1"][name]["barcodes"][1]

        persistence_dim0 = persistence_dim0[sortperm(persistence_dim0[:, 1]), :]
        persistence_dim1 = persistence_dim1[sortperm(persistence_dim1[:, 1]), :]
    end

    mplot_barcodes!(ax_barcode0, persistence_dim0, colour = colours[1], rev = sort_by_death)
    mplot_barcodes!(ax_barcode1, persistence_dim1, colour = colours[2], rev = sort_by_death)

    # ===-===-

    for ax in [ax_img, ax_cycles]
        hidedecorations!(
            ax,
            label = true,
            ticklabels = true,
            ticks = true,
            grid = true,
            minorgrid = true,
            minorticks = true,
        )
    end

    for (ax, local_dim) in zip([ax_pland0, ax_pland1], ["dim0", "dim1"])
        CairoMakie.xlims!(ax, low = 0, high = 255)
        CairoMakie.ylims!(ax, low = 0, high = max_land_height)
        ax.xticks = 0:20:255
        ax.yticks = 0:20:max_land_height
        ax.title = "Dimension $(split(local_dim, "dim")[2])"

        hidexdecorations!(
            ax,
            label = true,
            ticklabels = true,
            ticks = true,
            grid = false,
            minorgrid = false,
            minorticks = false,
        )
    end
    for (ax, label) in zip([ax_barcode0, ax_barcode1], ["0", "1"])
        CairoMakie.xlims!(ax, low = 0, high = 255)
        ax.xticks = 0:20:255
    end

    CairoMakie.rowgap!(fgl, 5)
    CairoMakie.colgap!(fgl, 10)

    CairoMakie.rowgap!(fgl, 3, 30)

    CairoMakie.colsize!(fgl, 1, Relative(0.33))
    CairoMakie.colsize!(fgl, 2, Relative(0.33))

    CairoMakie.rowsize!(fgl, 3, Relative(0.65))
    CairoMakie.rowsize!(fgl, 2, Relative(0.25))

    f
    img_plot = f

    # ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
    @info "Saving."
    plot_2f3h_dir(args...) =
        plotsdir("section2", script_prefix * "_$(script_name)", args...)

    # ===-===-===-
    @info "Saving file: $(name)"
    out_img_name = "$(split(name, ".csv")[1]).png"
    thr = "threshold=$(PERSISTENCE_THRESHOLD)"

    if sort_by_death
        out_name = plot_2f3h_dir(CONFIG.path_args..., thr * "_death_sorted", out_img_name)
    else
        out_name = plot_2f3h_dir(CONFIG.path_args..., thr, out_img_name)
    end
    safesave(out_name, img_plot)

    # ===-===-
    # PDF export
    # out_img_name = "$(split(file, ".csv")[1]).pdf"

    # if sort_by_death
    #     out_name = plot_2f3h_dir(CONFIG.path_args..., thr * "_death_sorted", "pdf", out_img_name)
    # else
    #     out_name = plot_2f3h_dir(CONFIG.path_args..., thr, "pdf", out_img_name)
    # end
    # safesave(out_name, img_plot)
end

@info "Saved all files."
# ===-===-
do_nothing = "ok"
