using DrWatson
@quickactivate "ArtTopology"

## ===-===-===-===-===-===-===-===-===-===-===-===-
"1_processing_set_up.jl" |> scriptsdir |> include

using Pipe
import Base.Threads: @threads, @spawn, nthreads
## ===-===-===-===-===-===-===-===-===-===-===-===-
images_list = @pipe images_for_dipha_folder() |> readdir |> filter_out_DS

file = images_list[1]
for file in images_list
    in_file = @pipe file |> images_for_dipha_folder
    out_file = @pipe file |> split(_, ".")[1] |> dipha_result_folder

    # @info "(thread: $(Threads.threadid()))"
    @info "File: " file
    @info "Output file:" out_file

    # files_check
    # run(`ls $piece`)

    run(`./dipha/dipha $in_file $out_file`)
end

@info "===-===-===-===-"

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# ===-
@info "Finished DIPHA processing."