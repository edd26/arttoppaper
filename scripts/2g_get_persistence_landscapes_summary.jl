
using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-
using DataStructures: OrderedDict
using DelimitedFiles
using DataFrames
using Images
using PersistenceLandscapes
using Pipe
using Ripserer

# ===-===-===-
"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include

# ===-===-
import .CONFIG:
    preproc_img_dir_set,
    SELECTED_DIM,
    PERSISTENCE_THRESHOLD,
    DATA_CONFIG,
    DATA_SET,
    total_trials,
    ripserer_computations_dir

@info "Arguments processed."
# ===-===-===-
script_prefix = "2g"
readrows(file_name) = DelimitedFiles.readdlm(file_name, ',', Float64, '\n')
landscapes_dir(args...) =
    datadir("exp_pro", "section2", script_prefix, "landscapes_df", args...)

## ===-===-===-===-===-===-===-===-===-===-
set1 = ["art", "pseudoart"]
data_sets = set1

# ===-
setup = DATA_CONFIG
last_of_filtration = 255
extension = ".jpg"

land_areas = DataFrame(
    dataset = String[],
    landscape = Any[],
    pland_area = Float64[],
    dim = Int[],
    threshold = Float64[],
    file = String[],
)

for data in data_sets
    @info "Working on $(data)"

    do_force = false

    thr = PERSISTENCE_THRESHOLD
    config = @dict data setup thr
    landscapes_df, p = produce_or_load(
        landscapes_dir(),
        config,
        prefix = "landscape_df",
        force = false,
    ) do config
        @unpack data, setup, thr, = config

        # for file in filtered_list
        land_area = DataFrame(
            dataset = String[],
            landscape = Any[],
            pland_area = Float64[],
            dim = Int[],
            threshold = Float64[],
            file = String[],
        )

        simple_img_dir(args...) =
            datadir("exp_pro", "img_initial_preprocessing", "$(setup)", data, args...)

        files_list = simple_img_dir() |> readdir |> filter_out_hidden |> sort
        files_list = filter(x -> occursin("$(CONFIG.DATA_CONFIG)", x), files_list)
        files_names = @pipe files_list |> [k[1] for k in split.(_, ".")]

        file = files_names[1]
        for file in files_names
            @info "\tComputing landscapes info for file: " file

            img1 = file * extension |> simple_img_dir |> load
            scaled_img = floor.(Int, Gray.(img1) .* last_of_filtration)
            scaled_img_WB = abs.(scaled_img .- last_of_filtration)

            selected_dim = 0
            input_img = scaled_img

            data_dir = if data == "pseudoart"
                "pseudoart"
            else
                data
            end
            # >>>>
            alg = :homology
            reps = true
            cutoff = PERSISTENCE_THRESHOLD
            homology_config = @dict alg reps cutoff input_img

            homology_data, p = produce_or_load(
                ripserer_computations_dir(data_dir, "image_$(replace(file, ".jpg"=>""))"), # path
                homology_config, # config
                prefix = "homology_info", # file prefix
                # force=true # force computations
            ) do homology_config
                # do things
                @unpack alg, reps, cutoff, input_img = homology_config
                println("\tStarting homology computations...")
                homolgy_result = ripserer(
                    Cubical(input_img),
                    cutoff = cutoff,
                    reps = reps,
                    alg = alg,
                )
                println("\tFinished homology computations. ")
                Dict("homolgy_result" => homolgy_result)
            end # produce_or_load

            homology_info = homology_data["homolgy_result"]

            # <<<<
            dim_index = 1
            local_dim = 0
            for (dim_index, local_dim) in enumerate([0, 1])# , persistence_threshold = [PERSISTENCE_THRESHOLD,]
                @info "Dimension: " local_dim

                homology_info[dim_index]


                births = [p[1] for p in homology_info[dim_index]]
                deaths = [p[2] for p in homology_info[dim_index]]

                landscape =
                    [MyPair(b, d) for (b, d) in zip(births, deaths)] |>
                    PersistenceBarcodes |>
                    PersistenceLandscape

                push!(
                    land_area,
                    (
                        dataset = data,
                        landscape = landscape,
                        pland_area = landscape |> computeIntegralOfLandscape,
                        dim = local_dim,
                        threshold = PERSISTENCE_THRESHOLD,
                        file = split(file, "_dim=")[1],
                    ),
                )
            end # dataset
        end
        Dict("landscapes_df" => land_area)
    end # produce_or_load

    @info "Appending...\n"
    global land_areas = vcat(land_areas, landscapes_df["landscapes_df"])
    @info "Finished appending"
end

## ===-===-
do_nothing = "ok"
