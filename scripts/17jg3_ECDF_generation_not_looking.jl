
using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
"17j_cycles_in_unit_coverage_both_config.jl" |> scriptsdir |> include

using HypothesisTests
using StatsBase: ecdf
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
scriptprefix = "17jg3"

# ===-===-===-===-
df_info_storage(args...) = datadir(
    "exp_pro",
    "section17",
    "$(scriptprefix)-ecdf_not_looking_BW_WB",
    "fixation_sequence=$(CONFIG.FIXATION_SEQUENCE)",
    args...,
)

# ===-===-===-===-
selected_window = 51

# ===-===-
total_subjects = length(subjects_name["art"])
windows = "windows_" * join(["$(k)" for k in window_sizes], "_")

selected_data = [l for l in keys(unique_cycles_count_in_windows["BW"][window_size])][2]
img_name =
    [l for l in keys(unique_cycles_count_in_windows["BW"][window_size][selected_data])][5]
func = parameters_vec[3]

force_computaions = false
parameters_df = DataFrame(
    :data_name => String[],
    :img_name => String[],
    :parameter => String[],
    :window_size => Int[],
    :parameters_values => Vector{Float64}[],
    :parameter_map => Matrix{Float64}[],
)

ECDF_not_looking_df = DataFrame(
    :data_name => [],
    :subject => String[],
    :session => Int[],
    :view => Union{Symbol,Int}[],
    :img_name => String[],
    :parameter => String[],
    :window_size => Int[],
    :KS_looking => [],
    :KS_not_looking => [],
    :ECDF_image => [],
    :ECDF_looked => [],
    :ECDF_not_looked => [],
    :subject_looking => [],
    :mean_heatmap_in_window => [],
)
view_range = [:both]

func = parameters_vec[1]
for func in parameters_vec[func_range]
    @info "Working on: $(func)"

    for window_size in window_sizes[windows_range]
        @info "\tWorking on: $(window_size)"

        for selected_data in dataset_names[1:2]
            @info "\t\tWorking on: $(selected_data)"

            et_df = dataset_df_dict[selected_data]
            img_names = [
                l for l in
                keys(unique_cycles_count_in_windows["BW"][window_size][selected_data])
            ]
            for img_name in img_names
                @info "\t\t\tWorking on: $(img_name)"

                parameter_map_BW, parameters_values_BW = get_parameters_map(
                    func,
                    cycles_on_image_canvas["BW"][window_size][selected_data][img_name],
                    window_size,
                    all_homology_info["BW"][selected_window][selected_data][img_name],
                    all_perimeter_info["BW"][selected_window][selected_data][img_name];
                )

                wb_img_name = replace(img_name, "BW" => "WB")
                parameter_map_WB, parameters_values_WB = get_parameters_map(
                    func,
                    cycles_on_image_canvas["WB"][window_size][selected_data][wb_img_name],
                    window_size,
                    all_homology_info["WB"][selected_window][selected_data][wb_img_name],
                    all_perimeter_info["WB"][selected_window][selected_data][wb_img_name];
                    default_map_value = default_map_value,
                )

                parameter_map = get_parameters_map_from_joined_filtration(
                    parameter_map_BW,
                    parameter_map_WB,
                    func,
                )
                parameters_values = get_parameters_values_from_joined_filtration(
                    parameters_values_BW,
                    parameters_values_WB,
                    func,
                )

                push!(
                    parameters_df,
                    (
                        selected_data,
                        replace(img_name, r"_BW\...." => ""),
                        "$(func)",
                        window_size,
                        parameters_values,
                        parameter_map,
                    ),
                )
                ecdf_img = ecdf(parameters_values)

                session_index = 1
                view_indicator = ""

                for session_index = 1:total_sessions,
                    (view_index, view_indicator) in enumerate(view_range)

                    @info "\t\t\t\tWorking on session $(session_index) "

                    parameter = "$(func)"
                    image_name = replace(img_name, r"_BW\...." => "")
                    ecdf_generation_config =
                        @dict window_sizes unique_cycles_count_in_windows total_subjects window_size func selected_data et_df image_name session_index parameter
                    if !isnan(default_map_value)
                        ecdf_generation_config[:default_map_value] = default_map_value
                    end
                    ECDF_not_looking_data, p = produce_or_load(
                        df_info_storage("$(func)"), # path
                        ecdf_generation_config, # config
                        prefix = "p_value_df", # file prefix
                        force = force_computaions, # force computations
                    ) do ecdf_generation_config
                        @unpack window_sizes,
                        unique_cycles_count_in_windows,
                        total_subjects,
                        window_size,
                        func,
                        selected_data,
                        et_df,
                        image_name,
                        session_index,
                        parameter = ecdf_generation_config

                        session_df = filter(row -> row.Session == session_index, et_df)

                        ECDF_not_looking_local_df = DataFrame(
                            :data_name => [],
                            :subject => String[],
                            :session => Int[],
                            :view => Union{Symbol,Int}[],
                            :img_name => String[],
                            :parameter => String[],
                            :window_size => Int[],
                            :KS_looking => [],
                            :KS_not_looking => [],
                            :ECDF_image => [],
                            :ECDF_looked => [],
                            :ECDF_not_looked => [],
                            :subject_looking => [],
                            :mean_heatmap_in_window => [],
                        )

                        subject = subjects_name[selected_data][end-1]
                        img_number = get_img_number(
                            selected_data,
                            image_name;
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

                                subject_looking_values = Float64[]
                                for (weight, value) in zip(
                                    hist_weights,
                                    parameters_values[subject_looking],
                                )
                                    for k = 1:ceil(weight)
                                        push!(subject_looking_values, value)
                                    end
                                end
                                looked_values =
                                    Vector{Float64}(parameters_values[subject_looking])
                                # ===-===-
                                empty_positions =
                                    [p for (p, v) in mean_heatmap_in_window if v == 0]
                                not_looked_values = filter(
                                    x -> !isnan(x),
                                    [parameter_map[k[1], k[2]] for k in empty_positions],
                                )

                                # ===-
                                ecdf_viewing =
                                    ecdf(looked_values; weights = hist_weights)
                                ecdf_not_viewing = ecdf(not_looked_values)
                                # ===-
                                KS_test_results_looking = ApproximateTwoSampleKSTest(
                                    parameters_values,
                                    subject_looking_values,
                                )
                                KS_test_results_not_looking =
                                    ApproximateTwoSampleKSTest(
                                        parameters_values,
                                        not_looked_values,
                                    )
                                if view_indicator == ""
                                    view_index = 1
                                elseif view_indicator == "s2"
                                    view_index = 2
                                else
                                    view_index = :both
                                end

                                push!(
                                    ECDF_not_looking_local_df,
                                    (
                                        selected_data,
                                        subject,
                                        session_index,
                                        view_index,
                                        image_name,
                                        "$(func)",
                                        window_size,
                                        KS_test_results_looking,
                                        KS_test_results_not_looking,
                                        ecdf_img,
                                        ecdf_viewing,
                                        ecdf_not_viewing,
                                        subject_looking,
                                        mean_heatmap_in_window,
                                    ),
                                )
                            end # if
                        end # subject
                        Dict("ECDF_not_looking_results" => ECDF_not_looking_local_df)
                    end # produce_or_load
                    ECDF_not_looking_local_df =
                        ECDF_not_looking_data["ECDF_not_looking_results"]
                    global ECDF_not_looking_df =
                        vcat(ECDF_not_looking_df, ECDF_not_looking_local_df)
                end # session, view index
            end # img_nam
        end # selected_data
    end # window_size
end # func


ECDF_not_looking_error_df = DataFrame(
    :data_name => [],
    :subject => String[],
    :session => Int[],
    :view => Union{Symbol,Int}[],
    :img_name => String[],
    :parameter => String[],
    :window_size => Int[],
    :ECDF_looking_mse => Float64[],
    :ECDF_looking_error => Float64[],
    :ECDF_not_looking_mse => Float64[],
    :ECDF_not_looking_error => Float64[],
    :ECDF_looking_KS => Float64[],
    :ECDF_not_looking_KS => Float64[],
    :ECDF_looking_05 => Float64[],
    :ECDF_not_looking_05 => Float64[],
    :ECDF_looking_075 => Float64[],
    :ECDF_not_looking_075 => Float64[],
    :ECDF_lnl_me => Float64[],
    :ECDF_lnl_mse => Float64[],
    :ECDF_lnl_manual_KS => Float64[],
    :ECDF_lnl_KS_statistic => Float64[],
)


func = parameters_vec[2]
d = ["art", "pseudoart"][1]
session_index = 1
for func in parameters_vec[func_range]
    @info "Working on: $(func)"
    func_related_df = filter(row -> row.parameter == "$(func)", ECDF_not_looking_df)

    if func == persistence || func == max_persistence
        ecdf_range = 0:256
    elseif func == density_scaled
        ecdf_range = 0:0.0001:1
    elseif func == cycles_perimeter
        ecdf_range = 0:1:500000
    else
        ecdf_range = 0:0.1:256
    end

    for d in ["art", "pseudoart"]
        @info "\tWorking on: $(d)"
        data_related_df = filter(row -> row.data_name == d, func_related_df)
        images = data_related_df.img_name |> unique

        for session_index = 1:total_sessions,
            (view_index, view_indicator) in enumerate(view_range)

            @info "\t\tWorking one session: $(session_index), view: $(view_indicator)"
            view_df = filter(row -> row.view == view_indicator, data_related_df)
            session_df = filter(row -> row.session == session_index, view_df)

            img_name = images[end]
            for img_name in images
                @info "\t\t\tWorking on: $(img_name)"
                img_df = filter(row -> row.img_name == img_name, session_df)

                k = 2
                ecdf_image = img_df.ECDF_image[k]
                ecdf_looked = img_df.ECDF_looked[k]
                ecdf_not_looked = img_df.ECDF_not_looked[k]

                for (ecdf_looked, ecdf_not_looked, subject) in
                    zip(img_df.ECDF_looked, img_df.ECDF_not_looked, img_df.subject)

                    # Take the original data, check the index of the ecdf? Check the length of the ECDF?
                    img_ecdf_vals = ecdf_image(ecdf_range)
                    ecdf_vals_looked = ecdf_looked(ecdf_range)
                    ecdf_vals_not_looked = ecdf_not_looked(ecdf_range)
                    first_one = max(
                        map(
                            y -> findfirst(x -> x == 1, y),
                            [
                                x for x in
                                [img_ecdf_vals, ecdf_vals_looked, ecdf_vals_not_looked] if
                                !all(isnan.(x))
                            ],
                        )...,
                    )

                    fixed_ecdf_range = ecdf_range[1:first_one]
                    img_ecdf_vals = ecdf_image(fixed_ecdf_range)
                    ecdf_vals_looked = ecdf_looked(fixed_ecdf_range)
                    ecdf_vals_not_looked = ecdf_not_looked(fixed_ecdf_range)


                    ecdf_looking_mse = mse(img_ecdf_vals, ecdf_vals_looked)
                    ecdf_looking_error = mean(img_ecdf_vals .- ecdf_vals_looked)
                    ecdf_looking_KS = max(abs.(img_ecdf_vals .- ecdf_vals_looked)...)
                    _, middle_position = findmin(abs.(ecdf_vals_looked .- 0.5))
                    ecdf_looking_05 = fixed_ecdf_range[middle_position]
                    _, last_quarter_position = findmin(abs.(ecdf_vals_looked .- 0.75))
                    ecdf_looking_075 = fixed_ecdf_range[last_quarter_position]

                    # if !all(isnan.(ecdf_vals_not_looked))
                    ecdf_not_looking_mse = mse(img_ecdf_vals, ecdf_vals_not_looked)
                    ecdf_not_looking_error = mean(img_ecdf_vals .- ecdf_vals_not_looked)
                    ecdf_not_looking_KS =
                        max(abs.(img_ecdf_vals .- ecdf_vals_not_looked)...)

                    _, middle_position2 = findmin(abs.(ecdf_vals_not_looked .- 0.5))
                    ecdf_not_looking_05 = fixed_ecdf_range[middle_position2]

                    _, last_quarter_position2 = findmin(abs.(ecdf_vals_not_looked .- 0.75))
                    ecdf_not_looking_075 = fixed_ecdf_range[last_quarter_position2]

                    ecdf_lnl_me = mean(ecdf_vals_looked .- ecdf_vals_not_looked)
                    ecdf_lnl_mse = mse(ecdf_vals_looked, ecdf_vals_not_looked)
                    ecdf_lnl_manual_KS =
                        max(abs.(ecdf_vals_looked .- ecdf_vals_not_looked)...)
                    ecdf_lnl_KS_statistic = teststatistic(
                        ApproximateTwoSampleKSTest(ecdf_vals_looked, ecdf_vals_not_looked),
                    )
                    # end

                    push!(
                        ECDF_not_looking_error_df,
                        (
                            d,
                            subject,
                            session_index,
                            view_indicator,
                            img_name,
                            "$(func)",
                            window_size,
                            ecdf_looking_mse,
                            ecdf_looking_error,
                            ecdf_not_looking_mse,
                            ecdf_not_looking_error,
                            ecdf_looking_KS,
                            ecdf_not_looking_KS,
                            ecdf_looking_05,
                            ecdf_not_looking_05,
                            ecdf_looking_075,
                            ecdf_not_looking_075,
                            ecdf_lnl_me,
                            ecdf_lnl_mse,
                            ecdf_lnl_manual_KS,
                            ecdf_lnl_KS_statistic,
                        ),
                    )
                end # ecdf subject 
            end # img
        end # sessions
    end # d
end # func


# ===-===-
do_nothing = "ok"
