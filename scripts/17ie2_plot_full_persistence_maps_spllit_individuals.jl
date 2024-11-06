using DrWatson
@quickactivate "ArtTopology"

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-

"17i_cycles_in_unit_coverage.jl" |> scriptsdir |> include

import .CONFIG: DATA_CONFIG
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
scriptprefix = "17ie2"

# ===-===-===-===-
selected_window = 51
homology_info = all_homology_info[selected_window]
perimeter_info = all_perimeter_info[selected_window]

func = parameters_vec[1]
window_size = window_sizes[1]
selected_data = "art"
img_name = [k for k in keys(unique_cycles_count_in_windows[window_size][selected_data])][1]
session_index = 1

func = parameters_vec[2]
d = ["art", "fake"][1]
session_index = 1

# ===-===-===-===-
single_height = 400
single_width = 300
subjects_colours = cgrad(
    :reds,
    max(length(subjects_name["art"]), length(subjects_name["fake"])),
    categorical=true,
    rev=true
);

selected_data = [l for l in keys(unique_cycles_count_in_windows[window_size])][2]
img_name = [l for l in keys(unique_cycles_count_in_windows[window_size][selected_data])][1]

window_sizes_range = 1:1
for func = parameters_vec[1:2:3]
    @info "Working on: $(func)"
    # func_related_df = filter(row -> row.parameter == "$(func)", ECDF_rmse_df)

    if func == persistence
        ecdf_range = 0:256
    elseif func == density_scaled
        ecdf_range = 0:0.0001:0.1
    else
        ecdf_range = 0:0.001:256
    end
    @info "Working on: $(func)"

    for window_size in window_sizes[window_sizes_range]
        @info "\tWorking on: $(window_size)"

        for selected_data in [k for k in keys(unique_cycles_count_in_windows[window_size])]
            @info "\t\tWorking on: $(selected_data)"
            et_df = dataset_df_dict[selected_data]

            for img_name = keys(unique_cycles_count_in_windows[window_size][selected_data])
                @info "\t\t\tWorking on: $(img_name)"

                # ===-
                subject = subjects_name[selected_data][1]
                session_index = 1
                view_indicator = ""
                @info ""
                for (k, subject) = subjects_name[selected_data] |> enumerate
                    f = Figure(size=(single_width * 3, single_height * 3,))
                    fgl = GridLayout(f[1, 1])
                    ax_heatmap = CairoMakie.Axis(fgl[1, 1], title="Heatmap")
                    ax_heatmap_grid = CairoMakie.Axis(fgl[1, 2], title="Heatmap in grid")
                    ax_cycles_count_grid = CairoMakie.Axis(fgl[1, 3], title="$(func) in grid")
                    ax_hist_cycles_count = CairoMakie.Axis(fgl[2, 1], title="Histogram of mean $(func)s")
                    ax_hist_subject_subsample = CairoMakie.Axis(fgl[2, 2], title="Subject subsample of histogram")
                    ax_weighted_hist = CairoMakie.Axis(fgl[2, 3], title="Heatmap weighted subject subsample of histogram")
                    ax_ecdf = CairoMakie.Axis(fgl[3, :], title="ECDF")

                    # ===-
                    img_cycles = cycles_on_image_canvas[window_size][selected_data][img_name]
                    parameter_map, parameters_values = get_parameters_map(
                        func,
                        img_cycles,
                        window_size,
                        homology_info[selected_data][img_name],
                        perimeter_info[selected_data][img_name];
                    )
                    parameter_map_for_plot = Matrix(parameter_map')[:, end:-1:1]

                    # ===-
                    hist!(ax_hist_cycles_count, parameters_values, bins=total_bins)
                    heatmap!(ax_cycles_count_grid, parameter_map_for_plot)
                    ecdfplot!(ax_ecdf, Vector{Float64}(parameters_values), color=:blue, label=img_name)


                    subject_df = filter(row -> row.Subject == subject, et_df)
                    session_df = filter(row -> row.Session == session_index, subject_df)


                    img_number = get_img_number(selected_data, img_name; data_config=DATA_CONFIG)
                    view_and_img_df = filter(row -> row.Stimulus == "$(img_number)$(view_indicator).jpg", session_df)

                    if isempty(view_and_img_df.Stimulus)
                        # @info subject
                        @info "\t\t\t\tEmpty for subject $(subject)"
                        continue
                    else
                        @info "\t\t\t\tComputing $(func) for subject $(subject)"
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
                            Vector{Float64}(parameters_values[subject_looking]),
                            weights=ceil.(Int, hist_weights),
                            color=subjects_colours[k],
                            label=subject
                        )

                        hidedecorations!(ax_heatmap)
                        hidedecorations!(ax_heatmap_grid)
                        hidedecorations!(ax_cycles_count_grid)
                    end #if empty

                    f
                    # ===-===-===-
                    # Save image 
                    total_subjects = length(subjects_name[selected_data])
                    img = replace(img_name, ".jpg" => "")
                    data_stuff = savename(@dict img selected_data window_size total_subjects)
                    out_name = "$(scriptprefix)_full_histogram_story_$(func)_$(data_stuff )_$(subject)"
                    image_export_dir(args...) = plotsdir("section17", "$(scriptprefix)-topology_param_heatmap_histogram_ecdf_split_individuals", "$(DATA_CONFIG)", "fixation_sequence=$(CONFIG.FIXATION_SEQUENCE)", args...)

                    func_folder = "$(func)"
                    folder_name = selected_data

                    final_name1 = image_export_dir(func_folder, folder_name, "window=$(window_size)_total_subjects=$(total_subjects)", "$(img)", out_name * ".png")
                    safesave(final_name1, f)
                end

                # final_name_pdf = image_export_dir(func_folder, folder_name, "window=$(window_size)_total_subjects=$(total_subjects)", "pdf", out_name * ".pdf")
                # safesave(final_name_pdf, f)
                # f
            end# img_nam
        end # selected_data
    end # window_size
end # func

# ===-===-
do_nothing = "ok"
