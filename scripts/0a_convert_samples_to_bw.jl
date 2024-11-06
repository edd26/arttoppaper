using DrWatson
@quickactivate "ArtTopology"

# ===-===-===-===-===-===-===-===-
using Images

# ===-===-===-===-===-===-===-===-
"config.jl" |> scriptsdir |> include

import .CONFIG: SELECTED_DIM, PERSISTENCE_THRESHOLD, DATA_SET, DATA_CONFIG
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# import .CONFIG: dipha_img_export_path
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# Image loading
set1 = ["Artysta", "wystawa_fejkowa"]# , "noise_images", "Artysta_heatmaps"]
set2 = ["Real_Kandinsky", "Faked_Kandinsky"]
set3 = ["Pollock", "Rothko", "Mark"]
set4 = ["textures", "non-textures"]
set5 = ["Malewicz", "Rothko", "Jarema", "Richter", "Mark"]
set6 = ["mixed-art",]
set7 = ["fractals",]

if DATA_SET in set1
    data_sets = [path for path in CONFIG.raw_paths if any(occursin.(set1, path[1]))]
elseif DATA_SET in set2
    data_sets = [path for path in CONFIG.raw_paths if any(occursin.(set2, path[1]))]
elseif DATA_SET in set3
    data_sets = [path for path in CONFIG.raw_paths if any(occursin.(set3, path[1]))]
elseif DATA_SET in set4
    data_sets = [path for path in CONFIG.raw_paths if any(occursin.(set4, path[1]))]
elseif DATA_SET in set5
    data_sets = [path for path in CONFIG.raw_paths if any(occursin.(set5, path[1]))]
elseif DATA_SET in set6
    data_sets = [path for path in CONFIG.raw_paths if any(occursin.(set6, path[1]))]
elseif DATA_SET in set7
    data_sets = [path for path in CONFIG.raw_paths if any(occursin.(set7, path[1]))]
else
    data_sets = [path for path in CONFIG.raw_paths if any(occursin.([DATA_SET,], path[1]))]
    @warn "Unrecognised set"
end

for raw_path in data_sets

    # if CONFIG.data_set != raw_path[1]
    #     @info "Skipping for $(raw_path)"
    #     continue
    # else
    raw_img_path(args...) = datadir("exp_raw", raw_path..., args...)
    all_sample_files = [k for k in raw_img_path() |> readdir if occursin("jpg", k) || occursin("png", k)]

    # sample_image = all_sample_files[1]
    for sample_image = all_sample_files
        @info sample_image
        channelview_img = sample_image |> raw_img_path |> load |> channelview
        base_name, extension = split(sample_image, ".")

        if CONFIG.DATA_CONFIG == "RGB"
            @info "Woringk on RGB"

            for (col_index, col) in ["R", "G", "B"] |> enumerate
                @info col
                output_file = datadir("exp_pro", "img_initial_preprocessing", DATA_CONFIG, raw_path..., base_name * "_$(col).$(extension )")

                bw_color_img = channelview_img[col_index, :, :] .|> Gray
                # Images.save(output_file, bw_color_img )
                @info "Saved as " output_file
                Images.save(output_file, bw_color_img)
            end
        elseif CONFIG.DATA_CONFIG == "BW"
            output_file = datadir("exp_pro", "img_initial_preprocessing", DATA_CONFIG, raw_path..., base_name * "_$(DATA_CONFIG).$(extension )")

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
            output_file = datadir("exp_pro", "img_initial_preprocessing", DATA_CONFIG, raw_path..., base_name * "_$(DATA_CONFIG).$(extension )")

            # if output_file |> isfile && !(CONFIG.force_image_export)
            #     @warn "File already exists! Skipping..."
            #     continue
            # elseif output_file |> isfile && CONFIG.force_image_export
            #     @warn "File already exists but witll be overwritten (forced)..."
            # else
            #     @info "Saving " sample_image
            # end # if file exists

            function invert_colors(c)
                return RGB(clamp(1 - red(c), 0 .. 1),
                    clamp(1 - green(c), 0 .. 1),
                    clamp(1 - blue(c), 0 .. 1))
            end
            function invert_colors2(c)
                return Gray(clamp(1 - c, 0 .. 1))
            end

            bw_img = sample_image |>
                     raw_img_path |>
                     load .|>
                     Gray #.|>
            bw_img = (size(bw_img) |> ones .|> Gray) .- bw_img
            @info "Saved as " output_file
            Images.save(output_file, bw_img)
        end
    end # for sample
    # end # if 
end # for paths
