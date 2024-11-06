using DrWatson
@quickactivate "ArtTopology"

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
"17jg3_ECDF_generation_not_looking.jl" |> scriptsdir |> include

import .CONFIG: art_images_names, names_to_order, fake_images_names
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
scriptprefix = "17jg2g"

selected_data = dataset_names[2]
func = parameters_vec[1]

color_palette = Makie.wong_colors();
art_color = color_palette[3];
fake_color = color_palette[6];

art_colours = cgrad([
        RGB([98, 197, 84] / 255...),
        RGB([91, 121, 177] / 255...),
        :purple], 12, categorical=true)[1:12]
fake_colours = cgrad([
        RGB([150, 49, 49] / 255...),
        RGB([224, 154, 58] / 255...),
        :yellow
    ], 12, categorical=true, rev=true)[1:12]

# ===-===-
for func = parameters_vec[func_range]
    @info "\tWorking on: $(func)"
    func_parameters_df = filter(row -> row.parameter == "$(func)", parameters_df |> unique)

    test_pvalues = fill(0.0, 24, 24)
    for (row, df1) in enumerate(eachrow(func_parameters_df))
        for (col, df2) in enumerate(eachrow(func_parameters_df))
            test_outcome = ApproximateTwoSampleKSTest(df1.parameters_values, df2.parameters_values)

            test_pvalues[row, col] = test_pvalues[col, row] = pvalue(test_outcome)
        end
    end
end # func



# ===-===-
art_images_numbers = [split(n, "_$(CONFIG.DATA_CONFIG).jpg")[1] for n in filter(row -> row.data_name == "art", parameters_df)[:, :img_name] |> unique]
fake_images_numbers = [split(n, "_$(CONFIG.DATA_CONFIG).jpg")[1] for n in filter(row -> row.data_name == "fake", parameters_df)[:, :img_name] |> unique]

art_ordering = [parse(Int, just_name) for just_name in art_images_numbers] |> sortperm
fake_ordering = [names_to_order[just_name] for just_name in fake_images_numbers] |> sortperm

art_names = [art_images_names[parse(Int, just_name)] for just_name in art_images_numbers][art_ordering]
fake_names = [@pipe names_to_order[just_name] |> fake_images_names[_] for just_name in fake_images_numbers][fake_ordering]

target_len = 15
short_names_art = String[]
short_names_fake = String[]
for (k, n) in art_names |> enumerate
    short_name = "$(k). " * create_short_name(n, target_len)
    push!(short_names_fake, short_name)
end
for (k, n) in fake_names |> enumerate
    short_name = "$(k). " * create_short_name(n, target_len)
    push!(short_names_fake, short_name)
end

# ===-===-
x_lims = Dict(
    "density_scaled" => (-0.002, 0.060),
    "persistence" => (0, 260),
    "max_persistence" => (0, 260),
    "cycles_perimeter" => (0, 120000),
)

func = density_scaled
for func = parameters_vec[func_range]
    @info "\tWorking on: $(func)"
    func_parameters_df = filter(row -> row.parameter == "$(func)", parameters_df |> unique)


    ecdf_vals = 0:0.0001:256
    results = Dict()
    for df = eachrow(func_parameters_df)
        params = df.parameters_values
        param_ecdf = ecdf(params) |> (y -> y(ecdf_vals))
        min_in_ecdf = findmin(abs.(param_ecdf .- 0.75))[2]
        @info "$(df.img_name) -> $(ecdf_vals[min_in_ecdf])"
        results["$(df.img_name)"] = ecdf_vals[min_in_ecdf]
    end
    resutls = sort(results, byvalue=true)

    if func == persistence
        x_label = "Persistence"
    elseif func == max_persistence
        x_label = "Max. Persistence"
    elseif func == density_scaled || func == "density"
        x_label = "Cycles Density"
    elseif func == cycles_perimeter
        x_label = "Cycles Perimeter"
    else
        ErrorException("Unknown function") |> throw
    end
    y_label = "Proportion of total windows"

    plt_width = 800
    plt_height = 300
    f = CairoMakie.Figure(; size=(plt_width - 100, plt_height + 100))
    fgl = CairoMakie.GridLayout(f[1, 1])
    f2 = CairoMakie.Figure(; size=(plt_width, plt_height))
    fgl2 = CairoMakie.GridLayout(f2[1, 1])
    scaling_factor = 1.8
    f3 = CairoMakie.Figure(; size=(plt_width, plt_height * scaling_factor))
    fgl3 = CairoMakie.GridLayout(f3[1, 1])
    f4 = CairoMakie.Figure(; size=(plt_width, plt_height * scaling_factor))
    fgl4 = CairoMakie.GridLayout(f4[1, 1])

    ax_ecdf = CairoMakie.Axis(
        fgl[1, 1],
        xlabel=x_label,
        ylabel=y_label,
        title="",
        # xlims=(0, 20)
    )
    ax_ecdf_art = CairoMakie.Axis(
        fgl2[1, 1],
        xlabel=x_label,
        ylabel=y_label,
        title="Art"
    )
    ax_ecdf_fake = CairoMakie.Axis(
        fgl2[1, 2],
        xlabel=x_label,
        ylabel=y_label,
        title="Pseudo-art"
    )
    ax_ecdf_art2 = CairoMakie.Axis(
        fgl3[1, 1],
        xlabel=x_label,
        ylabel=y_label,
        title="Art"
    )
    ax_ecdf_fake2 = CairoMakie.Axis(
        fgl3[1, 2],
        xlabel=x_label,
        ylabel=y_label,
        title="Pseudo-art"
    )
    ax_ecdf2 = CairoMakie.Axis(
        fgl4[1, 1],
        xlabel=x_label,
        ylabel=y_label,
        title="",
    )
    for ax in [ax_ecdf_art, ax_ecdf_fake, ax_ecdf_art2, ax_ecdf_fake2]
        CairoMakie.xlims!(ax, x_lims["$(func)"]...)
    end

    for selected_data in [k for k in keys(unique_cycles_count_in_windows["BW"][window_size])]
        @info "\t\tworking on: $(selected_data)"
        data_parameters_df = filter(row -> row.data_name == selected_data, func_parameters_df)

        if selected_data == "art"
            c = art_color
            ax = ax_ecdf_art
            ax2 = ax_ecdf_art2
            selected_colour = art_colours
            ordering = art_ordering
        else
            c = fake_color
            ax = ax_ecdf_fake
            ax2 = ax_ecdf_fake2
            selected_colour = fake_colours
            ordering = fake_ordering
        end

        img_list = data_parameters_df.img_name |> unique
        img_index = 1
        img_name = img_list[img_index]
        for (img_index, img_name) = enumerate(img_list[ordering])
            @info "\t\t\tworking on: $(img_name)"
            img_parameters_df = filter(row -> row.img_name == img_name, data_parameters_df)

            CairoMakie.ecdfplot!(
                ax_ecdf,
                img_parameters_df.parameters_values[1],
                color=c
            )
            CairoMakie.ecdfplot!(
                ax,
                img_parameters_df.parameters_values[1],
                color=c
            )
            CairoMakie.ecdfplot!(
                ax2,
                img_parameters_df.parameters_values[1],
                color=selected_colour[img_index]
            )
            CairoMakie.ecdfplot!(
                ax_ecdf2,
                img_parameters_df.parameters_values[1],
                color=selected_colour[img_index]
            )

        end# img_nam
    end # selected_data

    colours = [:red, :blue]
    group_color = [PolyElement(color=color, strokecolor=:transparent)
                   for color in [art_color, fake_color]]

    Legend(fgl[2, 1],
        group_color,
        ["Art", "Pseudo-art"],
        tellheight=true,
        tellwidth=false,
        nbanks=2,
        framevisible=false,
        halign=:left
    )

    # ===-===-
    # Legend
    markers_for_legend1 = [
        PolyElement(
            color=c,
            strokecolor=:black
        )
        for c in art_colours
    ]

    markers_for_legend2 = [
        PolyElement(color=c,
            strokecolor=:black
        )
        for c in fake_colours
    ]

    # ---==---==---==

    Legend(fgl3[2, :],
        [markers_for_legend1, markers_for_legend2],
        [short_names_art, short_names_fake,],
        ["Art", "Pseudo-art",],
        tellheight=true,
        nbanks=4,
        framevisible=false
    )
    Legend(fgl4[2, :],
        [markers_for_legend1, markers_for_legend2],
        [short_names_art, short_names_fake,],
        ["Art", "Pseudo-art",],
        tellheight=true,
        nbanks=4,
        framevisible=false
    )
    rowgap!(fgl, -10)
    CairoMakie.ylims!(ax_ecdf, low=0)
    if func == cycles_perimeter
        ax_ecdf_art2.xtickformat = "{:0.0e}"
        ax_ecdf_fake2.xtickformat = "{:0.0e}"
    end

    f
    f2
    f3
    f4

    # Save image 
    parameter = "$(func)"
    data_stuff = savename(@dict window_size selected_data parameter)
    # data_stuff = replace(data_stuff, ".jpg" => "")
    out_name = "$(scriptprefix)_image_ECDF_BW+WB_$(data_stuff )"
    image_export_dir(args...) = plotsdir("section17", "$(scriptprefix)-image_ECDF", "BW+WB", args...)

    folders_args = join(["window=$(window_size)", "$(func)",], "_")

    for (ver, ff) in enumerate([f, f2, f3, f4])
        suffix_ = "_ver$(ver)"
        final_name3 = image_export_dir(folders_args, out_name * "$(suffix_).png")
        safesave(final_name3, ff)
        final_name4 = image_export_dir(folders_args, "pdf", out_name * "$(suffix_).pdf")
        safesave(final_name4, ff)
    end
end # func
# end # deata_type


# ===-===-
do_nothing = "ok"
