using PlotUtils
using HypothesisTests: MannWhitneyUTest, LeveneTest
using Printf

artists_datasets =
    set2 = [
        "Jarema",
        "Malewicz",
        "Pollock",
        "Kandinsky",
        "Richter",
        "Rothko",
        "art",
        "pseudoart",
    ]
# artists_datasets = set2 = ["Jarema", "Malewicz", "Pollock", "Kandinsky", "Richter"]

ripserer_landscapes_dir(args...) =
    datadir("exp_pro", "ripserer_computations", "ripserer-landscapes", args...)


function load_landscape(
    loading_name::String,
    dataset::String;
    alg=:homology,
    reps=true,
    cutoff=5,
)
    # ===-===-
    # Get cycles and their persistence
    homology_config = @dict alg reps cutoff

    produced_landscapes, p = produce_or_load(
        ripserer_landscapes_dir(dataset, "image_$(replace(loading_name, ".jpg"=>""))"), # path
        homology_config, # config
        prefix="homology_info", # file prefix
        force=false, # force computations
    ) do homology_config
        ErrorException("This should have been run in the loop above, terminating") |> throw
    end # produce_or_load
    return produced_landscapes["ripserer_landsacpes"]
end #file

function load_bd_data(
    loading_name::String,
    dataset::String;
    alg=:homology,
    reps=true,
    cutoff=5,
)
    # ===-===-
    # Get cycles and their persistence
    homology_config = @dict alg reps cutoff

    produced_landscapes, p = produce_or_load(
        ripserer_landscapes_dir(dataset, "image_$(replace(loading_name, ".jpg"=>""))"), # path
        homology_config, # config
        prefix="homology_info", # file prefix
        force=false, # force computations
    ) do homology_config
        ErrorException("This should have been run in the loop above, terminating") |> throw
    end # produce_or_load

    births_dict, deaths_dict =
        produced_landscapes["ripserer_births"], produced_landscapes["ripserer_deaths"]

    return births_dict, deaths_dict
end #file


function get_landscapes_sum(landscapes_names, dataset::String; selected_dim="dim0")
    if length(landscapes_names) == 1
        # @info "len==1" landscapes_names

        loaded_landscape = load_landscape(landscapes_names[1], dataset)[selected_dim]
        return loaded_landscape
    elseif length(landscapes_names) == 2
        # @info "len==2" landscapes_names
        l_name1, l_name2 = landscapes_names
        loaded_landscape1 = load_landscape(l_name1, dataset)[selected_dim]
        loaded_landscape2 = load_landscape(l_name2, dataset)[selected_dim]

        return loaded_landscape1 + loaded_landscape2

    elseif length(landscapes_names) > 2
        landscapes_count = length(landscapes_names)
        half_landscapes_count = landscapes_count ÷ 2 + 1
        range1 = 1:(half_landscapes_count-1)
        range2 = half_landscapes_count:landscapes_count

        return get_landscapes_sum(
            landscapes_names[range1],
            dataset,
            selected_dim=selected_dim,
        ) + get_landscapes_sum(
            landscapes_names[range2],
            dataset,
            selected_dim=selected_dim,
        )

    else
        ErrorException("In landscapes sum, an unhandeled error occured, throwing it") |>
        throw
    end
end


my_palette = PlotUtils.palette(:Paired_10, 10);
net_palette = PlotUtils.palette(:YlOrRd_9, 9);
net_palette2 = PlotUtils.palette(:Set1_9, 10);

plt_atributes = Dict(
    "art" => (m=:star6, c=my_palette[6]),
    "pseudoart" => (m=:star4, c=my_palette[9]),
    "Kandinsky" => (m=:pentagon, c=my_palette[2]),
    "textures" => (m=:utriangle, c=my_palette[10]),
    "Pollock" => (m=:diamond, c=net_palette2[1]),
    "Rothko" => (m=:star5, c=net_palette2[2]),
    "Mark" => (m=:xcross, c=net_palette2[1]),
    "Jarema" => (m=:star6, c=net_palette2[3]),
    "Malewicz" => (m=:star8, c=net_palette2[4]),
    "Richter" => (m=:dtriangle, c=net_palette2[4]),
    "all_pseudoart" => (m=:hexagon, c=my_palette[7]),
    "net0" => (m=:circle, c=net_palette[1]),
    "net1" => (m=:circle, c=net_palette[2]),
    "net2" => (m=:circle, c=net_palette[3]),
    "net3" => (m=:circle, c=net_palette[4]),
    "net4" => (m=:circle, c=net_palette[5]),
    "net5" => (m=:circle, c=net_palette[6]),
    "net6" => (m=:circle, c=net_palette2[7]),
    "net7" => (m=:circle, c=net_palette2[8]),
    "net8" => (m=:circle, c=net_palette2[end]),
)

function get_boxplots_and_violins_plot(
    data1,
    data2,
    f,
    fgl::GridLayout,
    all_datasets;
    leged_title="",
    ylabel="",
    plot_labels::Vector{String}=["", ""],
    y_low=0.0,
    y_high=2.0,
    selected_test::Function=MannWhitneyUTest,
)

    measure_vals_both = [data1, data2]
    color_palette = cgrad(:heat, 3, categorical=true)[2:end]
    color_values =
        reduce(vcat, [[color_palette[k] for _ in measure_vals_both[k]] for k = 1:2])

    categories = []
    color_indices = []
    for (k, vec) in measure_vals_both |> enumerate
        push!(categories, [k for v in vec])
        push!(color_indices, [color_values[k] for v in vec])
    end
    categories = vcat(categories...)
    color_indices = vcat(color_indices...)

    values = vcat(measure_vals_both...)
    bracket_y = 0.8 * y_high
    ax_boxplot =
        CairoMakie.Axis(fgl[1, 1], xtrimspine=true, ytrimspine=true, ylabel=ylabel)
    ax_estimate = CairoMakie.Axis(fgl[1, 2])

    hidexdecorations!(
        ax_boxplot,
        label=false,
        ticklabels=false,
        ticks=false,
        grid=true,
        minorgrid=true,
        minorticks=true,
    )

    for ax in [ax_boxplot]
        ax.rightspinevisible = false
        ax.topspinevisible = false
    end
    # ax_boxplot.leftspinevisible = false

    hidespines!(ax_estimate)
    hidedecorations!(ax_estimate)

    # ==
    CairoMakie.boxplot!(
        ax_boxplot,
        categories,
        values,
        whiskerwidth=0.5,
        strokecolor=:black,
        strokewidth=1,
        color=color_values,
    )

    violin_kwargs = (side=:right, strokecolor=:black, strokewidth=1)
    violin_alpha = 0.5
    for (k, values_vec) in enumerate(measure_vals_both)
        if length(measure_vals_both) > 2
            category_x_vals = [color_values[k] for m in values_vec]
        else
            category_x_vals = [1 for m in values_vec]
        end
        not_nan_positions2 = findall(x -> !isnan(x), values_vec)
        category_colour = [color_values[categories.==k]][1]
        if length(values_vec) > 0
            CairoMakie.violin!(
                ax_estimate,
                category_x_vals[not_nan_positions2],
                values_vec[not_nan_positions2];
                color=(category_colour[k], violin_alpha),
                violin_kwargs...,
            )
        end
    end

    elements = [PolyElement(polycolor=color_palette[i]) for i = 1:length(plot_labels)]

    fgl3 = GridLayout(f[2, :])
    fgl3_row_index = 1
    legend_title = leged_title

    i = 1
    l1 = Legend(
        fgl3[fgl3_row_index, i],
        elements[:, i],
        plot_labels,
        legend_title,
        tellwidth=false,
        nbanks=2,
        tellheight=true,
        framevisible=false,
    )
    ##
    fgl3_row_index += 1
    xtick_start = 1
    xtick_end = 2
    ax_boxplot.xticks = ([xtick_start, xtick_end], plot_labels)

    for ax in [ax_boxplot, ax_estimate]
        CairoMakie.ylims!(ax, low=y_low, high=y_high)
    end

    stat_test_result = selected_test(data1, data2)
    @info stat_test_result
    (p_marker, p_value_str) = if pvalue(stat_test_result) <= 0.05
        (p_marker, p_value_str) =
            if pvalue(stat_test_result) < 0.001
                ("***", "p<0.001")
            elseif pvalue(stat_test_result) < 0.01
                ("**", "p<0.01")
            elseif pvalue(stat_test_result) < 0.05
                ("*", "p<0.05")
            else
                "Adding star in distribution plot: This shouldn't have happened" |> ErrorException |> throw
            end#
        CairoMakie.bracket!(
            ax_boxplot,
            xtick_start,
            bracket_y,
            xtick_end,
            bracket_y,
            offset=0,
            text=p_marker,
            style=:square,
            fontsize=30,
            textoffset=-1,
        )
        (p_marker, p_value_str)
    else
        ("", "")
    end # p-plot

    p_value_truncated = if p_value_str == ""
        (@sprintf "%.3f" pvalue(stat_test_result))
    else
        p_value_str
    end
    description = "$(selected_test), p-value: " * p_value_truncated
    Label(fgl3[fgl3_row_index, :], description, tellwidth=false)
    fgl3_row_index += 1

    if length(all_datasets) > 2
        art_description =
            "Data in art:" * join([d for d in all_datasets if !occursin("pseudo", d)], " ")
        Label(fgl3[fgl3_row_index, :], art_description, tellwidth=false)
    end

    return f, l1, stat_test_result
end
