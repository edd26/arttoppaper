using PlotUtils

artists_datasets =
    set2 = [
        "Jarema",
        "Malewicz",
        "Pollock",
        "Kandinsky",
        "Richter",
        "Rothko",
        "art",
        "pseudoart",
    ]
# artists_datasets = set2 = ["Jarema", "Malewicz", "Pollock", "Kandinsky", "Richter"]

ripserer_landscapes_dir(args...) =
    datadir("exp_pro", "ripserer_computations", "ripserer-landscapes", args...)


function load_landscape(
    loading_name::String,
    dataset::String;
    alg = :homology,
    reps = true,
    cutoff = 5,
)
    # ===-===-
    # Get cycles and their persistence
    homology_config = @dict alg reps cutoff

    produced_landscapes, p = produce_or_load(
        ripserer_landscapes_dir(dataset, "image_$(replace(loading_name, ".jpg"=>""))"), # path
        homology_config, # config
        prefix = "homology_info", # file prefix
        force = false, # force computations
    ) do homology_config
        ErrorException("This should have been run in the loop above, terminating") |> throw
    end # produce_or_load
    return produced_landscapes["ripserer_landsacpes"]
end #file

function load_bd_data(
    loading_name::String,
    dataset::String;
    alg = :homology,
    reps = true,
    cutoff = 5,
)
    # ===-===-
    # Get cycles and their persistence
    homology_config = @dict alg reps cutoff

    produced_landscapes, p = produce_or_load(
        ripserer_landscapes_dir(dataset, "image_$(replace(loading_name, ".jpg"=>""))"), # path
        homology_config, # config
        prefix = "homology_info", # file prefix
        force = false, # force computations
    ) do homology_config
        ErrorException("This should have been run in the loop above, terminating") |> throw
    end # produce_or_load

    births_dict, deaths_dict =
        produced_landscapes["ripserer_births"], produced_landscapes["ripserer_deaths"]

    return births_dict, deaths_dict
end #file


function get_landscapes_sum(landscapes_names, dataset::String; selected_dim = "dim0")
    if length(landscapes_names) == 1
        # @info "len==1" landscapes_names

        loaded_landscape = load_landscape(landscapes_names[1], dataset)[selected_dim]
        return loaded_landscape
    elseif length(landscapes_names) == 2
        # @info "len==2" landscapes_names
        l_name1, l_name2 = landscapes_names
        loaded_landscape1 = load_landscape(l_name1, dataset)[selected_dim]
        loaded_landscape2 = load_landscape(l_name2, dataset)[selected_dim]

        return loaded_landscape1 + loaded_landscape2

    elseif length(landscapes_names) > 2
        landscapes_count = length(landscapes_names)
        half_landscapes_count = landscapes_count ÷ 2 + 1
        range1 = 1:(half_landscapes_count-1)
        range2 = half_landscapes_count:landscapes_count

        return get_landscapes_sum(
            landscapes_names[range1],
            dataset,
            selected_dim = selected_dim,
        ) + get_landscapes_sum(
            landscapes_names[range2],
            dataset,
            selected_dim = selected_dim,
        )

    else
        ErrorException("this is not handeled, throwing error") |> throw
    end
end


my_palette = PlotUtils.palette(:Paired_10, 10);
net_palette = PlotUtils.palette(:YlOrRd_9, 9);
net_palette2 = PlotUtils.palette(:Set1_9, 10);

plt_atributes = Dict(
    "art" => (m = :star6, c = my_palette[6]),
    "pseudoart" => (m = :star4, c = my_palette[9]),
    "Kandinsky" => (m = :pentagon, c = my_palette[2]),
    "textures" => (m = :utriangle, c = my_palette[10]),
    "Pollock" => (m = :diamond, c = net_palette2[1]),
    "Rothko" => (m = :star5, c = net_palette2[2]),
    "Mark" => (m = :xcross, c = net_palette2[1]),
    "Jarema" => (m = :star6, c = net_palette2[3]),
    "Malewicz" => (m = :star8, c = net_palette2[4]),
    "Richter" => (m = :dtriangle, c = net_palette2[4]),
    "all_pseudoart" => (m = :hexagon, c = my_palette[7]),
    "net0" => (m = :circle, c = net_palette[1]),
    "net1" => (m = :circle, c = net_palette[2]),
    "net2" => (m = :circle, c = net_palette[3]),
    "net3" => (m = :circle, c = net_palette[4]),
    "net4" => (m = :circle, c = net_palette[5]),
    "net5" => (m = :circle, c = net_palette[6]),
    "net6" => (m = :circle, c = net_palette2[7]),
    "net7" => (m = :circle, c = net_palette2[8]),
    "net8" => (m = :circle, c = net_palette2[end]),
)
