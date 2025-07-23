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
dipha_exec = projectdir("dipha", "dipha")

# ===-===-
ENV["GKSwstype"] = "100"

# ===-===-
# Datasets paths configuration
artist_raw_path_args = ("art",)
pseudoart_raw_path_args = ("pseudoart",)


raw_paths = [
    artist_raw_path_args,
    pseudoart_raw_path_args,
]

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
    if data_set .== "art"
        if image_type == "BW"
            path_args = ("BW", data_set)
        elseif image_type == "WB"
            path_args = ("WB", data_set)
        else
            ErrorException("Unknow data config. Failed to parse arguments") |> throw
        end

    elseif data_set == "pseudoart"
        if image_type == "BW"
            path_args = ("BW", "pseudoart",)
        elseif image_type == "WB"
            path_args = ("WB", "pseudoart",)
        else
            ErrorException("Unknow data config. Failed to parse arguments") |> throw
        end

    else
        if image_type == "BW"
            path_args = ("BW", data_set)
        elseif image_type == "WB"
            path_args = ("WB", data_set,)
        else
            ErrorException("Unknow data config. Failed to parse arguments") |> throw
        end
    end

    return path_args
end # function

path_args = set_path_args(data_set, data_config)
# ===-===-
# 0:
preproc_img_dir(args...) = datadir("exp_pro", "img_initial_preprocessing", args...)
preproc_img_dir_set(args...) = preproc_img_dir(path_args..., args...)
# 1:
export_for_dipha_folder(args...) = datadir("exp_pro", "img_dipha_input", args...)
export_for_dipha_folder_set(args...) = export_for_dipha_folder(path_args..., args...)
# 2:
dipha_raw_export_folder(args...) = datadir("exp_pro", "dipha_raw_results", args...)
dipha_raw_export_folder_set(args...) = dipha_raw_export_folder(path_args..., args...)
# 3
dipha_bd_info_export_folder(args...) = datadir("exp_pro", "dipha_bd_data", args...)
dipha_bd_info_export_folder_set(args...) = dipha_bd_info_export_folder(path_args..., args...)

homology_info_storage(args...) = datadir("exp_pro", "section17", "17e-hausdorff_computations", args...)
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
