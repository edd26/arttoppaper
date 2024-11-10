
"""
    populate_dict(input_dict, source_keys; final_structure=Any[])

A recursive function to create a dictionary within dictionaries.

Returns a sequence of dictionaries, in which keys are the elements of
`source_keys`.

"""
function populate_dict(input_dict, source_keys; final_structure=Any[])
    final_dictionary = copy(input_dict)
    dict_keys = copy(source_keys)
    populate_dict!(final_dictionary, dict_keys; final_structure=final_structure)

    return final_dictionary
end

function populate_dict!(final_dictionary, dict_keys; final_structure=Any[], dict_type=Dict)
    if length(dict_keys) == 0
        # Do final call
        final_dictionary = copy(final_structure)

        return final_dictionary
    else
        # do a recursive call with dict_keys reduced by 1
        first_keys = copy(dict_keys[1])
        other_keys = copy(dict_keys[2:end])

        a_dict = dict_type()
        for local_key in first_keys
            @debug "\t" local_key dict_keys[2:end]
            a_dict[local_key] = populate_dict!(final_dictionary,
                other_keys,
                final_structure=final_structure)
        end
        final_dictionary = a_dict
    end

    return final_dictionary
end


function create_short_name(n, target_len)
    if length(n) > target_len
        while length(n) > target_len
            n = chop(n)
        end
        short_name = n * "..."
    else
        short_name = n
    end
    return short_name
end