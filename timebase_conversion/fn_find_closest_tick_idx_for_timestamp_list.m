function [ cur_closests_tick_idx_list, cur_closests_distance_list ] = fn_find_closest_tick_idx_for_timestamp_list( reference_timestamp_data, timestamp_list )
%FN_FIND_CLOSEST_TICK_IDX_FOR_TIMESTAMP_LIST Summary of this function goes here
%   For a list of timestamps find the row_idx of the nearest timestamp in a
%   reference timestamp_list

cur_closests_tick_idx_list = zeros(size(timestamp_list));
cur_closests_distance_list = zeros(size(timestamp_list));

for i_timestamp = 1 : length(timestamp_list)
	cur_timetamp = timestamp_list(i_timestamp);
	distance_list = reference_timestamp_data - cur_timetamp;
	abs_distance_list = abs(distance_list);
	[~, cur_min_dist_idx] = min(abs_distance_list);
	cur_closests_tick_idx_list(i_timestamp) = cur_min_dist_idx;
	cur_closests_distance_list(i_timestamp) = distance_list(i_timestamp);
end	

% do not try to find nan timestamps...
cur_closests_tick_idx_list(isnan(timestamp_list)) = nan;

end

