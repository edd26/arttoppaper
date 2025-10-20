
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
using CairoMakie
using DataFrames: DataFrame
using Pipe

using HypothesisTests

import Base.Threads: @spawn, @sync

CairoMakie.set_theme!(fonts = (; regular = "Arial", bold = "Arial Bold"))
# ===-===-===-
"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include
"DataStructuresUtils.jl" |> srcdir |> include
"LandscapesPlotting.jl" |> srcdir |> include
"MakiePlots.jl" |> srcdir |> include

"ExtendedDatasetUtils.jl" |> srcdir |> include


@info "Arguments processed."
# ====================================================
all_x_values = 0:255
all_x_index = 1:256
extension = ".jpg"
selected_config = CONFIG.DATA_CONFIG

all_datasets = vcat("all_pseudoart", artists_datasets)

# all_datasets =
persistence_data =
    populate_dict!(Dict(), [all_datasets, ["BW", "WB"]], final_structure = OrderedDict())

## ===-===-===-===-===-===-===-===-===-===-
land_areas = DataFrame(
    dataset = String[],
    pland_area = Float64[],
    dim = Int[],
    threshold = Float64[],
    file = String[],
    config = String[],
)

d = all_datasets[1]
selected_config = "WB"
for d in all_datasets
    @info "Working on $(d)..."
    for selected_config in ["BW", "WB"]
        @info "\tWorking on $(selected_config)..."

        simple_img_dir(args...) =
            datadir("exp_pro", "img_initial_preprocessing", "BW", d, args...)

        files_list = simple_img_dir() |> readdir |> filter_out_hidden |> sort
        files_list = filter(x -> occursin("BW", x), files_list)
        artist_bw_files_names = @pipe files_list |> ["$(k[1])" for k in split.(_, ".")]
        artist_bw_files_names = if selected_config=="WB"
            replace.(artist_bw_files_names, "BW"=>"WB")
        else
            artist_bw_files_names
        end

        for f in artist_bw_files_names
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
                    config = selected_config,
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
                    config = selected_config,
                ),
            )
        end
    end # selected_config
end

# =====
selected_config = ["BW", "WB"][1]
config_land_areas = filter(row->row.config==selected_config, land_areas)

dim0_df = filter(row->row.dim==0, land_areas)
dim1_df = filter(row->row.dim==1, land_areas)
dim0_areas = dim0_df.pland_area
dim1_areas = dim1_df.pland_area
normalised_differences = (dim1_areas .- dim0_areas) ./ ((dim0_areas .+ dim1_areas)/2)

landscape_difference_df = DataFrame(
    dataset = dim0_df.dataset,
    area_d0 = dim0_df.pland_area,
    area_d1 = dim1_df.pland_area,
    config1 = dim1_df.config,
    norm_difference = normalised_differences,
    norm_abs_difference = abs.(normalised_differences),
)

selected_config = ["BW", "WB"][2]
config_land_areas = filter(row->row.config==selected_config, land_areas)

dim0_df = filter(row->row.dim==0, land_areas)
dim1_df = filter(row->row.dim==1, land_areas)
dim0_areas = dim0_df.pland_area
dim1_areas = dim1_df.pland_area
normalised_differences = (dim1_areas .- dim0_areas) ./ ((dim0_areas .+ dim1_areas)/2)

landscape_difference_df = vcat(
    landscape_difference_df,
    DataFrame(
        dataset = dim0_df.dataset,
        area_d0 = dim0_df.pland_area,
        area_d1 = dim1_df.pland_area,
        config1 = dim1_df.config,
        norm_difference = normalised_differences,
        norm_abs_difference = abs.(normalised_differences),
    ),
)

landscape_difference_df = unique(landscape_difference_df)

# ===-===-===-===-===-

datasets_combinations = [
    # artists_datasets,
    all_datasets[all_datasets .!= "art".&&all_datasets .!= "pseudoart"],
    all_datasets[all_datasets .!= "pseudoart"],
    ["art", "pseudoart"],
]
non_art_labels_vec = ["all_pseudoart", "all_pseudoart", "pseudoart"]



first_selected_dim = "dim0"
second_selected_dim = "dim1"

selected_first_config = "WB"
k = 3
selected_datasets = datasets_combinations[k]
non_art_label = ["all_pseudoart", "all_pseudoart", "pseudoart"][k]

for selected_first_config in ["BW", "WB"]
    @info "selected_first_config = $(selected_first_config)"
    config_filtered_differences_df =
        filter(row -> row.config1==selected_first_config, landscape_difference_df)


    for (selected_datasets, non_art_label) in zip(datasets_combinations, non_art_labels_vec)
        # @info "Selected datasets: " selected_datasets

        filtered_differences_df = filter(
            row -> any(selected_datasets .== row.dataset),
            config_filtered_differences_df,
        )

        for measure in [:norm_difference, :norm_abs_difference]

            pseudoart_differences =
                filter(row -> row.dataset == non_art_label, filtered_differences_df)[
                    :,
                    measure,
                ]
            artists_differences =
                filter(row -> row.dataset != non_art_label, filtered_differences_df)[
                    :,
                    measure,
                ]

            first_selected_dim = "dim1"
            second_selected_dim = "dim0"

            title_sufix = @pipe map(
                      x -> join(x, "_"),
                      [
                          [selected_first_config, first_selected_dim],
                          [selected_first_config, second_selected_dim],
                      ],
                  ) |>
                  (y -> "landscape_area(" .* y .* ")") |>
                  join(_, " - ") |>
                  z -> "(" * z .* ")/average landscape"

            if measure == :norm_abs_difference
                title_sufix = "abs(" * title_sufix * ")"
            end


            # 1724 pixels
            points_per_cm = 28.3465 * 1.5
            plt_width = 12.6 * points_per_cm
            plt_height = 12.3 * points_per_cm
            if length(selected_datasets) > 2
                plt_height += 0.8*points_per_cm
            end
            f2 = Figure(size = (plt_width, plt_height))
            fgl = CairoMakie.GridLayout(f2[1, 1])

            f, l = get_boxplots_and_violins_plot(
                artists_differences,
                pseudoart_differences,
                f2,
                fgl,
                selected_datasets;
                leged_title = replace(title_sufix, "_" => " "),
                ylabel = if measure == :norm_difference
                    "normalised landscapes difference"
                else
                    "absolute of normalised landscapes difference"
                end,
                y_low = -2.8,
                y_high = 3.0,
            )


            display(f)

            # ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
            @info "Saving..."
            scriptprefix = "2m5e"
            script_subname = "histograms_landscapes_difference"
            plot_2m5_dir(args...) =
                plotsdir("section2", scriptprefix * "-$(script_subname)", args...)

            # ===-===-===-

            joined_keys = join(selected_datasets, "-")
            version =
                "$(measure)" * split(
                    replace(replace(replace(title_sufix, " "=>"_"), "("=>""), ")"=>""),
                    "/",
                )[1]
            out_img_name = "$(version)_$(joined_keys)"
            thr = "threshold=$(CONFIG.PERSISTENCE_THRESHOLD)"

            out_name = plot_2m5_dir(
                "$(selected_first_config)_$(thr)_$(version)",
                out_img_name * ".png",
            )
            @info out_name
            safesave(out_name, f, dpi = 300)

            out_name = plot_2m5_dir(
                "$(selected_first_config)_$(thr)_$(version)",
                "pdf",
                out_img_name * ".pdf",
            )
            safesave(out_name, f, dpi = 300)
        end # measure
    end # selected_dataset 
end # selected_first_config
## ===-===-
do_nothing = "ok"
