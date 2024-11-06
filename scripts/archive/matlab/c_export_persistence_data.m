clc
close all
clear all

%%
sets_names = ["wystawa_fejkowa", "Artysta"];
% sets_names = ["Artysta"];

doing_RGB = false;

if doing_RGB
    suffix = "RGB";
else
    suffix = "BW";
end

for set_index = 1:2
    file_set = sets_names(set_index);
    % file_set = 'Artysta';

    dipha_files_folder = strcat('../../data/exp_pro/', suffix, '/dipha_results/', file_set, '/');
    dipha_persitence_info_folder = strcat('../../data/exp_pro/', suffix, '/bd-data/', file_set, '/');

    files_list = dir(dipha_files_folder);
    export_folder = dir(dipha_persitence_info_folder);
    export_path = export_folder(1).folder;

    total_files = size(files_list, 1);

    %% Export file with all persistence data

    % for file_index = 3:total_files
    %     display(file_index)
    %     file_info = files_list(file_index);
    %
    %     name = file_info.name;
    %     path = file_info.folder;
    %     in_filename = strcat(path, '/', name);
    %     out_filename = strcat(export_path, '/', name, '.csv');
    %
    %     [dims, birth_values, death_values]  = load_persistence_diagram( in_filename );
    %
    %     total_elements = size(dims, 1);
    %     dim_info_matrix = zeros(total_elements, 3);
    %     dim_info_matrix(:,1) = dims;
    %     dim_info_matrix(:,2) = birth_values;
    %     dim_info_matrix(:,3) = death_values;
    %
    %     csvwrite(out_filename, dim_info_matrix)
    % end

    %% Export file with all persistence data for each dimension
    persistence_threshold = 0;

    for file_index = 1:total_files
        display(file_index)
        file_info = files_list(file_index);

        path = file_info.folder;
        name = file_info.name;

        if strcmp(name, '.') || strcmp(name, ".DS_Store") || strcmp(name, "..") || strcmp(name, "._.DS_Store")
            continue
        end

        in_filename = strcat(path, '/', name);

        [dims, birth_values, death_values] = load_persistence_diagram(in_filename);

        thresholded_points = death_values - birth_values > persistence_threshold;
        dims = dims(thresholded_points);
        births = birth_values(thresholded_points);
        deaths = death_values(thresholded_points);
        max_dim = max(unique(dims));

        for dim = 0:max_dim
            dim_indices = dims == dim;
            new_dims = dims(dim_indices);
            new_births = birth_values(dim_indices);
            new_deaths = death_values(dim_indices);
            total_elements = size(new_dims, 1);

            dim_info_matrix = zeros(total_elements, 3);
            dim_info_matrix(:, 1) = new_dims;
            dim_info_matrix(:, 2) = new_births;
            dim_info_matrix(:, 3) = new_deaths;

            final_name = strcat(name, '_dim=', string(dim), '_threshold=', string(persistence_threshold), '.csv');
            final_export_path = strcat(export_path, '/dim=', string(dim), '/');

            if ~(isfolder(final_export_path))
                mkdir(final_export_path)
            end

            out_filename = strcat(final_export_path, final_name);
            csvwrite(out_filename, dim_info_matrix)
        end

    end

end
