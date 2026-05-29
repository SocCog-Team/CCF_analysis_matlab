function [ out_struct ] = fn_calculate_gaze_sample_count_and_proportions_per_object(data_sub_table, sample_src_col_stem, reference_object_position_stem_list, reference_object_position_stem_closeness_threshold_list, prefix, suffix)
%FN_CALCULATE_GAZE_SAMPLE_PROPORTIONS_PER_OBJECT Summary of this function goes here
%   Detailed explanation goes here


if ~exist('prefix', 'var')
	prefix = [];
end

if ~exist('suffix', 'var')
	suffix = [];
end

% prepare a few 
out_struct.cycle = nan;
out_struct.sessionID = '';
out_struct.epoch = '';
out_struct.vergence = '';
out_struct.total_N = size(data_sub_table, 1);


sample_position_XY = [data_sub_table.([sample_src_col_stem, '_X']), data_sub_table.([sample_src_col_stem, '_X'])];


for i_ref_object = 1 : length(reference_object_position_stem_list)
	cur_ref_object_stem = reference_object_position_stem_list{i_ref_object};
	cur_closeness_threshold = reference_object_position_stem_closeness_threshold_list(i_ref_object);
	
	cur_ref_object_XY =  [data_sub_table.([cur_ref_object_stem, '_X']), data_sub_table.([cur_ref_object_stem, '_X'])];
	cur_distance_sample_to_ref_object = vecnorm(cur_ref_object_XY - sample_position_XY, 2, 2);

	% find 
	sample_on_ref_object_ldx = cur_distance_sample_to_ref_object <= cur_closeness_threshold;

	cur_out_object_name_stem = [prefix, sample_src_col_stem, '_on_', cur_ref_object_stem, suffix];
	out_struct.([cur_out_object_name_stem, '_N']) = sum(sample_on_ref_object_ldx);
	out_struct.([cur_out_object_name_stem, '_PCT']) = 100 * out_struct.([cur_out_object_name_stem, '_N']) / out_struct.total_N;

end



end

