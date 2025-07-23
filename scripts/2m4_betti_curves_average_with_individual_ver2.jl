using DrWatson
@quickactivate "ArtTopology"

# ===-===-===-
using DataStructures: OrderedDict
using DelimitedFiles
using Images
using PersistenceLandscapes
using Makie
using CairoMakie
using TopologyPreprocessing
using Pipe
using Statistics
using Ripserer

import Base.Threads: @spawn, @sync
# ===-===-===-
"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include
"DataStructuresUtils.jl" |> srcdir |> include
"LandscapesPlotting.jl" |> srcdir |> include
"MakiePlots.jl" |> srcdir |> include
"HeatmapsUtils.jl" |> srcdir |> include

import .CONFIG: dipha_bd_info_export_folder, export_for_dipha_folder, preproc_img_dir_set, SELECTED_DIM, PERSISTENCE_THRESHOLD, DATA_CONFIG
import .CONFIG: homology_info_storage

@info "Arguments processed."
# ===-===-===-
readrows(file_name) = DelimitedFiles.readdlm(file_name, ',', Float64, '\n')

# ===-===-===-
persistence_data = populate_dict!(Dict(),
    [["pseudoart", "art"], ["BW", "WB"], ["dim0", "dim1"]],
    final_structure=OrderedDict()
)

selected_config = CONFIG.DATA_CONFIG
all_x_values = 0:255
all_x_index = 1:256


for dataset = ["pseudoart", "art"]
    if dataset == "pseudoart"
        data_folder = "pseudoart"
    else
        data_folder = dataset
    end
    selected_dim = 1
    files_list = dipha_bd_info_export_folder(selected_config, data_folder, "dim=$(selected_dim)") |> readdir |> filter_out_hidden |> sort
    files_list = filter(x -> occursin(selected_config, x), files_list)
    bw_files_names = @pipe [k for k in filter_out_by_threshold(files_list, PERSISTENCE_THRESHOLD)] |>
                           [k[1] for k in split.(_, ".")] |>
                           [k[1] for k in split.(_, "_dim=")]


    for file in bw_files_names
        @info "Working on file $(file)"

        name = split(file, "_dim=")[1]

        extension = ""
        if dataset == "art"
            raw_img_name = "art"
            extension = ".jpg"
        elseif dataset == "pseudoart"
            raw_img_name = "pseudoart"
            extension = ".jpg"
        else
            ErrorException("raw img name not set") |> throw
        end
        simple_img_dir(args...) = datadir("exp_pro", "img_initial_preprocessing", "$(selected_config)", raw_img_name, args...)


        # Load image
        img1 = name * extension |> simple_img_dir |> load
        scaled_img = floor.(Int, Gray.(img1) .* 255)
        scaled_img_WB = abs.(scaled_img .- 255)

        selected_dim = 0
        for (selected_config, input_img) = zip(["BW", "WB",], [scaled_img, scaled_img_WB])

            if selected_config == "BW"
                loading_name = name
            else
                loading_name = replace(name, "BW" => "WB")
            end

            @info selected_config
            # ===-===-
            # Get cycles and their persistence
            alg = :homology
            reps = true
            cutoff = PERSISTENCE_THRESHOLD
            homology_config = @dict alg reps cutoff input_img

            homology_data, p = produce_or_load(
                homology_info_storage("homology_computation", dataset, "image_$(replace(loading_name, ".jpg"=>""))"), # path
                homology_config, # config
                prefix="homology_info", # file prefix
                # force=true # force computations
            ) do homology_config
                @unpack alg, reps, cutoff, input_img = homology_config
                println("\tStarting homology computations...")
                homolgy_result = ripserer(Cubical(input_img), cutoff=cutoff, reps=reps, alg=alg)
                println("\tFinished homology computations. ")

                Dict("homolgy_result" => homolgy_result)
            end # produce_or_load

            homology_info = homology_data["homolgy_result"]

            for (dim_index, selected_dim) in enumerate([0, 1])
                births = [barcode[1] for barcode in homology_info[dim_index]]
                deaths = [barcode[2] for barcode in homology_info[dim_index]]
                persistances = [persistence(barcode) for barcode in homology_info[dim_index] if !isinf(persistence(barcode))]

                # ===-
                bd_data = [hcat(births, deaths)]
                persistances = deaths - births
                barcodes = [MyPair(b, d) for (b, d) in zip(births, deaths)] |> PersistenceBarcodes

                # get betti curve from barcodes
                x_range = 0:255

                if selected_dim == 1
                    betticurve_pt1 = [
                        (births .<= x .&& deaths .> x) |> sum
                        for x in x_range[1:255]]
                    betticurve = vcat(betticurve_pt1, [0])
                else
                    betticurve_pt1 = [
                        (births .<= x .&& deaths .> x) |> sum
                        for x in x_range[1:255]]
                    betticurve = vcat(betticurve_pt1, [
                        (births .<= 255 .&& deaths .>= 255) |> sum
                    ])
                end

                bettis = Dict(
                    :x => x_range,
                    :y => betticurve
                )

                resampled_betti = zeros(Int, length(all_x_values))
                resampled_betti[bettis[:x].+1] .= bettis[:y]

                for x in all_x_index[2:end]
                    if resampled_betti[x] == 0
                        resampled_betti[x] = resampled_betti[x-1]
                    end
                end

                persistence_data[dataset][selected_config]["dim$(selected_dim)"][loading_name] = Dict()
                persistence_data[dataset][selected_config]["dim$(selected_dim)"][loading_name]["landscapes"] = PersistenceLandscape(barcodes)
                persistence_data[dataset][selected_config]["dim$(selected_dim)"][loading_name]["barcodes"] = bd_data
                persistence_data[dataset][selected_config]["dim$(selected_dim)"][loading_name]["betti"] = bettis
                persistence_data[dataset][selected_config]["dim$(selected_dim)"][loading_name]["resampled_bettis"] = resampled_betti
            end # selected_dim
        end # config
    end #file
end #datafile


## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# Average betti

average_bettis = populate_dict!(Dict(),
    [["pseudoart", "art"], ["BW", "WB"], ["dim0", "dim1"]],
    final_structure=zeros(1, length(all_x_index))
)
std_bettis = populate_dict!(Dict(),
    [["pseudoart", "art"], ["BW", "WB"], ["dim0", "dim1"]],
    final_structure=zeros(1, length(all_x_index))
)

img_bettis = hcat([v["resampled_bettis"] for (k, v) in persistence_data["pseudoart"][selected_config]["dim0"]]...)

for (dataset, persistence_dataset) in persistence_data
    for (selected_config, persistence_config) in persistence_dataset
        for (dim_key, persistence_dim) in persistence_config

            img_bettis = hcat([v["resampled_bettis"] for (k, v) in persistence_dim]...)


            average_bettis[dataset][selected_config][dim_key] = mean(img_bettis, dims=2)
            std_bettis[dataset][selected_config][dim_key] = std(img_bettis, dims=2)
        end #dim
    end # selected_config
end # datset

## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# Create plots

betti_colours = TopologyPreprocessing.get_bettis_color_palete(min_dim=0);

art_colours = cgrad([
        RGB([98, 197, 84] / 255...),
        RGB([91, 121, 177] / 255...),
        :purple], 12, categorical=true)[1:12]
pseudoart_colours = cgrad([
        RGB([150, 49, 49] / 255...),
        RGB([224, 154, 58] / 255...),
        :yellow
    ], 12, categorical=true, rev=true)[1:12]

colurs_selection = OrderedDict(
    "art" => OrderedDict(
        "dim0" => art_colours[1],
        "dim1" => art_colours[end-3],
    ),
    "pseudoart" => OrderedDict(
        "dim0" => pseudoart_colours[end],
        "dim1" => pseudoart_colours[2],
    )
)

low_y = 0
high_y = 0
y_step = 0
y_range = 0

points_per_cm = 28.3465 * 1.6
final_width = 16.03 * points_per_cm
final_height = 9.86 * points_per_cm

f = CairoMakie.Figure(size=(final_width, final_height))
fgl = GridLayout(f[1, 1])


selected_data = "pseudoart"

for (d, selected_dim) = ["dim0", "dim1"] |> enumerate
    if selected_dim == "dim1"
        y_label = L"$\beta_{1}$"
    else
        y_label = L"$\beta_{0}$"
    end

    if selected_dim == "dim1"
        low_y = -100
        high_y = 9000
        y_range = 0:2000:high_y
        y_label = L"$\beta_{1}$"
    else
        low_y = -100
        high_y = 12000
        y_range = 0:2000:high_y
        y_label = L"$\beta_{0}$"
    end

    dim_label = replace(selected_dim, "dim" => "dimension ")

    ax1 = CairoMakie.Axis(
        fgl[d, 1],
        title="$(dim_label)",
        xtrimspine=true,
        ytrimspine=true,
        rightspinevisible=false,
        topspinevisible=false,
        xticks=0:50:256,
        #  yticks=0:25:100,
        xlabel="Filtration step",
        ylabel=y_label,
        yticks=y_range,
        ytickformat=yticks_formatter
    )

    for (i, selected_data) = ["art", "pseudoart",] |> enumerate
        if selected_data == "art"
            data_label = "Art"
        else
            data_label = "Pseudo-art"
        end

        # Plot average beetis
        bettis_mean = average_bettis[selected_data][selected_config][selected_dim][:, 1]
        band_low = bettis_mean .- std_bettis[selected_data][selected_config][selected_dim][:, 1]
        band_high = bettis_mean .+ std_bettis[selected_data][selected_config][selected_dim][:, 1]

        band_low = [max(x, 0) for x in band_low]
        band_high = [max(x, 0) for x in band_high]


        c = colurs_selection[selected_data][selected_dim]

        band!(ax1, all_x_values, band_low, band_high, color=(c, 0.3))
        lines!(ax1, all_x_values, bettis_mean, linewidth=4, color=(c))

        # Plot individual curves
        for (k, (name, params_dict)) in enumerate(persistence_data[selected_data][selected_config][selected_dim])

            bettis_vector = params_dict["resampled_bettis"]

            if selected_data == "art"
                data_label = "Art"
            else
                data_label = "Pseudo-art"
            end

            line_alpha = 0.5
            linestyle = (:solid, :dense)
            lines!(
                ax1,
                all_x_values,
                bettis_vector,
                linestyle=linestyle,
                linewidth=1,
                color=(c, line_alpha)
            )

        end # name
        if d == 2
            ax1.xlabel = "Filtration step"
        else
            ax1.xlabel = ""
            hidexdecorations!(ax1, ticks=false, grid=false)
        end
        CairoMakie.ylims!(ax1, low=low_y, high=high_y)
        CairoMakie.xlims!(ax1, low=-1, high=256)
    end # dim

end # dataset

f

group_color = [
    PolyElement(color=colurs_selection["art"]["dim0"], strokecolor=:transparent)
    PolyElement(color=colurs_selection["art"]["dim1"], strokecolor=:transparent)
    PolyElement(color=colurs_selection["pseudoart"]["dim0"], strokecolor=:transparent)
    PolyElement(color=colurs_selection["pseudoart"]["dim1"], strokecolor=:transparent)
];

group_lines = [
    LineElement(color=:gray, linestyle=:solid, linewidth=5)
    LineElement(color=:gray, linestyle=:solid, linewidth=1)
    PolyElement(color=(:gray, 0.3), strokecolor=:gray)
]

Legend(fgl[end+1, :],
    [group_color, group_lines],
    [
        ["Art, dimension 0", "Art, dimension 1", "Pseudo-art, dimension 0", "Pseudo-art, dimension 1"],
        ["Average curve", "Individual curve", "Standard deviation"]],
    ["", ""],
    nbanks=2,
    tellheight=true,
    framevisible=false,
    orientation=:horizontal
)

f

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
@info "Saving."
scriptprefix = "2m4"
script_subname = "average_and_individual_betti_curves_v2"
plot_2m2_dir(args...) = plotsdir("section2", scriptprefix * "-$(script_subname)", args...)

# ===-===-===-
out_img_name = "$(script_subname)_$(selected_config)"
thr = "threshold=$(PERSISTENCE_THRESHOLD)"

out_name = plot_2m2_dir("$(selected_config)_$(thr)", out_img_name * ".png")
safesave(out_name, f)

# ===-===-
# PDF export
out_name = plot_2m2_dir("$(selected_config)_$(thr)", "pdf", out_img_name * ".pdf")
safesave(out_name, f)

@info "Saved all files."
## ===-===-
do_nothing = "ok"
