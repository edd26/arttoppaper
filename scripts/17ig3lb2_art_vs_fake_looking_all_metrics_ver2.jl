using DrWatson
@quickactivate "ArtTopology"

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
"17ig3_ECDF_generation_not_looking.jl" |> scriptsdir |> include

using HypothesisTests
using StatsBase: ecdf
using HypothesisTests: OneWayANOVATest, MannWhitneyUTest
import LaTeXStrings: latexstring

"ECDFPlotting.jl" |> srcdir |> include
"statistics_utils.jl" |> srcdir |> include
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
scriptprefix = "17ig3lb2"

# ===-===-===-
fig_width = 600
fig_height = 300

color_palette = Makie.wong_colors();

data_keys = ["art", "fake"]
func = parameters_vec[1]

# Test selection
do_KW = false
do_mann_whitney = true
do_signed_rank = false
do_fdr_miller = false

selected_metric = :ECDF_looking_mse
scatter_label = L"MSE(ECDF_{image}-ECDF_{subject})"
# f2 = Figure(size=(fig_width, 2fig_height))

for looking_type = [:looking, :not_looking]

    if looking_type == :looking
        labels_vec = [:ECDF_looking_mse, :ECDF_looking_error, :ECDF_looking_KS][1:3]
    else
        labels_vec = [:ECDF_not_looking_mse, :ECDF_not_looking_error, :ECDF_not_looking_KS][1:3]
    end

    for (metric_index, selected_metric) in enumerate(labels_vec)
        f2 = Figure(size=(1.5fig_width, fig_height))
        fgl_sub = CairoMakie.GridLayout(f2[1, 1])
        @info "Working on: $(selected_metric )"
        if occursin("mse", "$(selected_metric)")
            scatter_label = L"MSE(ECDF_{image}-ECDF_{looking})"
        elseif occursin("error", "$(selected_metric)")
            scatter_label = L"ME(ECDF_{image}-ECDF_{looking})"
        else
            scatter_label = L"KS(ECDF_{image}-ECDF_{looking})"
        end
        d_label = split(scatter_label, "(")[1] * "\$" |> latexstring

        for (func_index, func) = parameters_vec[func_range] |> enumerate
            @info "Working on: $(func)"
            func_related_df = filter(row -> row.parameter == "$(func)", ECDF_not_looking_error_df)

            all_vals = vcat(func_related_df[:, selected_metric],)
            min_val = min([x for x in all_vals if !isnan(x)]...)
            max_val = max([x for x in all_vals if !isnan(x)]...)

            y_high = 1.35max_val
            bracket_y = 1.1max_val
            if min_val < 1e3 && min_val > 0
                y_low = -0.03
            else
                if min_val > 0
                    y_low = 0.8min_val
                else
                    y_low = 1.2min_val
                end
            end

            art_related_df = filter(row -> row.data_name == "art", func_related_df)
            fake_related_df = filter(row -> row.data_name == "fake", func_related_df)

            art_label = "Artist"
            fake_label = "Artificially Generated"

            vec1 = [k for k in art_related_df[:, selected_metric] if !isnan(k)]
            vec2 = [k for k in fake_related_df[:, selected_metric] if !isnan(k)]

            if isempty(vec1)
                vec1 = [0]
            end
            if isempty(vec2)
                vec2 = [0]
            end
            m1 = median(vec1)
            m2 = median(vec2)
            @info "Median value in vec1 is $(m1)"
            @info "Median value in vec2 is $(m2)"

            if func == persistence
                vec1_val = 1
                vec2_val = 2
                color_palette = [Makie.wong_colors()[5], Makie.wong_colors()[2]]
            elseif func == max_persistence
                vec1_val = 3
                vec2_val = 4
                color_palette = [Makie.wong_colors()[1:4]..., Makie.wong_colors()[3], Makie.wong_colors()[4]]
            else
                vec1_val = 5
                vec2_val = 6
                color_palette = [Makie.wong_colors()[1:4]..., Makie.wong_colors()[1], Makie.wong_colors()[6]]
            end

            stat_test_result, test_p_value = get_p_values(vec1, vec2; do_KW=do_KW, do_mann_whitney=do_mann_whitney, do_signed_rank=do_signed_rank, do_fdr_miller=do_fdr_miller)

            fgl = CairoMakie.GridLayout(fgl_sub[1, func_index])
            ax_scatter, ax_boxplot, ax_estimate = set_up_ax_distro_plt(fgl; scatter_label=scatter_label)
            do_distro_plot(
                ax_scatter, ax_boxplot, ax_estimate,
                vec1,
                vec2;
                art_val=vec1_val,
                fake_val=vec2_val,
                color_palette=color_palette
            )
            ax_scatter.xticks = (vec1_val:vec2_val, ["Art", "Artificially\nGenerated",])
            for ax in [ax_scatter, ax_boxplot, ax_estimate]
                CairoMakie.ylims!(ax, low=y_low, high=y_high)
            end

            if test_p_value < 0.05
                if test_p_value < 0.001
                    p_marker = "***"
                elseif test_p_value < 0.01
                    p_marker = "**"
                elseif test_p_value < 0.05
                    p_marker = "*"
                end#
                CairoMakie.bracket!(ax_boxplot, vec1_val, bracket_y, vec2_val, bracket_y, offset=0, text=p_marker, style=:square, fontsize=30, textoffset=-1)
            else
                p_marker = ""
            end # p-plot

            param = split("$(func)", "_")[1]
            if func_index == 1
                indicator = "a)"
            elseif func_index == 2
                indicator = "b)"
            elseif func_index == 3
                indicator = "c)"
            end
            func_str = split("$(func)", "_")[1]
            if func == persistence
                func_str = "avg. persistence"
            elseif func == max_persistence
                persistence
                func_str = "max. persistence"
            elseif func == density_scaled
                func_str = "density"
            end

            latex_text = ("$(d_label), $(func_str)" |> latexstring)
            label_text = "$(indicator) $(latex_text)"

            Label(fgl[0, :],
                "$(indicator) $(d_label), $(func_str)" |> latexstring,
                tellheight=true,
                tellwidth=false,
                fontsize=18,
                justification=:left,
                halign=:left
            )

        end # func
        f2

        # ===-===-===-
        data_stuff = savename(@dict window_size)
        data_stuff = replace(data_stuff, ".jpg" => "")

        section_name = "art_vs_fake_all_metrics_all_subjects"
        out_name = "$(scriptprefix)_$(section_name)_$(data_stuff)_$(selected_metric)"
        image_export_dir(args...) = plotsdir(
            "section17",
            "$(scriptprefix)-$(section_name)",
            "fixation_sequence=$(CONFIG.FIXATION_SEQUENCE)",
            args...
        )

        if do_KW
            stattest_folder = "KruskalWallisTest"
        elseif do_mann_whitney
            stattest_folder = "MannWhitneyUTest"
        elseif do_fdr_miller
            stattest_folder = "frdAllPairsMillerTest"
        elseif do_signed_rank
            stattest_folder = "SignedRankTest"
        else
            stattest_folder = "OneWayANOVATest"
        end

        # folder_name =
        folder_arg = join(["$(CONFIG.DATA_CONFIG)_window=$(window_size)", "$(stattest_folder)", selected_metric, looking_type], "_")
        final_name1 = image_export_dir(folder_arg, out_name * ".png")
        @info "Saving under the name $(final_name1)"
        safesave(final_name1, f2)
        final_name2 = image_export_dir(folder_arg, "pdf", out_name * ".pdf")
        safesave(final_name2, f2)
    end # selected_metric
end # looking_type 


# ===-===-
do_nothing = "ok"
