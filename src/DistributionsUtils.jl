using Distributions
using Pipe
using DataFrames

import DataStructures: OrderedDict

"""
   get_MSC_key_subrange(strings_vector, left_text)

Returns string with range of numbers that are used in the keys
"""
function get_MSC_key_subrange(strings_vector, left_text)
    vals_range = [@pipe k |>
                        split(_, left_text)[2] |>
                        split(_, "_")[1] |>
                        parse(Int, _)
                  for k in strings_vector
    ]
    return "$(findmin(vals_range)[1])-$(findmax(vals_range)[1])"
end
get_MSC_range(strings_vector) = get_MSC_key_subrange(strings_vector, "MSC")
get_session_range(strings_vector) = get_MSC_key_subrange(strings_vector, "_f")
get_runs_range(strings_vector) = get_MSC_key_subrange(strings_vector, "_r")


function get_geom_subrange(strings_vector, left_text)
    join(
        [@pipe k |>
               split(_, left_text)[2] |>
               split(_, "_R")[2]
         for k in strings_vector
        ], "-")
end


"""

    get_config_from_keys(data_labels::Vector{String})

Takes a vector with data lables and returns a config file with labels
indicating range of parameters found in the set.

Currently prepared for MSC, MSC_shuff and Geometric data sets.
"""
function get_config_from_keys(data_labels::Vector{String})
    data_label = data_labels[1]
    config_dict = OrderedDict()

    MSC_flag = occursin("MSC", data_label)
    session_flag = occursin(r"_ses[0-9]", data_label) ||
                   occursin("_ses-func", data_label) ||
                   occursin(r"_f[0-9]", data_label)
    runs_flag =
        occursin("_run", data_label) ||
        occursin(r"_r[0-9]", data_label)


    if MSC_flag && session_flag && runs_flag
        key = join((@pipe data_label |>
                          split(_, r"[0-9][0-9]")),
            "")

        config_dict[:key] = key
    elseif MSC_flag && session_flag && occursin("BOLD", data_label)
        key = join((@pipe data_label |>
                          split(_, r"[0-9][0-9]")),
            "")

        config_dict[:key] = key

    end

    if MSC_flag && !(occursin("BOLD", data_label))
        MSC = get_MSC_key_subrange(data_labels, "MSC")
        config_dict[:MSC] = MSC
        MSC_flag = true
    end

    if session_flag
        if occursin(r"_ses[0-9]", data_label)
            f = get_MSC_key_subrange(data_labels, "_ses")
        else
            f = get_MSC_key_subrange(data_labels, "_f")
        end
        config_dict[:f] = f
    end

    if runs_flag
        if occursin("_run", data_label)
            r = get_MSC_key_subrange(data_labels, "_run")
        elseif occursin(r"_r[0-9]", data_label)
            r = get_MSC_key_subrange(data_labels, "_r")
        end
        config_dict[:r] = r
    end


    # Random and geometric keys processing
    if occursin("rand", data_label)
        key = "rand"
        config_dict[:key] = key
    end

    if occursin("geom_R", data_label)
        key = "geom"
        config_dict[:key] = key

        cube_dims = get_geom_subrange(data_labels, "geom")
        config_dict[:cube_dims] = cube_dims
    end

    if !haskey(config_dict, :key)
        @warn "Config was created without key"
        key = @pipe data_label |>
                    split(_, r"[0-9][0-9]")[end][2:end]
        config_dict[:key] = key
    end

    return config_dict
end


"""

Takes a vector of values and returns n-th percentile value.

If 'two_tailed' is true, returns two values, where each indicate left and right
tail values consicutevly.
"""
function get_nth_percentile(data_vector::Vector, nth_percentile::Float64; two_tailed::Bool=false)
    total_samples = data_vector |> length

    if two_tailed
        final_percentile = (1 - nth_percentile) / 2
    else
        final_percentile = (1 - nth_percentile)
    end

    percentaile_index_right = total_samples * (1 - final_percentile) |> ceil |> Int
    percentaile_value_right = (data_vector|>sort)[percentaile_index_right]

    percentaile_index_left = total_samples * final_percentile |> ceil |> Int
    percentaile_value_left = (data_vector|>sort)[percentaile_index_left]

    return percentaile_value_left, percentaile_value_right

end

function get_nth_percentile(data_matrix::Matrix, nth_percentile::Float64)
    if (sum(size(data_vector)) - 1) != length(data_vector)
        DimensionMismatch("Input matrix is built of many vectors, please provide structure with all but 1 dimension equal to 1") |> throw
    end

    get_nth_percentile(data_vector[:], nth_percentile)
end



# ===-===-===-===-===-
"""
Takes a matrix with Wasserstein distances and returns values contained
in the upper half of the matrix.
"""
function get_distances_vector(w_matrix::Matrix)::Vector{Float64}
    total_cols, _ = size(w_matrix)
    return vcat([w_matrix[k, (k+1):end] for k in 1:(total_cols-1)]...)
end

# ===-===-

struct DistributionMerge
    keys::Vector{String}
    distances_values::OrderedDict{String,Vector{Float64}}
    dimensions::Vector{String}


    function DistributionMerge(wmatrix_distributions, dimensions_keys; values_generator=get_distance_values)
        all_ids = [k for k in keys(wmatrix_distributions)]
        if all_ids |> isempty
            ErrorException("Input structure is empty") |> throw
        end

        all_subs = [k for k in keys(wmatrix_distributions[all_ids[1]])]

        population_distances_per_dim = OrderedDict()
        for dim_ind in dimensions_keys
            population_distances_per_dim[dim_ind] =
                vcat(
                    [vcat([@pipe wmatrix_distributions[id][sub] |> values_generator(_, dim_ind) for sub in all_subs]...)
                     for id in all_ids]...)
        end

        new(all_ids,
            population_distances_per_dim,
            dimensions_keys
        )
    end
end

# ==-
get_distance_values(wmatrix_info::DistributionMerge, dim_ind::String) =
    wmatrix_info.distances_values[dim_ind]


get_distance_sums(wmatrix_info::DistributionMerge, dim_ind::String) =
    @pipe wmatrix_info.w_matrices[dim_ind] |> sum(_, dims=2)

get_fitting(wmatrix_info::DistributionMerge, dim_ind::String) =
    wmatrix_info.fitted_distribution[dim_ind]

struct WMatrixDistribution
    key::String
    w_matrices::Dict{String,Matrix{Float64}}
    distances_values::Dict{String,Vector{Float64}}
    fitted_distribution::Dict

    function WMatrixDistribution(key::String, w_matrices::Dict{String,Matrix{Float64}}, fitted_distribution)
        for (key, w_matrix) in w_matrices
            distances_values[key] = get_distances_vector(w_matrix)
        end

        new(
            key,
            w_matrices,
            distances_values,
            fitted_distribution,
        )
    end

    function WMatrixDistribution(key::String, w_matrices::Dict{String,Matrix{Float64}}; distribution_to_fit=Distributions.LogNormal)
        distances_values = Dict()
        fitted_distributions = Dict()
        for (key, w_matrix) in w_matrices
            distances_values[key] = get_distances_vector(w_matrix)
            try
                fitted_distributions[key] = Distributions.fit(distribution_to_fit,
                    distances_values[key])
            catch
                fitted_distributions[key] = distribution_to_fit()
                @warn "Can not fit the distribution for dimension " key
            end
        end


        new(
            key,
            w_matrices,
            distances_values,
            fitted_distributions,
        )
    end
end

function get_distance_values(wmatrix_info::WMatrixDistribution, dim_ind::String)
    return wmatrix_info.distances_values[dim_ind]
end

function get_distance_sums(wmatrix_info::WMatrixDistribution, dim_ind::String)
    data_matrix = @pipe wmatrix_info.w_matrices[dim_ind] |> sum(_, dims=2)
    # @info size(data_matrix)
    # @info size(data_matrix[:])

    return data_matrix[:]
end

function get_fitting(wmatrix_info::WMatrixDistribution, dim_ind::String)
    return wmatrix_info.fitted_distribution[dim_ind]
end

"""
Return ourliers given the Wasserstein matrix distribution for a given percentile. See
    `get_outlier_from_data` to learn more on kwargs

"""
function get_all_distances_outliers(wmatrix_info::WMatrixDistribution, percentile, dim_ind; kwargs...)
    return @pipe wmatrix_info |> get_distance_values(_, dim_ind) |> get_outlier_from_data(_, percentile; kwargs...)
end

"""
Return ourliers given the columns sum of Wasserstein matrix distribution for a given percentile. See
    `get_outlier_from_data` to learn more on kwargs

"""
function get_distances_sums_outliers(wmatrix_info::WMatrixDistribution, percentile, dim_ind; kwargs...)
    return @pipe wmatrix_info |> get_distance_sums(_, dim_ind) |> get_outlier_from_data(_, percentile; kwargs...)
end

"""
Return ourliers given the distribution for a given percentile. There are 2 possible methods for outliers:
    - `:sample_based` takes `percentile` last of sorted values
    - `:distro_based` takes `percentile` computes threshold form the distribution and returns values above
        that threshold

    TODO Add option for upper or lower percentile.
"""
function get_outlier_from_data(data_vector::Vector{Float64}, percentile::Float64; method::Symbol=:sample_based)
    if method == :sample_based
        return @pipe data_vector |> get_nth_percentile(_, percentile)
    elseif method == :distro_based
        # return @pipe wmatrix_info |> get_distance_values  |> get_nth_percentile(_, percentile)
        ErrorException("Not yet imeplemented! Sorry...")
    else
        UndefKeywordError(method) |> throw
    end
end

# ===-===-===-
# Plotting DistributionsUtils

"""

Saves `plt_to_save` as a png and a pdf files under `plots_dir` and `pathargs`
path under the name starting with `script_prefix` followed by `file_midname`.
"""
function save_plot(script_prefix::String, plots_dir::Function, pathargs::Tuple, file_midname::String, plt_to_save)
    @info "$(script_prefix): Saving"
    for ext = ["png", "pdf"]
        if ext == "pdf"
            pathargs = (pathargs..., ext)
        end

        file_name = plots_dir(pathargs...,
            # "$(script_prefix)_wasserstein_distances_sum_$(config[:key])_$(description)_$(distro_key).$(ext)"
            "$(script_prefix)_$(file_midname).$(ext)"
        )

        safesave(file_name,
            plt_to_save
        )
    end # subject
end


"""
    get_BH_critical_values_form_landscapes(landscapes_distance, distances_distribution, clusters_keys)

The Benjamini-Hochberg Procedure for landscapes

Step 1: Conduct all of your statistical tests and find the p-value for each
test.

Step 2: Arrange the p-values in order from smallest to largest, assigning a rank
to each one – the smallest p-value has a rank of 1, the next smallest has a rank
of 2, etc.

Step 3: Calculate the Benjamini-Hochberg critical value for each p-value, using
the formula (i/m)*Q

where:
i = rank of p-value
m = total number of tests
Q = your chosen false discovery rate

form:
https://www.statology.org/benjamini-hochberg-procedure/


Returns a Data Frame with the following columns: "ClusterKeys", "p value", "(i/m)*Q", "AcceptedValue".

"""
function get_BH_critical_values_form_landscapes(landscapes_distance, distances_distribution, clusters_keys; Q::Float64=5 / 100)
    # ===-===-
    # Step 1
    p_value_results = OrderedDict()
    for cluster_key in clusters_keys

        dist = landscapes_distance[cluster_key]
        p_value_results[cluster_key] = ((distances_distribution[cluster_key] .> dist) |> sum) / total_shuffles
        # what is the p-value- put this info somwhere
    end

    # ===-===-
    # Step 2
    p_values = [v for (k, v) in p_value_results]

    sorting_vector = sortperm(p_values)
    sorted_p_values = p_values[sorting_vector]

    # ===-===-
    # Step 3
    m = length(sorted_p_values)
    # Q = 1 / (2 * 35)

    benjamini_hochberg_critical_values = [
        (i / m) * Q for (i, p) in enumerate(sorted_p_values)
    ]
    # ===-===-
    # refactore data into DataFrame

    critical_values = DataFrame()

    critical_values[!, "ClusterKeys"] = clusters_keys[sorting_vector]
    critical_values[!, "p value"] = sorted_p_values
    critical_values[!, "(i/m)*Q"] = round.(benjamini_hochberg_critical_values, digits=4)
    critical_values[!, "AcceptedValue"] = sorted_p_values .< benjamini_hochberg_critical_values

    return critical_values
end