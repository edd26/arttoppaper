using CairoMakie

function set_up_ax_distro_plt(fgl; scatter_label="")
    ax_scatter = CairoMakie.Axis(
        fgl[1, 1],
        ylabel=scatter_label,
        xtrimspine=true
    )# yscale=log10
    ax_boxplot = CairoMakie.Axis(fgl[1, 2])#, yscale=log10,)
    ax_estimate = CairoMakie.Axis(fgl[1, 3])#, yscale=log10,)

    hidedecorations!(ax_scatter,
        label=false,
        ticklabels=false,
        ticks=false,
        grid=true,
        minorgrid=true,
        minorticks=true
    )
    ax_scatter.rightspinevisible = false
    ax_scatter.topspinevisible = false

    hidespines!(ax_boxplot)
    hidespines!(ax_estimate)
    hidedecorations!(ax_boxplot)
    hidedecorations!(ax_estimate)

    return ax_scatter, ax_boxplot, ax_estimate
end

function set_up_ax_distro_plt2(fgl; scatter_label="")
    ax_scatter = CairoMakie.Axis(
        fgl[1, 1],
        ylabel=scatter_label,
        xlabel=L"ME(ECDF_{looking}-ECDF_{not\;looking})",
        # xtrimspine=true
    )# yscale=log10
    ax_boxplot = CairoMakie.Axis(
        fgl[1, 2],
        xtrimspine=true
    )#, yscale=log10,)
    ax_estimate = CairoMakie.Axis(
        fgl[1, 3]
    )#, yscale=log10,)

    hidedecorations!(ax_scatter,
        label=false,
        ticklabels=false,
        ticks=false,
        grid=true,
        minorgrid=true,
        minorticks=true
    )
    hidexdecorations!(ax_boxplot,
        label=false,
        ticklabels=false,
        ticks=false,
        grid=true,
        minorgrid=true,
        minorticks=true
    )
    hideydecorations!(ax_boxplot,)
    ax_scatter.rightspinevisible = false
    ax_scatter.topspinevisible = false
    ax_boxplot.leftspinevisible = false
    ax_boxplot.rightspinevisible = false
    ax_boxplot.topspinevisible = false

    # hidespines!(ax_boxplot)
    # hidedecorations!(ax_boxplot)
    hidespines!(ax_estimate)
    hidedecorations!(ax_estimate)

    return ax_scatter, ax_boxplot, ax_estimate
end

function do_distro_plot(ax_scatter::Makie.Axis, ax_boxplot::Makie.Axis, ax_estimate::Makie.Axis, art_vals::Vector{Float64}, fake_vals::Vector{Float64}; art_val=3, fake_val=6, color_palette=Makie.wong_colors(), skip_violin=false)
    return do_distro_plot(ax_scatter, ax_boxplot, ax_estimate, [art_vals, fake_vals]; category_values=[art_val, fake_val], color_palette=color_palette, skip_violin=skip_violin)
end

function do_distro_plot(ax_scatter::Makie.Axis, ax_boxplot::Makie.Axis, ax_estimate::Makie.Axis, all_values, me_values; category_values=[3, 6], color_palette=Makie.wong_colors(), skip_violin=false)
    values = vcat(all_values...)
    # me_values = vcat(me_values...)

    categories = []
    for (k, vec) in all_values |> enumerate
        push!(categories, [category_values[k] for v in vec])
    end
    categories = vcat(categories...)

    CairoMakie.scatter!(
        ax_scatter,
        me_values[1],
        all_values[1],
        markersize=8,
        marker=:xcross,
        color=(color_palette[category_values[1]], 0.4)
        # alpha = 0.5
    )
    CairoMakie.scatter!(
        ax_scatter,
        me_values[2],
        all_values[2],
        markersize=8,
        marker=:cross,
        color=(color_palette[category_values[2]], 0.4)
        # alpha = 0.5
    )

    CairoMakie.boxplot!(ax_boxplot,
        categories,
        values,
        whiskerwidth=0.5,
        strokecolor=:black,
        strokewidth=1,
        # color=categories
        color=color_palette[categories]
    )

    if !skip_violin
        # fake_x_vals = [1 for k in fake_vals]
        violin_kwargs = (
            side=:right,
            strokecolor=:black,
            strokewidth=1,
            alpha=0.7
        )
        violin_alpha = 0.5
        for (k, values_vec) in enumerate(all_values)
            if length(all_values) > 2
                category_x_vals = [category_values[k] for m in values_vec]
            else
                category_x_vals = [1 for m in values_vec]
            end
            category_colour = [color_palette[category_values[k]] for m in values_vec]
            if length(values_vec) > 0
                CairoMakie.violin!(ax_estimate, category_x_vals, values_vec; color=(category_colour[k], violin_alpha), violin_kwargs...)
            end
        end
    end
end

function do_distro_plot(
    ax_scatter::Makie.Axis,
    ax_boxplot::Makie.Axis,
    ax_estimate::Makie.Axis,
    all_values; category_values=[3, 6],
    color_palette=Makie.wong_colors(),
    skip_violin=false
)

    values = vcat(all_values...)

    categories = []
    for (k, vec) in all_values |> enumerate
        push!(categories, [category_values[k] for v in vec])
    end
    categories = vcat(categories...)

    CairoMakie.rainclouds!(
        ax_scatter,
        categories,
        values,
        clouds=nothing,
        plot_boxplots=false,
        cloud_width=0.0,
        markersize=8,
        jitter_width=0.3,
        side_nudge=0.0,
        # color=[art_color, fake_color]
        color=color_palette[categories]
    )
    CairoMakie.boxplot!(ax_boxplot,
        categories,
        values,
        whiskerwidth=0.5,
        strokecolor=:black,
        strokewidth=1,
        # color=categories
        color=color_palette[categories]
    )

    # fake_x_vals = [1 for k in fake_vals]
    if !skip_violin
        violin_kwargs = (
            side=:right,
            strokecolor=:black,
            strokewidth=1,
            alpha=0.7
        )
        violin_alpha = 0.5
        for (k, values_vec) in enumerate(all_values)
            if length(all_values) > 2
                category_x_vals = [category_values[k] for m in values_vec]
            else
                category_x_vals = [1 for m in values_vec]
            end
            category_colour = [color_palette[category_values[k]] for m in values_vec]
            if length(values_vec) > 0
                CairoMakie.violin!(ax_estimate, category_x_vals, values_vec; color=(category_colour[k], violin_alpha), violin_kwargs...)
            end
        end
    end # if skip
end

function get_looked_values(mean_heatmap_in_window, subject_looking, parameters_values)
    windowed_heatmap_values = [v for (k, v) in mean_heatmap_in_window]
    hist_weights = windowed_heatmap_values[subject_looking]

    subject_looking_values = Float64[]
    for (weight, value) in zip(hist_weights, parameters_values[subject_looking])
        for k in 1:ceil(weight)
            push!(subject_looking_values, value)
        end
    end
    looked_values = Vector{Float64}(parameters_values[subject_looking])
    return looked_values
end