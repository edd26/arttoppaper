#=

Basic tests of the Ripsere library

=#

using DrWatson
@quickactivate "ArtTopology"
using Revise

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-

"17ih_quartiles_width_test_persistence_ECDF.jl" |> scriptsdir |> include

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
scriptprefix = "17iha"

# ===-===-===-===-
# quartiles_testing_df = DataFrame(
#     :data_name => [],
#     :subject => String[],
#     :session => Int[],
#     :view => Int[],
#     :img_name => String[],
#     :parameter => String[],
#     :window_size => Int[],
#     :quartile25 => Float64[],
#     :quartile50 => Float64[],
#     :quartile75 => Float64[],
# )

struct BoxData
    categories
    q_values

    function BoxData(df, session_index, view_index, q)
        session_df = @pipe filter(row -> row.session == session_index, df) |>
                           filter(row -> row.view == view_index, _)
        if q == 0.25
            q_vals = session_df[:, :quartile25]
        elseif q == 0.5
            q_vals = session_df[:, :quartile50]
        elseif q == 0.75
            q_vals = session_df[:, :quartile75]
        else
            "Unknown q value" |> ErrorException |> throw
        end
        categories = [100 * session_index + view_index for k in q_vals]
        new(categories, q_vals)
    end
end

b_plot_colours = cgrad(:bluesreds, 10, categorical=true)
c = [b_plot_colours[1], b_plot_colours[3], b_plot_colours[end], b_plot_colours[end-2]]
group_color = [PolyElement(color=color, strokecolor=:transparent) for color in c]

for func = parameters_vec[func_range]
    @info "Working on: $(func)"
    for window_size in window_sizes[windows_range]
        @info "\tWorking on: $(window_size)"
        for selected_data in [k for k in keys(unique_cycles_count_in_windows[window_size])]
            @info "\t\tWorking on: $(selected_data)"

            y_ticks = (1:4, ["S1v1", "S1v2", "S2v1", "S2v2"])
            total_images = 12
            single_height = 200
            single_width = 350
            f = Figure(size=(single_width * total_images, single_height * 3,))
            img_index = 1
            for (img_index, img_name) = enumerate([k for k in keys(unique_cycles_count_in_windows[window_size][selected_data])])
                @info "\t\t\tWorking on: $(img_name)"

                img_df = @pipe filter(row -> row.parameter == "$(func)", quartiles_testing_df) |>
                               filter(row -> row.window_size == window_size, _) |>
                               filter(row -> row.data_name == selected_data, _) |>
                               filter(row -> row.img_name == img_name, _)


                fgl = CairoMakie.GridLayout(f[1, img_index])
                ax_q075 = CairoMakie.Axis(fgl[1, 1], ylabel="Q. 0.75", title=img_name, yticks=y_ticks)
                ax_q050 = CairoMakie.Axis(fgl[2, 1], ylabel="Q. 0.50", yticks=y_ticks)
                ax_q025 = CairoMakie.Axis(fgl[3, 1], ylabel="Q. 0.25", yticks=y_ticks, xlabel="$(func)")

                ax_vec = [ax_q075, ax_q050, ax_q025]
                for ax in ax_vec
                    CairoMakie.xlims!(ax, low=0, high=155)
                end

                q025 = BoxData[]
                q050 = BoxData[]
                q075 = BoxData[]
                bplot_vec = []
                for (k, data_vec, ax) = zip([0.75, 0.50, 0.25], [q075, q050, q025], ax_vec)
                    for session_index = [1, 2], view_indicator = ["", "s2"]
                        if view_indicator == ""
                            view_index = 1
                        else
                            view_index = 2
                        end

                        push!(data_vec, BoxData(img_df, session_index, view_index, k))
                    end # session_index, view_indicator
                    categories_general = vcat([box_data.categories for box_data in data_vec]...)
                    categories = Int[]
                    all_colours = []
                    for k in categories_general
                        if k == 101
                            push!(categories, 1)
                            push!(all_colours, c[1])
                        elseif k == 102
                            push!(categories, 2)
                            push!(all_colours, c[2])
                        elseif k == 201
                            push!(categories, 3)
                            push!(all_colours, c[3])
                        elseif k == 202
                            push!(categories, 4)
                            push!(all_colours, c[4])
                        end
                    end

                    dodge = vcat(
                        [1 for k in categories_general if k < 200],
                        [2 for k in categories_general if k > 200],
                    )
                    values = vcat([box_data.q_values for box_data in data_vec]...)

                    data_label = "Session $(session_index), view $(view_index), quartile $(k)"
                    push!(
                        bplot_vec,
                        boxplot!(
                            ax,
                            categories,
                            values,
                            dodge=dodge,
                            show_notch=true,
                            color=all_colours,
                            label=data_label,
                            orientation=:horizontal,)
                    )
                end # data_vec, k, 
            end # img_nam
            leg = Legend(
                f[end+1, :],
                group_color,
                ["Session 1, view 1", "Session 1, view 2",
                    "Session 2, view 1", "Session 2, view 2",],
                "Sessions",
                tellheight=true,
                # tellwidth=true
            )
            leg.nbanks = 4
            f
            # Save image 
            total_subjects = length(subjects_name[selected_data])
            parameter = "$(func)"
            data_stuff = savename(@dict window_size total_subjects selected_data parameter)
            out_name = "$(scriptprefix)_values_at_quatiles_$(data_stuff )"
            image_export_dir(args...) = plotsdir("section17", "$(scriptprefix)-values_at_quartiles", "fixation_sequence=$(CONFIG.FIXATION_SEQUENCE)", args...)

            folder_name = "window=$(window_size)"

            final_name1 = image_export_dir(folder_name, out_name * ".png")
            safesave(final_name1, f)
        end # selected_data
    end # window_size
end # func




# ===-===-
do_nothing = "ok"
