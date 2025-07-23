
function filter_by_threshold(files_vector, threshold)
    return [k for k in files_vector if occursin("_threshold=$(threshold)", k)]
end


filter_out_DS(files_list) = filter(x -> !occursin(".DS_Store", x), files_list)

filter_out_by_threshold(files_list, persistence_threshold) = filter(x -> occursin("threshold=$(persistence_threshold)", x), files_list)

function remove_inf(a_matrix::Matrix)
    binary_vector = [all(a_matrix[k, :] .|> !isinf) for k in 1:size(a_matrix, 1)]
    return a_matrix[binary_vector, :]
end

function filter_out_hidden(all_sample_files)
    [k for k in all_sample_files if k[1] != '.']
end


"""
refactor_files_names(files_list, data_set, config, pers_threshold)

Takes `files_list` and selects the files produced for `pers_threshold`, removes
    the threshold information from the name.

Due to differences in the names, names for different data sets have to be
processed in a different way. There is also difference if the files were
created for RGB or BW config.
"""
function filter_and_refactor_files_names(files_list, data_set, data_config, pers_threshold, selected_dim)

    files_names = String[]
    if data_set == "pseudoart"
        if data_config == "RGB"
            files_names = [join(split(k, "_")[1:4], "_") for k in filter_out_by_threshold(files_list, pers_threshold)]
        else
            files_names = [join(split(k, "_")[1:3], "_") for k in filter_out_by_threshold(files_list, pers_threshold)]
        end
    elseif data_set == "Rothko" || data_set == "Mark"
        files_names = [split(k, "BW_dim=$(selected_dim)_threshold=$(pers_threshold)")[1][1:end-1] for k in files_list]
    elseif data_set == "mixed-art"
        @info "mart"
        if data_config == "RGB"
            @info "RGB"
            files_names = [split(k, "_dim=$(selected_dim)_threshold=$(pers_threshold)")[1] for k in files_list]
        elseif data_config == "BW"
            files_names = [split(k, "_BW_dim=$(selected_dim)_threshold=$(pers_threshold)")[1] for k in files_list]
        else
            ErrorException("Wrong data config") |> throw
        end
    elseif data_set == "SimpleExamples"
        files_names = [join(split(k, "_")[1:end-3], "_") for k in files_list]
    elseif data_set == "fractals"
        files_names = [join(split(k, "_")[1:2], "_") for k in files_list]
    else
        if data_config == "RGB"
            files_names = [join(split(k, "_")[1:2], "_") for k in filter_out_by_threshold(files_list, pers_threshold)]
        else
            files_names = [split(k, "_")[1] for k in files_list]
        end
    end

    return files_names
end
