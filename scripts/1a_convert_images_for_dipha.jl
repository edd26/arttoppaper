#=
First stage of processing for cubical complexes- image conversion
=#

using DrWatson
@quickactivate "ArtTopology"
## ===-===-===-===-
using Images

## ===-===-===-===-
"dipha_utils.jl" |> srcdir |> include
"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include

## ===-===-===-===-
import .CONFIG: preproc_img_dir_set, export_for_dipha_folder_set

## ===-===-===-===-
if ~(export_for_dipha_folder_set() |> isdir)
    export_for_dipha_folder_set() |> mkpath
end

## ===-===-===-===-
files_list_pt1 = [k for k in preproc_img_dir_set() |> readdir if !occursin("pdf", k)] |> filter_out_DS
files_list = [k for k in files_list_pt1 if occursin("png", k)]
files_list |> isempty && (files_list = [k for k in files_list_pt1 if occursin("jpg", k)])

# missing files list
# files_list = [
#     "net_5364_1.jpg"
#     "net_5365_1.jpg"
#     "net_5067_2.jpg"
#     "net_5068_2.jpg"
#     "net_5033_3.jpg"
#     "net_5034_3.jpg"
#     "net_5413_6.jpg"
#     "net_5414_6.jpg"
#     "net_5382_7.jpg"
#     "net_5383_7.jpg"
#     "net_5066_8.jpg"
#     "net_5066_8.jpg"
# ]

for file in files_list
    @info "Converting file:" file
    if occursin("png", file)
        name = split(file, ".png")[1]
    elseif occursin("jpg", file)
        name = split(file, ".jpg")[1]
    end

    loaded_img = preproc_img_dir_set(file) |> load .|> Gray |> Matrix{Float64}
    scaled_img = ceil.(Int, loaded_img .* 255)

    export_file_name = export_for_dipha_folder_set(name)
    save_image_data(scaled_img, export_file_name)
end
