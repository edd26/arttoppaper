module ArtTopoArgParse

using ArgParse

# ===-===-===-===-===-
function parse_plotting_commandline()
    s = ArgParseSettings()

    # ===
    @add_arg_table! s begin
        "--data_set", "-d"
        help = "Specifies data set to use; possible options are: art, pseudoart"
        arg_type = String
        default = "art"

        "--data_config", "-c"
        help = "Specifies whether to use BW or RGB version of images; possible options are BW (black-to-white filtration), WB (white-to-black filtration), RGB, RGB_rev (last two run computations for each RGB channels separately, with last doing it from highest values to the lowest)"
        arg_type = String
        default = "BW"

        "--selected_dim"
        help = "Specifies dimension that will be processed"
        arg_type = Int
        default = 0

        "--persistence_threshold", "-t"
        help = "Specifies threshold for birth-death diagram"
        arg_type = Int
        default = 5

        "--selected_ET"
        help = "Specifies eye tracking set to use"
        arg_type = Int
        default = 1

        "--total_trials"
        help = "Total number of shuffling for networks"
        arg_type = Int
        default = 1000

        "--BW_only"
        help = "Option for 1abc to decide if include RGB in computations"
        arg_type = Bool
        default = true

        "--total_images", "-i"
        help = "Option for 1abc to decide if include RGB in computations"
        arg_type = Int
        default = 12


        "--fixation_sequence", "-f"
        help = "Option for 17 to select total samples in fixation sequence; set to 0 to use all heatmap data"
        arg_type = Int
        default = 35

        "--longest_fixation_sequence", "-l"
        help = "Option for 17 to select maximal samples in fixation sequence; set to -1 to use all heatmap data"
        arg_type = Int
        default = -1
    end

    return parse_args(s)
end


end # module
