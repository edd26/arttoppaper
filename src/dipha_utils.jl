## ===-===-===-===-
# Save image for dipha
function save_image_data(data, filename)
    #% open file for writing
    # fid = open(filename, "w")
    open(filename, "w") do fid

        #% DIPHA magic number
        write(fid, Int64(8067171840))

        #% file type identifier
        write(fid, Int64(1))

        #% total number of values
        write(fid, Int64(length(data)))

        #% dimension
        write(fid, Int64(length(size(data))))

        #% lattice resolution
        size1, size2 = size(data)
        write(fid, Int64(size1))
        write(fid, Int64(size2))

        #% actual data in x-fastest order
        write(fid, Float64.(data[:]))
    end
end


## ===-===-===-===-
# Birth-death diagrams loading and procesesing
function load_persistence_diagram(filename)
    dims = zeros(Int, 1)
    births = zeros(Float64, 1)
    deaths = zeros(Float64, 1)

    open(filename, "r") do fid
        fid = open(filename, "r")

        # make sure it is a DIPHA file
        dipha_identifier = read(fid, Int64)
        dipha_identifier == 8067171840 || ErrorException("input is not a DIPHA file") |> throw

        # make sure it is a persistence_diagram file
        diagram_identifier = read(fid, Int64)
        diagram_identifier == 2 || ErrorException("input is not a persistence_diagram file") |> throw

        # read actual data from file
        num_pairs = read(fid, Int64)
        dims = zeros(Int, num_pairs)
        births = zeros(Float64, num_pairs)
        deaths = zeros(Float64, num_pairs)

        for k in 1:num_pairs
            dims[k] = read(fid, Int64)
            births[k] = read(fid, Float64)
            deaths[k] = read(fid, Float64)
        end
    end # open
    return dims, births, deaths
end

function get_thresholded_values(persistence_threshold, bd_data)
    thresholded_points = bd_data[:, 3] - bd_data[:, 2] .> persistence_threshold
    return bd_data[thresholded_points, :]
end