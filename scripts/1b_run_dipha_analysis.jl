#=
Second stage of processing for cubical complexes- DIPHA analysis
=#
using DrWatson
@quickactivate "ArtTopology"

## ===-===-===-
"dipha_utils.jl" |> srcdir |> include

"config.jl" |> scriptsdir |> include

## ===-===-===-===-
import .CONFIG: dipha_exec, export_for_dipha_folder_set, dipha_raw_export_folder_set

import Base.Threads: @sync, @spawn, nthreads
## ===-===-===-===-
files_vector = [k for k in export_for_dipha_folder_set() |> readdir if !occursin(".DS_Store", k)]


# missing files
# files_vector = [split(k, ".jpg")[1] for k in [
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
# ] ]

total_files = files_vector |> length

if total_files > 200
    @info "Total threads $(nthreads())"
    files_per_thread = total_files ÷ nthreads()
else
    files_per_thread = total_files
end

split_vector = vcat([k for k in range(1, step=files_per_thread, stop=total_files)], total_files)

@sync for k in 2:length(split_vector)
    l_ind = split_vector[k-1]
    r_ind = split_vector[k]

    # @spawn for img_file in files_vector[l_ind:r_ind]
    for img_file in files_vector[l_ind:r_ind]
        file_name = split(img_file, ".png")[1]
        @info file_name

        file = export_for_dipha_folder_set(img_file)

        # !isfile(dipha_exec) || ErrorException("Dipha exec file can not be found! Make sure it is compiled.") |> throw
        isfile(file) && @warn "Will overwrite existing file"
        !(dipha_raw_export_folder_set() |> ispath) && dipha_raw_export_folder_set() |> mkpath

        command = `$dipha_exec $file $(dipha_raw_export_folder_set(file_name))`
        @info "Running: " command

        command |> run
    end
end

## ===-===-===-===-
@info "Finished DIPHA processing."
