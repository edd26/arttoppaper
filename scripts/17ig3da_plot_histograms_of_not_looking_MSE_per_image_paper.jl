using DrWatson
@quickactivate "ArtTopology"

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
"17ig3_ECDF_generation_not_looking.jl" |> scriptsdir |> include

using HypothesisTests
using StatsBase: ecdf

"ECDFPlotting.jl" |> srcdir |> include
"statistics_utils.jl" |> srcdir |> include

import .CONFIG: dipha_bd_info_export_folder, preproc_img_dir
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
scriptprefix = "17ig3da_v2"

do_mann_whitney = true
do_KW = false
do_signed_rank = false
do_fdr_miller = false

selected_data = dataset_names[1]
func = parameters_vec[1]

for data_type in [:ECDF_mse, :ECDF_error, :KS_statistic]
    @info "Working on: $(data_type )"

    if data_type == :ECDF_mse
        scatter_label = L"MSE(ECDF_{image}-ECDF_{subject})"
        slection_looking_label = :ECDF_looking_mse
        slection_notlooking_label = :ECDF_not_looking_mse
    elseif data_type == :ECDF_error
        scatter_label = L"ME(ECDF_{image}-ECDF_{subject})"
        slection_looking_label = :ECDF_looking_error
        slection_notlooking_label = :ECDF_not_looking_error
    elseif data_type == :KS_statistic
        scatter_label = L"KS(ECDF_{image}-ECDF_{subject})"
        slection_looking_label = :ECDF_looking_KS
        slection_notlooking_label = :ECDF_not_looking_KS
    else
        ErrorException("Unknown data type") |> throw
    end
    for func = parameters_vec[func_range]
        @info "\tWorking on: $(func)"
        func_df = filter(row -> row.parameter == "$(func)", ECDF_not_looking_error_df)
        func_ecdf_df = filter(row -> row.parameter == "$(func)", ECDF_not_looking_df)
        func_parameters_df = filter(row -> row.parameter == "$(func)", parameters_df)

        for selected_data in [k for k in keys(unique_cycles_count_in_windows[window_size])]
            @info "\t\tworking on: $(selected_data)"
            data_df = filter(row -> row.data_name == selected_data, func_df)
            data_ecdf_df = filter(row -> row.data_name == selected_data, func_ecdf_df)
            data_parameters_df = filter(row -> row.data_name == selected_data, func_parameters_df)

            all_vals = vcat(data_df[:, slection_looking_label]..., data_df[:, slection_notlooking_label]...)
            min_val = min([x for x in all_vals if !isnan(x)]...)
            max_val = max([x for x in all_vals if !isnan(x)]...)

            if min_val < 1e3 && min_val > 0
                y_low = 0.0
            else
                if min_val > 0
                    y_low = 0.8min_val
                else
                    y_low = 1.2min_val
                end
            end
            y_high = 1.2max_val
            bracket_y = 1.0max_val

            single_height = 250
            single_width = 220
            f = Figure(size=(single_width * 4, single_height * 12,))
            fgl_main = GridLayout(f[1, 1])

            et_df = dataset_df_dict[selected_data]
            img_list = data_df.img_name |> unique
            img_index = 1
            img_name = img_list[1]
            for (img_index, img_name) = enumerate(img_list)
                @info "\t\t\tworking on: $(img_name)"
                img_df = filter(row -> row.img_name == img_name, data_df)
                img_ecdf_df = filter(row -> row.img_name == img_name, data_ecdf_df)
                img_parameters_df = filter(row -> row.img_name == img_name, data_parameters_df)

                session_df = filter(row -> row.session == session_index, img_df)
                session_ecdf_df = filter(row -> row.session == session_index, img_ecdf_df)
                if selected_data == "art"
                    val1 = 3
                    val2 = 4
                else
                    val1 = 5
                    val2 = 6
                end

                ###############
                vec1 = session_df[:, slection_looking_label]
                vec2 = session_df[:, slection_notlooking_label]
                not_nans = (!isnan).(vec1) .&& (!isnan).(vec2)
                vec1 = vec1[not_nans]
                vec2 = vec2[not_nans]

                all_vals = vcat(vec1..., vec2...)
                min_val = min([x for x in all_vals if !isnan(x)]...)
                max_val = max([x for x in all_vals if !isnan(x)]...)
                y_high = 1.2max_val
                bracket_y = 1.0max_val
                if min_val < 1e3 && min_val > 0
                    y_low = 0.0
                else
                    if min_val > 0
                        y_low = 0.8min_val
                    else
                        y_low = 1.2min_val
                    end
                end

                stat_test_result, test_p_value = get_p_values(vec1, vec2; do_KW=do_KW, do_mann_whitney=do_mann_whitney, do_signed_rank=do_signed_rank, do_fdr_miller=do_fdr_miller)

                fgl1 = GridLayout(fgl_main[img_index, session_index])

                ax_scatter, ax_boxplot, ax_estimate = set_up_ax_distro_plt(fgl1; scatter_label=scatter_label)
                do_distro_plot(ax_scatter, ax_boxplot, ax_estimate, vec1, vec2, art_val=val1, fake_val=val2, skip_violin=true)
                ax_scatter.xticks = (val1:val2, ["Looking", "Not looking",])

                for ax in [ax_scatter, ax_boxplot, ax_estimate]
                    CairoMakie.ylims!(ax, low=y_low, high=y_high)
                end

                ax_ecdf_looked = CairoMakie.Axis(fgl1[1, 3], title="looked")
                ax_ecdf_not_looked = CairoMakie.Axis(fgl1[1, 4], title="not looked")
                ax_img = CairoMakie.Axis(fgl1[1, 5], aspect=AxisAspect(1434 / 2048))

                extension = ".jpg"
                name = split(img_parameters_df.img_name[1], ".jpg")[1]
                if !occursin("$(CONFIG.DATA_CONFIG)", name)
                    input_img_name = name * "_$(CONFIG.DATA_CONFIG)" * extension
                else
                    input_img_name = name * extension
                end

                if selected_data == "art"
                    loaded_img = preproc_img_dir("$(CONFIG.DATA_CONFIG)", "Artysta", input_img_name) |> load |> channelview
                else
                    loaded_img = preproc_img_dir("$(CONFIG.DATA_CONFIG)", "wystawa_fejkowa", input_img_name) |> load |> channelview
                end

                if loaded_img |> size |> length == 3
                    loaded_img = loaded_img[1, :, :]
                end
                image!(ax_img, loaded_img')
                ax_img.yreversed = true
                hidedecorations!(ax_img,
                    label=true,
                    ticklabels=true,
                    ticks=true,
                    grid=true,
                    minorgrid=true,
                    minorticks=true
                )

                img_data = img_df[1, :,]
                img_ecdf_data = img_ecdf_df[1, :,]

                subjects = session_ecdf_df.subject |> unique
                subject = subjects[1]
                for subject in subjects
                    subject_ecdf_df = filter(row -> row.subject == subject, session_ecdf_df)

                    windowed_heatmap_values = [v for (k, v) in subject_ecdf_df.mean_heatmap_in_window[1]]
                    hist_weights = windowed_heatmap_values[subject_ecdf_df.subject_looking[1]]

                    subject_looking_values = Float64[]
                    for (weight, value) in zip(hist_weights, img_parameters_df.parameters_values[1][subject_ecdf_df.subject_looking[1]])
                        for k in 1:ceil(weight)
                            push!(subject_looking_values, value)
                        end
                    end
                    looked_values = subject_looking_values
                    # ===-===-
                    empty_positions = [p for (p, v) in subject_ecdf_df.mean_heatmap_in_window[1] if v == 0]
                    not_looked_values = filter(x -> !isnan(x), [img_parameters_df.parameter_map[1][k[1], k[2]] for k in empty_positions])

                    if isempty(not_looked_values)
                        not_looked_values = [0]
                    end

                    colours = Makie.wong_colors()
                    ecdfplot!(ax_ecdf_looked, looked_values, color=:red)
                    ecdfplot!(ax_ecdf_not_looked, not_looked_values, color=colours[2])
                end

                ecdfplot!(ax_ecdf_looked, img_parameters_df.parameters_values[1], color=:blue)
                ecdfplot!(ax_ecdf_not_looked, img_parameters_df.parameters_values[1], color=:blue)
                f

                # ===-===-
                if pvalue(stat_test_result) < 0.05
                    if pvalue(stat_test_result) < 0.001
                        p_marker = "*** "
                    elseif pvalue(stat_test_result) < 0.01
                        p_marker = "** "
                    elseif pvalue(stat_test_result) < 0.05
                        p_marker = "* "
                    end#
                    CairoMakie.bracket!(ax_boxplot, val1, bracket_y, val2, bracket_y, offset=0, text=p_marker, style=:square, fontsize=30, textoffset=-1)
                else
                    p_marker = "-"
                end # p-plot

                ################33
            end# img_nam
            rowgap!(fgl_main, 20)
            f
            # Save image 
            total_subjects = length(subjects_name[selected_data])
            data_stuff = savename(@dict window_size total_subjects selected_data)
            data_stuff = replace(data_stuff, ".jpg" => "")
            main_name = "ECDF_analysis_per_image_looking_vs_not"
            out_name = "$(scriptprefix)_$(main_name)_$(data_stuff )_$(func)"
            image_export_dir(args...) = plotsdir("section17", "$(scriptprefix)-$(main_name)", "$(CONFIG.DATA_CONFIG)_fixation_sequence=$(CONFIG.FIXATION_SEQUENCE)", args...)

            folders_args = join(["$(data_type)", "window=$(window_size)", "$(func)",], "_")

            final_name1 = image_export_dir(folders_args, out_name * ".png")
            safesave(final_name1, f)
            final_name2 = image_export_dir(folders_args, "pdf", out_name * ".pdf")
            safesave(final_name2, f)
        end # selected_data
    end # func
end # metric

# ===-===-
do_nothing = "ok"
