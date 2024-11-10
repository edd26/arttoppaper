#=
Third step of dipha data processing: birth death data export
=#

using DrWatson
@quickactivate "ArtTopology"

## ===-===-===-===-
using DelimitedFiles

## ===-===-===-===-
"dipha_utils.jl" |> srcdir |> include
"loading_utils.jl" |> srcdir |> include
"config.jl" |> scriptsdir |> include

## ===-===-===-===-
import .CONFIG: dipha_raw_export_folder_set, dipha_bd_info_export_folder_set, PERSISTENCE_THRESHOLD

## ===-===-===-===-
scriptprefix = "1c"
files_list = dipha_raw_export_folder_set() |> readdir |> filter_out_hidden

# missing files
# files_list = [split(k, ".jpg")[1] for k in [
#     "net_5364_1.jpg"
#     "net_5365_1.jpg"
#     "net_5067_2.jpg"
#     "net_5068_2.jpg"
#     "net_5033_3.jpg"
#     "net_5034_3.jpg"
#     "net_5413_6.jpg"
#     "net_5414_6.jpg"
#     "net_5382_7.jpg"
#     "net_5383_7.jpg"
#     "net_5066_8.jpg"
#     "net_5066_8.jpg"
# ]]

## ===-===-===-===-
# Load birth death diagrams for all files in the specified folder
thresholded_bd = [f => zeros(1, 3) for f in files_list] |> Dict

for name in files_list
    in_filename = dipha_raw_export_folder_set(name)

    dims, birth_values, death_values = load_persistence_diagram(in_filename)
    bd_data = hcat(dims, birth_values, death_values)
    thresholded_bd[name] = get_thresholded_values(PERSISTENCE_THRESHOLD, bd_data)
end

## ===-===-===-===-
# Export the birth death diagrams to csv files

max_dim = 1
name = files_list[2]
for name in files_list
    @info "Working on: $(name)"
    data_matrix = thresholded_bd[name]
    if data_matrix |> isempty
        @warn "Skipping empty structure for $(name)"
        continue
    end
    # max_dim = Int(max(unique(data_matrix[:, 1])...))

    for selected_dim = 0:max_dim

        if selected_dim == 1
            dim_indices = data_matrix[:, 1] .== selected_dim
        else
            dim_indices = data_matrix[:, 1] .<= selected_dim
        end

        if all(dim_indices .== 0)
            export_data = [selected_dim 0.0 0.0]
        else
            # Why setting the inf component to 255? 
            # The filtration last until the end. The software "kills" it with the last value found in the Matrix
            # This affects final results, when partitions are analysed 
            data_matrix[data_matrix[:, 1].==-1, 3] .= 255
            export_data = data_matrix[dim_indices, :]
        end

        final_name = "$(name)_dim=$(selected_dim)_threshold=$(PERSISTENCE_THRESHOLD).csv"
        final_export_path = dipha_bd_info_export_folder_set("dim=$(selected_dim)")

        if ~(isdir(final_export_path))
            mkpath(final_export_path)
        end

        out_filename = dipha_bd_info_export_folder_set("dim=$(selected_dim)", final_name)
        writedlm(out_filename, export_data, ",")
        @info "Saved files as" out_filename
    end
end

@info "$(scriptprefix): Finished birth-death data export for: $(CONFIG.data_set)/$(CONFIG.data_config) threshold: $(PERSISTENCE_THRESHOLD)."
