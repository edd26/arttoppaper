#=

Basic tests of the Ripsere library

=#

using DrWatson
@quickactivate "ArtTopology"

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
"17i_cycles_in_unit_coverage.jl" |> scriptsdir |> include

using HypothesisTests
using StatsBase: ecdf
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
scriptprefix = "17ijb"
pvalues_info_storage(args...) = datadir("exp_pro", "section17", "$(scriptprefix)-p_value_all_heatmap_computations", "fixation_sequence=$(CONFIG.FIXATION_SEQUENCE)", args...)

# ===-===-===-===-===-===-===-===-===-===-===-===-
selected_window = 51
homology_info = all_homology_info[selected_window]


# What do we want to plot? Heatmap, windowed heatmap, cycles count in windows,
# Distribution of cycles counts, subsample of Distribution counts, weighted Distribution
# keep the number of bins the same
# subjects_colours = cgrad(
#     :reds,
#     max(length(subjects_name["art"]), length(subjects_name["fake"])),
#     categorical=true,
#     rev=true
# )

# single_height = 400
# single_width = 300

selected_data = [l for l in keys(unique_cycles_count_in_windows[window_size])][2]
img_name = [l for l in keys(unique_cycles_count_in_windows[window_size][selected_data])][1]

window_size = 51

ECDF_img_avg_heatmap_df = DataFrame(
    :data_name => [],
    :session => Int[],
    :view => Int[],
    :img_name => String[],
    :KS_test => Float64[],
    :parameter => String[],
    :window_size => Int[],
    :ECDF_imgae => [],
    :ECDF_view => [],
)

total_sessions = 2
total_views = 2

# for func = [persistence, birth]
for func = [persistence,]
    parameter = "$(func)"
    for selected_data in [k for k in keys(unique_cycles_count_in_windows[window_size])]
        @info "\t\tWorking on: $(selected_data)"

        et_df = dataset_df_dict[selected_data]
        for img_name = [k for k in keys(unique_cycles_count_in_windows[window_size][selected_data])][1:total_images]
            @info "\t\t\tWorking on: $(img_name)"

            img_cycles = cycles_on_image_canvas[window_size][selected_data][img_name]
            parameter_map, parameters_values = get_parameters_map(
                func,
                img_cycles,
                window_size,
                homology_info[selected_data][img_name]
            )
            vec1 = Vector{Float64}(parameters_values)
            ecdf_img = ecdf(vec1)


            session_index = 1
            view_indicator = ""

            for session_index = [1, 2][1:total_sessions], (view_index, view_indicator) = ["", "s2"][1:total_views] |> enumerate
                @info "\t\t\t\tWorking on session $(session_index) and view $(view_indicator)"

                total_subjects = et_df.Subject |> unique |> length
                parameter = "$(func)"
                pvalue_config = @dict window_sizes unique_cycles_count_in_windows total_subjects window_size func selected_data et_df img_name session_index view_indicator parameter
                ECDF_results, p = produce_or_load(
                    pvalues_info_storage("split"), # path
                    pvalue_config, # config
                    prefix="p_value_df", # file prefix
                    force=false# force computations
                ) do pvalue_config
                    # do things
                    @unpack window_sizes, unique_cycles_count_in_windows, total_subjects, window_size, func, selected_data, et_df, img_name, session_index, view_indicator, parameter = pvalue_config

                    session_df = filter(row -> row.Session == session_index, et_df)

                    ECDF_img_avg_heatmap_local_df = DataFrame(
                        :data_name => [],
                        :session => Int[],
                        :view => Int[],
                        :img_name => String[],
                        :KS_test => [],
                        :parameter => String[],
                        :window_size => Int[],
                        :ECDF_imgae => [],
                        :ECDF_view => [],
                    )

                    session_df = filter(row -> row.Session == session_index, et_df)

                    img_number = get_img_number(selected_data, img_name)
                    view_and_img_df = filter(row -> row.Stimulus == "$(img_number)$(view_indicator).jpg", session_df)

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


                    ecdf_viewing = ecdf(Vector{Float64}(parameters_values[subject_looking]); weights=hist_weights)
                    vec2 = Float64[]
                    for (weight, value) in zip(hist_weights, parameters_values[subject_looking])
                        for k in 1:ceil(weight)
                            push!(vec2, value)
                        end
                    end

                    # ===-
                    KS_test_results = ApproximateTwoSampleKSTest(vec1, vec2)
                    if view_indicator == ""
                        view_index = 1
                    else
                        view_index = 2
                    end
                    push!(ECDF_img_avg_heatmap_local_df,
                        (selected_data,
                            session_index,
                            view_index,
                            img_name,
                            KS_test_results,
                            "$(func)",
                            window_size,
                            ecdf_img,
                            ecdf_viewing
                        )
                    )

                    ECDF_results = Dict("pvalue_results" => ECDF_img_avg_heatmap_local_df)
                end # produce_or_load
                ECDF_img_avg_heatmap_local_df = ECDF_results["pvalue_results"]
                global ECDF_img_avg_heatmap_df = vcat(ECDF_img_avg_heatmap_df, ECDF_img_avg_heatmap_local_df)
            end # session, view
        end# img_nam
    end # selected_data
    #     end # window_size
end # func
# ===-===-
do_nothing = "ok"
