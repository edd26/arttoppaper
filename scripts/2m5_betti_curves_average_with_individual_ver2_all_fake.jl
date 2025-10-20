
using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-
using DataStructures: OrderedDict
using DelimitedFiles
using Images
using PersistenceLandscapes
using CairoMakie
using Pipe
using Statistics
using Ripserer

import Base.Threads: @spawn, @sync

CairoMakie.set_theme!(fonts=(; regular="Arial", bold="Arial Bold"))
# ===-===-===-
"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include
"DataStructuresUtils.jl" |> srcdir |> include
"LandscapesPlotting.jl" |> srcdir |> include
"MakiePlots.jl" |> srcdir |> include

"ExtendedDatasetUtils.jl" |> srcdir |> include

# "HeatmapsUtils.jl" |> srcdir |> include

import .CONFIG: preproc_img_dir_set, SELECTED_DIM, PERSISTENCE_THRESHOLD, DATA_CONFIG
import .CONFIG: ripserer_computations_dir

@info "Arguments processed."
# ===-===-===-
readrows(file_name) = DelimitedFiles.readdlm(file_name, ',', Float64, '\n')
# ====================================================
selected_config = CONFIG.DATA_CONFIG
all_x_values = 0:255
all_x_index = 1:256
extension = ".jpg"

# ===-===-===-
# for d in artists_datasets

# artists_datasets =
# set2 = ["Jarema", "Malewicz", "Pollock", "Kandinsky", "Richter", "Rothko"]
#     set2 = ["art", "pseudoart"]
# artists_datasets = set2 = ["Jarema", "Malewicz", "Pollock", "Kandinsky", "Richter"]
total_img_per_artist = Dict()

alg = :homology
reps = true
cutoff = PERSISTENCE_THRESHOLD
force_computations = false

@sync for dataset in set2

    simple_img_dir(args...) = datadir(
        "exp_pro",
        "img_initial_preprocessing",
        CONFIG.DATA_CONFIG,
        dataset,
        args...,
    )

    files_list = simple_img_dir() |> readdir |> filter_out_hidden |> sort
    files_list = filter(x -> occursin(CONFIG.DATA_CONFIG, x), files_list)
    artist_bw_files_names = @pipe files_list |> [k[1] for k in split.(_, ".")]
    total_img_per_artist[dataset] = length(artist_bw_files_names)

    name = artist_bw_files_names[end]
    @spawn for name in artist_bw_files_names
        # for name in artist_bw_files_names
        @info "Working on file $(name)"


        # load image
        img1 = name * extension |> simple_img_dir |> load
        scaled_img = floor.(Int, gray.(img1) .* 255)
        scaled_img_wb = abs.(scaled_img .- 255)

        for (selected_config, input_img) = zip(["BW", "WB"], [scaled_img, scaled_img_wb])

            if selected_config == "BW"
                loading_name = name
            else
                loading_name = replace(name, "BW" => "WB")
            end

            @info "\t$(selected_config)"
            # ===-===-
            # get cycles and their persistence
            homology_config = @dict alg reps cutoff input_img

            homology_data, p = produce_or_load(
                ripserer_landscapes_dir(dataset, "image_$(replace(loading_name, ".jpg"=>""))"), # path
                homology_config, # config
                prefix="homology_info", # file prefix
                force=force_computations, # force computations
            ) do homology_config
                @unpack alg, reps, cutoff, input_img = homology_config
                println("\tStarting homology computations...")
                homolgy_result =
                    ripserer(Cubical(input_img), cutoff=cutoff, reps=reps, alg=alg)
                println("\tFinished homology computations. ")

                homology_info = homolgy_result
                births_dict = Dict()
                deaths_dict = Dict()
                landscapes_dict = Dict()
                println("\tStarting producion of landsacpes... ")
                for (dim_index, selected_dim) in enumerate([0, 1])
                    births = [barcode[1] for barcode in homology_info[dim_index]]
                    deaths = [barcode[2] for barcode in homology_info[dim_index]]
                    barcodes =
                        [MyPair(b, d) for (b, d) in zip(births, deaths)] |> PersistenceBarcodes

                    births_dict["dim$(selected_dim)"] = births
                    deaths_dict["dim$(selected_dim)"] = deaths
                    landscapes_dict["dim$(selected_dim)"] = PersistenceLandscape(barcodes)
                end # selected_dim
                println("\tFinished landsacpes. ")

                Dict("ripserer_landsacpes" => landscapes_dict,
                    "ripserer_births" => births_dict,
                    "ripserer_deaths" => deaths_dict,
                )
            end # produce_or_load
        end # config
    end #file
end #datafile

# ===-===-===-
dataset = "all_pseudoart"

simple_img_dir(args...) =
    datadir("exp_pro", "img_initial_preprocessing", CONFIG.DATA_CONFIG, dataset, args...)

files_list = simple_img_dir() |> readdir |> filter_out_hidden |> sort
files_list = filter(x -> occursin(CONFIG.DATA_CONFIG, x), files_list)
bw_files_names = @pipe files_list |> ["$(k[1])" for k in split.(_, ".")]

batch_size = 225
@sync for batch = 1:batch_size:4500
    @spawn for name in bw_files_names[batch:(batch+batch_size-1)]
        continue
        @info "Working on file $(name)"

        # load image
        img1 = name * extension |> simple_img_dir |> load
        scaled_img = floor.(Int, gray.(img1) .* 255)
        scaled_img_wb = abs.(scaled_img .- 255)

        for (selected_config, input_img) = zip(["BW", "WB"], [scaled_img, scaled_img_wb])

            if selected_config == "BW"
                loading_name = name
            else
                loading_name = replace(name, "BW" => "WB")
            end

            # @info selected_config
            # ===-===-
            # get cycles and their persistence
            homology_config = @dict alg reps cutoff input_img

            homology_data, p = produce_or_load(
                ripserer_landscapes_dir(dataset, "image_$(replace(loading_name, ".jpg"=>""))"), # path
                homology_config, # config
                prefix="homology_info", # file prefix
                force=force_computations, # force computations
            ) do homology_config
                @unpack alg, reps, cutoff, input_img = homology_config
                println("\tStarting homology computations...")
                homolgy_result =
                    ripserer(Cubical(input_img), cutoff=cutoff, reps=reps, alg=alg)
                println("\tFinished homology computations. ")

                homology_info = homolgy_result
                births_dict = Dict()
                deaths_dict = Dict()
                landscapes_dict = Dict()
                println("\tStarting producion of landsacpes... ")
                for (dim_index, selected_dim) in enumerate([0, 1])
                    births = [barcode[1] for barcode in homology_info[dim_index]]
                    deaths = [barcode[2] for barcode in homology_info[dim_index]]
                    barcodes =
                        [MyPair(b, d) for (b, d) in zip(births, deaths)] |> PersistenceBarcodes

                    births_dict["dim$(selected_dim)"] = births
                    deaths_dict["dim$(selected_dim)"] = deaths
                    landscapes_dict["dim$(selected_dim)"] = PersistenceLandscape(barcodes)
                end # selected_dim
                println("\tFinished landsacpes. ")

                Dict("ripserer_landsacpes" => landscapes_dict,
                    "ripserer_births" => births_dict,
                    "ripserer_deaths" => deaths_dict,
                )
            end # produce_or_load
        end # config
    end #file
end # batch

## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-

# @bprofile get_landscapes_sum(bw_files_names[1:32])
# @bprofile get_landscapes_sum(bw_files_names[1:64])
# @bprofile get_landscapes_sum(bw_files_names[1:128])
# @bprofile get_landscapes_sum(bw_files_names[1:256])
# @bprofile get_landscapes_sum(bw_files_names[1:512])
#
do_nothing = "ok"
