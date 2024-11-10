clc
close all
clear all

%%
sets_names = ["wystawa_fejkowa", "Artysta"];

for set_index = 1:2
    file_set = sets_names(set_index);
    % file_set = 'Artysta';

    dipha_files_folder = strcat('../../data/exp_pro/dipha_results/', file_set, '/');
    dipha_plots_folder = strcat('../../plots/dipha_results/bd-diagrams/', file_set, '/');

    files_list = dir(dipha_files_folder);
    export_folder = dir(dipha_plots_folder);
    export_path = export_folder(1).folder;

    total_files = size(files_list, 1);

    %%
    persistence_threshold = 0;

    for file_index = 1:total_files

        display(file_index)
        file_info = files_list(file_index);

        name = string(file_info.name);

        if name == '.' || (name == ".DS_Store") || strcmp(name, "..")
            continue
        end

        path = file_info.folder;
        filename = strcat(path, '/', name);
        export_plot_name = strcat(export_path, '/', name);

        f = figure();
        plt = plot_persistence_diagram(filename, persistence_threshold);
        %     saveas(f, export_plot_name);
        saveas(gcf, export_plot_name, 'png');
    end

end

%%

dimension = 1;
resolution = 50;

% for file_index = 3:total_files
%     file_info = files_list(file_index);
%
%     name = file_info.name;
%     path = file_info.folder;
%     filename = strcat(path, '/', name);
%     % Plot with diagonal as a base
%     plt = plot_midlife_persistence_diagram( filename, persistence_threshold )
%
%     plot_persistence_diagram_density( filename, dimension, resolution )
% end
