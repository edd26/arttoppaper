#=
Place to save path configurations for the processed data as well as to select which data
    will be used in the processing.
=#

module CONFIG

import DrWatson: datadir, projectdir, srcdir
import UnPack: @unpack
import .Main: ENV

# ===-===-
"ArgsParsing.jl" |> srcdir |> include

parsed_args = ArtTopoArgParse.parse_plotting_commandline()
@info "Processing arguments: " parsed_args

begin
    @unpack data_set,
    data_config,
    selected_dim,
    persistence_threshold,
    selected_ET,
    total_trials,
    BW_only,
    total_images,
    fixation_sequence,
    longest_fixation_sequence = parsed_args

end

DATA_SET = data_set
DATA_CONFIG = data_config
SELECTED_DIM = selected_dim
PERSISTENCE_THRESHOLD = persistence_threshold
TOTAL_TRIALS = total_trials
TOTAL_IMAGES = total_images
force_image_export = false
FIXATION_SEQUENCE = fixation_sequence
LONGEST_FIXATION_SEQUENCE = longest_fixation_sequence

# ===-===-
ENV["GKSwstype"] = "100"

# ===-===-
# Datasets paths configuration
raw_paths = [
    ("art",),
    ("pseudoart",),
    ("Jarema",),
    ("Kandinsky",),
    ("Malewicz",),
    ("Pollock",),
    ("Richter",),
    ("Rothko",),
    ("SimpleExamples",),
]

# ===-===-
# Named groups for batch processing. Anything not listed here is treated as a
# literal directory name under exp_raw/ and checked at runtime.
const dataset_groups = Dict(
    "main"       => ["art-cropped", "pseudoart"],
    "additional" => ["Jarema", "Malewicz", "Pollock", "Kandinsky", "Richter", "Rothko"],
)

function get_data_sets(data_set)
    if haskey(dataset_groups, data_set)
        group = dataset_groups[data_set]
        return [path for path in raw_paths if any(occursin.(group, path[1]))]
    else
        dir = datadir("exp_raw", data_set)
        if isdir(dir)
            @info "\"$data_set\" not a named group — using directory: $dir"
            return [(data_set,)]
        else
            error("Dataset \"$data_set\" is not a named group and directory does not exist: $dir")
        end
    end
end

# ===-===-
TOTAL_NOISE_IMAGES = 100

IMG_WIDTH = 1434
IMG_HEIGHT = 2048

SPACE_WIDTH = 1680
SPACE_HEIGHT = 1066

STARTING_POINT = 472
VIEWING_WIDTH = 735
VIEWING_HEIGHT = 1066

# ===-===-===-===-===-===-
function set_path_args(data_set, image_type)
    path_args = ("", "")
    # if any(data_set .== ["art", "pseudoart", "all_pseudoart"])
    if image_type == "BW"
        path_args = ("BW", data_set)
    elseif image_type == "resized_BW"
        path_args = ("resized_BW", data_set)
    elseif image_type == "WB"
        path_args = ("WB", data_set)
    elseif image_type == "RGB"
        path_args = ("RGB", data_set)
    elseif image_type == "RGB_rev"
        path_args = ("RGB_rev", data_set)
    else
        ErrorException("Unknow data config. Failed to parse arguments") |> throw
    end

    return path_args
end # function

path_args = set_path_args(data_set, data_config)
# ===-===-
# 0:
preproc_img_dir(args...) = datadir("exp_pro", "img_initial_preprocessing", args...)
preproc_img_dir_set(args...) = preproc_img_dir(path_args..., args...)

ripserer_computations_dir(args...) =
    datadir("exp_pro", "ripserer_computations", "ripserer-cubical", args...)
# --------

# pseudoart images order
pseudoart_images_order = Dict(
    1 => "net_5278_4",
    2 => "net_5299_2",
    3 => "net_5496_8",
    # 4 => "net_5021_8",
    4 => "net_5024_8",
    5 => "net_5390_4",
    6 => "net_5063_7",
    7 => "net_5250_6",
    8 => "net_5193_0",
    9 => "net_5013_5",
    10 => "net_5390_8",
    11 => "net_5210_4",
    12 => "net_5225_1",
)

art_images_order = Dict(
    1 => "1",
    2 => "2",
    3 => "3",
    4 => "4",
    5 => "5",
    6 => "6",
    7 => "7",
    8 => "8",
    9 => "9",
    10 => "10",
    11 => "11",
    12 => "12",
)

pseudoart_name_to_order = Dict(
    "net_5278_4" => 1,
    "net_5299_2" => 2,
    "net_5496_8" => 3,
    # "net_5021_8" => 4,
    "net_5024_8" => 4,
    "net_5390_4" => 5,
    "net_5063_7" => 6,
    "net_5250_6" => 7,
    "net_5193_0" => 8,
    "net_5013_5" => 9,
    "net_5390_8" => 10,
    "net_5210_4" => 11,
    "net_5225_1" => 12,
)

pseudoart_images_names = Dict(
    1 => "Wyjście z domu",
    2 => "Krzyżowanie się światów",
    3 => "Oddech",
    4 => "Zimny ogień",
    5 => "Alchemia",
    6 => "Wnętrze",
    7 => "Początek",
    8 => "Czarne słońce",
    9 => "Wibracje czasu",
    10 => "Kadzidlany makat- delikatne pochodzenie i rosnąca si",
    11 => "Rozwijając",
    12 => "Everything is a thing and noting is everything",
)

art_images_names = Dict(
    1 => "Czarne dziury pamięci",
    2 => "Czernidło",
    3 => "Płuca czerni",
    4 => "Ucho czerni",
    5 => "Jelita czerni",
    6 => "Przycisk do serc",
    7 => "Czerń na miednicy emaliowanej",
    8 => "Czerń żółta",
    9 => "Kolor Ciemności Bożej",
    10 => "Czarne na czarnym",
    11 => "Czarna dziura",
    12 => "Oko czerni",
)

names_to_order = [v => k for (k, v) in pseudoart_images_order] |> Dict

end # module
