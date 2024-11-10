using DrWatson
@quickactivate "ArtTopology"

using Pipe
using DelimitedFiles

"config.jl" |> scriptsdir |> include
"loading_utils.jl" |> srcdir |> include
"et_utils.jl" |> srcdir |> include
"HeatmapsUtils.jl" |> srcdir |> include
"DataStructuresUtils.jl" |> srcdir |> include
"et_utils.jl" |> srcdir |> include

import .CONFIG: homology_info_storage
# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===- 8
eyedatadir(args...) = datadir("exp_raw", "EyeTracking", args...)
possible_sessions = ["Surowe_ET_kontrolna.csv", "Surowe_ET_prawdziwa.csv"]

if CONFIG.LONGEST_FIXATION_SEQUENCE == -1
    adjusted_ET_sessions = [
        "Fixation_sequence_ET_control_fixation_samples=$(CONFIG.FIXATION_SEQUENCE).csv",
        "Fixation_sequence_ET_real_fixation_samples=$(CONFIG.FIXATION_SEQUENCE).csv"
    ]
    adjusted_ET_sessions_dict = [
        "fake" => "Fixation_sequence_ET_control_fixation_samples=$(CONFIG.FIXATION_SEQUENCE).csv",
        "art" => "Fixation_sequence_ET_real_fixation_samples=$(CONFIG.FIXATION_SEQUENCE).csv"
    ] |> Dict
else
    adjusted_ET_sessions = [
        "Fixation_sequence_ET_control_fixation_samples=$(CONFIG.FIXATION_SEQUENCE)-$(CONFIG.LONGEST_FIXATION_SEQUENCE).csv",
        "Fixation_sequence_ET_real_fixation_samples=$(CONFIG.FIXATION_SEQUENCE)-$(CONFIG.LONGEST_FIXATION_SEQUENCE).csv"
    ]
    adjusted_ET_sessions_dict = [
        "fake" => "Fixation_sequence_ET_control_fixation_samples=$(CONFIG.FIXATION_SEQUENCE)-$(CONFIG.LONGEST_FIXATION_SEQUENCE).csv",
        "art" => "Fixation_sequence_ET_real_fixation_samples=$(CONFIG.FIXATION_SEQUENCE)-$(CONFIG.LONGEST_FIXATION_SEQUENCE).csv"
    ] |> Dict
end

dataset_names = ["fake", "art",]
raw_fake_ET_df, raw_art_ET_df =
    map(x -> eyedatadir("raw", x) |> (y -> get_filtered_ET(y, filterout_time=false, filterout_pupil_info=false)), possible_sessions)

# ===-===-===-===-===-===-===-===-===-===-===-
dataset_df = [raw_fake_ET_df, raw_art_ET_df]


# ===-===-
fake_selection = unique(raw_fake_ET_df.Subject)
fake_subjects_df = filter(row -> row.Subject in fake_selection, raw_fake_ET_df)

art_selection = unique(raw_art_ET_df.Subject)
art_subjects_df = filter(row -> row.Subject in art_selection, raw_art_ET_df)

subjects_name = Dict("fake" => fake_selection, "art" => art_selection)
# ===-===-===-
do_isoline_plot = false

if any(isfile.([
    eyedatadir("processed", adjusted_ET_sessions[1]),
    eyedatadir("processed", adjusted_ET_sessions[2])
]))
    fake_sub_fixations_df, art_sub_fixations_df =
        map(x -> eyedatadir("processed", x) |> (y -> CSV.read(y, DataFrame)), adjusted_ET_sessions)


elseif CONFIG.FIXATION_SEQUENCE == 0
    total_rows, total_cols = size(fake_subjects_df)
    fixation_sequence_fake = zeros(Int, total_rows)
    durations_vec1 = zeros(Int, total_rows)
    fake_subjects_df[!, "Fixation index"] .= fixation_sequence_fake
    fake_subjects_df[!, "Durations"] .= durations_vec1

    total_rows, total_cols = size(art_subjects_df)
    fixation_sequence_art = zeros(Int, total_rows)
    durations_vec2 = zeros(Int, total_rows)
    art_subjects_df[!, "Fixation index"] .= fixation_sequence_art
    art_subjects_df[!, "Durations"] .= durations_vec2

    # fake_sub_fixations_df = @pipe filter(row -> row["Category Right"] == "Fixation", fake_subjects_df) |>
    fake_sub_fixations_df = @pipe filter(row -> row.Stimulus != "NoImage", fake_subjects_df) |>
                                  filter(row -> !occursin("maska", row.Stimulus), _) |>
                                  filter(row -> !occursin("n", row.Stimulus), _) |>
                                  filter(row -> !ismissing(row["Point of Regard Right X [px]"]), _) |>
                                  filter(row -> row["Point of Regard Right X [px]"] > 10, _) |>
                                  #   filter(row -> row.Durations > CONFIG.FIXATION_SEQUENCE, _) |>
                                  select(_, Not("Trial", "Category Left", "Index Right", "Index Left"))


    # art_sub_fixations_df = @pipe filter(row -> row["Category Right"] == "Fixation", art_subjects_df) |>
    art_sub_fixations_df = @pipe filter(row -> row.Stimulus != "NoImage", art_subjects_df) |>
                                 filter(row -> !occursin("maska", row.Stimulus), _) |>
                                 filter(row -> !occursin("n", row.Stimulus), _) |>
                                 filter(row -> !ismissing(row["Point of Regard Right X [px]"]), _) |>
                                 filter(row -> row["Point of Regard Right X [px]"] > 10, _) |>
                                 #  filter(row -> row.Durations > CONFIG.FIXATION_SEQUENCE, _) |>
                                 select(_, Not("Trial", "Category Left", "Index Right", "Index Left"))

    dataset_df_dict = ["fake" => fake_sub_fixations_df, "art" => art_sub_fixations_df] |> Dict

    df_key = "fake"
    df = dataset_df_dict[df_key]
    for (df_key, df) in dataset_df_dict
        df_name = adjusted_ET_sessions_dict[df_key]
        ispath(eyedatadir("processed")) || mkpath(eyedatadir("processed"))
        CSV.write(
            eyedatadir("processed", df_name),
            df,
        )
    end
else
    fixation_sequence_fake = get_fixation_sequence_vector(fake_subjects_df)
    durations_vec1 = get_fixation_durations(fake_subjects_df, fixation_sequence_fake; samples_sequence=CONFIG.FIXATION_SEQUENCE)
    fake_subjects_df[!, "Fixation index"] .= fixation_sequence_fake
    fake_subjects_df[!, "Durations"] .= durations_vec1

    fixation_sequence_art = get_fixation_sequence_vector(art_subjects_df)
    durations_vec2 = get_fixation_durations(art_subjects_df, fixation_sequence_art; samples_sequence=CONFIG.FIXATION_SEQUENCE)
    art_subjects_df[!, "Fixation index"] .= fixation_sequence_art
    art_subjects_df[!, "Durations"] .= durations_vec2

    @info "Filtering df..."
    fake_sub_fixations_df = @pipe filter(row -> row["Category Right"] == "Fixation", fake_subjects_df) |>
                                  filter(row -> row.Stimulus != "NoImage", _) |>
                                  filter(row -> !occursin("maska", row.Stimulus), _) |>
                                  filter(row -> !occursin("n", row.Stimulus), _) |>
                                  filter(row -> row["Point of Regard Right X [px]"] > 10, _) |>
                                  filter(row -> row.Durations > CONFIG.FIXATION_SEQUENCE, _) |>
                                  select(_, Not("Trial", "Category Left", "Index Right", "Index Left"))


    art_sub_fixations_df = @pipe filter(row -> row["Category Right"] == "Fixation", art_subjects_df) |>
                                 filter(row -> row.Stimulus != "NoImage", _) |>
                                 filter(row -> !occursin("maska", row.Stimulus), _) |>
                                 filter(row -> !occursin("n", row.Stimulus), _) |>
                                 filter(row -> row["Point of Regard Right X [px]"] > 10, _) |>
                                 filter(row -> row.Durations > CONFIG.FIXATION_SEQUENCE, _) |>
                                 select(_, Not("Trial", "Category Left", "Index Right", "Index Left"))

    if CONFIG.LONGEST_FIXATION_SEQUENCE != -1
        fake_sub_fixations_df = filter(row -> row.Durations < CONFIG.LONGEST_FIXATION_SEQUENCE, fake_sub_fixations_df)
        art_sub_fixations_df = filter(row -> row.Durations < CONFIG.LONGEST_FIXATION_SEQUENCE, art_sub_fixations_df)
    end

    dataset_df_dict = ["fake" => fake_sub_fixations_df, "art" => art_sub_fixations_df] |> Dict

    df_key = "fake"
    df = dataset_df_dict[df_key]
    for (df_key, df) in dataset_df_dict
        df_name = adjusted_ET_sessions_dict[df_key]
        ispath(eyedatadir("processed")) || mkpath(eyedatadir("processed"))
        CSV.write(
            eyedatadir("processed", df_name),
            df,
        )
    end
end # if

dataset_df = [fake_sub_fixations_df, art_sub_fixations_df]
dataset_df_dict = ["fake" => fake_sub_fixations_df, "art" => art_sub_fixations_df] |> Dict

function load_raw_heatmap(data_name, subject, session, view, img_number, fixation)
    if data_name == "Artysta"
        data_dir = "art"
    else
        data_dir = "fake"
    end

    file_name = "hmap_$(data_dir)__img$(img_number)_s$(session)_v$(view)_fixation$(fixation).csv"
    full_file_path = datadir("exp_pro", "section8", "8e2-heatmaps_from_pygaze", "heatmap_data",
        data_dir, "$(subject)", "session$(session)", file_name)

    matrix = readdlm(full_file_path, ',', Float64)
    return matrix
end

function load_raw_heatmap(data_name, session, view, img_number)
    if data_name == "Artysta"
        data_dir = "art"
    else
        data_dir = "fake"
    end

    file_name = "hmap_$(data_dir)__img$(img_number)_s$(session)_v$(view).csv"
    full_file_path = datadir("exp_pro", "heatmaps_from_pytrack", "heatmap_data",
        data_dir, "session$(session)", file_name)

    matrix = readdlm(full_file_path, ',', Float64)
    return matrix
end
