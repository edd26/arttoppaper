#=
Load an sample of the data, convert it to BW image, display image.

=#
import DrWatson: @quickactivate, datadir, scriptsdir, srcdir
@quickactivate "ArtTopology"

## ===-===-===-===-===-===-===-===-
using Images
using Pipe

## ===-===-===-===-===-===-===-===-
"config.jl" |> scriptsdir |> include

"loading_utils.jl" |> srcdir |> include

## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
script_prefix = "0f"
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# Image loading
using ImageFiltering


path_args = [p for p in CONFIG.raw_paths if occursin("fake_networks_cleaned", p[1])][1]

img_height = 256
img_width = 180
img_start = 256 ÷ 2 - img_width ÷ 2 + 1 # more
# img_start = 256 ÷ 2 - img_width ÷ 2 + 2
patch_size = (3, 3)
##

raw_img_path(args...) = datadir("exp_raw", path_args..., args...)

all_sample_files =
    [k for k in raw_img_path() |> readdir if occursin("jpg", k) || occursin("png", k)] |>
    filter_out_DS |>
    filter_out_hidden

sample_image = all_sample_files[123]
for sample_image in all_sample_files
    @info "Working on" sample_image

    # k = 821
    cut_resized_bw_img = (@pipe sample_image |> raw_img_path |> load .|> Gray # |>
    # mapwindow(median, _, patch_size) |>
    # imfilter(_, Kernel.gaussian(1.4)) |>
    #   imresize(_, ratio=1 / 1)
    )[
        :,
        8img_start:(8img_start+8img_width-1),
    ]
    # )[:, img_start:(img_start+img_width-r)]

    # pixel_fixek = imresize(cut_resized_bw_img, 256, 180,)
    # pixel_fixed = @pipe imresize(cut_resized_bw_img, 256, 180,) |>
    # imfilter(_, Kernel.gaussian([0.4, 0.4], [7, 7]))
    # img = imresize(cut_resized_bw_img, 256, 180,)
    # pixel_fixed = 

    # new_name = "cut_resized_" * sample_image
    # new_name = * "_"*
    new_name_png = split(sample_image, ".jpg")[1] * "_$(CONFIG.data_config).jpg"

    Images.save(
        datadir(
            "exp_pro",
            "img_initial_preprocessing",
            CONFIG.data_config,
            path_args...,
            new_name_png,
        ),
        cut_resized_bw_img,
        # pixel_fixed
    )
end
@info "$(script_prefix): Finished image processing."
