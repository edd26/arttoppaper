
using DrWatson
@quickactivate "arttopopaper"

using Images
using CairoMakie
using Pipe

CairoMakie.set_theme!(fonts = (; regular = "Arial", bold = "Arial Bold"))

"2f3h_load_and_makie_plot_persistence_landscapes_with_cycles_visualisation.jl" |>
scriptsdir |>
include
"HeatmapsUtils.jl" |> srcdir |> include

## ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
script_prefix = "2f3hd"
target_name = "net_5390_8_$(CONFIG.DATA_CONFIG)"

output_dir(args...) =
    plotsdir("section2", "$(script_prefix)_cycles_canvas_export", CONFIG.DATA_SET, args...)

# ===-===-
loaded_img = target_name * extension |> simple_img_dir |> load |> channelview
if loaded_img |> size |> length == 3
    loaded_img = loaded_img[1, :, :]
end
img_height, img_width = size(loaded_img)

dim_index = 2
cycles = all_homology_info[CONFIG.DATA_CONFIG][target_name][dim_index]
cycles_on_image_canvas = get_cycles_on_image_canvas(loaded_img, cycles)

if all(isnan.(cycles_on_image_canvas))
    @warn "No cycles found for $(target_name), nothing to plot."
else
    for (suffix, with_background) in [("cycles_only", false), ("cycles_with_bg", true)]

        fig = CairoMakie.Figure(size = (img_width, img_height), figure_padding = 0)
        ax = CairoMakie.Axis(fig[1, 1])
        hidedecorations!(ax)
        hidespines!(ax)
        CairoMakie.rowgap!(fig.layout, 0)
        CairoMakie.colgap!(fig.layout, 0)

        if with_background
            CairoMakie.image!(ax, loaded_img[end:-1:1, :]', alpha = 0.4, interpolate = false)
        end

        CairoMakie.heatmap!(
            ax,
            cycles_on_image_canvas[end:-1:1, :]',
            colormap = cgrad(:roma, rev = true),
            alpha = 1.0,
            interpolate = false,
            colorrange = (0, 255),
        )

        for file_ext in [".png", ".pdf"]
            out = output_dir(target_name * "_$(suffix)" * file_ext)
            @info "Saving: $(out)"
            safesave(out, fig)
        end
    end
end

@info "Done."
do_nothing = "ok"
