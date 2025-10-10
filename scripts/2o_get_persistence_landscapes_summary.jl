
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
script_prefix = "2o"
readrows(file_name) = DelimitedFiles.readdlm(file_name, ',', Float64, '\n')
landscapes_dir(args...) =
    datadir("exp_pro", "section2", script_prefix, "landscapes_df", args...)

## ===-===-===-===-===-===-===-===-===-===-
land_areas = DataFrame(
    dataset = String[],
    pland_area = Float64[],
    dim = Int[],
    threshold = Float64[],
    file = String[],
)

# TODO missing here, but in 2m5, (artists_datasets, load_landscape)
for d in artists_datasets
    @info "Working on $(d)..."

    simple_img_dir(args...) =
        datadir("exp_pro", "img_initial_preprocessing", CONFIG.DATA_CONFIG, d, args...)

    files_list = simple_img_dir() |> readdir |> filter_out_hidden |> sort
    files_list = filter(x -> occursin(CONFIG.DATA_CONFIG, x), files_list)
    artist_bw_files_names = @pipe files_list |> ["$(k[1])" for k in split.(_, ".")]

    for f in artist_bw_files_names
        landscapes = load_landscape(f, d)
        pland_area_dim0 = landscapes["dim0"] |> computeIntegralOfLandscape
        pland_area_dim1 = landscapes["dim1"] |> computeIntegralOfLandscape

        push!(
            land_areas,
            (
                dataset = d,
                pland_area = pland_area_dim0,
                dim = 0,
                threshold = CONFIG.PERSISTENCE_THRESHOLD,
                file = f,
            ),
        )
        push!(
            land_areas,
            (
                dataset = d,
                pland_area = pland_area_dim1,
                dim = 1,
                threshold = CONFIG.PERSISTENCE_THRESHOLD,
                file = f,
            ),
        )
    end
end

# ===-
# All pseudoart
#

d = "all_pseudoart"
@info "Working on $(d)..."

simple_img_dir(args...) =
    datadir("exp_pro", "img_initial_preprocessing", CONFIG.DATA_CONFIG, d, args...)

files_list = simple_img_dir() |> readdir |> filter_out_hidden |> sort
files_list = filter(x -> occursin(CONFIG.DATA_CONFIG, x), files_list)
pseudoart_bw_files_names = @pipe files_list |> ["$(k[1])" for k in split.(_, ".")]

f = pseudoart_bw_files_names[1]
for (i, f) in enumerate(pseudoart_bw_files_names)

    if i % 100 == 0
        @info f
    end

    landscapes = load_landscape(f, d)

    pland_area_dim0 = if isempty(landscapes["dim0"].land)
        0
    else
        landscapes["dim0"] |> computeIntegralOfLandscape
    end
    pland_area_dim1 = if isempty(landscapes["dim1"].land)
        0
    else
        landscapes["dim1"] |> computeIntegralOfLandscape
    end

    push!(
        land_areas,
        (
            dataset = d,
            pland_area = pland_area_dim0,
            dim = 0,
            threshold = CONFIG.PERSISTENCE_THRESHOLD,
            file = f,
        ),
    )
    push!(
        land_areas,
        (
            dataset = d,
            pland_area = pland_area_dim1,
            dim = 1,
            threshold = CONFIG.PERSISTENCE_THRESHOLD,
            file = f,
        ),
    )
end

## ===-===-
do_nothing = "ok"
