using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-===-
using DataFrames
using JLD2
using CSV
using Pipe
using PersistenceLandscapes

# ===-
"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include

# ===-===-===-===-===-===-
data_folder(args...) = datadir("exp_pro", "image_complexity", args...)
FSlope_folder(args...) = data_folder("FourierSlope", args...)
PHOG_folder(args...) = data_folder("PHOG", args...)
EdgeOrientation_folder(args...) = data_folder("EdgeOrientationEntropy", args...)

# ===-
selected_data1 = "art"
selected_data2 = "pseudoart"

# ===-===-===-===-===-===-
data_names_vec = [selected_data1, selected_data2]

useddata = join(data_names_vec, "-")
thr = CONFIG.PERSISTENCE_THRESHOLD
setup = "BW"

## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# Load the data
land_areas_df = DataFrame(
    dataset = String[],
    landscape = Any[],
    pland_area = Float64[],
    dim = Int[],
    threshold = Float64[],
    file = String[],
)

for data in data_names_vec
    @info "Working on $(data)"

    config = @dict data setup thr
    landscapes_df, p = produce_or_load(
        datadir("exp_pro", "section2", "2g", "landscapes_df"),
        config,
        prefix = "landscape_df",
        # force=true
    ) do config
        ErrorException("Please run 2g before running this script") |> throw
    end # produce_or_load

    @info "Appending...\n"
    global land_areas_df = vcat(land_areas_df, landscapes_df["landscapes_df"])
end

FSlope_df = vcat(
    map(
        x -> "FourierSlope_results_$(x).csv" |> FSlope_folder |> CSV.File |> DataFrame,
        data_names_vec,
    )...,
)

PHOG_df = vcat(
    map(
        x -> "PHOG_results_$(x).csv" |> PHOG_folder |> CSV.File |> DataFrame,
        data_names_vec,
    )...,
)

EdgeOrientation_df = vcat(
    map(
        x ->
            "EdgeOrientationEntropy_results_$(x).csv" |>
            EdgeOrientation_folder |>
            CSV.File |>
            DataFrame,
        data_names_vec,
    )...,
)

# ===-===-
split_and_replace(k) = replace(split(k, ".")[1], "_BW" => "")

FSlope_mod_df = hcat(
    DataFrame(image = [k |> split_and_replace for k in FSlope_df.image]),
    FSlope_df[:, 2:(end-1)],
)

fslope_sorting = FSlope_mod_df.image |> sortperm
FSlope_mod_df = FSlope_mod_df[fslope_sorting, :]

# ===-
PHOG_mod_df = hcat(
    DataFrame(image = [k |> split_and_replace for k in PHOG_df.files]),
    PHOG_df[:, 2:end],
)

phog_sorting = PHOG_mod_df.image |> sortperm
PHOG_mod_df = PHOG_mod_df[phog_sorting, :]

# ===-
EdgeOrientation_mod_df = hcat(
    DataFrame(image = [k |> split_and_replace for k in EdgeOrientation_df.image]),
    select(EdgeOrientation_df, ["avg-shannon20-80", "edge-density"]),
)

edge_sorting = EdgeOrientation_mod_df.image |> sortperm
EdgeOrientation_mod_df = EdgeOrientation_mod_df[edge_sorting, :]

# ===-
land_areas_mod_df = hcat(
    DataFrame(
        image = [
            split(k, "_BW")[1] for k in filter(row -> row.dim == 0, land_areas_df)[:, :file]
        ],
    ),
    DataFrame(
        set = filter(row -> row.dim == 0, land_areas_df)[:, :dataset],
        pland_area_0 = filter(row -> row.dim == 0, land_areas_df)[:, :pland_area],
        pland_area_1 = filter(row -> row.dim == 1, land_areas_df)[:, :pland_area],
    ),
)
land_area_sorting = land_areas_mod_df.image |> sortperm
land_areas_mod_df = land_areas_mod_df[land_area_sorting, :]

# Clean up art section
for subset_name in ["art"]
    art_subsection = filter(x -> x.set .== subset_name, land_areas_mod_df)
    sorted_subset = sortperm(["$(k)" for k in art_subsection.image])
    land_areas_mod_df[land_areas_mod_df.set .== subset_name, :] .=
        art_subsection[sorted_subset, :]
end

all_df_vec = [FSlope_mod_df, PHOG_mod_df, EdgeOrientation_mod_df, land_areas_mod_df]

if !(
    land_areas_mod_df.image ==
    FSlope_mod_df.image ==
    PHOG_mod_df.image ==
    EdgeOrientation_mod_df.image
)
    AssertionError("The names in the data sets are not matching!") |> throw
else
    all_data_df = hcat(
        DataFrame(:image => land_areas_mod_df.image),
        DataFrame(:set => land_areas_mod_df.set),
        [
            select(x, [k for k in names(x) if k != "set" && k != "image"]) for
            x in all_df_vec
        ]...,
    )
end


## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# 
do_nothing = "ok"
