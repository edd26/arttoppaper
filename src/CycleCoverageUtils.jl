get_items_count_from_window(cycles_window) =
    length([k for k in cycles_window if !isnan(k)])

get_unique_items_from_window(cycles_window) =
    [k for k in cycles_window if !isnan(k)] |> unique

get_total_unique_items_from_window(cycles_window) =
    [k for k in cycles_window if !isnan(k)] |> unique |> length

function count_unique_cycles_in_windows(cycles_map, window_size,)
    total_rows, total_cols = size(cycles_map)
    last_col_range = 0
    last_row_range = 0
    unique_cycles_count_in_windows = []
    for row in 1:window_size:(total_rows-window_size),
        col in 1:window_size:(total_cols-window_size)

        row_range = row:(row+window_size-1)
        col_range = col:(col+window_size-1)
        cycles_window = cycles_map[row_range, col_range]

        push!(unique_cycles_count_in_windows,
            cycles_window |> get_total_unique_items_from_window
        )
        last_col_range = col_range
        last_row_range = row_range
    end

    final_row_range = (last_row_range[end]+1):total_rows
    final_col_range = (last_col_range[end]+1):total_cols

    # Last rows, top to bottom
    for col in 1:window_size:(total_cols-window_size)
        col_range = col:(col+window_size-1)

        cycles_window = cycles_map[final_row_range, col_range]
        push!(unique_cycles_count_in_windows,
            cycles_window |> get_total_unique_items_from_window
        )
    end

    # Last rows, left to right
    for row in 1:window_size:(total_rows-window_size)
        row_range = row:(row+window_size-1)
        cycles_window = cycles_map[row_range, final_col_range]

        push!(unique_cycles_count_in_windows,
            cycles_window |> get_total_unique_items_from_window
        )
    end

    # Last rows, last cols
    cycles_window = cycles_map[final_row_range, final_col_range]
    push!(unique_cycles_count_in_windows,
        cycles_window |> get_total_unique_items_from_window
    )

    return unique_cycles_count_in_windows
end

function count_unique_cycles_in_windows_with_positions(cycles_map, window_size,)

    unique_cycles_in_windows = unique_cycles_in_windows_with_positions(cycles_map, window_size,)
    unique_cycles_count_in_windows = [k => length(v) for (k, v) in unique_cycles_in_windows]

    return unique_cycles_count_in_windows
end

function unique_cycles_in_windows_with_positions(cycles_map, window_size,)
    total_rows, total_cols = size(cycles_map)
    last_col_range = 0
    last_row_range = 0
    col_index = 0
    row_index = 0

    unique_cycles_in_windows = Pair{Tuple{Int64,Int64},Vector{Int}}[]
    for row in 1:window_size:(total_rows-window_size)
        row_index += 1
        col_index = 0
        for col in 1:window_size:(total_cols-window_size)
            col_index += 1

            row_range = row:(row+window_size-1)
            col_range = col:(col+window_size-1)
            cycles_window = cycles_map[row_range, col_range]

            push!(unique_cycles_in_windows,
                (row_index, col_index) => cycles_window |> get_unique_items_from_window |> (y -> round.(Int, y))
            )
            last_col_range = col_range
            last_row_range = row_range
        end
    end

    final_row_index = row_index + 1
    final_col_index = col_index + 1
    final_row_range = (last_row_range[end]+1):total_rows
    final_col_range = (last_col_range[end]+1):total_cols

    # Last rows, top to bottom
    col_index = 0
    for col in 1:window_size:(total_cols-window_size)
        col_range = col:(col+window_size-1)
        col_index += 1

        cycles_window = cycles_map[final_row_range, col_range]
        push!(unique_cycles_in_windows,
            (final_row_index, col_index) => cycles_window |> get_unique_items_from_window |> (y -> round.(Int, y))
        )
    end

    # Last rows, left to right
    row_index = 0
    for row in 1:window_size:(total_rows-window_size)
        row_range = row:(row+window_size-1)
        row_index += 1
        cycles_window = cycles_map[row_range, final_col_range]

        push!(unique_cycles_in_windows,
            (row_index, final_col_index) => cycles_window |> get_unique_items_from_window |> (y -> round.(Int, y))
        )
    end

    # Last rows, last cols
    cycles_window = cycles_map[final_row_range, final_col_range]
    push!(unique_cycles_in_windows,
        (final_row_index, final_col_index) =>
            cycles_window |> get_unique_items_from_window |> (y -> round.(Int, y))
    )

    return unique_cycles_in_windows
end

get_non_nan(vec) = [k for k in vec if !isnan(k)]
function mean_heatmap_in_windows(heatmap_img, window_size,)
    total_rows, total_cols = size(heatmap_img)
    last_col_range = 0
    last_row_range = 0
    col_index = 0
    row_index = 0

    mean_heatmap_in_window = []
    for row in 1:window_size:(total_rows-window_size)
        row_index += 1
        col_index = 0
        for col in 1:window_size:(total_cols-window_size)
            col_index += 1

            row_range = row:(row+window_size-1)
            col_range = col:(col+window_size-1)

            all_non_nan = heatmap_img[row_range, col_range] |> get_non_nan
            if isempty(all_non_nan)
                mean_heatmap = 0
            else
                mean_heatmap = all_non_nan |> mean
            end

            push!(mean_heatmap_in_window,
                (row_index, col_index) => mean_heatmap
            )
            last_col_range = col_range
            last_row_range = row_range
        end
    end

    final_row_index = row_index + 1
    final_col_index = col_index + 1
    final_row_range = (last_row_range[end]+1):total_rows
    final_col_range = (last_col_range[end]+1):total_cols

    # Last rows, top to bottom
    col_index = 0
    for col in 1:window_size:(total_cols-window_size)
        col_index += 1
        col_range = col:(col+window_size-1)

        all_non_nan = heatmap_img[final_row_range, col_range] |> get_non_nan
        if isempty(all_non_nan)
            mean_heatmap = 0
        else
            mean_heatmap = all_non_nan |> mean
        end
        push!(mean_heatmap_in_window,
            (final_row_index, col_index) => mean_heatmap
        )
    end

    # Last rows, left to right
    row_index = 0
    for row in 1:window_size:(total_rows-window_size)
        row_index += 1
        row_range = row:(row+window_size-1)

        all_non_nan = heatmap_img[row_range, final_col_range] |> get_non_nan
        if isempty(all_non_nan)
            mean_heatmap = 0
        else
            mean_heatmap = all_non_nan |> mean
        end
        push!(mean_heatmap_in_window,
            (row_index, final_col_index) => mean_heatmap
        )
    end

    # Last rows, last cols
    all_non_nan = heatmap_img[final_row_range, final_col_range] |> get_non_nan
    if isempty(all_non_nan)
        mean_heatmap = 0
    else
        mean_heatmap = all_non_nan |> mean
    end
    push!(mean_heatmap_in_window,
        (final_row_index, final_col_index) => mean_heatmap
    )

    return mean_heatmap_in_window
end


function add_cycles_to_image(cycles, img1)
    cycles_on_image = fill(NaN, size(img1))
    for (k, cycle) in ProgressBar(enumerate(cycles), unit="Cycle", unit_scale=true)
        cycle_coordinates = get_cycle_boundary(cycle, img1)

        cycles_on_image[cycle_coordinates] .= k
    end # cycle
    return cycles_on_image
end

function get_perimeter_sizes(cycles, img1)
    perimeter_size = zeros(Int, length(cycles))
    cycle = cycles[1]
    for (k, cycle) in ProgressBar(enumerate(cycles), unit="Cycle", unit_scale=true)
        cycle_coordinates = get_cycle_boundary(cycle, img1)

        perimeter_size[k] = length(unique(cycle_coordinates))
    end # cycle
    return perimeter_size
end

function get_img_number(data_name, img_name; data_config="BW")
    img_number = 0
    pruned_name = replace(img_name, "_$(data_config)" => "", ".jpg" => "")
    if data_name == "pseudoart"
        pseudoarts_name_to_order = [v => k for (k, v) in CONFIG.pseudoart_images_order] |> OrderedDict
        img_number = pseudoarts_name_to_order[pruned_name]
    else
        img_number = parse(Int, pruned_name)
    end
    return img_number
end

function density(img_cycles, window_size; default_map_value=NaN)
    unique_cycles_count = count_unique_cycles_in_windows_with_positions(
        img_cycles,
        window_size,)

    total_grid_rows = max([k[1] for (k, v) in unique_cycles_count]...)
    total_grid_cols = max([k[2] for (k, v) in unique_cycles_count]...)

    parameter_map = fill(default_map_value, total_grid_rows, total_grid_cols)
    for (k, v) in unique_cycles_count
        if v != 0
            parameter_map[k[1], k[2]] = v
        end
    end

    parameters_values = [v for (k, v) in unique_cycles_count]

    return parameter_map, parameters_values
end

function density_scaled(img_cycles, window_size; default_map_value=NaN)
    parameter_map, parameters_values = density(img_cycles, window_size; default_map_value=default_map_value)
    parameter_map ./= window_size^2
    parameters_values = parameters_values ./ window_size^2
    return parameter_map, parameters_values
end

function max_persistence(img_cycles, window_size, cycles_info; default_map_value=NaN)
    unique_cycles = unique_cycles_in_windows_with_positions(
        img_cycles, window_size,)

    total_grid_rows = max([k[1] for (k, v) in unique_cycles]...)
    total_grid_cols = max([k[2] for (k, v) in unique_cycles]...)

    parameter_map = fill(default_map_value, total_grid_rows, total_grid_cols)
    parameters_values = Float64[]
    k = [k for (k, v) in (unique_cycles)][1]
    v = [v for (k, v) in (unique_cycles)][1]
    for (k, v) in unique_cycles
        if !isempty(v)
            related_cycles = cycles_info[v]
            all_persistence = [c for c in persistence.(related_cycles) if !isnan(c)]
            p = 0
            if isempty(all_persistence)
                @warn "No persistence data in a window, setting max to 0"
                p = 0
            else
                p = max(all_persistence...)
            end
            push!(parameters_values, p)

            parameter_map[k[1], k[2]] = p
        else
            push!(parameters_values, 0)
        end
    end
    return parameter_map, parameters_values
end

function cycles_perimeter(img_cycles, window_size, cycles_info, cycles_perimeters; default_map_value=NaN)
    unique_cycles = unique_cycles_in_windows_with_positions(img_cycles, window_size,)

    total_grid_rows = max([k[1] for (k, v) in unique_cycles]...)
    total_grid_cols = max([k[2] for (k, v) in unique_cycles]...)

    parameter_map = fill(default_map_value, total_grid_rows, total_grid_cols)
    parameters_values = Float64[]
    k = [k for (k, v) in (unique_cycles)][1]
    v = [v for (k, v) in (unique_cycles)][1]

    for (k, v) in unique_cycles
        if !isempty(v)

            all_perimeters = cycles_perimeters[v]
            p = 0
            if isempty(all_perimeters)
                @warn "No persistence data in a window, setting max to 0"
                p = 0
            else
                p = max(all_perimeters...)
            end
            push!(parameters_values, p)

            parameter_map[k[1], k[2]] = p
        else
            push!(parameters_values, 0)
        end
    end
    return parameter_map, parameters_values

end

function get_parameters_map(func, img_cycles, window_size, cycles_info, cycles_perimeters; default_map_value=NaN)
    if func == density
        return density(img_cycles, window_size; default_map_value=default_map_value)
    elseif func == density_scaled
        return density_scaled(img_cycles, window_size; default_map_value=default_map_value)
    elseif func == cycles_perimeter
        return cycles_perimeter(img_cycles, window_size, cycles_info, cycles_perimeters; default_map_value=default_map_value)
    elseif func == max_persistence
        return max_persistence(img_cycles, window_size, cycles_info; default_map_value=default_map_value)
    else
        unique_cycles = unique_cycles_in_windows_with_positions(
            img_cycles, window_size,)

        total_grid_rows = max([k[1] for (k, v) in unique_cycles]...)
        total_grid_cols = max([k[2] for (k, v) in unique_cycles]...)

        parameter_map = fill(default_map_value, total_grid_rows, total_grid_cols)
        parameters_values = []
        k = [k for (k, v) in (unique_cycles)][1]
        v = [v for (k, v) in (unique_cycles)][1]
        for (k, v) in unique_cycles
            if !isempty(v)
                related_cycles = cycles_info[v]
                p = func.(related_cycles) |> mean
                push!(parameters_values, p)

                parameter_map[k[1], k[2]] = p
            else
                push!(parameters_values, 0)
            end
        end
        return parameter_map, parameters_values
    end
end

function get_heatmap_windows(
    view_and_img_df, window_size,
    SPACE_WIDTH, SPACE_HEIGHT,
    STARTING_POINT, VIEWING_WIDTH,
    IMG_HEIGHT, IMG_WIDTH;
    divide_by_total_subjects=true)
    heatmap_from_image_area = get_heatmap_py(view_and_img_df, SPACE_WIDTH, SPACE_HEIGHT) |>
                              (y -> y[:, STARTING_POINT:(STARTING_POINT+VIEWING_WIDTH)])

    if divide_by_total_subjects
        total_subjects = view_and_img_df.Subject |> unique |> length
        heatmap_from_image_area = heatmap_from_image_area ./ total_subjects
    end

    non_nan_map = [x for x in heatmap_from_image_area if !isnan(x)]
    if isempty(non_nan_map)
        max_in_area = 1
    else
        max_in_area = max(non_nan_map...)
    end
    heatmap_image = imresize(
                        Gray.(heatmap_from_image_area ./ max_in_area),
                        (IMG_HEIGHT, IMG_WIDTH)
                    ) |>
                    Matrix{Float64} .|>
                    (y -> y * max_in_area)

    mean_heatmap_in_window = mean_heatmap_in_windows(heatmap_image, window_size,)

    windowed_heatmap_values = [v for (k, v) in mean_heatmap_in_window]
    subject_looking = findall(x -> x != 0, windowed_heatmap_values)
    return subject_looking, mean_heatmap_in_window
end

function teststatistic(x)
    n = x.n_x * x.n_y / (x.n_x + x.n_y)
    sqrt(n) * x.δ
end
function resolve_with_max(max_values)
    if all(isnan.(max_values))
        return NaN
    elseif isnan(max_values[1])
        return max_values[2]
    elseif isnan(max_values[2])
        return max_values[1]
    else
        return max(max_values...)
    end
end
function resolve_with_sum(max_values)
    if all(isnan.(max_values))
        return NaN
    elseif isnan(max_values[1])
        return max_values[2]
    elseif isnan(max_values[2])
        return max_values[1]
    else
        return sum(max_values)
    end
end


function get_parameters_map_from_joined_filtration(parameter_map_BW, parameter_map_WB, func)
    merged_maps = cat(parameter_map_BW, parameter_map_WB, dims=3)
    total_rows, total_cols = size(parameter_map_BW)
    parameter_map = zeros(total_rows, total_cols)
    for row in 1:total_rows, col in 1:total_cols
        max_values = merged_maps[row, col, :]

        if func == density || func == density_scaled
            parameter_map[row, col] = resolve_with_sum(max_values)
        elseif func == max_persistence || func == persistence
            parameter_map[row, col] = resolve_with_max(max_values)
        elseif func == cycles_perimeter
            parameter_map[row, col] = resolve_with_max(max_values)
        else
            ErrorException("Function not known") |> throw
        end

    end
    return parameter_map
end
function get_parameters_values_from_joined_filtration(parameters_values_BW, parameters_values_WB, func)
    parameters_values = Float64[]
    for (param_BW, param_WB) in zip(parameters_values_BW, parameters_values_WB)
        joined_values = [param_BW, param_WB]
        if func == density || func == density_scaled
            push!(parameters_values, resolve_with_sum(joined_values))
        elseif func == max_persistence || func == persistence
            push!(parameters_values, resolve_with_max(joined_values))
        elseif func == cycles_perimeter
            push!(parameters_values, resolve_with_max(joined_values))
        else
            ErrorException("Function not known") |> throw
        end
    end

    if typeof(parameters_values) != Vector{Float64}
        parameters_values = Vector{Float64}(parameters_values)
    end
    return parameters_values
end
