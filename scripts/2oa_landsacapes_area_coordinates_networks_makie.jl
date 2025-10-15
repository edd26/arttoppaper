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
using Random
import Printf: @sprintf

import PlotUtils
using Pipe

CairoMakie.set_theme!(fonts = (; regular = "Arial", bold = "Arial Bold"))
update_theme!(fontsize = 18)
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
y_dim_lims = (1e1, 1e9)
y_dim_ticks = [1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e8, 1e9]

my_palette = PlotUtils.palette(:Paired_10, 10);
net_palette = PlotUtils.palette(:YlOrRd_9, 9);
net_palette2 = PlotUtils.palette(:Set1_9, 10);

plt_atributes = Dict(
    "art" => (m=:star6, c=my_palette[6]),
    "pseudoart" => (m=:star4, c=my_palette[9]),
    "Kandinsky" => (m=:pentagon, c=my_palette[2]),
    "textures" => (m=:utriangle, c=my_palette[10]),
    "Pollock" => (m=:diamond, c=net_palette2[1]),
    "Rothko" => (m=:star5, c=net_palette2[2]),
    "Mark" => (m=:xcross, c=net_palette2[1]),
    "Jarema" => (m=:star6, c=net_palette2[3]),
    "Malewicz" => (m=:star8, c=net_palette2[4]),
    "Richter" => (m=:dtriangle, c=net_palette2[4]),
    "all_pseudoart" => (m=:hexagon, c=my_palette[7]),
    "net0" => (m=:circle, c=net_palette[1]),
    "net1" => (m=:circle, c=net_palette[2]),
    "net2" => (m=:circle, c=net_palette[3]),
    "net3" => (m=:circle, c=net_palette[4]),
    "net4" => (m=:circle, c=net_palette[5]),
    "net5" => (m=:circle, c=net_palette[6]),
    "net6" => (m=:circle, c=net_palette2[7]),
    "net7" => (m=:circle, c=net_palette2[8]),
    "net8" => (m=:circle, c=net_palette2[end]),
)

scatter_plt_vec = []
scatter_plt_names = String[]

points_per_cm = 28.3465 * 1.6
# plt_width = 900
# plt_height = 700
ratio_hw = 700 / 900

final_width = 21.03 * points_per_cm
final_height = ratio_hw * final_width

tellwidth = true
tellheight = false

f = CairoMakie.Figure(size = (final_width, final_height));
fgl = GridLayout(f[1, 1])

axis_args = (
    low_x = y_dim_lims[1],
    low_y = y_dim_lims[1],
    high_x = y_dim_lims[2],
    high_y = y_dim_lims[2],
)
ax_main = get_log_log_axis(fgl, 1, 1; axis_args...)

# all_pseudoart
for selected_dataset in ["all_pseudoart", artists_datasets...]

    pseudo_network_df_dim0 =
        (@pipe filter(row -> row.dataset == selected_dataset, land_areas) |>
               filter(row -> row.dim == 0, _)).pland_area
    pseudo_network_df_dim1 =
        (@pipe filter(row -> row.dataset == selected_dataset, land_areas) |>
               filter(row -> row.dim == 1, _)).pland_area

    marker, colour = plt_atributes[selected_dataset]
    marker_alpha = if selected_dataset == "all_pseudoart"
        0.4
    else
        0.9
    end
    # Get pland areas
    scatter_plt = CairoMakie.scatter!(
        ax_main,
        pseudo_network_df_dim0,
        pseudo_network_df_dim1;
        label = if selected_dataset == "all_pseudoart"
            uppercasefirst(replace(selected_dataset, "_" => " "))
        else
            selected_dataset
        end,
        markersize = 18,
        # markerstrokewidth=0,
        marker = marker,
        color = (colour, marker_alpha),
        transparency = true,
    )
    push!(scatter_plt_vec, scatter_plt)
    push!(scatter_plt_names, if selected_dataset == "all_pseudoart"
        uppercasefirst(replace(selected_dataset, "_" => " "))
    else
        selected_dataset
    end)
end
f

leg = Legend(fgl[1, end+1], scatter_plt_vec, scatter_plt_names)
leg.nbanks = 1
# end

f
## ===-====-===-====-===-====-===-====-===-====-===-====-===-====-

@info "Saving..."
# ===-===-===-
scriptprefix = "2oa"
plot_2oa_dir(args...) =
    plotsdir("section2", scriptprefix * "-lanscape-area-space-networks", args...)
# ===-===-===-
# thr_folder = "threshold=$(PERSISTENCE_THRESHOLD)"

joined_keys = lowercase(DATA_CONFIG) * "_" * join(artists_datasets, "-")
out_name0 = plot_2oa_dir(
    DATA_CONFIG,
    joined_keys,
    "lanscape-area-sapce-networks_thr=$(PERSISTENCE_THRESHOLD).png",
)
safesave(out_name0, f)
out_name1 = plot_2oa_dir(
    DATA_CONFIG,
    joined_keys,
    "pdf",
    "lanscape-area-sapce-networks_thr=$(PERSISTENCE_THRESHOLD).pdf",
)
safesave(out_name1, f)

# out_name1 = plot_2gf_dir(DATA_CONFIG, joined_keys, "all_net-lanscape-area-sapce_thr=$(PERSISTENCE_THRESHOLD).png")
# safesave(out_name1, net_plt)

@info "Saved."

## ===-===-
do_nothing = "ok"
