using DrWatson
@quickactivate "arttopopaper"

using CairoMakie
using NPZ

CairoMakie.set_theme!(fonts=(; regular="Arial", bold="Arial Bold"))
# ===-===-

eeg_filed_dir(args...) = datadir("exp_raw", "EEG", args...)
files_names = ["beta1.npy", "gamma.npy"]

beta_matrix, gamma_matrix = map(x -> x |> eeg_filed_dir |> npzread, files_names)

beta_matrix |> unique
gamma_matrix |> unique

# ===-===-

electrodes = ["Fp1", "Fp2", "F7", "F3", "Fz", "F4", "F8", "FC5", "FC1", "FC2", "FC6", "T7", "C3", "Cz", "C4", "T8", "TP9", "CP5", "CP1", "CP2", "CP6", "TP10", "P7", "P3", "Pz", "P4", "P8", "P09", "O1", "Oz", "O2", "PO10", "AF7", "AF3", "AF4", "AF8", "F5", "F1", "F2", "F6", "FT9", "FT7", "FC3", "FC4", "FT8", "FT10", "C5", "C1", "C2",
    "C6", "TP7", "CP3", "CPz", "CP4", "TP8", "P5", "P1", "P2", "P6", "PO7",
    "PO3", "POz", "PO4", "PO8",
]
total_electrodes = length(electrodes)

numbered_electrodes = ["$(i). $(e)" for (i, e) in enumerate(electrodes)]
longest_label = max([length(e) for e in numbered_electrodes]...)
shortest_label = min([length(e) for e in numbered_electrodes]...)

i = 12
e = numbered_electrodes[i]

electrode_label_v1 = String[]
mod_val = 2
for (i, e) in enumerate(numbered_electrodes)
    length_adjustment_size = longest_label - length(e)
    if longest_label - length(e) == 3
        length_adjustment_size += 2
    end
    if longest_label - length(e) == 2
        length_adjustment_size += 1
    end
    label_width_adjustment = repeat(" ", length_adjustment_size)

    label_shif = repeat(" ", 14 * ((i) % mod_val))
    push!(electrode_label_v1,
        e *
        label_width_adjustment * label_shif
    )
end

electrode_label_v2 = String[]
for (i, e) in enumerate(electrodes)
    length_adjustment_size = 4 - length(e)

    label_width_adjustment = repeat("  ", length_adjustment_size)

    label_shif = repeat(" ", 10 * ((i) % mod_val))
    push!(electrode_label_v2,
        e *
        #  label_width_adjustment * 
        label_shif
    )
end


electrode_label =
    electrode_label |> reverse

# ===-===-
points_per_cm = 28.3465 * 1.5
plt_width = ceil(Int, 18.0 * points_per_cm)
plt_height = ceil(Int, 20.0 * points_per_cm)

f1 = CairoMakie.Figure(size=(plt_width, plt_height));
fgl1_0 = CairoMakie.GridLayout(f1[1, 1])

f2 = CairoMakie.Figure(size=(plt_width, plt_height));
fgl2_0 = CairoMakie.GridLayout(f2[1, 1])

selected_labels = electrode_label_v2
ax_hmap_beta = CairoMakie.Axis(fgl1_0[1, 1],
    aspect=AxisAspect(1),
    title="Beta waves",
    xticks=(1:total_electrodes, selected_labels),
    yticks=(1:total_electrodes, reverse(selected_labels)),
    yreversed=false,
    xticklabelrotation=pi / 2,
    yticklabelsize=12,
    xticklabelsize=12,
)
ax_hmap_gamma = CairoMakie.Axis(fgl2_0[1, 1],
    aspect=AxisAspect(1),
    title="Gamma waves",
    xticks=(1:total_electrodes, selected_labels),
    yticks=(1:total_electrodes, reverse(selected_labels)),
    yreversed=false,
    xticklabelrotation=pi / 2,
    yticklabelsize=12,
    xticklabelsize=12,
)


cmap = cgrad([:red, RGBf(0, 1.0, 0.5), :blue], rev=true)
colorrange = (-1, 1)
hmp1 = heatmap!(ax_hmap_beta, beta_matrix[end:-1:1, :]',
    colormap=cmap,
    colorrange=colorrange
)
hmp2 = heatmap!(ax_hmap_gamma, gamma_matrix[end:-1:1, :]',
    colormap=cmap,
    colorrange=colorrange
)

for fgl in [fgl1_0, fgl2_0]
    CairoMakie.Colorbar(
        fgl[2, 1],
        hmp1,
        label="Connectivity strength",
        labelfont=:bold,
        vertical=false,
    )
end

f1
f2
# ===-===-

# ===-===-===-
scriptprefix = "0j"
script_subname = "EEG_heatmap"
plot_0j_dir(args...) = plotsdir("section0", scriptprefix * "-$(script_subname)", args...)


wave_name = "beta"
for (wave_name, f) in ("beta" => f1, "gamma" => f2)
    out_img_name = "$(wave_name)"

    out_name =
        plot_0j_dir(out_img_name * ".png")
    safesave(out_name, f, dpi=300)

    out_name = plot_0j_dir(
        "pdf",
        out_img_name * ".pdf",
    )
    safesave(out_name, f, dpi=300)
end