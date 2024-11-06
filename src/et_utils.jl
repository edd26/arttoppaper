import ImageFiltering: Kernel
using DataFrames
using CSV
import StatsBase: countmap

function get_filtered_ET(selected_file; filterout_time::Bool=true, filterout_pupil_info::Bool=true)
    raw_eye_tracing = CSV.read(selected_file, DataFrame)

    # Remove coluns that will not be used for further processing
    filtered_columns = names(raw_eye_tracing)
    filter!(x -> !occursin("Column1", x), filtered_columns)
    filter!(x -> !occursin("Group", x), filtered_columns)
    filterout_time && filter!(x -> !occursin("RecordingTime [ms]", x), filtered_columns)

    filter!(x -> !occursin("Color", x), filtered_columns)
    filter!(x -> !occursin("Tracking Ratio", x), filtered_columns)
    if filterout_pupil_info
        filter!(x -> !occursin("Pupil Size", x), filtered_columns)
        filter!(x -> !occursin("Pupil Diameter", x), filtered_columns)
    end
    filter!(x -> !occursin("Time of Day", x), filtered_columns)

    return raw_eye_tracing[:, filtered_columns]
end


"""
Replace every position of `-` with the mean value of neighbouring values.

If it is at the extremes (beginning or ending) use second or second to last 
value consectively.
"""
function approximate_positions(positions_vector)
    converable_numbers = positions_vector .!= "-"
    non_floats = findall(x -> x == 0, converable_numbers)

    replacements = ["" for k in non_floats]
    index = 1
    non_float = non_floats[index]
    for (index, non_float) in non_floats |> enumerate
        if non_float == 1
            if positions_vector[2] != "-"
                replacements[index] = positions_vector[2]
            else
                ErrorException("Can not replace- neighbouring values are non-float values") |> throw
            end
            continue
        end
        if non_float == length(positions_vector)
            if positions_vector[end-1] != "-"
                replacements[index] = positions_vector[end-1]
            else
                ErrorException("Can not replace- neighbouring values are non-float values") |> throw
            end
            continue
        end
        before = parse(Float64, positions_vector[non_float-1])
        after = parse(Float64, positions_vector[non_float+1])
        replacements[index] = "$((before+after)/2)"
    end

    refactored_positions = copy(positions_vector)
    refactored_positions[non_floats] .= replacements
    return refactored_positions
end

function float_convert(x::Vector{String})
    return parse.(Float64, copy(x))
end

struct Point
    x::Int
    y::Int
end

# function get_points_from_vec(x_coords, y_coords, ind; PRECISION_FACTOR=10)
function get_points_from_vec(x_coords, y_coords, ind)
    x_start_index, y_start_index, x_stop_index, y_stop_index =
    # map(x -> x * PRECISION_FACTOR |> Int, [
        map(x -> x |> Int, [
            x_coords[ind],
            y_coords[ind],
            x_coords[ind+1],
            y_coords[ind+1],
        ])
    p1 = Point(x_start_index, y_start_index)
    p2 = Point(x_stop_index, y_stop_index)
    return p1, p2
end

function get_path_coords(p1::Point, p2::Point)
    # Code for line approximation
    a = (p2.y - p1.y) / (p2.x - p1.x)
    b = p1.y - a * p1.x

    x_vec = [x for x in p1.x:p2.x]
    y_vec = ceil.(Int, [a * x + b for x in x_vec])
    return x_vec, y_vec
end

function get_point_coords(p1)
    x_vec = [p1.x,]
    y_vec = [p1.y,]
    return x_vec, y_vec
end

function get_hline_coords(p1::Point, p2::Point)
    x_vec = [x for x in p1.x:p2.x]
    y_vec = [p1.y for k in x_vec]
    return x_vec, y_vec
end

function get_hline_coords(p1::Point, p2::Point)
    y_vec = [x for x in p1.y:p2.y]
    x_vec = [p1.x for k in y_vec]
    return x_vec, y_vec
end

function append_path!(x_vec::Vector, y_vec::Vector, space_matrix::Matrix{Float64}, kernel)
    for (x_ind, y_ind) in zip(x_vec, y_vec)
        append_kernel!(x_ind, y_ind, space_matrix::Matrix{Float64}, kernel)
    end
end

function append_kernel!(x_ind, y_ind, space_matrix::Matrix{Float64}, kernel)
    total_rows, total_cols = size(space_matrix)
    kernel_size = size(kernel, 1)

    if kernel_size == 1
        space_matrix[x_ind, y_ind] .+= kernel
    elseif kernel_size % 2 == 1
        half_kernel = kernel_size ÷ 2

        # Get indices where the kernel have to be applied
        kernel_left, kernel_bottom, = map(x -> x - half_kernel, [x_ind, y_ind])
        kernel_right, kernel_top, = map(x -> x + half_kernel, [x_ind, y_ind])


        # Range of values in map where kernel is applied
        img_x_left, img_x_right, img_y_bottom, img_y_top = kernel_left,
        kernel_right, kernel_bottom, kernel_top

        # range of kernel indices used
        kernel_index_min_x = 1
        kernel_index_max_x = kernel_size
        kernel_index_min_y = 1
        kernel_index_max_y = kernel_size

        # Corner cases >>>
        # left part of kernel is out of image
        if kernel_left <= 0
            img_x_left = 1
            kernel_index_min_x = abs(kernel_left) + 2
        end

        # right part of kernel is out of image
        # if kernel_right > total_rows
        if kernel_right > total_cols
            img_x_right = min(kernel_right, total_cols)
            kernel_index_max_x = kernel_size - (kernel_right - total_cols)
        end
        if kernel_bottom <= 0
            img_y_bottom = 1
            kernel_index_min_y = abs(kernel_bottom) + 2
        end
        if kernel_top > total_rows
            img_y_top = min(kernel_top, total_rows)
            kernel_index_max_y = kernel_size - (kernel_top - total_rows)
        end
        # Corner cases <<<
        kernel_index_x = kernel_index_min_x:kernel_index_max_x
        kernel_index_y = kernel_index_min_y:kernel_index_max_y
        index_x_range = img_x_left:img_x_right
        index_y_range = img_y_bottom:img_y_top
        space_matrix[index_y_range, index_x_range] .+= kernel[kernel_index_y, kernel_index_x]

    else #  kernel_size is an even number
        ErrorException("Can not work with even kernel size- run with kernel_size%2==1") |> throw
    end
end

function get_heatmap_kernel(;
    kernel_type::Symbol=:gauss,
    kernel_size::Int=100,
    kernel_multiplier::Float64=1.0,
    width_factor::Int=4
)

    σ1, σ2 = kernel_size / width_factor, kernel_size / width_factor
    kernel_args = ([σ1, σ2], [kernel_size + 1, kernel_size + 1])

    kernel = get_kernel(kernel_size, kernel_type, kernel_args...) .* kernel_multiplier
    kernel ./= findmax(kernel)[1]
    kernel .*= kernel_multiplier
    half_kernel = kernel_size ÷ 2
    kernel_range = -half_kernel:half_kernel
    return kernel[kernel_range, kernel_range]
end


function get_kernel(kernel_size::Int, kernel_type::Symbol, kernel_args...)
    if kernel_size <= 0
        ErrorException("Kernel size must be greater than 0") |> throw
    end

    if kernel_type == :ones
        return ones(kernel_size, kernel_size)
    elseif kernel_type == :gauss
        return Kernel.gaussian(kernel_args...)
    else
        ErrorException("Unknow kernel type") |> throw
    end
end

# x_indices = x_vals
# y_indices = y_vals
function create_eye_tracking_matrix(x_indices, y_indices, kernel, img_widht, img_height)

    space_matrix = zeros(img_widht, img_height)
    total_samples = length(x_indices)

    ind = 5729
    for ind = 1:total_samples-1
        # @info ind
        if ind % 100 == 0
            @debug ind
        end
        p1, p2 = get_points_from_vec(x_indices, y_indices, ind)
        if (p1.x == 0 && p1.y == 0) || (p2.x == 0 && p2.y == 0)
            @debug "Skipping"
            continue
        end
        if p1.x < 0 || p1.y < 0 || p2.x < 0 || p2.y < 0
            @warn "Skipping for a point with negative coordinates!"
            continue
        end

        if p1 == p2
            @debug "$(ind): equals" p1, p2
            x_vec, y_vec = get_point_coords(p1)

        elseif p1.x == p2.x
            @debug "$(ind): x equal " p1, p2
            x_vec, y_vec = get_hline_coords(p1, p2)

        elseif p1.y == p2.y
            @debug "$(ind): y equal " p1, p2
            x_vec, y_vec = get_hline_coords(p1, p2)

        elseif p1 != p2
            x_vec, y_vec = get_path_coords(p1, p2)
        else
            ErrorException("Did not meet any of the set conditions") |> throw
        end
        append_path!(x_vec, y_vec, space_matrix, kernel,)
    end
    return space_matrix
end


"""
Split df into df specific for session and view of the image for a given subject.
"""
function split_df_into_views_for_subject(filtered_ET, selected_subject)
    subject_df = filter(row -> row.Subject == selected_subject, filtered_ET)

    # session1_view1_df, session1_view2_df, session2_view1_df, session2_view2_df, no_image_df =
    sub_session1_view1_df, sub_session1_view2_df, sub_session2_view1_df, sub_session2_view2_df, no_image_df =
        split_df_into_views(subject_df)

    # sub_session1_view1_df, sub_session1_view2_df, sub_session2_view1_df, sub_session2_view2_df = 
    # map(
    #     x -> filter(row -> row.Subject == selected_subject, x),
    #     [session1_view1_df, session1_view2_df, session2_view1_df, session2_view2_df, no_image_df]
    # )

    return sub_session1_view1_df, sub_session1_view2_df, sub_session2_view1_df, sub_session2_view2_df, no_image_df
end

"""
Split df into df specific for session and view of the image.
"""
function split_df_into_views(filtered_ET)
    no_image_df = filter(
        row -> row.Stimulus == "NoImage" || occursin("n0", row.Stimulus),
        filtered_ET
    )
    filtered_ET_with_image = filter(
        row -> row.Stimulus != "NoImage" && !occursin("n0", row.Stimulus) && !occursin("mask", row.Stimulus),
        filtered_ET
    )

    session1_df = filter(row -> row.Session == 1, filtered_ET_with_image)
    session2_df = filter(row -> row.Session == 2, filtered_ET_with_image)

    session1_view1_df = filter(row -> !occursin("s2", row.Stimulus), session1_df)
    session1_view2_df = filter(row -> occursin("s2", row.Stimulus), session1_df)

    session2_view1_df = filter(row -> !occursin("s2", row.Stimulus), session2_df)
    session2_view2_df = filter(row -> occursin("s2", row.Stimulus), session2_df)

    return session1_view1_df, session1_view2_df, session2_view1_df, session2_view2_df, no_image_df
end

"""
function get_fixation_sequence_vector(filtered_ET)

Takes a DataFrame structure and returns a vector indicating which of the
items in the data structure is an element of a sequence.

An element is considered as a sequence, when it and the previous elements are
fixation points, what is indicated by the "Category Right" and "Category Left"
columns- both of them have to be a fixation for the point to be considered as a
fixation.

Non-fixation elements are indicated with -1. All fixation points within sequence 
are marked with the number, which is the index where the fixation started.
"""
function get_fixation_sequence_vector(filtered_ET)
    total_rows, total_cols = size(filtered_ET)
    # Get all of the items that are fixations of duration 200 and more
    fixation_sequence = zeros(Int, total_rows)
    sequence_start = -1
    previous_fixation = false
    previous_subject = filtered_ET[1, :Subject]
    for (i, r) in eachrow(filtered_ET) |> enumerate
        if r.Subject == previous_subject
            if r["Category Right"] == "Fixation" && r["Category Left"] == "Fixation"
                if sequence_start == -1
                    sequence_start = i
                end
                fixation_sequence[i] = sequence_start
            elseif previous_fixation && i != total_rows # this handles single samples that were interuption in a sequence of fixations
                previous_fixation = false
                fixation_sequence[i] = sequence_start
            else
                if sequence_start != -1
                    sequence_start = -1
                end
                fixation_sequence[i] = sequence_start
            end
        else
            if sequence_start != -1
                sequence_start = -1
            end
        end
        previous_subject = r.Subject
    end
    return fixation_sequence
end

"""
The input is data frame together with a vector indicating which of its elements
are the fixation points. Returns a vector that shows the duration of the
fixation sequence- every point within a sequence is represented with the
duration of the sequence that it is a member of.

The duration is computed as difference between last and fist elements in
"RecordingTime [ms]" column that corresponds to a sequence. 
"""
function get_fixation_durations(filtered_ET, fixation_sequence; samples_sequence=100)
    total_rows = length(fixation_sequence)
    # ===-===-
    @info "Computing durations"
    # Estimate how long the fixations are
    fixations_lengths = fixation_sequence |> countmap |> sort

    # Process only fixations that are longet than 100 samples (takes less time with reducing at this stage)
    long_fixations = [k => v for (k, v) in fixations_lengths if v >= samples_sequence]

    # k, v = long_fixations[256]
    durations_vec = zeros(Int, total_rows)
    for (i, (k, v)) in long_fixations |> enumerate
        if i % 100 == 0
            @info "Currently at step $(i)"
        end
        if k == -1 || k == 0
            continue
        end
        all_k_related = findall(x -> x .== k, fixation_sequence)

        related_times = filtered_ET[all_k_related, "RecordingTime [ms]"]
        duration = ceil(Int, related_times[end] - related_times[1])
        if duration < 0
            ErrorException("Duration of a sequence is less than 0 ms!") |> throw
        end

        durations_vec[all_k_related] .= duration
    end
    return durations_vec
end


"""
Scripts from 8e2 to create a dataframe that is processed
by PyGaze, after being saved.

The format is: columns are x and y coordinate with rows being data points.
"""
function get_fixation_df(view_and_img_df, fixation)
    fixation_df = filter(row -> row["Fixation index"] == fixation, view_and_img_df)
    export_df = DataFrame(
        "GazeRightx" => round.(Int, fixation_df[:, "Point of Regard Right X [px]"]),
        "GazeRighty" => round.(Int, fixation_df[:, "Point of Regard Right Y [px]"]),
    )
    return export_df
end

function get_gaze_df(view_and_img_df,)
    export_df = DataFrame(
        "GazeRightx" => round.(Int, view_and_img_df[:, "Point of Regard Right X [px]"]),
        "GazeRighty" => round.(Int, view_and_img_df[:, "Point of Regard Right Y [px]"]),
    )
    return export_df
end

function save_fixations(exportdir, export_df, viewing_index, name_number, name, fixation)
    saving_dir(args...) = exportdir("view$(viewing_index)", "img$(name_number )", args...)

    saving_dir() |> isdir || saving_dir() |> mkpath

    open(saving_dir("pygaze_format_img_$(name)_fixation$(fixation ).csv"), "w") do f
        writedlm(f, Matrix(export_df), ',')
    end #open
end
