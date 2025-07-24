#=
Load csv with bd info and plot distribution

=#

using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-
"2n3_histogram_manipulation_grayscale_with_lansdcapes_for_paper.jl" |> scriptsdir |> include

using CairoMakie

CairoMakie.set_theme!(fonts = (; regular = "Arial", bold = "Arial Bold"))
# ===-===-===-
scriptprefix = "2n3a"
scriptname = "manipulation_demonstration"
export_img_di(args...) = plotsdir("section2", "$(scriptprefix)-$(scriptname)", args...)

# ===-===-===-
selected_config = [k for k in keys(persistence_data)][2]

img_names =
    [k for k in persistence_data[selected_config]["dim0"][to_string(transformations[1])]] |> OrderedDict


function add_topo_plot!(
    fgl_to_use,
    p_data_d0,
    p_data_d1,
    sort_by_death::Bool;
    dims_range = 0:1,
    colours = get_bettis_color_palete(min_dim = 0),
    rowgap = 4,
    colgap = 20,
    relativerow1 = 0.4,
    relativerow3 = 0.2,
    pland_tick_step = 20,
)
    fgl_transformed_topo = CairoMakie.GridLayout(fgl_to_use)

    for (fig_position, d) in enumerate(dims_range)
        dim_index = d + 1
        p_data = [p_data_d0, p_data_d1][dim_index]
        label = ["0", "1"][dim_index]

        ax_betti0 = CairoMakie.Axis(fgl_transformed_topo[3, fig_position])
        ax_barcode0 = CairoMakie.Axis(
            fgl_transformed_topo[2, fig_position],
            ytickformat = yticks_formatter,
        )
        ax_pland0 = CairoMakie.Axis(fgl_transformed_topo[1, fig_position])

        # ===-===-
        plot_persistence_landscape!(ax_pland0, p_data["landscapes"])

        if sort_by_death
            persistence_dim0 = p_data["barcodes"][1]
            persistence_dim0 = persistence_dim0[sortperm(persistence_dim0[:, 2]), :]
        else
            persistence_dim0 = p_data["barcodes"][1]
            persistence_dim0 = persistence_dim0[sortperm(persistence_dim0[:, 1]), :]
        end


        mplot_barcodes!(
            ax_barcode0,
            persistence_dim0,
            colour = colours[dim_index],
            rev = sort_by_death,
        )
        mplot_bettis!(ax_betti0, p_data["betti"], colour = colours[dim_index])

        if size(persistence_dim0, 1) <= 5
            ax_barcode0.yticks = 1:5
        elseif size(persistence_dim0, 1) <= 10
            ax_barcode0.yticks = 1:2:10
        end

        local_dim = ["dim0", "dim1"][dim_index]
        CairoMakie.xlims!(ax_pland0, low = 0, high = 255)
        CairoMakie.ylims!(ax_pland0, low = 0, high = max_land_height)
        ax_pland0.xticks = 0:pland_tick_step:255
        ax_pland0.yticks = 0:pland_tick_step:max_land_height
        ax_pland0.title = "Dimension $(split(local_dim, "dim")[2])"

        hidexdecorations!(
            ax_pland0,
            label = true,
            ticklabels = true,
            ticks = true,
            grid = false,
            minorgrid = false,
            minorticks = false,
        )

        ax = ax_barcode0
        CairoMakie.xlims!(ax, low = 0, high = 255)
        ax.xticks = 0:pland_tick_step:255
        hidexdecorations!(
            ax,
            label = true,
            ticklabels = true,
            ticks = true,
            grid = false,
            minorgrid = false,
            minorticks = false,
        )

        # ===-===-
        CairoMakie.xlims!(ax_betti0, low = 0, high = 255)
        CairoMakie.ylims!(ax_betti0, low = 0)
        ax_betti0.xticks = 0:pland_tick_step:255
        ax_betti0.xticklabelrotation = -pi / 2
        hidedecorations!(
            ax_betti0,
            label = true,
            ticklabels = false,
            ticks = false,
            grid = false,
            minorgrid = false,
            minorticks = false,
        )

        # ===-===-
    end # dim_index

    CairoMakie.rowgap!(fgl_transformed_topo, rowgap)
    CairoMakie.colgap!(fgl_transformed_topo, colgap)

    CairoMakie.rowsize!(fgl_transformed_topo, 1, Relative(relativerow1))
    CairoMakie.rowsize!(fgl_transformed_topo, 3, Relative(relativerow3))
end

# ===-===-===-
sort_by_death = false
max_land_height = √2 * 255 * 0.5
colours = get_bettis_color_palete(min_dim = 0)
data_config = CONFIG.DATA_CONFIG

points_per_cm = 28.3465 * 2
plt_width = 19.03 * points_per_cm
plt_height = 25 * points_per_cm

max_rows = 5
name_base = "histogram_adjustement_demonstration_threshold=$(PERSISTENCE_THRESHOLD)"

if do_rescaling
    name_base *= "_rescaling=$(0.3)"
end

dataset = all_datasets[1]
name = [n for n in keys(img_names)][1]

for (name, dataset) in zip([n for n in keys(img_names)], all_datasets)
    img1 = dataset.datadir(dataset.datadir_args..., name * extension) |> load
    img1_gray = Gray.(img1)

    used_img = if data_config == "WB" || data_config == "RGB_rev"
        img_rev = ones(size(img1_gray)) .- img1_gray
    else
        img1_gray
    end

    f = CairoMakie.Figure(size = (plt_width, plt_height))
    fgl = GridLayout(f[1, 1])

    img_row = 1
    img_col = 1

    for (k, transformation) in enumerate(transformations_extended)
        @info transformation
        img_bw_adjusted = if isnothing(transformation)
            used_img
        else
            adjust_histogram(used_img, transformation |> execute)
        end

        img_for_computations = if do_rescaling
            new_size = trunc.(Int, size(img_bw_adjusted) .* percentage_scale)
            imresize(img_bw_adjusted, new_size)
        else
            img_bw_adjusted
        end

        scaled_img = floor.(Int, Gray.(img_for_computations) .* 255)

        fgl_transformed = CairoMakie.GridLayout(fgl[img_row, img_col])

        img_row += 1
        if img_row > max_rows
            img_row = 1
            img_col += 1
        end

        img_title = if isnothing(transformation)
            "$(transformation)"
        else
            "$(transformation.alg)"
        end
        if !isnothing(transformation) && !isempty(transformation.args)
            t_args = transformation.args

            img_title *= "\n"
            for (i, (key, val)) in enumerate(zip(keys(t_args), t_args))
                if i != 1
                    img_title *= ", "
                end
                k = arguments_nice_translation[key]
                img_title *= "$(k)=$(val)"
            end

        end
        img_title *= ",\n$(data_config)"

        ax_img_bw_t =
            CairoMakie.Axis(fgl_transformed[1, 1], aspect = DataAspect(), title = img_title)
        image!(ax_img_bw_t, rotr90(scaled_img))
        hidedecorations!(ax_img_bw_t)

        p_data_d0 = persistence_data[data_config]["dim0"][transformation|>to_string][name]
        p_data_d1 = persistence_data[data_config]["dim1"][transformation|>to_string][name]
        dims_range = 0:1
        add_topo_plot!(
            fgl_transformed[1, 2],
            p_data_d0,
            p_data_d1,
            sort_by_death;
            dims_range = dims_range,
            colours = get_bettis_color_palete(min_dim = 0),
            pland_tick_step = 40,
        )
        CairoMakie.colsize!(fgl_transformed, 1, Relative(0.4))
    end # transformations
    CairoMakie.colgap!(fgl, 80)
    display(f)

    # # ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
    @info "Saving."
    plot_2n3a_dir(args...) = plotsdir("section2", scriptprefix * "-$scriptname", args...)

    # # ===-===-===-
    file = name
    @info "File: $(file)"

    out_img_name = "$(name_base)_$(data_config)_$(split(file, ".csv")[1]).png"

    out_name = plot_2n3a_dir(out_img_name)
    safesave(out_name, f)

    # ===-===-
    # PDF export
    # out_img_name = "$(split(file, ".csv")[1]).pdf"

end

## ===-===-
do_nothing = "ok"
