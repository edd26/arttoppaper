
# ===-===-
struct ImagesSequence
    img_path::String
    img_list::Vector{String}
end

function Base.length(sequence::ImagesSequence)
    sequence.img_list |> Base.length
end

function load_from_sequence(sequence::ImagesSequence, img_index)
    Images.load(sequence.img_path * "/" * sequence.img_list[img_index])
end

# ===-===-
struct ImageInfo
    img_name::String
    img_path::String
    img_dataset::String
end

function load_from_sequence(my_img::ImageInfo)
    Images.load(my_img.img_path * "/" * my_img.img_name)
end

function get_img_from_sequence(sequence::ImagesSequence, img_index::Int)::ImageInfo
    img_name = sequence.img_list[img_index]
    img_path = sequence.img_path
    img_dataset = split(sequence.img_path, "/")[end]

    if img_dataset == "pseudoart_networks_cleaned_2048" && length(sequence) < 10
        img_dataset *= "_net" * split(img_name, "_")[2]

    end

    return ImageInfo(img_name, img_path, img_dataset)
end

# ===-===- 
struct ImgSize
    width::Int
    height::Int
end

## ===-===-
function get_barcodes_info_with_dipha(bw_img_resized, img_name, data_set; img_config::String="BW", id::String="")
    ## ===-===-
    # 0b >>>
    scaled_img = floor.(Int, bw_img_resized .* 255)

    ## ===-===-===-===-
    # 1a: Export dipha file >>>
    if ~(export_for_dipha_folder(img_config, data_set,) |> isdir)
        export_for_dipha_folder(img_config, data_set,) |> mkpath
    end

    dipha_file_name = split(img_name, r"\.[jp][pn]g")[1] * "_$(img_config)_id$(id)"
    export_file_name = export_for_dipha_folder(img_config, data_set, dipha_file_name)
    save_image_data(scaled_img, export_file_name)

    ## ===-===-===-===-
    # 1b: run dipha processing >>>
    !(dipha_raw_export_folder(img_config, data_set,) |> ispath) && dipha_raw_export_folder(img_config, data_set,) |> mkpath

    command = `$dipha_exec $(export_file_name) $(dipha_raw_export_folder(img_config, data_set, dipha_file_name))`
    # @info "Running dipha: " command
    process_info = command |> run

    if process_info.exitcode == 0
        @info "Sucessfuly finished DIPHA processing."
    else
        @warn "Failed to finish DIPHA processing. Skiping further conputations"
    end
    @info "Removing DIPHA file"
    try
        rm(export_file_name)
    catch
        @warn "Could not remove file- it does not exist"
    end

    ## ===-===-===-===-
    # 1c >>
    # Load birth death diagrams
    dims, birth_values, death_values = dipha_raw_export_folder(img_config, data_set, dipha_file_name) |> load_persistence_diagram
    bd_data = hcat(dims, birth_values, death_values)
    data_matrix = get_thresholded_values(PERSISTENCE_THRESHOLD, bd_data)

    return data_matrix
end

function get_survival_barcodes(bd_matrix, threshold)
    all_dim_births = bd_matrix[:, 2]
    all_dim_deaths = bd_matrix[:, 3]
    persistances = all_dim_deaths .- all_dim_births
    survivals = persistances .> threshold
    return bd_matrix[survivals, :]
end


struct ImageLandscapes
    landscape_dim0::PersistenceLandscape
    landscape_dim1::PersistenceLandscape

    function ImageLandscapes(bd_matrix)
        landscapes = []
        for topology_dim in [0, 1]
            dim_position = bd_matrix[:, 1] .== topology_dim
            births = bd_matrix[dim_position, 2]
            deaths = bd_matrix[dim_position, 3]
            barcodes = [MyPair(b, d) for (b, d) in zip(births, deaths)] |> PersistenceBarcodes
            push!(landscapes, PersistenceLandscape(barcodes, topology_dim))
        end

        land_dim0, land_dim1 = landscapes
        new(land_dim0, land_dim1)
    end
end