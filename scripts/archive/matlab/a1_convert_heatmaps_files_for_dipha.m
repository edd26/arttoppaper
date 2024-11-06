clc
close all
clear all

%%
sources = ["size=81"];
% "fake_networks_cleaned_2048",
base_path = '../../data/exp_pro/Heatmaps/kernel=gauss/';

total_sources = size(sources, 2);

for k = 1:total_sources
    source = sources(k);
    display(source)

    %     data_files_folder = strcat(base_path,'/bw_export/',source);
    %     dipha_files_folder = strcat(base_path,'/images_for_dipha/',source);
    data_files_folder = strcat(base_path, source);
    dipha_export_folder = strcat(base_path, source, '/dipha_export/');

    if ~isfolder(dipha_export_folder)
        mkdir(dipha_export_folder)
    end

    files_list = dir(data_files_folder);
    export_dir = dir(dipha_export_folder);

    total_files = size(files_list, 1);

    for file_index = 1:total_files
        %         display(file_index)
        file_info = files_list(file_index);

        name = file_info.name;
        display(name)

        if strcmp(name, '.') || strcmp(name, ".DS_Store") || strcmp(name, "..") || strcmp(name, "pdf") || strcmp(name, "dipha_export")
            continue
        end

        path = file_info.folder;
        loaded_img = imread(strcat(path, '/', name));

        %         export_name = strsplit(name, '.');
        %         export_name = [export_name{1}];
        %         export_name = strcat(export_name, '.complex')
        %         export_file_name = strcat(dipha_files_folder, '/', export_name);
        %         display(export_file_name)
        %         save_image_data(loaded_img, export_file_name);

        export_file_name = strcat(dipha_export_folder, '/', name);
        save_image_data(loaded_img, export_file_name);

    end

end
