#=
Load csv with bd info and plot distribution

=#

using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-
using Pipe
using DataStructures: OrderedDict
using Images
using Ripserer
using CairoMakie
using PersistenceLandscapes
using TopologyPreprocessing

import Base.Threads: @spawn, @sync
# ===-===-===-
"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include
"DataStructuresUtils.jl" |> srcdir |> include
"LandscapesPlotting.jl" |> srcdir |> include
"MakiePlots.jl" |> srcdir |> include
"HistogramManipulations.jl" |> srcdir |> include

import .CONFIG: preproc_img_dir, SELECTED_DIM, PERSISTENCE_THRESHOLD, DATA_SET, DATA_CONFIG
import .CONFIG: ripserer_computations_dir

@info "Arguments processed."
# ===-===-===-
extension = ".jpg"

# ===-===-===-

transformations = [
    Transformation(ContrastStretching, (t = 0.5, slope = 0.5))
    Transformation(ContrastStretching, (t = 0.5, slope = 1.5))
    Transformation(ContrastStretching, (t = 1.0, slope = 1))
    Transformation(ContrastStretching, (t = 1.5, slope = 1))
    Transformation(LinearStretching, (dst_minval = 0.2, dst_maxval = 0.8))
    Transformation(GammaCorrection, (gamma = 0.25,))
    Transformation(GammaCorrection, (gamma = 0.5,))
    Transformation(GammaCorrection, (gamma = 2,))
]

transformations_extended = [nothing, transformations...]

exec_range = 1:1
config_vec = ["BW", "WB"][exec_range]
persistence_data = populate_dict!(
    Dict(),
    [config_vec, ["dim0", "dim1"], [to_string(t) for t in transformations_extended]],
    final_structure = OrderedDict(),
)

do_rescaling = false
percentage_scale = 0.3


k = 5
transformation = transformations_extended[k]
selected_dim = 1
dataset = [fake_data, art_data][1]
file = dataset.files_names[2]
selected_dim = 0
exec_range = 1:1

dataset = all_datasets[1]
for dataset in all_datasets
    @info "Working on dataset $(dataset)"

    selected_files = if dataset == art_data
        dataset.files_names
    else
        dataset.files_names
    end

    for file in selected_files
        @info "Working on file $(file)"

        name = split(file, ".")[1]

        # Load image
        img1 = dataset.datadir(dataset.datadir_args..., name * extension) |> load
        img1_gray = Gray.(img1)

        k = 1
        transformation = transformations_extended[k]
        for (k, transformation) in enumerate(transformations_extended)
            @info transformation
            img_bw_adjusted = if isnothing(transformation)
                img1_gray
            else
                adjust_histogram(img1_gray, transformation |> execute)
            end

            img_for_computations = if do_rescaling
                new_size = trunc.(Int, size(img_bw_adjusted) .* percentage_scale)
                imresize(img_bw_adjusted, new_size)
            else
                img_bw_adjusted
            end

            scaled_img = floor.(Int, Gray.(img_for_computations) .* 255)
            scaled_img_WB = abs.(scaled_img .- 255)

            input_img = scaled_img
            # data_config = "BW"
            for (data_config, input_img) in
                zip(config_vec, [scaled_img, scaled_img_WB][exec_range])
                @info data_config

                loading_name = "$(name)"

                # ===-===-
                # Get cycles and their persistence
                alg = :homology
                reps = true
                cutoff = PERSISTENCE_THRESHOLD
                homology_config = @dict alg reps cutoff input_img transformation

                if do_rescaling
                    homology_config[:scaling] = percentage_scale
                end

                the_prefix = "homology_info_$(loading_name)_$(data_config)"
                if !isnothing(transformation)
                    the_prefix *= "_$(transformation.alg)"

                    for (arg, val) in zip(keys(transformation.args), transformation.args)
                        # @info arg val
                        the_prefix *= "_$(arg)=$(val)"
                    end

                end

                homology_data, p = produce_or_load(
                    ripserer_computations_dir(dataset.name, to_string(transformation)), # path
                    homology_config, # config
                    prefix = the_prefix, # file prefix
                    # force=true # force computations
                ) do homology_config
                    # do things
                    @unpack alg, reps, cutoff, input_img, transformation = homology_config
                    println("\tStarting homology computations...")
                    homolgy_result = ripserer(
                        Cubical(input_img),
                        cutoff = cutoff,
                        reps = reps,
                        alg = alg,
                    )
                    println("\tFinished homology computations. ")
                    # Last line is the dictionary with the results
                    Dict("homolgy_result" => homolgy_result)
                end # produce_or_load

                homology_info = homology_data["homolgy_result"]

                for (dim_index, selected_dim) in enumerate([0, 1])
                    births = [barcode[1] for barcode in homology_info[dim_index]]
                    deaths = [barcode[2] for barcode in homology_info[dim_index]]
                    persistances = [
                        persistence(barcode) for barcode in homology_info[dim_index] if
                        !isinf(persistence(barcode))
                    ]

                    # ===-
                    bd_data = [hcat(births, deaths)]
                    persistances = deaths - births
                    barcodes =
                        [MyPair(b, d) for (b, d) in zip(births, deaths)] |> PersistenceBarcodes

                    x_range = 0:255

                    if selected_dim == 1
                        betticurve_pt1 =
                            [(births .<= x .&& deaths .> x) |> sum for x in x_range[1:255]]
                        betticurve = vcat(betticurve_pt1, [0])
                    else
                        betticurve_pt1 =
                            [(births .<= x .&& deaths .> x) |> sum for x in x_range[1:255]]
                        betticurve = vcat(
                            betticurve_pt1,
                            [(births .<= 255 .&& deaths .>= 255) |> sum],
                        )
                    end

                    bettis = Dict(:x => x_range, :y => betticurve)

                    persistence_data[data_config]["dim$(selected_dim)"][to_string(
                        transformation,
                    )][loading_name] = Dict()
                    persistence_data[data_config]["dim$(selected_dim)"][to_string(
                        transformation,
                    )][loading_name]["landscapes"] = PersistenceLandscape(barcodes)
                    persistence_data[data_config]["dim$(selected_dim)"][to_string(
                        transformation,
                    )][loading_name]["barcodes"] = bd_data
                    persistence_data[data_config]["dim$(selected_dim)"][to_string(
                        transformation,
                    )][loading_name]["betti"] = bettis
                end # selected_dim
            end # config
        end # alg
    end #file
end # dataset

## ===-===-
do_nothing = "ok"
