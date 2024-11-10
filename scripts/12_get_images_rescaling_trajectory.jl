using DrWatson
@quickactivate "ArtTopology"

# ===-===-===-
using DataStructures: OrderedDict
# using DelimitedFiles
using DataFrames
using Images
using PersistenceLandscapes
# using TopologyPreprocessing

# using Random
import Base.Threads: @spawn, @sync

# ===-===-===-
"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include
"DataStructuresUtils.jl" |> srcdir |> include

"dipha_utils.jl" |> srcdir |> include

"SequenceAnalysis.jl" |> srcdir |> include
# ===-===-
import .CONFIG: dipha_bd_info_export_folder,
    export_for_dipha_folder_set,
    preproc_img_dir_set,
    SELECTED_DIM,
    PERSISTENCE_THRESHOLD,
    DATA_CONFIG,
    DATA_SET,
    dipha_bd_info_export_folder_set,
    TOTAL_TRIALS

import .CONFIG: export_for_dipha_folder, dipha_raw_export_folder, dipha_bd_info_export_folder, dipha_exec
@info "Arguments processed."

## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# Pre-definitions
script_prefix = "12"
landscapes_dir(args...) = datadir("exp_pro", "section12", script_prefix * "-images-trajectories", args...)


## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# Get the images with their paths
art_raw_path = [k for k in CONFIG.raw_paths if occursin("Artysta", k[1],)][1]
fake_exhibition_raw_path = [k for k in CONFIG.raw_paths if occursin("wystawa", k[1])][1]

selected_paths = [
    art_raw_path,
    fake_exhibition_raw_path,
]

# ===-===-
raw_img_path(args...) = datadir("exp_raw", args...)

files_list_pt1 = [
    [k for k in raw_img_path(rpath...) |> readdir if !occursin("pdf", k)
    ] |> filter_out_hidden
    for rpath in selected_paths
]

net = 2
files_list_pt2 = files_list_pt1

# ===-===-
data_to_process = [
    ImagesSequence(raw_img_path(art_raw_path...), files_list_pt2[1])
    ImagesSequence(raw_img_path(fake_exhibition_raw_path...), files_list_pt2[2])
]

## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# How all images will be rescaled?
sizes = [
    # ImgSize(32, 32),
    ImgSize(45, 64,),
    # ImgSize(64, 64),
    ImgSize(90, 128,),
    # ImgSize(128, 128,),
    ImgSize(180, 256,),
    # ImgSize(256, 256,),
    ImgSize(359, 512,),
    # ImgSize(512, 512),
    ImgSize(716, 1024,),
    # ImgSize(1024, 1024),
    ImgSize(1434, 2048,),
    # ImgSize(2048, 2048),
    ImgSize(2160, 3072),
    # ImgSize(3072, 3072),
    ImgSize(2868, 4096),
    # ImgSize(4096, 4096),
]

## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# for every data to process, for every image

img_trajectories_df = DataFrame(
    file=String[],
    dataset=String[],
    image_size=ImgSize[],
    landscape_dim0=Any[],
    pland_area_dim0=Float64[],
    landscape_dim1=Any[],
    pland_area_dim1=Float64[],
)


for images_sequence in data_to_process
    total_images = images_sequence |> length
    img_index = 12
    for img_index in 1:total_images
        # 1. Load -> 2. loop (3. rescale -> 4. get topology -> 5. get landscapes)

        my_img = get_img_from_sequence(images_sequence, img_index)
        loaded_img = load_from_sequence(my_img)

        # ===-===-
        # 1. Make sure the longer dimension is the width 
        img_height, img_width = size(loaded_img)

        if img_height > img_width
            adjusted_img = loaded_img' |> typeof(loaded_img)
        else
            adjusted_img = loaded_img
        end
        bw_img = adjusted_img .|> Gray

        # ===-===-
        # 2.
        img_size = sizes[1]
        # @spawn for img_size in sizes
        for img_size in sizes
            img_width = img_size.width
            img_height = img_size.height
            img_name = my_img.img_name
            img_dataset = my_img.img_dataset
            config = @dict bw_img img_width img_height img_name img_dataset
            @info "Working on " config

            ## ===-===-===-===-===-===-===-===-===-===-
            # produce_or_load
            landsacpes_info, p = produce_or_load(
                landscapes_dir(),
                config,
                prefix="landscapes_trajectory",
                # force=true
            ) do config
                @unpack bw_img, img_width, img_height, img_name, img_dataset = config
                @info img_width, img_height, img_name, img_dataset

                # 3.
                bw_img_resized = imresize(bw_img, img_width, img_height)

                # 4. 
                bd_matrix = get_barcodes_info_with_dipha(bw_img_resized, img_name, img_dataset, id="$(img_name)_$(img_width)_$(img_height)_$(img_dataset)")
                survivals_matrix = get_survival_barcodes(bd_matrix, CONFIG.PERSISTENCE_THRESHOLD)

                # 5.
                img_landscapes = ImageLandscapes(survivals_matrix)

                dim0_pland = 0
                dim1_pland = 0
                if !isempty(img_landscapes.landscape_dim0.land)
                    dim0_pland = img_landscapes.landscape_dim0 |> computeIntegralOfLandscape
                end
                if !isempty(img_landscapes.landscape_dim1.land)
                    dim1_pland = img_landscapes.landscape_dim1 |> computeIntegralOfLandscape
                end
                landsacpes_info = Dict(
                    "land_dim0" => img_landscapes.landscape_dim0,
                    "land_dim1" => img_landscapes.landscape_dim1,
                    "dim0_area" => dim0_pland,
                    "dim1_area" => dim1_pland
                )
            end# produce_or_load
            push!(img_trajectories_df,
                (
                    file=img_name,
                    dataset=img_dataset,
                    image_size=img_size,
                    landscape_dim0=landsacpes_info["land_dim0"],
                    pland_area_dim0=landsacpes_info["dim0_area"],
                    landscape_dim1=landsacpes_info["land_dim1"],
                    pland_area_dim1=landsacpes_info["dim1_area"]
                )
            )
        end # img_size 
    end # img_index
end # images_sequence 


## ===-===-
do_nothing = "ok"
