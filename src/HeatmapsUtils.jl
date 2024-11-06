
"""
    get_fixation_postions(fixation_per_image_per_view)

Exports matrix with 2 columns, where first column are x positions of eye fixation and 
2nd column is y position of eye fixation.
"""
function get_fixation_postions(fixation_per_image_per_view)
    right_x =
        [x for x in fixation_per_image_per_view[:, "Point of Regard Right X [px]"] if !ismissing(x)]
    right_y =
        [y for y in fixation_per_image_per_view[:, "Point of Regard Right Y [px]"] if !ismissing(y)]

    hcat(right_x, right_y)
end

"""
    convert_positions_to_indices(positions, PRECISION_FACTOR)

Convert fixation points to index coordinates from original floating points Euclidean space coordinates.
"""
convert_positions_to_indices(positions, PRECISION_FACTOR) = ceil.(Int, positions .* PRECISION_FACTOR)

"""

Create a heatmap from the values stored in `positions`. The size of the output heatmap
is `width` \times `height `. 

The map is generated as follows:
- create an empty matrix of size `width * scaling_factor` \times `height * scaling_factor`
- for each row of matrix `positions` describing position of fixation, append a `kernel` that is
  centered at position of fixation
- return a heatmap that is downscaled by factort `scaling_factor`

"""
function create_heatmap(space_width::Int,
    space_height::Int,
    positions::Matrix,
    scaling_factor::Int,
    kernel;
    top_bottom_flip=false,
    skip_corner_gaze=false,
    corner_margin=10,
    weights=ones(size(positions, 1))
)

    # blank_map = zeros(space_width * scaling_factor, space_height * scaling_factor)
    blank_map = zeros(space_height * scaling_factor, space_width * scaling_factor)

    # First column is the x positiong (left and right eye movement)
    # Second column is the y positiong (up and down eye movement)
    kernel_positioning = convert_positions_to_indices(positions, PRECISION_FACTOR)
    for k in 1:size(kernel_positioning, 1)
        if kernel_positioning[k, 1] > space_width * scaling_factor
            kernel_positioning[k, 1] = space_width * scaling_factor
        end
        if kernel_positioning[k, 1] < 0
            kernel_positioning[k, 1] = 0
        end
        if kernel_positioning[k, 2] > space_height * scaling_factor
            kernel_positioning[k, 2] = space_height * scaling_factor
        end
        if kernel_positioning[k, 2] < 0
            kernel_positioning[k, 2] = 0
        end
    end

    for k in 1:size(kernel_positioning, 1)
        x_pos = kernel_positioning[k, 2]
        y_pos = kernel_positioning[k, 1]

        if skip_corner_gaze && (x_pos <= corner_margin && y_pos <= corner_margin)
            # @warn "Gazing at the x-1 y-1 corner! Skipping..."
            continue
        end
        if skip_corner_gaze && (x_pos <= corner_margin && y_pos >= space_height * scaling_factor - corner_margin)
            # @warn "Gazing at the x-1 y-end corner! Skipping..."
            continue
        end
        if skip_corner_gaze && (x_pos >= space_width * scaling_factor - corner_margin && y_pos >= space_height * scaling_factor - corner_margin)
            # @warn "Gazing at the x-end y-end corner! Skipping..."
            continue
        end
        if skip_corner_gaze && (x_pos >= space_width * scaling_factor - corner_margin && y_pos <= corner_margin)
            # @warn "Gazing at the x-end y-1 corner! Skipping..."
            continue
        end

        append_kernel!(y_pos, x_pos, blank_map, kernel .* weights[k])
    end
    if top_bottom_flip
        return blank_map[end:-PRECISION_FACTOR:1, 1:PRECISION_FACTOR:end]
    else
        return blank_map[1:PRECISION_FACTOR:end, 1:PRECISION_FACTOR:end]
    end
end

function get_image_number(file_name)

    number = 0
    if file_name == "net_5278_4"
        number = 1
    elseif file_name == "net_5299_2"
        number = 2
    elseif file_name == "net_5964_8" || file_name == "net_5496_8"
        number = 3
    elseif file_name == "net_5024_8"
        number = 4
    elseif file_name == "net_5390_4"
        number = 5
    elseif file_name == "net_5063_7"
        number = 6
    elseif file_name == "net_5250_6"
        number = 7
    elseif file_name == "net_5193_0"
        number = 8
    elseif file_name == "net_5013_5"
        number = 9
    elseif file_name == "net_5390_8"
        number = 10
    elseif file_name == "net_5210_4"
        number = 11
    elseif file_name == "net_5225_1"
        number = 12
    else
        ErrorException("Unknown file name, check function") |> throw
    end
    return number
end


function find_isoline(matrix, threshold, precision)
    isoline = (abs.(matrix .- threshold) .<= precision)
    return isoline
end

function get_cycle_boundary(cycle, img1)
    sxs = Ripserer.apply_threshold(cycle, Inf, Inf)
    series, _ = Ripserer.plottable(sxs, img1)
    cycle_coordinates = [CartesianIndex(v1[2], v1[1]) for v1 in series if v1 .|> !isnan |> all]

    return cycle_coordinates
end