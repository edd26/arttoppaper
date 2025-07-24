
using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-
using DataStructures: OrderedDict
using DelimitedFiles
using Images
using PersistenceLandscapes
# using Makie
# using CairoMakie
using TopologyPreprocessing
using Pipe
using Ripserer

import Base.Threads: @spawn, @sync


# ===-===-===-
"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include
"DataStructuresUtils.jl" |> srcdir |> include
"LandscapesPlotting.jl" |> srcdir |> include
"MakiePlots.jl" |> srcdir |> include
"HeatmapsUtils.jl" |> srcdir |> include

import .CONFIG: preproc_img_dir, SELECTED_DIM, PERSISTENCE_THRESHOLD, DATA_SET, DATA_CONFIG
import .CONFIG: ripserer_computations_dir

@info "Arguments processed."
# ===-===-===-
readrows(file_name) = DelimitedFiles.readdlm(file_name, ',', Float64, '\n')

if DATA_SET == "fake"
    data_folder = "wystawa_fejkowa"
else
    data_folder = DATA_SET
end
# ===-===-===-
x_range = 0:255

extension = ".jpg"
simple_img_dir(args...) = datadir(
    "exp_pro",
    "img_initial_preprocessing",
    CONFIG.DATA_CONFIG,
    CONFIG.DATA_SET,
    args...,
)

files_list = simple_img_dir() |> readdir |> filter_out_hidden |> sort
files_names = [k[1] for k in split.(files_list, ".")] # |>

config_list = if CONFIG.DATA_CONFIG == "RGB"
    ["RGB"]
elseif CONFIG.DATA_CONFIG == "RGB_rev"
    ["RGB_rev"]
else
    ["BW", "WB"]
end

persistence_data =
    populate_dict!(Dict(), [config_list, ["dim0", "dim1"]], final_structure = OrderedDict())

all_homology_info = populate_dict!(Dict(), [config_list], final_structure = OrderedDict())


for file in files_names
    @info "Working on file $(file)"

    name = split(file, "_dim=")[1]

    # Load image
    img1 = name * extension |> simple_img_dir |> load
    scaled_img = floor.(Int, Gray.(img1) .* 255)
    img_list = if CONFIG.DATA_CONFIG == "RGB"
        [scaled_img]
    elseif CONFIG.DATA_CONFIG == "RGB_rev"
        scaled_img_WB = abs.(scaled_img .- 255)
        [scaled_img_WB]
    else
        scaled_img_WB = abs.(scaled_img .- 255)
        [scaled_img, scaled_img_WB]
    end

    for (CONFIG.DATA_CONFIG, input_img) in zip(config_list, img_list)

        if CONFIG.DATA_CONFIG == "BW" || CONFIG.DATA_CONFIG == "RGB"
            loading_name = name
        else
            loading_name = replace(name, "BW" => "WB")
        end

        @info CONFIG.DATA_CONFIG
        # ===-===-
        # Get cycles and their persistence
        alg = :homology
        reps = true
        cutoff = PERSISTENCE_THRESHOLD
        homology_config = @dict alg reps cutoff input_img

        homology_data, p = produce_or_load(
            ripserer_computations_dir(
                DATA_SET,
                "image_$(replace(loading_name, ".jpg"=>""))",
            ), # path
            homology_config, # config
            prefix = "homology_info", # file prefix
            # force=true # force computations
        ) do homology_config
            # do things
            @unpack alg, reps, cutoff, input_img = homology_config
            println("\tStarting homology computations...")
            homolgy_result =
                ripserer(Cubical(input_img), cutoff = cutoff, reps = reps, alg = alg)
            println("\tFinished homology computations. ")
            # Last line is the dictionary with the results
            Dict("homolgy_result" => homolgy_result)
        end # produce_or_load
        #     end
        # end

        homology_info = homology_data["homolgy_result"]
        all_homology_info[CONFIG.DATA_CONFIG][loading_name] = homology_info

        for (dim_index, selected_dim) in enumerate([0, 1])
            births = [barcode[1] for barcode in homology_info[dim_index]]
            deaths = [barcode[2] for barcode in homology_info[dim_index]]
            persistances = [
                persistence(barcode) for
                barcode in homology_info[dim_index] if !isinf(persistence(barcode))
            ]

            # ===-
            bd_data = [hcat(births, deaths)]
            persistances = deaths - births
            barcodes =
                [MyPair(b, d) for (b, d) in zip(births, deaths)] |> PersistenceBarcodes


            if selected_dim == 1
                betticurve_pt1 =
                    [(births .<= x .&& deaths .> x) |> sum for x in x_range[1:255]]
                betticurve = vcat(betticurve_pt1, [0])
            else
                betticurve_pt1 =
                    [(births .<= x .&& deaths .> x) |> sum for x in x_range[1:255]]
                betticurve =
                    vcat(betticurve_pt1, [(births .<= 255 .&& deaths .>= 255) |> sum])
            end

            bettis = Dict(:x => x_range, :y => betticurve)

            persistence_data[CONFIG.DATA_CONFIG]["dim$(selected_dim)"][loading_name] =
                Dict()
            persistence_data[CONFIG.DATA_CONFIG]["dim$(selected_dim)"][loading_name]["landscapes"] =
                PersistenceLandscape(barcodes)
            persistence_data[CONFIG.DATA_CONFIG]["dim$(selected_dim)"][loading_name]["barcodes"] =
                bd_data
            persistence_data[CONFIG.DATA_CONFIG]["dim$(selected_dim)"][loading_name]["betti"] =
                bettis
        end # selected_dim
    end # config
end #file

# ===-===-
do_nothing = "ok"
