function [ matching_entry_ldx, nonmatching_entry_ldx, ordered_matching_entry_idx ] = fn_find_object_by_field_regexp( input_object_array, match_to_propertyname, match_regexp_list)
%UNTITLED Summary of this function goes here
%   Helper function to get the index of rows in the input_object_array
%   based on whether a desired field/property matches a given list of regular
%   expressions

num_entries = size(input_object_array, 1);

% these are in the natural order of the inout_object_array, which for axes
% means oldest last, which results in wrong legend ordering...
matching_entry_ldx = logical(zeros(size(input_object_array)));
nonmatching_entry_ldx = logical(zeros(size(input_object_array)));

match_regexp_idx = nan(size(input_object_array));	% if each match regexp is unique this is the order requested by match_regexp_list

for i_entry = 1 : num_entries
	cur_entry = input_object_array(i_entry);

	% does the requested property exist
	if isprop(cur_entry, match_to_propertyname)
		cur_property_value = cur_entry.(match_to_propertyname);

		match_ldx = logical(zeros(size(match_regexp_list)));
		for i_match_regexp = 1 : length(match_regexp_list)
			cur_match_regexp = match_regexp_list{i_match_regexp};
			match = regexp(cur_property_value, cur_match_regexp, 'match');
			if ~isempty(match)
				match_ldx(i_match_regexp) = true;
				match_regexp_idx(i_entry) = i_match_regexp;
			end
		end
		if any(match_ldx)
			matching_entry_ldx(i_entry) = true;
			nonmatching_entry_ldx(i_entry) = false;
		else
			matching_entry_ldx(i_entry) = false;
			nonmatching_entry_ldx(i_entry) = true;
		end
	else
		% by default do the right thing...
		matching_entry_ldx(i_entry) = false;
		nonmatching_entry_ldx(i_entry) = true;
	end
end

% condense the 
matching_entry_idx = find(match_regexp_idx > 0);
matching_entry_idx_order = match_regexp_idx(matching_entry_idx);
[sorted_matching_entry_idx_order, sorted_matching_entry_idx_order_idx] = sort(matching_entry_idx_order);
ordered_matching_entry_idx = matching_entry_idx(sorted_matching_entry_idx_order_idx);


return
end

