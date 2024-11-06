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
scriptprefix = "17ih"

# ===-===-===-===-
quartiles_info_storage(args...) = datadir("exp_pro", "section17", "$(scriptprefix)-quartiles_info_storage", args...)

# ===-===-===-===-
selected_window = 51
homology_info = all_homology_info[selected_window]

# ===-===-
# parameters_vec = [persistence, birth, death]
total_subjects = length(subjects_name["art"])
windows = "windows_" * join(["$(k)" for k in window_sizes], "_")

selected_data = [l for l in keys(unique_cycles_count_in_windows[window_size])][1]
img_name = [l for l in keys(unique_cycles_count_in_windows[window_size][selected_data])][1]
func = parameters_vec[1]

quartiles_testing_df = DataFrame(
    :data_name => [],
    :subject => String[],
    :session => Int[],
    :view => Int[],
    :img_name => String[],
    :parameter => String[],
    :window_size => Int[],
    :quartile25 => Float64[],
    :quartile50 => Float64[],
    :quartile75 => Float64[],
)

for func = parameters_vec[func_range]
    @info "Working on: $(func)"
    for window_size in window_sizes[windows_range]
        @info "\tWorking on: $(window_size)"
        for selected_data in [k for k in keys(unique_cycles_count_in_windows[window_size])]
            @info "\t\tWorking on: $(selected_data)"

            et_df = dataset_df_dict[selected_data]
            for img_name = [k for k in keys(unique_cycles_count_in_windows[window_size][selected_data])]
                @info "\t\t\tWorking on: $(img_name)"

                img_cycles = cycles_on_image_canvas[window_size][selected_data][img_name]
                parameter_map, parameters_values = get_parameters_map(
                    func,
                    img_cycles,
                    window_size,
                    homology_info[selected_data][img_name]
                )
                parameters_values = Vector{Float64}(parameters_values)
                vec1 = parameters_values

                session_index = 1
                view_indicator = ""
                for session_index = [1, 2], view_indicator = ["", "s2"]
                    @info "\t\t\t\tWorking on session $(session_index) and view $(view_indicator)"

                    parameter = "$(func)"
                    session_df = filter(row -> row.Session == session_index, et_df)


                    # quartile_config  = @dict window_sizes unique_cycles_count_in_windows total_subjects subjects_name window_size func selected_data et_df img_name session_index view_indicator parameter
                    quartile_config = @dict window_sizes unique_cycles_count_in_windows total_subjects subjects_name window_size func selected_data session_df img_name session_index view_indicator parameter
                    quartiles_data, p = produce_or_load(
                        quartiles_info_storage(), # path
                        quartile_config, # config
                        prefix="p_value_df", # file prefix
                        force=false# force computations
                    ) do quartile_config
                        # do things
                        # @unpack window_sizes, unique_cycles_count_in_windows, total_subjects, windows, parameters_vec, dataset_df_dict = quartile_config
                        @unpack window_sizes, unique_cycles_count_in_windows, total_subjects, subjects_name, window_size, func, selected_data, session_df, img_name, session_index, view_indicator, parameter = quartile_config


                        quartiles_local_df = DataFrame(
                            :data_name => [],
                            :subject => String[],
                            :session => Int[],
                            :view => Int[],
                            :img_name => String[],
                            :parameter => String[],
                            :window_size => Int[],
                            :quartile25 => Float64[],
                            :quartile50 => Float64[],
                            :quartile75 => Float64[],
                        )

                        subject = subjects_name[selected_data][end-1]
                        for (k, subject) = subjects_name[selected_data] |> enumerate

                            img_number = get_img_number(selected_data, img_name)
                            subject_df = filter(row -> row.Subject == subject, session_df)
                            view_and_img_df = filter(row -> row.Stimulus == "$(img_number)$(view_indicator).jpg", subject_df)

                            if isempty(view_and_img_df.Stimulus)
                                @info "\t\t\t\t\tEmpty for subject $(subject)"
                                continue
                            else
                                @info "\t\t\t\t\tComputing $(func) for subject $(subject)"

                                subject_looking, mean_heatmap_in_window =
                                    get_heatmap_windows(
                                        view_and_img_df,
                                        window_size,
                                        SPACE_WIDTH,
                                        SPACE_HEIGHT,
                                        STARTING_POINT,
                                        VIEWING_WIDTH,
                                        IMG_HEIGHT,
                                        IMG_WIDTH
                                    )
                                windowed_heatmap_values = [v for (k, v) in mean_heatmap_in_window]
                                hist_weights = windowed_heatmap_values[subject_looking]

                                # vec2 = Float64[]
                                # for (weight, value) in zip(hist_weights, parameters_values[subject_looking])
                                #     for k in 1:ceil(weight)
                                #         push!(vec2, value)
                                #     end
                                # end

                                # # ===-
                                # total_sampels = length(vec2)
                                # sorted_vec2 = sort(vec2)
                                # quartile25 = sorted_vec2[(total_sampels÷4)*1]
                                # quartile50 = sorted_vec2[(total_sampels÷4)*2]
                                # quartile75 = sorted_vec2[(total_sampels÷4)*3]

                                # x_vals = 0:1:255
                                # ecdf_values = ecdf_sb.(x_vals)
                                sorted_subject_param_values = sort(parameters_values[subject_looking])

                                if isempty(hist_weights) || isempty(parameters_values[subject_looking])
                                    @info "Empty hist weights or parameters map where looked at"
                                    continue
                                end
                                ecdf_sb = ecdf(parameters_values[subject_looking]; weights=hist_weights)
                                sampled_ecdf = ecdf_sb.(sorted_subject_param_values)

                                min_025_index = findmin(abs.(sampled_ecdf .- 0.25))[2]
                                min_050_index = findmin(abs.(sampled_ecdf .- 0.50))[2]
                                min_075_index = findmin(abs.(sampled_ecdf .- 0.75))[2]


                                quartile25 = sorted_subject_param_values[min_025_index]
                                quartile50 = sorted_subject_param_values[min_050_index]
                                quartile75 = sorted_subject_param_values[min_075_index]

                                # ===-
                                if view_indicator == ""
                                    view_index = 1
                                else
                                    view_index = 2
                                end
                                push!(quartiles_local_df,
                                    (selected_data,
                                        subject,
                                        session_index,
                                        view_index,
                                        img_name,
                                        "$(func)",
                                        window_size,
                                        quartile25,
                                        quartile50,
                                        quartile75,
                                    )
                                )
                            end # if
                        end # subject
                        Dict("quartiles_results" => quartiles_local_df)
                    end # produce_or_load
                    quartiles_local_df = quartiles_data["quartiles_results"]
                    quartiles_testing_df = vcat(quartiles_testing_df, quartiles_local_df)
                end # session, view index
            end # img_nam
        end # selected_data
    end # window_size
end # func




# ===-===-
do_nothing = "ok"
