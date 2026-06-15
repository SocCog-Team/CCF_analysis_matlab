function [ ] = fn_delete_children_from_axis_handle( cur_ah, axis_children_to_delete, selection_property, valid_to_delete_entry_regexp_list )
%FN_DELETE_CHILDREN_FROM_AXIS_HANDLE Summary of this function goes here
%   Detailed explanation goes here

% if set only delete children where the content of the selection_property
% property matches valid_entry_regexp_list
if ~exist('selection_property', 'var') || isempty(selection_property)
	selection_property = [];
end

if ~exist('valid_entry_regexp_list', 'var') || isempty(valid_entry_regexp_list)
	valid_entry_regexp_list = [];
end



% deleting intermediate entries changes the indices of entries to the right
% of the deletion index, to avoid that reordering affecting the entry a
% given IDX refers to, simply delete from the right...
sorted_axis_children_to_delete = sort(axis_children_to_delete, 'descend');


for i_child_to_delete = 1 : length(sorted_axis_children_to_delete)
	cur_child_idx_to_delete_idx = sorted_axis_children_to_delete(i_child_to_delete);
	if isempty(selection_property)
		delete(cur_ah.Children(cur_child_idx_to_delete_idx));
	else
		%cur_child_idx_to_delete = cur_ah.Children(cur_child_idx_to_delete_idx);
		if isprop(cur_ah.Children(cur_child_idx_to_delete_idx), selection_property)

			match_ldx = logical(zeros(size(valid_to_delete_entry_regexp_list)));
			for i_match_regexp = 1 : length(valid_to_delete_entry_regexp_list)
				cur_match_regexp = valid_to_delete_entry_regexp_list{i_match_regexp};
				match = regexp(cur_ah.Children(cur_child_idx_to_delete_idx).(selection_property), cur_match_regexp, 'match');
				if ~isempty(match)
					match_ldx(i_match_regexp) = true;
				end
			end
			if any(match_ldx)
				% this was a match, so remove this...
				delete(cur_ah.Children(cur_child_idx_to_delete_idx));
			end

		else
			error([mfilename, ': selection_property miossing: ', selection_property]);
		end

	end
end

return
end

