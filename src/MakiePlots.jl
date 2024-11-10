import LaTeXStrings: latexstring

markers_labels = [
    (:pentagon, ":pentagon",),
    (:circle, ":circle"),
    (:rect, ":rect"),
    (:star4, ":star4"),
    (:star5, ":star5"),
    (:diamond, ":diamond"),
    (:hexagon, ":hexagon"),
    (:cross, ":cross"),
    (:xcross, ":xcross"),
    (:utriangle, ":utriangle"),
    (:dtriangle, ":dtriangle"),
    (:ltriangle, ":ltriangle"),
    (:rtriangle, ":rtriangle"),
    (:star6, ":star6"),
    (:star7, ":star7"),
    (:star8, ":star8"),
    ('✈', "'\\:airplane:'"),
]

# in_x_ticks = 20:10:80
# in_x_labels = ["$(k)e1" for k in 2:1:8]
# in_y_ticks = 3000:1000:5000
# in_y_labels = ["$(k)e3" for k in 3:1:5]


function get_log_log_axis(fig, i, j; low_x=1e3, low_y=1e3, high_x=1e8, high_y=1e8, label_pefix::String="1e")
    tick_values = [10^(k) for k in ceil(Int, log10(low_x)):ceil(Int, log10(high_x))]
    tick_labels = ["10^{$(k)}" |> latexstring for k in ceil(Int, log10(low_x)):ceil(Int, log10(high_x))]


    ax = CairoMakie.Axis(
        fig[i, j],
        xscale=log10,
        yscale=log10,
        xticks=(tick_values, tick_labels),
        yticks=(tick_values, tick_labels),
        xminorgridvisible=true,
        xminorticksvisible=true,
        xminorticks=IntervalsBetween(10),
        yminorgridvisible=true,
        yminorticksvisible=true,
        yminorticks=IntervalsBetween(10),
        xlabel="Area in dimension 0",
        ylabel="Area in dimension 1",
        aspect=AxisAspect(1),
    )

    CairoMakie.xlims!(ax, low_x, high_x)
    CairoMakie.ylims!(ax, low_y, high_y)

    ax.xticklabelrotation = pi / 4
    ax.yticklabelrotation = pi / 4
    return ax
end

function mplot_barcodes!(ax_barcodes, bd_data; colour=:blue, rev=false)
    total_rows, total_dims = size(bd_data)
    for row in 1:total_rows
        if rev
            y_position = [total_rows + 1 - row, total_rows + 1 - row]
        else
            y_position = [row, row]
        end
        lines!(
            ax_barcodes,
            bd_data[row, :],
            y_position,
            # xmin=dim_data[1:total_rows, 1],
            color=colour,
            # label="",
        )
    end
end

function mplot_bettis!(ax, bettis_data; colour=:blue, step=:pre)
    CairoMakie.stairs!(
        ax,
        bettis_data[:x],
        bettis_data[:y],
        color=colour,
        step=step,
    )
end