
using HypothesisTests: KruskalWallisTest, MannWhitneyUTest, OneWayANOVATest, SignedRankTest
# using RCall
import Pingouin

function get_friedman_test(session_df; do_julia_firedman=true, do_fdr_miller=false)
    looking_vec = vcat(
        ["looking" for k in session_df.ECDF_looking_error]...,
        ["not looking" for k in session_df.ECDF_looking_error],
    )

    data_type_vec = vcat(session_df.data_name, session_df.data_name)

    img_vec_sample = String[]
    for df_sample in eachrow(session_df)
        img_name = replace(df_sample.img_name, ".jpg" => "") * "_s$(df_sample.session)_v$(df_sample.view)"
        push!(img_vec_sample, img_name)
    end
    img_vec = vcat(img_vec_sample, img_vec_sample,)
    ecdf_vec = vcat(session_df.ECDF_looking_error, session_df.ECDF_not_looking_error)
    test_data = DataFrame(
        "image" => img_vec,
        "exhibition" => data_type_vec,
        "looking_type" => looking_vec,
        "ECDF_error" => ecdf_vec,
    )
    test_data = test_data[test_data.image|>sortperm, :]

    if do_julia_firedman
        @info "Running Pingouin version of Friedman tets"
        friedman_result = Pingouin.friedman(
            data,
            dv="ECDF_error",
            within="looking_type",
            subject="image")
        return friedman_result[1, :p_unc]
    else
        ErrorException("RCall is not workin on mac-m")
    end
end


function get_p_values(measure_vals_art, measure_vals_pseudoart; do_KW=false, do_mann_whitney=false, do_signed_rank=false, do_fdr_miller=false)
    if do_KW
        stat_test_result = KruskalWallisTest(measure_vals_art, measure_vals_pseudoart)
        test_p_value = pvalue(stat_test_result)
    elseif do_mann_whitney
        stat_test_result = MannWhitneyUTest(measure_vals_art, measure_vals_pseudoart)
        test_p_value = pvalue(stat_test_result)
        println(stat_test_result)
    elseif do_signed_rank
        stat_test_result = SignedRankTest(measure_vals_art, measure_vals_pseudoart)
        test_p_value = pvalue(stat_test_result)
    elseif do_fdr_miller
        stat_test_result = Nothing
        test_p_value = get_friedman_test(session_df; do_julia_firedman=false, do_fdr_miller=do_fdr_miller)
    else
        @warn "Producing p-values with default One Way ANOVA"
        stat_test_result = OneWayANOVATest(measure_vals_art, measure_vals_pseudoart)
        test_p_value = pvalue(stat_test_result)
    end
    return stat_test_result, test_p_value
end