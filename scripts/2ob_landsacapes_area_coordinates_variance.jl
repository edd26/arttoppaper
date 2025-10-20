#=
Load csv with bd info and plot distribution

=#

using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-===-===-===-===-===-===-===-===-===-
"2o_get_persistence_landscapes_summary.jl" |> scriptsdir |> include
# "DistributionsUtils.jl" |> srcdir |> include
"MakiePlots.jl" |> srcdir |> include
# ===-
using Makie
using CairoMakie
using Pipe

using StatsBase

using Statistics
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
land_areas

all_pseudoart_df = filter(row->row.dataset=="all_pseudoart", land_areas)
all_art_df = filter(row->row.dataset!="all_pseudoart", land_areas)

# mean_pseudoart_dim0_area = filter(row -> row.dim==0, all_pseudoart_df).pland_area |> StatsBase.mean
# mean_pseudoart_dim1_area = filter(row -> row.dim==1, all_pseudoart_df).pland_area |> StatsBase.mean

# mean_allart_dim0_area = filter(row -> row.dim==0, all_art_df).pland_area |> StatsBase.mean
# mean_allart_dim1_area = filter(row -> row.dim==1, all_art_df).pland_area |> StatsBase.mean

differences_vec = []
abs_differences_vec = []
norm_differences_vec = []
norm_abs_differences_vec = []

df = [all_pseudoart_df, all_art_df][2]
# for (df, relevant_mean) in zip([all_pseudoart_df, all_art_df], )
for df in [all_pseudoart_df, all_art_df]
    dim_0_data = filter(row -> row.dim==0, df)
    dim_1_data = filter(row -> row.dim==1, df)

    mean_difference = (dim_1_data.pland_area .+ dim_0_data.pland_area) ./ 2

    push!(differences_vec, (dim_1_data.pland_area .- dim_0_data.pland_area))
    push!(abs_differences_vec, abs.(dim_1_data.pland_area .- dim_0_data.pland_area))

    push!(
        norm_differences_vec,
        (dim_1_data.pland_area .- dim_0_data.pland_area) ./ mean_difference,
    )
    push!(
        norm_abs_differences_vec,
        abs.(dim_1_data.pland_area .- dim_0_data.pland_area) ./ mean_difference,
    )

end # df

# 
# mean(differences_vec[1])
# mean(differences_vec[2])

# std(differences_vec[1])
# std(differences_vec[2])

# mean(abs_differences_vec[1])
# mean(abs_differences_vec[2])

# std(abs_differences_vec[1])
# std(abs_differences_vec[2])

function get_data_histogram(v1, v2, l1, l2)
    f, ax, h = hist(v1, normalization = :pdf, label = l1)
    hist!(v2, normalization = :pdf, label = l2)
    Legend(f[2, 1], ax, tellheight = true, tellwidth = false, orientation = :horizontal)

    ax.ylabel="PDF"
    return f, ax
end

f1, ax1 =
    get_data_histogram(differences_vec[1], differences_vec[2], "all pseudoart", "all art")
f2, ax2 = get_data_histogram(
    abs_differences_vec[1],
    abs_differences_vec[2],
    "all pseudoart",
    "all art",
)
f3, ax3 = get_data_histogram(
    norm_differences_vec[1],
    norm_differences_vec[2],
    "all pseudoart",
    "all art",
)
f4, ax4 = get_data_histogram(
    norm_abs_differences_vec[1],
    norm_abs_differences_vec[2],
    "all pseudoart",
    "all art",
)

ax1.title="pland_area dim1 - pland_area dim0"
ax1.xlabel="landsacpes difference"
ax2.title="abs(pland_area dim1 - pland_area dim0)"
ax2.xlabel="abs(landsacpes difference)"

ax3.title="(pland_area dim1 - pland_area dim0) ./ (mean pland area)"
ax3.xlabel="normalised landscapes difference"

ax4.title="(abs(pland_area dim1 - pland_area dim0)) ./ (mean pland area)"
ax4.xlabel="normalised abs(landscapes difference)"

f1
f2
f3
f4


f4_final = Figure()
fgl = CairoMakie.GridLayout(f4_final[1, 1])

f, l = get_boxplots_and_violins_plot(
    norm_abs_differences_vec[2],
    norm_abs_differences_vec[1],
    f4_final,
    fgl,
    all_datasets;
    # ["art", "pseudo-art"];
    leged_title = "Normalised difference in area under p. landscapes",
    y_low = -1.0,
)

a = min(vcat(norm_abs_differences_vec[1], norm_abs_differences_vec[2])...)
a * 0.8

f4_final
## ===-====-===-====-===-====-===-====-===-====-===-====-===-====-
using HypothesisTests: MannWhitneyUTest

MannWhitneyUTest(differences_vec[1], differences_vec[2])
MannWhitneyUTest(abs_differences_vec[1], abs_differences_vec[2])
MannWhitneyUTest(norm_differences_vec[1], norm_differences_vec[2])
MannWhitneyUTest(norm_abs_differences_vec[1], norm_abs_differences_vec[2])



@info "Saving..."
# ===-===-===-
scriptprefix = "2ob"
plot_2oa_dir(args...) =
    plotsdir("section2", scriptprefix * "-lanscape-area-difference-histogram", args...)
# ===-===-===-
# thr_folder = "threshold=$(PERSISTENCE_THRESHOLD)"

joined_keys = lowercase(DATA_CONFIG) * "_" * join(artists_datasets, "-") * "-all_pseudoart"
out_name0 = plot_2oa_dir(
    DATA_CONFIG,
    joined_keys,
    "lanscape-area-difference_histogram_thr=$(PERSISTENCE_THRESHOLD).png",
)
safesave(out_name0, f4)
out_name1 = plot_2oa_dir(
    DATA_CONFIG,
    joined_keys,
    "pdf",
    "lanscape-area-difference_histogram_thr=$(PERSISTENCE_THRESHOLD).pdf",
)
safesave(out_name1, f4)

## ===-===-
do_nothing = "ok"
