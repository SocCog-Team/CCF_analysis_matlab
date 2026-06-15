function [ ] = fn_manipulate_properties_by_objecthandles( manipulation_string, object_handle_list, property_cadidate_list, new_value, value_to_match, max_abs_diff )
%FN_MANIPULATE_CHILD_PROPERTIES_BY_CHILD_LDX Summary of this function goes here
%   Detailed explanation goes here

%fn_manipulate_child_properties_by_child_ldx('change_existing_property', cur_ah.Children(matching_entry_ldx), {'Color', 'FaceColor', 'MarkerEdgeColor', 'MarkerFaceColor'}, [0 0 0]);


for i_child_object = 1 : length(object_handle_list)
	cur_object_handle = object_handle_list(i_child_object);
	switch manipulation_string
		case 'change_existing_property'
			% only replace values for properties that already exist...
			for i_property = 1 : length(property_cadidate_list)
				cur_property = property_cadidate_list{i_property};
				if isprop(cur_object_handle, cur_property)
					cur_object_handle.(cur_property) = new_value;
				end
			end
		case 'change_matching_existing_property'
			% only replace values for properties that already exist and
			% that have the expected value
			for i_property = 1 : length(property_cadidate_list)
				cur_property = property_cadidate_list{i_property};
				if isprop(cur_object_handle, cur_property) && isequal(cur_object_handle.(cur_property), value_to_match)
					cur_object_handle.(cur_property) = new_value;
				end
			end
		case 'change_fuzzy_matching_existing_property'
			% only replace values for properties that already exist and
			% that have the expected value
			for i_property = 1 : length(property_cadidate_list)
				cur_property = property_cadidate_list{i_property};
				if isprop(cur_object_handle, cur_property)
					cur_value = cur_object_handle.(cur_property);
					if isnumeric(cur_value)
						% if the delta is smaller than requested we declare
						% a fuzzy match
						if sum(abs(cur_object_handle.(cur_property) - value_to_match)) <= max_abs_diff
							cur_object_handle.(cur_property) = new_value;
						end
					end
				end
			end
		otherwise
			error([mfilename, ': unhandled manipulation_string: ', manipulation_string]);
	end
end

end

