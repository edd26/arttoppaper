using DrWatson
@quickactivate "arttopopaper"

using Pipe
using DelimitedFiles

"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include
"et_utils.jl" |> srcdir |> include
"HeatmapsUtils.jl" |> srcdir |> include
"DataStructuresUtils.jl" |> srcdir |> include
"et_utils.jl" |> srcdir |> include

import .CONFIG: ripserer_computations_dir
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===- 8
eyedatadir(args...) = datadir("exp_raw", "EyeTracking", args...)

if CONFIG.LONGEST_FIXATION_SEQUENCE == -1
    adjusted_ET_sessions = [
        "Fixation_sequence_ET_control_fixation_samples=$(CONFIG.FIXATION_SEQUENCE).csv",
        "Fixation_sequence_ET_real_fixation_samples=$(CONFIG.FIXATION_SEQUENCE).csv",
    ]
    adjusted_ET_sessions_dict =
        [
            "pseudoart" => "Fixation_sequence_ET_control_fixation_samples=$(CONFIG.FIXATION_SEQUENCE).csv",
            "art" => "Fixation_sequence_ET_real_fixation_samples=$(CONFIG.FIXATION_SEQUENCE).csv",
        ] |> Dict
else
    adjusted_ET_sessions = [
        "Fixation_sequence_ET_control_fixation_samples=$(CONFIG.FIXATION_SEQUENCE)-$(CONFIG.LONGEST_FIXATION_SEQUENCE).csv",
        "Fixation_sequence_ET_real_fixation_samples=$(CONFIG.FIXATION_SEQUENCE)-$(CONFIG.LONGEST_FIXATION_SEQUENCE).csv",
    ]
    adjusted_ET_sessions_dict =
        [
            "pseudoart" => "Fixation_sequence_ET_control_fixation_samples=$(CONFIG.FIXATION_SEQUENCE)-$(CONFIG.LONGEST_FIXATION_SEQUENCE).csv",
            "art" => "Fixation_sequence_ET_real_fixation_samples=$(CONFIG.FIXATION_SEQUENCE)-$(CONFIG.LONGEST_FIXATION_SEQUENCE).csv",
        ] |> Dict
end

dataset_names = ["pseudoart", "art"]

# ===-===-===-

if any(
    isfile.([
        eyedatadir("processed", adjusted_ET_sessions[1]),
        eyedatadir("processed", adjusted_ET_sessions[2]),
    ]),
)
    pseudoart_sub_fixations_df, art_sub_fixations_df = map(
        x -> eyedatadir("processed", x) |> (y -> CSV.read(y, DataFrame)),
        adjusted_ET_sessions,
    )

else
    "Raw files are not included, please contact authors" |> ErrorException |> throw
end # if


dataset_df = [pseudoart_sub_fixations_df, art_sub_fixations_df]
dataset_df_dict =
    ["pseudoart" => pseudoart_sub_fixations_df, "art" => art_sub_fixations_df] |> Dict

# ===-===-
art_selection = unique(art_sub_fixations_df.Subject)
pseudoart_selection = unique(pseudoart_sub_fixations_df.Subject)

subjects_name = Dict("pseudoart" => pseudoart_selection, "art" => art_selection)