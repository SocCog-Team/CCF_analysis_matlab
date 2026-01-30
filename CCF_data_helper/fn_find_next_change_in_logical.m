function [ last_idx_with_current_logical_value ] = fn_find_next_change_in_logical( cur_logical, start_idx, increment )
%FN_FIND_NEXT_CHANGE_IN_LOGICAL Summary of this function goes here
%   Detailed explanation goes here

last_idx_with_current_logical_value = [];




% search in the past or the future
cur_search_offset = 0;
% find the next change in the ligical..
while cur_logical(start_idx + cur_search_offset) == cur_logical(start_idx)
	cur_search_offset = cur_search_offset + increment;
	% exit before trying to index out side of the list
	if (start_idx + cur_search_offset) == 0
		break;
	elseif ((start_idx + cur_search_offset) >= length(cur_logical))
		break;
	end
end

if (increment == - 1)
	last_idx_with_current_logical_value = start_idx + cur_search_offset + 1;
elseif (increment == 1)
	last_idx_with_current_logical_value = start_idx + cur_search_offset - 1;
end



end

