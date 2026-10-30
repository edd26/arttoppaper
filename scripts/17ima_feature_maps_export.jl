
using DrWatson
@quickactivate "arttopopaper"

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-

"17im_feature_maps_extraction.jl" |> scriptsdir |> include
# ===-===-
# load df with measures
# names(parameters_df.parameter |> unique)

file_name = "kot_net_dim_flowall_avg.csv"
file_full_path = datadir("exp_pro", file_name)

all_measures_df = file_full_path |> CSV.File |> DataFrame

# Create empty DataFrame with matching structure
schema = Tables.schema(all_measures_df)
empty_df = DataFrame([n => t[] for (n, t) in zip(schema.names, schema.types)]...)

parameters_names = parameters_df.parameter |> unique

extended_measures_df =
    hcat(empty_df, DataFrame([p => Float64[] for p in parameters_names]...))

loaded_datasets = all_measures_df.Exhibition |> unique


ld = "Art"
ld = "Pseudo-art"
for ld in loaded_datasets
    @info "\t" ld
    dataset_df = filter(row -> row.Exhibition == ld, all_measures_df)

    images_names = dataset_df.Image |> unique

    img_name = images_names[1]
    for img_name in images_names
        @info "\t\t" img_name
        img_df = filter(row -> row.Image == img_name, dataset_df)

        data_name_filter = if ld == "Art"
            lowercase(ld)
        elseif ld == "Pseudo-art"
            "pseudoart"
        else
            ld
        end

        image_related_df = @pipe parameters_df |>
                                 filter(row -> row.data_name == data_name_filter, _) |>
                                 filter(row -> row.export_name == img_name, _)

        average_params = [
            # n=>mean(p) for
            mean(p) for (n, p) in
            zip(image_related_df.parameter, image_related_df.parameters_values)
        ]

        # r = img_df[1, :]
        for r in eachrow(img_df)
            new_data = (r..., average_params...)
            @info "\t\t\t" length(new_data)
            push!(extended_measures_df, new_data)
        end
    end
end

# ===-===-
out_file = split(file_name, ".")
out_file[1] *= "-" * join(parameters_names, "-")
out_file = join(out_file, ".")

out_path(args...) = datadir("exp_pro", "section17", args...)
out_path() |> ispath || out_path() |> mkpath
out_file_full_path = out_file |> out_path

CSV.write(out_file_full_path, extended_measures_df)





# ===-===-
do_nothing = "ok"
