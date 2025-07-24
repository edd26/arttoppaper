
using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-
"2n3b_distance_matrix_for_manipulated_histograms.jl" |> scriptsdir |> include

scriptprefix = "2n3ba"

# ===-===-===-
using CairoMakie

CairoMakie.set_theme!(fonts = (; regular = "Arial", bold = "Arial Bold"))

"MakiePlots.jl" |> srcdir |> include

# ===-===-===-
# Plot the results
default_gap = 18
final_row_gap = 30
final_col_gap = 60

scaling = 1
total_transformations = length(transformations_extended)

points_per_cm = 28.3465 * 2
plt_width = 14.03 * points_per_cm
plt_height = 25.86 * points_per_cm

max_rows = 5
for (i, transofrmation_range) in enumerate([2:5, 6:length(transformations_extended)])
    f = CairoMakie.Figure(size = (plt_width, plt_height))
    fgl = CairoMakie.GridLayout(f[1, 1])

    fig_row = 1
    fig_col = 1

    for (t_index, t) in enumerate(transformations_extended[transofrmation_range])

        range_start = 24 * (t_index - 1)
        selected_range = (range_start+1):(range_start+24)
        distances_matrix_dim0 = matrices_dim0[t|>to_string]
        distances_matrix_dim1 = matrices_dim1[t|>to_string]

        empty_matrix = fill(NaN, total_landscapes, total_landscapes)
        tick_values = 1:total_landscapes

        fgl_per_transformation = CairoMakie.GridLayout(fgl[fig_row, fig_col])
        fig_row += 1
        if fig_row > max_rows
            fig_row = 1
            fig_col += 1
        end

        ax_heatmap_dim0_labels = CairoMakie.Axis(
            fgl_per_transformation[2, 1];
            # title="Dimension 0",
            xticks = (tick_values[13:end], tick_labels[13:end]),
            yticks = (tick_values[13:end], tick_labels[13:end]),
            xticklabelcolor = fake_colour,
            yticklabelcolor = fake_colour,
            yaxisposition = :right,
            hmap_kwargs...,
        )
        CairoMakie.heatmap!(ax_heatmap_dim0_labels, empty_matrix)

        ax_heatmap_dim0 = CairoMakie.Axis(
            fgl_per_transformation[2, 1];
            title = "Dimension 0",
            xticks = (tick_values[1:12], tick_labels[1:12]),
            yticks = (tick_values[1:12], tick_labels[1:12]),
            xticklabelcolor = art_colour,
            yticklabelcolor = art_colour,
            yaxisposition = :right,
            hmap_kwargs...,
        )

        ax_heatmap_dim1_labels = CairoMakie.Axis(
            fgl_per_transformation[2, 2];
            xticks = (tick_values[13:end], tick_labels[13:end]),
            yticks = (tick_values[13:end], tick_labels[13:end]),
            xticklabelcolor = fake_colour,
            yticklabelcolor = fake_colour,
            hmap_kwargs...,
        )
        CairoMakie.heatmap!(ax_heatmap_dim1_labels, empty_matrix)

        ax_heatmap_dim1 = CairoMakie.Axis(
            fgl_per_transformation[2, 2];
            title = "Dimension 1",
            xticks = (tick_values[1:12], tick_labels[1:12]),
            yticks = (tick_values[1:12], tick_labels[1:12]),
            xticklabelcolor = art_colour,
            yticklabelcolor = art_colour,
            hmap_kwargs...,
        )

        diagonal = [CartesianIndex(k, k) for k = 1:total_landscapes]

        for (ax, data) in zip(
            [ax_heatmap_dim0, ax_heatmap_dim1],
            [distances_matrix_dim0, distances_matrix_dim1],
        )

            data[diagonal] .= NaN
            global hm = CairoMakie.heatmap!(
                ax,
                log10.(data),
                colormap = cgrad(:redsblues, rev = true),
            )
        end

        Colorbar(
            fgl_per_transformation[2, end+1],
            hm,
            label = L"log_{10}(distance)",
            labelrotation = -pi / 2,
        )

        main_label = if isnothing(t)
            "No transformation"
        else
            label = "Transformation: $(t.alg|>Symbol)"
            if !isempty(t.args)
                for (i, (arg, val)) in enumerate(zip([a for a in keys(t.args)], t.args))
                    if i == 1
                        label *= "\n"
                    else
                        label *= ", "
                    end
                    label *= "$arg=$val"
                end
            end
            label
        end

        CairoMakie.Label(
            fgl_per_transformation[1, :],
            main_label,
            tellwidth = false,
            font = :bold,
            fontsize = 18,
        )

        hidexdecorations!(ax_heatmap_dim0)
        hidexdecorations!(ax_heatmap_dim0_labels)
        hidexdecorations!(ax_heatmap_dim1)
        hidexdecorations!(ax_heatmap_dim1_labels)

        hideydecorations!(ax_heatmap_dim1, ticks = false)
        hideydecorations!(ax_heatmap_dim1_labels, ticks = false)

        CairoMakie.rowgap!(fgl_per_transformation, -20)
    end # t

    CairoMakie.rowgap!(fgl, final_row_gap)
    CairoMakie.colgap!(fgl, final_col_gap)

    display(f)
    # ===-===-===-

    @info "Saving."
    # ===-===-===-
    plot_2n3c_dir(args...) = plotsdir(
        "section2",
        scriptprefix * "-transformation_effect_on_pland_distance_paper",
        args...,
    )
    # ===-===-===-
    thr_folder = "threshold=$(PERSISTENCE_THRESHOLD)"

    data_sets = ["art", "pseudoart"]
    joined_keys = lowercase(DATA_CONFIG) * "_" * join(data_sets, "-")

    out_name0 = plot_2n3c_dir(
        joined_keys,
        thr_folder,
        "transformation_effect_on_pland_distance_pt$(i).png",
    )
    safesave(out_name0, f)

    out_name1 = plot_2n3c_dir(
        joined_keys,
        thr_folder,
        "pdf",
        "transformation_effect_on_pland_distance_pt$(i).pdf",
    )
    safesave(out_name1, f)

    @info "Saved all files."
end # transformation range
## ===-===-
do_nothing = "ok"

