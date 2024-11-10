using DrWatson
@quickactivate "ArtTopology"

# ===-===-===-
using CairoMakie
using TopologyPreprocessing

using Pipe

# ===-===-===-
"12_get_images_rescaling_trajectory.jl" |> scriptsdir |> include

"MakiePlots.jl" |> srcdir |> include

import .CONFIG: art_images_names, names_to_order, fake_images_names
## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# Pre-definitions
script_prefix = "12c2"
plot_12c_dir(args...) = plotsdir("section12", script_prefix * "-image-trajectories", args...)


unique_files = img_trajectories_df.file |> unique
unique_datasets = (img_trajectories_df.dataset|>unique)[1:2]

# ===-===-===-
dataset_schemes = Dict(
    "Artysta" => :matter,
    "wystawa_fejkowa" => :roma,
    "natural_textures" => :solar,
    "Rothko" => :thermal,
    "Mark" => :deep,
    "Jackson Pollock" => :rust,
    "fake_networks_cleaned_2048" => :roma,
    "fake_networks_cleaned_2048_net5000" => :matter,
    "fake_networks_cleaned_2048_net5489" => :rust,
)

dset = unique_datasets[1]

pixels_per_cm = 28 * 2
width_in_cm = 19
height_in_cm = 15
f = Figure(size=(width_in_cm * pixels_per_cm, height_in_cm * pixels_per_cm))
fgl = CairoMakie.GridLayout(f[1, 1])
axis_args = (low_x=5e0, low_y=5e0, high_x=1e8, high_y=1e8)

dset = unique_datasets[1]
for (k, dset) in unique_datasets |> enumerate
    fgl_local = CairoMakie.GridLayout(fgl[1, k])
    ax = get_log_log_axis(fgl_local, 1, 1; axis_args...)

    set_related_df = filter(row -> row.dataset == dset, img_trajectories_df)
    dataset_files = set_related_df.file |> unique

    file_index = 1
    selected_file = dataset_files[file_index]
    set_colourscheme = cgrad(dataset_schemes[dset], dataset_files |> length, categorical=true)

    scatter_vector = []
    for (file_index, selected_file) in dataset_files |> enumerate
        file_related_df = filter(row -> row.file == selected_file, set_related_df)

        dim0_areas = file_related_df[:, :pland_area_dim0]
        dim1_areas = file_related_df[:, :pland_area_dim1]

        if dset == "wystawa_fejkowa"
            img_ordering = names_to_order[split(selected_file, ".jpg")[1]]
        else
            img_ordering = parse(Int, split(selected_file, ".jpg")[1])
        end
        file_color = set_colourscheme[img_ordering]
        file_alpha = 0.8

        lines!(
            ax,
            dim0_areas,
            dim1_areas,
            linestyle=:dash,
            color=(file_color, file_alpha),
        )
        for (marker_size, (selected_img_size, (selected_marker, label))) = zip(sizes, markers_labels) |> enumerate
            size_related_df = filter(row -> row.image_size == selected_img_size, file_related_df)

            scat_plt = scatter!(
                ax,
                size_related_df.pland_area_dim0[1],
                size_related_df.pland_area_dim1[1],
                color=(file_color, file_alpha),
                markersize=10,
                marker=selected_marker,
                strokecolor=(:black, 0.2),
                strokewidth=2,
            )
            if file_index == 1
                push!(scatter_vector, scat_plt)
            end
        end
    end # selected_file
    if dset == "Artysta"
        d_label = "Art"
    else
        d_label = "Pseudo-art"
    end
    if k == 1
        indicator = "a)"
    elseif k == 2
        indicator = "b)"
    end
    Label(fgl_local[0, :],
        "$(indicator) $(d_label)",
        tellheight=true,
        tellwidth=false,
        fontsize=18,
        justification=:left,
        halign=:left
    )
end #dset 

f


orig_images = @pipe filter(row -> row.dataset == dset, img_trajectories_df) |>
                    filter(row -> row.image_size == sizes[end-2], _)
images_sorting = orig_images.pland_area_dim0 |> sortperm
@info "Sorting of art images according to pland area dim 0 "
for df in eachrow(orig_images[images_sorting, :])
    @info "$(df.file) -> $(df.pland_area_dim0)"

end

# ===-===-
# Legend
markersizes = [4 for k in 1:2:(2*(sizes|>length))]
markers_for_legend1 = [MarkerElement(marker=m, color=:black,
    strokecolor=:transparent,
    markersize=25) for (m, label) in markers_labels]

art_colourscheme = cgrad(dataset_schemes["Artysta"], 12, categorical=true)
fake_colourscheme = cgrad(dataset_schemes["wystawa_fejkowa"], 12, categorical=true)
group_color1 = [PolyElement(color=color, strokecolor=:transparent)
                for color in art_colourscheme]
group_color2 = [PolyElement(color=color, strokecolor=:transparent)
                for color in fake_colourscheme]

art_files = filter(row -> row.dataset == "Artysta", img_trajectories_df).file |> unique
fake_files = filter(row -> row.dataset == "wystawa_fejkowa", img_trajectories_df).file |> unique

files_names1 = [split(k, ".jpg")[1] for k in art_files]
files_names2 = [k[1:min(10, length(k))] for k in fake_files]

art_ordering = [parse(Int, just_name) for just_name in files_names1] |> sortperm
fake_ordering = [names_to_order[just_name] for just_name in files_names2] |> sortperm

art_names = [art_images_names[parse(Int, just_name)] for just_name in files_names1][art_ordering]
fake_names = [@pipe names_to_order[just_name] |> fake_images_names[_] for just_name in files_names2][fake_ordering]

target_len = 15
short_names_art = String[]
short_names_fake = String[]
for (k, n) in art_names |> enumerate
    if length(n) > target_len
        while length(n) > target_len
            n = chop(n)
        end
        push!(short_names_art, "$(k). " * n * "...")
    else
        push!(short_names_art, "$(k). " * n)
    end
end

for (k, n) in fake_names |> enumerate
    if length(n) > target_len
        while length(n) > target_len
            n = chop(n)
        end
        push!(short_names_fake, "$(k). " * n * "...")
    else
        push!(short_names_fake, "$(k). " * n)
    end
end


# ---==---==---==
img_sizes = ["$(imgs.height)x$(imgs.width)" for imgs in sizes]

Legend(
    fgl[end+1, :],
    [markers_for_legend1,],
    [img_sizes,],
    ["Image size",],
    tellheight=true,
    # tellwidth=true,
    nbanks=8,
    framevisible=false
)
Legend(
    fgl[end+1, :],
    # Legend(fgl2[end+1, 1],
    [group_color1, group_color2],
    [short_names_art, short_names_fake],
    # ["Art images", "Artifically Generated images"],
    ["Art images", "Pseudo-art images"],
    tellheight=true,
    # tellwidth=true,
    nbanks=6,
    framevisible=false
)

f
# Save image
@info "Saving..."

total_sizes = length(sizes)
savename_val = @savename dset total_sizes

out_name = "image_trajectories_$(savename_val)"
path_png = plot_12c_dir("$(out_name).png")
safesave(path_png, f)

path_pdf = plot_12c_dir("pdf", "$(out_name).pdf")
safesave(path_pdf, f)

@info "Saved."


## ===-===-
do_nothing = "ok"
