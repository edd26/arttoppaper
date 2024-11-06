using DrWatson
@quickactivate "ArtTopology"

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-

"17i_cycles_in_unit_coverage.jl" |> scriptsdir |> include

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
scriptprefix = "17id"

# ===-===-===-===-
selected_window = 51
homology_info = all_homology_info[selected_window]

# ===-===-===-===-
single_height = 400
single_width = 300
subjects_colours = cgrad(
    :reds,
    max(length(subjects_name["art"]), length(subjects_name["fake"])),
    categorical=true,
    rev=true
)

selected_data = [l for l in keys(unique_cycles_count_in_windows[window_size])][2]
img_name = [l for l in keys(unique_cycles_count_in_windows[window_size][selected_data])][1]



for window_size in keys(all_homology_info)
    @info "\tWorking on: $(window_size)"

    for selected_data in [k for k in keys(unique_cycles_count_in_windows[window_size])]
        @info "\t\tWorking on: $(selected_data)"
        et_df = dataset_df_dict[selected_data]

        for img_name = keys(unique_cycles_count_in_windows[window_size][selected_data])
            @info "\t\t\tWorking on: $(img_name)"

            f = Figure(size=(single_width * 3, single_height * 3,))
            fgl = GridLayout(f[1, 1])
            ax_heatmap = CairoMakie.Axis(fgl[1, 1], title="Heatmap")
            ax_heatmap_grid = CairoMakie.Axis(fgl[1, 2], title="Heatmap in grid")
            ax_cycles_count_grid = CairoMakie.Axis(fgl[1, 3], title="Cycles count in map")
            ax_hist_cycles_count = CairoMakie.Axis(fgl[2, 1], title="Histogram of cycles count")
            ax_hist_subject_subsample = CairoMakie.Axis(fgl[2, 2], title="Subject subsample of histogram")
            ax_weighted_hist = CairoMakie.Axis(fgl[2, 3], title="Heatmap weighted subject subsample of histogram")
            ax_ecdf = CairoMakie.Axis(fgl[3, :], title="ECDF")

            # ===-
            img_cycles = cycles_on_image_canvas[window_size][selected_data][img_name]
            parameter_map, parameters_values = density(img_cycles, window_size)
            parameter_map_for_plot = Matrix(parameter_map')[:, end:-1:1]

            # ===-
            hist!(ax_hist_cycles_count, parameters_values, bins=total_bins)
            heatmap!(ax_cycles_count_grid, parameter_map_for_plot)
            ecdfplot!(ax_ecdf, parameters_values, color=:blue, label=img_name)

            # ===-
            subject = subjects_name[selected_data][1]
            session_index = 1
            view_indicator = ""
            @info ""
            for (k, subject) = subjects_name[selected_data] |> enumerate

                subject_df = filter(row -> row.Subject == subject, et_df)
                session_df = filter(row -> row.Session == session_index, subject_df)


                img_number = get_img_number(selected_data, img_name)
                view_and_img_df = filter(row -> row.Stimulus == "$(img_number)$(view_indicator).jpg", session_df)

                if isempty(view_and_img_df.Stimulus)
                    @info "\t\t\t\tEmpty for subject $(subject)"
                    continue
                else
                    @info "\t\t\t\tComputing for subject $(subject)"
                    heatmap_from_image_area = get_heatmap_py(view_and_img_df, SPACE_WIDTH, SPACE_HEIGHT) |>
                                              (y -> y[:, STARTING_POINT:(STARTING_POINT+VIEWING_WIDTH)])
                    max_in_area = max([x for x in heatmap_from_image_area if !isnan(x)]...)
                    heatmap_image = imresize(
                                        Gray.(heatmap_from_image_area ./ max_in_area),
                                        (IMG_HEIGHT, IMG_WIDTH)
                                    ) |>
                                    Matrix{Float64} .|>
                                    (y -> y * max_in_area)
                    heatmap_image_plt_adjusted = Matrix(heatmap_image')[:, end:-1:1]

                    mean_heatmap_in_window = mean_heatmap_in_windows(heatmap_image, window_size,)
                    total_grid_rows = max([k[1] for (k, v) in mean_heatmap_in_window]...)
                    total_grid_cols = max([k[2] for (k, v) in mean_heatmap_in_window]...)
                    grid_heatmap = fill(NaN, total_grid_rows, total_grid_cols)
                    for (k, v) in mean_heatmap_in_window
                        if v != 0
                            grid_heatmap[k[1], k[2]] = v
                        end
                    end
                    grid_heatmap_plt_adjusted = Matrix(grid_heatmap')[:, end:-1:1]

                    windowed_heatmap_values = [v for (k, v) in mean_heatmap_in_window]
                    subject_looking = findall(x -> x != 0, windowed_heatmap_values)
                    hist_weights = windowed_heatmap_values[subject_looking]

                    heatmap!(ax_heatmap, heatmap_image_plt_adjusted, alpha=0.4)
                    heatmap!(ax_heatmap_grid, grid_heatmap_plt_adjusted, alpha=0.4)
                    hist!(ax_hist_subject_subsample, parameters_values[subject_looking], bins=total_bins)
                    hist!(ax_weighted_hist, parameters_values[subject_looking], weights=hist_weights, bins=total_bins)


                    ecdfplot!(
                        ax_ecdf,
                        parameters_values[subject_looking],
                        weights=ceil.(Int, hist_weights),
                        color=subjects_colours[k],
                        label=subject
                    )
                end #if empty
            end
            axislegend(ax_ecdf, position=:rb, nbanks=8)

            f
            # ===-===-===-
            # Save image 
            total_subjects = length(subjects_name[selected_data])
            img = replace(img_name, ".jpg" => "")
            data_stuff = savename(@dict img selected_data window_size total_subjects)
            out_name = "$(scriptprefix)_full_histogram_story_$(data_stuff )"
            image_export_dir(args...) = plotsdir("section17", "$(scriptprefix)-density_heatmap_histogram_ecdf_individuals", "fixation_sequence=$(CONFIG.FIXATION_SEQUENCE)", args...)

            folder_name = selected_data

            final_name1 = image_export_dir(folder_name, "window=$(window_size)_total_subjects=$(total_subjects)", out_name * ".png")
            safesave(final_name1, f)

            # final_name_pdf = image_export_dir(folder_name, "window=$(window_size)_total_subjects=$(total_subjects)", "pdf", out_name * ".pdf")
            # safesave(final_name_pdf, f)
            # f
        end# img_nam
    end # selected_data
end # window_size
# ===-===-
do_nothing = "ok"
