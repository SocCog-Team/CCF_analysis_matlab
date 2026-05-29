function [ proportion_on_object_list, count_on_object_list, total_sample_count, object_name_list ] = fn_calculate_gaze_sample_proportions_per_object(data_sub_table, sample_src_col_stem, reference_object_position_stem_list, reference_object_position_stem_closeness_threshold_list, prefix, suffix)
%FN_CALCULATE_GAZE_SAMPLE_PROPORTIONS_PER_OBJECT Summary of this function goes here
%   Detailed explanation goes here

proportion_on_object_list = [];
count_on_object_list = [];
total_sample_count = [];
object_name_list = [];


if ~exist('prefix', 'var')
	prefix = [];
end

if ~exist('suffix', 'var')
	suffix = [];
end


sample_position_XY = [data_sub_table.([sample_src_col_stem, '_X']), data_sub_table.([sample_src_col_stem, '_X'])];

total_sample_count = size(data_sub_table, 1);

n_objects = length(reference_object_position_stem_list);


proportion_on_object_list = zeros([n_objects, 1]);
count_on_object_list = zeros([n_objects, 1]);
object_name_list = cell(size(reference_object_position_stem_list));


for i_ref_object = 1 : length(reference_object_position_stem_list)
	cur_ref_object_stem = reference_object_position_stem_list{i_ref_object};
	cur_closeness_threshold = reference_object_position_stem_closeness_threshold_list(i_ref_object);
	
	cur_ref_object_XY =  [data_sub_table.([cur_ref_object_stem, '_X']), data_sub_table.([cur_ref_object_stem, '_X'])];
	cur_distance_sample_to_ref_object = vecnorm(cur_ref_object_XY - sample_position_XY, 2, 2);

	% find 
	sample_on_ref_object_ldx = cur_distance_sample_to_ref_object <= cur_closeness_threshold;

	count_on_object_list(i_ref_object) = sum(sample_on_ref_object_ldx);
	proportion_on_object_list(i_ref_object) = count_on_object_list(i_ref_object) / total_sample_count;

	object_name_list(i_ref_object) = {[prefix, sample_src_col_stem, '_on_', cur_ref_object_stem, suffix]};


end



end

