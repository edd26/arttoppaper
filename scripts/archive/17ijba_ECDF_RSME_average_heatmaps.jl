#=

Basic tests of the Ripsere library

=#

using DrWatson
@quickactivate "ArtTopology"

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
"17ijb_Kolmogorov-Smirnof_test_average_heatmaps.jl" |> scriptsdir |> include

using HypothesisTests
using StatsBase: ecdf
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
scriptprefix = "17ijba"



param = "persistence"
param_df = @pipe filter(row -> row.parameter == param, ECDF_img_avg_heatmap_df)


intensity_range = 0:255
fakes_mse_all = Vector{Float64}[]
arts_mse_all = Vector{Float64}[]

function get_function_span(ecdf_est; intensity_range=0:255)
    first_non_0 = findfirst(x -> x != 0, ecdf_est(intensity_range))
    last_non_1 = findlast(x -> x != 1, ecdf_est(intensity_range)) + 1
    art_functions_span = last_non_1 - first_non_0
    return art_functions_span
end

session_index = 1
view_index = 1
for session_index in 1:2, view_index = 1:2
    fakes_mse = Float64[]
    arts_mse = Float64[]
    session1_view1_df = @pipe filter(row -> row.session == session_index, param_df) |>
                              filter(row -> row.view == view_index, _)
    art_df = filter(row -> row.data_name == "art", session1_view1_df)
    fake_df = filter(row -> row.data_name == "fake", session1_view1_df)

    # Added variable to compute spann of the images; removed because it's done automatically
    # art_spanns = [k |> get_function_span for k in art_df.ECDF_imgae]
    # fake_spanns = [k |> get_function_span for k in fake_df.ECDF_imgae]

    for k in 1:total_images
        ecdf_heatmap = fake_df[:, :ECDF_view][k]
        ecdf_img1 = fake_df[:, :ECDF_imgae][k]
        # ecdf_img1(intensity_range)

        push!(
            fakes_mse,
            mse(
                ecdf_img1(intensity_range),
                ecdf_heatmap(intensity_range)
            ) # ./ fake_spanns[k]
        )
    end
    for k in 1:total_images
        ecdf_heatmap = art_df[:, :ECDF_view][k]
        ecdf_img1 = art_df[:, :ECDF_imgae][k]
        # ecdf_img1(intensity_range)

        push!(
            arts_mse,
            mse(
                ecdf_img1(intensity_range),
                ecdf_heatmap(intensity_range)
            ) #./ art_spanns[k]
        )
    end
    push!(fakes_mse_all, fakes_mse)
    push!(arts_mse_all, arts_mse)
end


f = Figure();
ax = CairoMakie.Axis(
    f[1, 1],
    # yscale=log10,
    # ylabel=L"log_{10}(MSE)",
    xticks=([1, 2], ["Art", "Fake"])
)
#  ax.

categories = vcat([1 for k in 1:total_images*4], [2 for k in 1:total_images*4])
dodge = vcat(vcat([[s for k in 1:total_images] for s in 1:4], [[s for k in 1:total_images] for s in 1:4])...)
values = vcat(vcat(arts_mse_all...), vcat(fakes_mse_all...))

boxplot!(ax, categories, values, dodge=dodge, color=dodge)# clouds=nothing, markersize=10)
f

# Save image 
data_stuff = savename(@dict window_size selected_data session_index view_index img_name)
data_stuff = replace(data_stuff, ".jpg" => "")
out_name = "$(scriptprefix)_ecdf_RSME_average_heatmap_$(data_stuff )"
image_export_dir(args...) = plotsdir("section17", "$(scriptprefix)-ecdf_RSME_average_heatmaps", "fixation_sequence=$(CONFIG.FIXATION_SEQUENCE)", "boxplots-all_sessions", args...)

folder_name = "window=$(window_size)"

final_name1 = image_export_dir("$func", folder_name, selected_data, out_name * ".png")
safesave(final_name1, f)

###################### 
# Plot number 2, with marked sessions
markers_labels = [
    :circle,
    :rect,
    :diamond,
    :hexagon,
    :cross,
    :xcross,
    :utriangle,
    :dtriangle,
    :pentagon,
    :star4,
    :star5,
    '✈',
    # :vline,
]

art_colours = cgrad(:roma, 4, categorical=true,);
fake_colours = cgrad(:rust, 4, categorical=true,);

f2 = Figure(size=(800, 800))
fgl2 = GridLayout(f2[1, 1])
art_position = 1
fake_position = 2
ax = CairoMakie.Axis(
    fgl2[1, 1],
    yscale=log10,
    ylabel=L"log_{10}(MSE)",
    xticks=([art_position, fake_position] .+ 1 / 20 * 6, ["Art", "Fake"])
)


colour_counter = 1
for session_index in 1:2, view_index = 1:2
    session1_view1_df = @pipe filter(row -> row.session == session_index, param_df) |>
                              filter(row -> row.view == view_index, _)
    art_df = filter(row -> row.data_name == "art", session1_view1_df)
    fake_df = filter(row -> row.data_name == "fake", session1_view1_df)


    selected_colour1 = art_colours[colour_counter]
    selected_colour2 = fake_colours[colour_counter]
    colour_counter += 1

    art_counter = 0
    fake_counter = 0
    for k in 1:total_images



        ecdf_img1 = art_df[:, :ECDF_imgae][k]
        ecdf_heatmap1 = art_df[:, :ECDF_view][k]
        arts_mse_local = mse(ecdf_img1(intensity_range), ecdf_heatmap1(intensity_range))

        ecdf_img2 = fake_df[:, :ECDF_imgae][k]
        ecdf_heatmap2 = fake_df[:, :ECDF_view][k]
        fakes_mse_local = mse(ecdf_img2(intensity_range), ecdf_heatmap2(intensity_range))

        x_position1 = art_counter ./ 20 + art_position
        x_position2 = fake_counter ./ 20 + fake_position
        scatter!(ax,
            x_position1,
            arts_mse_local,
            marker=markers_labels[k],
            color=selected_colour1,
            markersize=15,
            alpha=0.8
        )
        scatter!(ax,
            x_position2,
            fakes_mse_local,
            marker=markers_labels[k],
            color=selected_colour2,
            markersize=15,
            alpha=0.8
        )
        art_counter += 1
        fake_counter += 1
    end
end




markers_for_legend1 = [
    MarkerElement(marker=ms,
        color=art_colours[1],
        strokecolor=:transparent,
        markersize=12) for ms in markers_labels]

markers_for_legend2 = [
    MarkerElement(marker=ms,
        color=fake_colours[2],
        strokecolor=:transparent,
        markersize=12) for ms in markers_labels]

colours_for_legend1 = [
    PolyElement(color=c,
        strokecolor=:transparent)
    for c in art_colours
]
colours_for_legend2 = [
    PolyElement(color=c,
        strokecolor=:transparent)
    for c in fake_colours
]

art_images = filter(row -> row.data_name == "art", ECDF_img_avg_heatmap_df)[:, :img_name] |> unique
fake_images = filter(row -> row.data_name == "fake", ECDF_img_avg_heatmap_df)[:, :img_name] |> unique

all_sessions_named = ["Session 1, view 1", "Session 1, view 2", "Session 2, view 1", "Session 2, view 2"]


Legend(fgl2[2, 1],
    [markers_for_legend1, markers_for_legend2, colours_for_legend1, colours_for_legend2],
    [art_images, fake_images, all_sessions_named, all_sessions_named],
    ["Art Images", "Fake images", "Art Sessions", "Fake sessions"],
    tellheight=true,
    tellwidth=true,
    nbanks=4
)
f2
# Save image 
data_stuff = savename(@dict window_size selected_data session_index view_index img_name)
data_stuff = replace(data_stuff, ".jpg" => "")
out_name = "$(scriptprefix)_ecdf_RSME_average_heatmap_$(data_stuff )"
image_export_dir(args...) = plotsdir("section17", "$(scriptprefix)-ecdf_RSME_average_heatmaps", "fixation_sequence=$(CONFIG.FIXATION_SEQUENCE)", "scatter_img_RMSE", args...)

folder_name = "window=$(window_size)"

final_name1 = image_export_dir("$func", folder_name, selected_data, out_name * ".png")
safesave(final_name1, f2)

# ===-===-
do_nothing = "ok"
