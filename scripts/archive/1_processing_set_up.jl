using DrWatson
@quickactivate "ArtTopology"

## ===-===-===-===-===-===-===-===-===-===-===-===-

sets_names = ["wystawa_fejkowa",
    # "fake_networks_cleaned_2048",
    "Artysta",
]

set_name = sets_names[2]

doing_RGB = false
if doing_RGB
    sufix = "RGB"
else
    sufix = "BW"
end

filter_out_nonjpg(some_files) = filter(x -> occursin("jpg", x), some_files)

dipha_img_export_path(args...) = datadir("exp_pro", sufix, "bw_export", set_name, args...)
images_for_dipha_folder(args...) = datadir("exp_pro", sufix, "images_for_dipha", set_name, args...)
dipha_result_folder(args...) = datadir("exp_pro", sufix, "dipha_results", set_name, args...)
dipha_bd_info_export_folder(args...) = datadir("exp_pro", sufix, "bd-data", set_name, args...)