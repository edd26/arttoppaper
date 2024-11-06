using DrWatson
@quickactivate "ArtTopology"

# ===-===-===-
using DataStructures: OrderedDict
using DelimitedFiles
using DataFrames
using Images
using PersistenceLandscapes
using StatsPlots
using TopologyPreprocessing
import Base.Threads: @spawn, @sync

# ===-===-===-
"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include

# ===-===-
import .CONFIG: dipha_bd_info_export_folder,
    export_for_dipha_folder_set,
    preproc_img_dir_set,
    SELECTED_DIM,
    PERSISTENCE_THRESHOLD,
    DATA_CONFIG,
    DATA_SET,
    dipha_bd_info_export_folder_set,
    total_trials

@info "Arguments processed."
# ===-===-===-
script_prefix = "2g"
readrows(file_name) = DelimitedFiles.readdlm(file_name, ',', Float64, '\n')
landscapes_dir(args...) = datadir("exp_pro", "section2", script_prefix, "landscapes_df", args...)

## ===-===-===-===-===-===-===-===-===-===-
set1 = ["Artysta", "wystawa_fejkowa"]
data_sets = set1

useddata = join(data_sets, "-")
# ===-
setup = DATA_CONFIG

land_areas = DataFrame(
    dataset=String[],
    landscape=Any[],
    pland_area=Float64[],
    dim=Int[],
    threshold=Float64[],
    file=String[],
)

for data in data_sets
    @info "Working on $(data)"

    do_force = false

    thr = PERSISTENCE_THRESHOLD
    config = @dict data setup thr
    landscapes_df, p = produce_or_load(
        landscapes_dir(),
        config,
        prefix="landscape_df",
        force=do_force
    ) do config

        # for file in filtered_list
        land_area = DataFrame(
            dataset=String[],
            landscape=Any[],
            pland_area=Float64[],
            dim=Int[],
            threshold=Float64[],
            file=String[],
        )

        # noise data couldn't have been processed because there are too many topological features
        for local_dim in [0, 1], persistence_threshold = [PERSISTENCE_THRESHOLD,]
            @info "dataset : " data

            files_folder(args...) = dipha_bd_info_export_folder(setup, data, "dim=$(local_dim)", args...)

            files_list = files_folder() |> readdir |> filter_out_hidden |> sort
            filtered_list = filter_out_by_threshold(files_list, persistence_threshold)

            for file in filtered_list
                @info "\tComputing landscapes info for file: " file

                data_matrix = zeros(1, 3)
                try
                    data_matrix = files_folder(file) |> readrows
                catch
                    @warn "Failed to read csv file " file
                end
                births = data_matrix[:, 2]
                deaths = data_matrix[:, 3]

                landscape = [MyPair(b, d) for (b, d) in zip(births, deaths)] |> PersistenceBarcodes |> PersistenceLandscape

                push!(land_area,
                    (dataset=data,
                        landscape=landscape,
                        pland_area=landscape |> computeIntegralOfLandscape,
                        dim=local_dim,
                        threshold=persistence_threshold,
                        file=split(file, "_dim=")[1],
                    ))
            end # dataset
        end
        Dict("landscapes_df" => land_area)
    end # produce_or_load

    @info "Appending...\n"
    global land_areas = vcat(land_areas, landscapes_df["landscapes_df"])
end

## ===-===-
do_nothing = "ok"
