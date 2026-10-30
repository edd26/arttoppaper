#=
Shared data loader for 2f3b and 2f3h.
Computes persistence homology (0–255 filtration, threshold cutoff) for all images
in the configured dataset. Produces `persistence_data` and `all_homology_info`.
=#

using DrWatson
@quickactivate "arttopopaper"

using DataStructures: OrderedDict
using DelimitedFiles
using Images
using PersistenceLandscapes
using Pipe
using Ripserer

"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include
"DataStructuresUtils.jl" |> srcdir |> include

import .CONFIG: preproc_img_dir, SELECTED_DIM, PERSISTENCE_THRESHOLD, DATA_SET, DATA_CONFIG
import .CONFIG: ripserer_computations_dir

@info "Arguments processed."

readrows(file_name) = DelimitedFiles.readdlm(file_name, ',', Float64, '\n')

x_range = 0:255

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

data_folder = DATA_SET

simple_img_dir(args...) = datadir(
    "exp_pro", "img_initial_preprocessing", CONFIG.DATA_CONFIG, DATA_SET, args...
)

files_list = simple_img_dir() |> readdir |> filter_out_hidden |> sort
extension = isempty(files_list) ? ".png" : splitext(first(files_list))[2]
files_names = [splitext(f)[1] for f in files_list]

alg = :homology
reps = true

for file in files_names
    name = split(file, "_dim=")[1]
    @info "Working on file $(file)"

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

    for (local_config, input_img) in zip(config_list, img_list)
        loading_name = if local_config == "WB"
            replace(name, "BW" => "WB")
        else
            name
        end

        @info local_config

        cutoff = PERSISTENCE_THRESHOLD
        homology_config = @dict alg reps cutoff input_img

        homology_data, p = produce_or_load(
            ripserer_computations_dir(DATA_SET, "image_$(replace(loading_name, extension => ""))"),
            homology_config,
            prefix = "homology_info",
        ) do homology_config
            @unpack alg, reps, cutoff, input_img = homology_config
            println("\tStarting homology computations...")
            homolgy_result =
                ripserer(Cubical(input_img), cutoff = cutoff, reps = reps, alg = alg)
            println("\tFinished homology computations.")
            Dict("homolgy_result" => homolgy_result)
        end

        homology_info = homology_data["homolgy_result"]
        all_homology_info[local_config][loading_name] = homology_info

        for (dim_index, selected_dim) in enumerate([0, 1])
            births = [barcode[1] for barcode in homology_info[dim_index]]
            deaths = [barcode[2] for barcode in homology_info[dim_index]]

            births = replace(births, Inf => 255)
            deaths = replace(deaths, Inf => 255)

            bd_data = [hcat(births, deaths)]
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

            persistence_data[local_config]["dim$(selected_dim)"][loading_name] = Dict()
            persistence_data[local_config]["dim$(selected_dim)"][loading_name]["landscapes"] =
                PersistenceLandscape(barcodes)
            persistence_data[local_config]["dim$(selected_dim)"][loading_name]["barcodes"] =
                bd_data
            persistence_data[local_config]["dim$(selected_dim)"][loading_name]["betti"] =
                bettis
        end
    end
end

do_nothing = "ok"
