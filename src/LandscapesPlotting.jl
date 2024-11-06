using Makie
using PersistenceLandscapes
using Makie.GeometryBasics

function plot_persistence_landscape!(
    plt_axis,
    pl1::PersistenceLandscape;
    max_layers=size(pl1.land, 1),
    max_colour_range=size(pl1.land, 1),
    alpha::Float64=0.0,
    custom_colors=[],
    plot_kwargs...
)
    if max_colour_range < max_layers
        @warn "Selected colour range is less than total layers! Changing to max layers instead"
        max_colour_range = max_layers
    end

    if isempty(custom_colors)
        colors = [RGBf(c) for c in cgrad(:cmyk, max(2, max_colour_range), categorical=true, rev=true, alpha=alpha)]
    else
        colors = custom_colors
    end

    try
        colors = cgrad(plot_kwargs[:palette], max_colour_range, categorical=true, rev=true, alpha=alpha)
    catch
        @debug "Catched no palette"
    end

    for k = 1:max_layers
        peaks_position, peaks = PersistenceLandscapes.get_peaks_and_positions(pl1.land[k])

        CairoMakie.lines!(
            plt_axis,
            peaks_position,
            peaks;
            color=colors[k],
            plot_kwargs...
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