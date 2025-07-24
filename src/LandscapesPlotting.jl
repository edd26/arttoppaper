using CairoMakie
using PersistenceLandscapes
using CairoMakie.GeometryBasics

function plot_persistence_landscape!(
    plt_axis,
    pl1::PersistenceLandscape;
    max_layers = size(pl1.land, 1),
    max_colour_range = size(pl1.land, 1),
    alpha::Float64 = 0.0,
    custom_colors = [],
    starting_layer::Int = 1,
    plot_kwargs...,
)
    if max_colour_range < max_layers
        @warn "Selected colour range is less than total layers! Changing to max layers instead"
        max_colour_range = max_layers
    end

    if isempty(custom_colors)
        colors = [
            RGBf(c) for c in cgrad(
                :cmyk,
                max(2, max_colour_range),
                categorical = true,
                rev = true,
                alpha = alpha,
            )
        ]
    else
        colors = custom_colors
    end

    try
        colors = cgrad(
            plot_kwargs[:palette],
            max_colour_range,
            categorical = true,
            rev = true,
            alpha = alpha,
        )
    catch
        @debug "Catched no palette"
    end

    for k = starting_layer:max_layers
        peaks_position, peaks = PersistenceLandscapes.get_peaks_and_positions(pl1.land[k])

        CairoMakie.lines!(
            plt_axis,
            peaks_position,
            peaks;
            color = colors[k],
            plot_kwargs...,
        )
    end
end


function yticks_formatter(values::Vector{Float64})
    max_val = max(values...)
    min_val = min(values...)
    labels = String[]
    if max_val > 5000
        labels = ["$(round(Int, value/1000))k" for value in values]
    elseif max_val > 1000
        labels = ["$(value/1000)k" for value in values]
    else
        labels = ["$(round(Int,value))" for value in values]
    end
    if min_val == 0.0
        labels[1] = "0"
    end
    return labels
end

"""
  function get_bettis_color_palete()

Generates vector with colours used for Betti plots. Created for Betti plots consistency.
"""
function get_bettis_color_palete(; min_dim = 1, use_set::Integer = 1)

    if use_set == 1
        cur_colors = [Gray(bw) for bw = 0.0:0.025:0.5]
        if min_dim == 0
            colors_set = [RGB(87 / 256, 158 / 256, 0 / 256)]
        else
            colors_set = []
        end
        max_RGB = 256
        colors_set = vcat(
            colors_set,
            [
                RGB(255 / max_RGB, 206 / max_RGB, 0 / max_RGB),
                RGB(248 / max_RGB, 23 / max_RGB, 0 / max_RGB),
                RGB(97 / max_RGB, 169 / max_RGB, 255 / max_RGB),
                RGB(163 / max_RGB, 0 / max_RGB, 185 / max_RGB),
                RGB(33 / max_RGB, 96 / max_RGB, 45 / max_RGB),
                RGB(4 / max_RGB, 0 / max_RGB, 199 / max_RGB),
                RGB(135 / max_RGB, 88 / max_RGB, 0 / max_RGB),
            ],
            cur_colors,
        )
    else
        use_set == 2
        cur_colors = get_color_palette(:auto, 1)
        cur_colors3 = get_color_palette(:lightrainbow, 1)
        cur_colors2 = get_color_palette(:cyclic1, 1)
        if min_dim == 0
            colors_set = [cur_colors3[3], cur_colors[5], cur_colors3[end], cur_colors[1]] #cur_colors[7],
        else
            colors_set = [cur_colors[5], cur_colors3[end], cur_colors[1]] #cur_colors[7],
        end
        colors_set = vcat(colors_set, [cur_colors2[c] for c in [collect(11:25);]])
    end

    return colors_set
end