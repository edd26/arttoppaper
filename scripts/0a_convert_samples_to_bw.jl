#=
Load an sample of the data, convert it to greyscale image, display image.

=#

using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-===-===-===-===-===-
using Images

# ===-===-===-===-===-===-===-===-
"config.jl" |> scriptsdir |> include

import .CONFIG: SELECTED_DIM, PERSISTENCE_THRESHOLD, DATA_SET

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# Image loading
set1 = ["art", "pseudoart"]
data_sets = [path for path in CONFIG.raw_paths if any(occursin.(set1, path[1]))]

for raw_path in data_sets

    raw_img_path(args...) = datadir("exp_raw", raw_path..., args...)
    all_sample_files =
        [k for k in raw_img_path() |> readdir if occursin("jpg", k) || occursin("png", k)]

    for sample_image in all_sample_files
        @info sample_image
        channelview_img = sample_image |> raw_img_path |> load |> channelview
        base_name, extension = split(sample_image, ".")

        if CONFIG.DATA_CONFIG == "RGB"
            @info "Woringk on RGB"

            for (col_index, col) in ["R", "G", "B"] |> enumerate
                @info col
                output_file = datadir(
                    "exp_pro",
                    "img_initial_preprocessing",
                    CONFIG.DATA_CONFIG,
                    raw_path...,
                    base_name * "_$(col).$(extension )",
                )

                bw_color_img = channelview_img[col_index, :, :] .|> Gray
                # Images.save(output_file, bw_color_img )
                @info "Saved as " output_file
                Images.save(output_file, bw_color_img)
            end
        elseif CONFIG.DATA_CONFIG == "RGB_rev"
            @info "Woringk on RGB reversed"

            for (col_index, col) in ["R", "G", "B"] |> enumerate
                @info col
                output_file = datadir(
                    "exp_pro",
                    "img_initial_preprocessing",
                    CONFIG.DATA_CONFIG,
                    raw_path...,
                    base_name * "_$(col)_rev.$(extension )",
                )

                bw_color_img = channelview_img[col_index, :, :] .|> Gray
                rev_rgb_img = (size(bw_color_img) |> ones .|> Gray) .- bw_color_img
                @info "Saved as " output_file
                Images.save(output_file, rev_rgb_img)
            end
        elseif CONFIG.DATA_CONFIG == "BW"
            output_file = datadir(
                "exp_pro",
                "img_initial_preprocessing",
                CONFIG.DATA_CONFIG,
                raw_path...,
                base_name * "_$(CONFIG.DATA_CONFIG).$(extension )",
            )

            if output_file |> isfile && !(CONFIG.force_image_export)
                @warn "File already exists! Skipping..."
                continue
            elseif output_file |> isfile && CONFIG.force_image_export
                @warn "File already exists but witll be overwritten (forced)..."
            else
                @info "Saving " sample_image
            end # if file exists

            bw_img = sample_image |> raw_img_path |> load .|> Gray
            @info "Saved as " output_file
            Images.save(output_file, bw_img)
        elseif CONFIG.DATA_CONFIG == "WB"
            output_file = datadir(
                "exp_pro",
                "img_initial_preprocessing",
                CONFIG.DATA_CONFIG,
                raw_path...,
                base_name * "_$(CONFIG.DATA_CONFIG).$(extension )",
            )

            function invert_colors(c)
                return RGB(
                    clamp(1 - red(c), 0 .. 1),
                    clamp(1 - green(c), 0 .. 1),
                    clamp(1 - blue(c), 0 .. 1),
                )
            end
            function invert_colors2(c)
                return Gray(clamp(1 - c, 0 .. 1))
            end

            bw_img = sample_image |> raw_img_path |> load .|> Gray #.|>
            bw_img = (size(bw_img) |> ones .|> Gray) .- bw_img
            @info "Saved as " output_file
            Images.save(output_file, bw_img)
        end
    end # for sample
    # end # if 
end # for paths
