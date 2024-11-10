clc
close all
clear all

%%
sources = ["wystawa_fejkowa", "Artysta"];
% "fake_networks_cleaned_2048",
base_path = '../../data/exp_pro';

total_sources = size(sources, 2);

for k = 1:total_sources
    source = sources(k);
    display(sources

    %     data_files_folder = strcat(base_path,'/bw_export/',source);
    %     dipha_files_folder = strcat(base_path,'/images_for_dipha/',source);
    data_files_folder = strcat(base_path, '/channels_export/', source);
    dipha_files_folder = strcat(base_path, '/images_for_dipha_RGB/', source);

    if ~isfolder(dipha_files_folder)
        mkdir(dipha_files_folder)
    end

    files_list = dir(data_files_folder);
    export_dir = dir(dipha_files_folder);

    total_files = size(files_list, 1);

    for file_index = 1:total_files
        %         display(file_index)
        file_info = files_list(file_index);

        name = file_info.name;

        if strcmp(name, '.') || strcmp(name, ".DS_Store") || strcmp(name, "..")
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

        export_file_name = strcat(dipha_files_folder, '/', name);
        save_image_data(loaded_img, export_file_name);

    end

end
