function [ out_struct ] = fn_calculate_gaze_sample_count_and_proportions_per_object(data_sub_table, sample_src_col_stem, reference_object_position_stem_list, reference_object_position_stem_closeness_threshold_list, method_string, prefix, suffix)
%FN_CALCULATE_GAZE_SAMPLE_PROPORTIONS_PER_OBJECT Summary of this function goes here
%   Detailed explanation goes here


if ~exist('prefix', 'var')
	prefix = [];
end

if ~exist('suffix', 'var')
	suffix = [];
end

% prepare a few fields for filling in by the caller later
out_struct.cycle = nan;
out_struct.sessionID = '';
out_struct.epoch = '';
out_struct.vergence = '';
out_struct.total_N = size(data_sub_table, 1);


sample_position_XY = [data_sub_table.([sample_src_col_stem, '_X']), data_sub_table.([sample_src_col_stem, '_X'])];

if ~strcmp(method_string, 'all')
	cur_distance_sample_to_ref_object_array = nan(size(data_sub_table, 1), length(reference_object_position_stem_list));
	sample_on_ref_object_ldx_array = false(size(cur_distance_sample_to_ref_object_array));
end

for i_ref_object = 1 : length(reference_object_position_stem_list)
	cur_ref_object_stem = reference_object_position_stem_list{i_ref_object};
	cur_closeness_threshold = reference_object_position_stem_closeness_threshold_list(i_ref_object);
	
	cur_ref_object_XY =  [data_sub_table.([cur_ref_object_stem, '_X']), data_sub_table.([cur_ref_object_stem, '_X'])];
	cur_distance_sample_to_ref_object = vecnorm(cur_ref_object_XY - sample_position_XY, 2, 2);

	% find 
	sample_on_ref_object_ldx = cur_distance_sample_to_ref_object <= cur_closeness_threshold;

	% all objects that meet the maximum distance requirements
	if strcmp(method_string, 'all')
		cur_out_object_name_stem = [prefix, sample_src_col_stem, '_on_', cur_ref_object_stem, suffix];
		out_struct.([cur_out_object_name_stem, '_N']) = sum(sample_on_ref_object_ldx);
		out_struct.([cur_out_object_name_stem, '_PCT']) = 100 * out_struct.([cur_out_object_name_stem, '_N']) / out_struct.total_N;
	else
		cur_distance_sample_to_ref_object_array(:, i_ref_object) = cur_distance_sample_to_ref_object;
		sample_on_ref_object_ldx_array(:, i_ref_object) = sample_on_ref_object_ldx;
	end
end

if strcmp(method_string, 'closest_object_within_threshold')
	% we should break ties based on depth, so for A:
	% A gaze:	aim0, agent0, agent1, targetN, aim1, B_face
	% B gaze:	aim1, agent1, agent0, targetN, aim0, A_face
	% but let"s start simply with closests

	% different objects have different distance thresholds, so first mask
	% out all distancesthat are too large
	masked_cur_distance_sample_to_ref_object_array = cur_distance_sample_to_ref_object_array;
	masked_cur_distance_sample_to_ref_object_array(~sample_on_ref_object_ldx_array) = nan;

	% then out of the surviving, pick the closest
	[closest_distance_val, closest_object_stem_idx] = min(masked_cur_distance_sample_to_ref_object_array, [], 2, 'omitnan');
	% if we pick NaN as closest, nan-out the index
	closest_object_stem_idx(isnan(closest_distance_val)) = nan;


	for i_ref_object = 1 : length(reference_object_position_stem_list)
		cur_object_idx = i_ref_object;
		cur_ref_object_stem = reference_object_position_stem_list{i_ref_object};

		cur_out_object_name_stem = [prefix, sample_src_col_stem, '_on_', cur_ref_object_stem, suffix];
		out_struct.([cur_out_object_name_stem, '_N']) = sum(closest_object_stem_idx == cur_object_idx);
		out_struct.([cur_out_object_name_stem, '_PCT']) = 100 * out_struct.([cur_out_object_name_stem, '_N']) / out_struct.total_N;
	end
end


end

