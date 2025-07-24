
using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-

"17i_cycles_in_unit_coverage.jl" |> scriptsdir |> include

using HypothesisTests
using StatsBase: ecdf
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
scriptprefix = "17ig2"

# ===-===-===-===-
pvalues_info_storage(args...) = datadir(
    "exp_pro",
    "section17",
    "$(scriptprefix)-rmse",
    "fixation_sequence=$(CONFIG.FIXATION_SEQUENCE)",
    args...,
)

# ===-===-===-===-
selected_window = 51
homology_info = all_homology_info[selected_window]
perimeter_info = all_perimeter_info[selected_window]

# ===-===-
total_subjects = length(subjects_name["art"])
windows = "windows_" * join(["$(k)" for k in window_sizes], "_")

selected_data = [l for l in keys(unique_cycles_count_in_windows[window_size])][2]
img_name = [l for l in keys(unique_cycles_count_in_windows[window_size][selected_data])][5]
func = parameters_vec[1]

force_computaions = false
parameters_df = DataFrame(
    :data_name => String[],
    :img_name => String[],
    :parameter => String[],
    :window_size => Int[],
    :parameters_values => Vector{Float64}[],
    :parameter_map => Matrix{Float64}[],
)

ECDF_rmse_df = DataFrame(
    :data_name => [],
    :subject => String[],
    :session => Int[],
    :view => Union{Symbol,Int}[],
    :img_name => String[],
    :parameter => String[],
    :window_size => Int[],
    :KS_statistic => [],
    :ECDF_image => [],
    :ECDF_view => [],
    :subject_looking => [],
    :mean_heatmap_in_window => [],
)

for func in parameters_vec[func_range]
    @info "Working on: $(func)"

    for window_size in window_sizes[windows_range]
        @info "\tWorking on: $(window_size)"
        # selected_data = [k for k in keys(unique_cycles_count_in_windows[window_size])][1]
        for selected_data in [k for k in keys(unique_cycles_count_in_windows[window_size])]
            @info "\t\tWorking on: $(selected_data)"

            et_df = dataset_df_dict[selected_data]
            for img_name in [
                k for k in keys(unique_cycles_count_in_windows[window_size][selected_data])
            ]
                @info "\t\t\tWorking on: $(img_name)"

                img_cycles = cycles_on_image_canvas[window_size][selected_data][img_name]

                parameter_map, parameters_values = get_parameters_map(
                    func,
                    img_cycles,
                    window_size,
                    homology_info[selected_data][img_name],
                    perimeter_info[selected_data][img_name];
                    default_map_value = default_map_value,
                )
                if typeof(parameters_values) != Vector{Float64}
                    parameters_values = Vector{Float64}(parameters_values)
                end

                push!(
                    parameters_df,
                    (
                        selected_data,
                        img_name,
                        "$(func)",
                        window_size,
                        parameters_values,
                        parameter_map,
                    ),
                )
                vec1 = parameters_values
                ecdf_img = ecdf(vec1)

                # session_index = 1
                # view_indicator = :both
                # for session_index = [1, 2], view_indicator = ["", "s2"]
                # @info "\t\t\t\tWorking on session $(session_index) and view $(view_indicator)"
                for session_index = 1:total_sessions,
                    (view_index, view_indicator) in enumerate(view_range)

                    @info "\t\t\t\tWorking on session $(session_index) "

                    parameter = "$(func)"
                    # pvalue_config = @dict window_sizes unique_cycles_count_in_windows total_subjects subjects_name window_size func selected_data session_df img_name session_index view_indicator
                    # pvalue_config = @dict window_sizes unique_cycles_count_in_windows total_subjects subjects_name window_size func selected_data session_df img_name session_index view_indicator parameter
                    pvalue_config =
                        @dict window_sizes unique_cycles_count_in_windows total_subjects subjects_name window_size func selected_data et_df img_name session_index parameter view_indicator
                    if !isnan(default_map_value)
                        pvalue_config[:default_map_value] = default_map_value
                    end
                    ECDF_rmse_data, p = produce_or_load(
                        pvalues_info_storage(
                            "$(func)_sesion$(session_index)_view$(view_index)",
                        ), # path
                        pvalue_config, # config
                        prefix = "p_value_df", # file prefix
                        # force=true # force computations
                    ) do pvalue_config
                        # do things
                        # @unpack window_sizes, unique_cycles_count_in_windows, total_subjects, subjects_name, window_size, func, selected_data, session_df, img_name, session_index, view_indicator = pvalue_config
                        # @unpack window_sizes, unique_cycles_count_in_windows, total_subjects, subjects_name, window_size, func, selected_data, session_df, img_name, session_index, view_indicator, parameter = pvalue_config
                        @unpack window_sizes,
                        unique_cycles_count_in_windows,
                        total_subjects,
                        subjects_name,
                        window_size,
                        func,
                        selected_data,
                        et_df,
                        img_name,
                        session_index,
                        parameter = pvalue_config

                        session_df = filter(row -> row.Session == session_index, et_df)

                        ECDF_rmse_local_df = DataFrame(
                            :data_name => [],
                            :subject => String[],
                            :session => Int[],
                            :view => Union{Symbol,Int}[],
                            :img_name => String[],
                            :parameter => String[],
                            :window_size => Int[],
                            :KS_statistic => [],
                            :ECDF_image => [],
                            :ECDF_view => [],
                            :subject_looking => [],
                            :mean_heatmap_in_window => [],
                        )

                        subject = subjects_name[selected_data][end-1]
                        img_number = get_img_number(
                            selected_data,
                            img_name;
                            data_config = CONFIG.DATA_CONFIG,
                        )
                        for (k, subject) in subjects_name[selected_data] |> enumerate

                            subject_df = filter(row -> row.Subject == subject, session_df)
                            view_and_img_df = DataFrame()
                            if view_indicator == :both
                                view_and_img_df = filter(
                                    row ->
                                        row.Stimulus == "$(img_number)s2.jpg" ||
                                        row.Stimulus == "$(img_number).jpg",
                                    subject_df,
                                )
                            else
                                view_and_img_df = filter(
                                    row ->
                                        row.Stimulus ==
                                        "$(img_number)$(view_indicator).jpg",
                                    subject_df,
                                )
                            end
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
                                        IMG_WIDTH,
                                    )
                                windowed_heatmap_values =
                                    [v for (k, v) in mean_heatmap_in_window]
                                hist_weights = windowed_heatmap_values[subject_looking]

                                vec2 = Float64[]
                                for (weight, value) in zip(
                                    hist_weights,
                                    parameters_values[subject_looking],
                                )
                                    for k = 1:ceil(weight)
                                        push!(vec2, value)
                                    end
                                end

                                # ===-
                                ecdf_viewing = ecdf(
                                    Vector{Float64}(parameters_values[subject_looking]);
                                    weights = hist_weights,
                                )
                                # ===-
                                KS_test_results = ApproximateTwoSampleKSTest(vec1, vec2)

                                if view_indicator == ""
                                    view_index = 1
                                elseif view_indicator == "s2"
                                    view_index = 2
                                else
                                    view_index = :both
                                end

                                push!(
                                    ECDF_rmse_local_df,
                                    (
                                        selected_data,
                                        subject,
                                        session_index,
                                        view_index,
                                        img_name,
                                        "$(func)",
                                        window_size,
                                        KS_test_results,
                                        ecdf_img,
                                        ecdf_viewing,
                                        subject_looking,
                                        mean_heatmap_in_window,
                                    ),
                                )
                            end # if
                        end # subject
                        Dict("ECDF_rmse_results" => ECDF_rmse_local_df)
                    end # produce_or_load
                    ECDF_rmse_local_df = ECDF_rmse_data["ECDF_rmse_results"]
                    global ECDF_rmse_df = vcat(ECDF_rmse_df, ECDF_rmse_local_df)
                end # session, view index
            end # img_nam
        end # selected_data
    end # window_size
end # func

ECDF_mse_data_df = DataFrame(
    :data_name => [],
    :subject => String[],
    :session => Int[],
    :view => Union{Symbol,Int}[],
    :img_name => String[],
    :parameter => String[],
    :window_size => Int[],
    :ECDF_mse => Float64[],
    :ECDF_error => Float64[],
    :KS_statistic => Float64[],
    :ECDF_05 => Float64[],
    :ECDF_075 => Float64[],
)
ECDF_looking_size_df = DataFrame(
    :data_name => [],
    :subject => String[],
    :session => Int[],
    :view => Union{Symbol,Int}[],
    :img_name => String[],
    :parameter => String[],
    :total_looked_items => Float64[],
    :total_not_looked_items => Float64[],
    :total_items => Float64[],
)
# mse_img = populate_dict!(Dict(), [["art", "pseudoart"], [1, 2], ["$(f)" for f in parameters_vec[func_range]]]; final_structure=Dict())
# mean_error_img = populate_dict!(Dict(), [["art", "pseudoart"], [1, 2], ["$(f)" for f in parameters_vec[func_range]]]; final_structure=Dict())

func = parameters_vec[2]
for func in parameters_vec[func_range]
    @info "Working on: $(func)"
    func_related_df = filter(row -> row.parameter == "$(func)", ECDF_rmse_df)

    if func == persistence || func == max_persistence
        ecdf_range = 0:256
    elseif func == density_scaled
        ecdf_range = 0:0.0001:1
    elseif func == cycles_perimeter
        ecdf_range = 0:1:500000
    else
        ecdf_range = 0:0.1:256
    end

    d = ["art", "pseudoart"][1]
    for d in ["art", "pseudoart"]
        data_related_df = filter(row -> row.data_name == d, func_related_df)
        images = data_related_df.img_name |> unique

        session_index = 1
        view_index = 1
        for session_index in [1, 2], view_indicator in view_range

            if view_indicator == ""
                view_index = 1
            elseif view_indicator == "s2"
                view_index = 2
            else
                view_index = :both
            end

            view_df = filter(row -> row.view == view_index, data_related_df)
            session_df = filter(row -> row.session == session_index, view_df)

            img_name = images[1]
            for img_name in images

                img_df = filter(row -> row.img_name == img_name, session_df)
                ecdf_image = img_df.ECDF_image[1]
                ecdf_subject = img_df.ECDF_view[1]
                # for (ecdf_subject, subject) in zip(img_df.ECDF_view, img_df.subject)
                subject_df = img_df[1, :]
                for subject_df in eachrow(img_df)
                    ecdf_subject = subject_df.ECDF_view
                    subject = subject_df.subject


                    # Take the original data, check the index of the ecdf? Check the length of the ECDF?
                    img_ecdf_vals = ecdf_image(ecdf_range)
                    first_in_img = findfirst(x -> x == 1, img_ecdf_vals)

                    subject_ecdf_vals = ecdf_subject(ecdf_range)
                    first_in_subject = findfirst(x -> x == 1, subject_ecdf_vals)
                    first_one = max(first_in_img, first_in_subject, 1)
                    fixed_ecdf_range = ecdf_range[1:first_one]

                    # ecdf_mse = mse(img_ecdf_vals, subject_ecdf_vals)
                    # ecdf_error = mean(img_ecdf_vals .- subject_ecdf_vals)
                    ecdf_mse =
                        mse(ecdf_image(fixed_ecdf_range), ecdf_subject(fixed_ecdf_range))
                    ecdf_error =
                        mean(ecdf_image(fixed_ecdf_range) .- ecdf_subject(fixed_ecdf_range))
                    ecdf_KS_manual = max(
                        abs.(
                            ecdf_image(fixed_ecdf_range) .- ecdf_subject(fixed_ecdf_range),
                        )...,
                    )

                    # push!(mse_img[d][session_index]["$(func)"][img_name], ecdf_mse)
                    # push!(mean_error_img[d][session_index]["$(func)"][img_name], ecdf_error)
                    total_items =
                        length([v for (k, v) in subject_df.mean_heatmap_in_window])
                    total_looked_items = length([
                        v for (k, v) in subject_df.mean_heatmap_in_window if v != 0
                    ])
                    total_not_looked_items = length([
                        v for (k, v) in subject_df.mean_heatmap_in_window if v == 0
                    ])

                    _, middle_position = findmin(abs.(subject_ecdf_vals .- 0.5))
                    ecdf_05 = fixed_ecdf_range[middle_position]

                    _, last_quarter_position = findmin(abs.(subject_ecdf_vals .- 0.75))
                    ecdf_075 = fixed_ecdf_range[last_quarter_position]

                    push!(
                        ECDF_mse_data_df,
                        (
                            d,
                            subject,
                            session_index,
                            view_index,
                            img_name,
                            "$(func)",
                            window_size,
                            ecdf_mse,
                            ecdf_error,
                            ecdf_KS_manual,
                            ecdf_05,
                            ecdf_075,
                        ),
                    )
                    push!(
                        ECDF_looking_size_df,
                        (
                            d,
                            subject,
                            session_index,
                            view_index,
                            img_name,
                            "$(func)",
                            total_looked_items,
                            total_not_looked_items,
                            total_items,
                        ),
                    )
                end # ecdf subject 
            end # img
        end # session
    end # d
end # func


# ===-===-
do_nothing = "ok"
