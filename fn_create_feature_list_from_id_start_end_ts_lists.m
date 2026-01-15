function [ per_sample_feature_list ] = fn_create_feature_list_from_id_start_end_ts_lists( sample_timestamp_list, feature_id_num_list, start_ts_list, end_ts_list )
%FN_CREATE_FEATURE_LIST_FROM_ID_START_END_TS_LISTS Summary of this function goes here
%   Detailed explanation goes here

per_sample_feature_list = [];


per_sample_feature_list = nan(size(sample_timestamp_list));

n_feature_ids = length(feature_id_num_list);

for i_feature_id = 1 : n_feature_ids
	cur_feature_id = feature_id_num_list(i_feature_id);
	cur_feature_id_sample_ldx = (sample_timestamp_list >= start_ts_list(i_feature_id)) & (sample_timestamp_list <= end_ts_list(i_feature_id));
	per_sample_feature_list(cur_feature_id_sample_ldx) = cur_feature_id;
end


end

