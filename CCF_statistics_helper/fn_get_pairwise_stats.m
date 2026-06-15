function [ pair_id_array, test_stat_structarr, report_string_list, pair_id_list ] = fn_get_pairwise_stats( stat_type, data, numerical_group_id_list, group_name_list )
%FN_GET_PAIRWISE_STATS Summary of this function goes here
%   Detailed explanation goes here

pair_id_array = [];
test_stat_structarr = [];
report_string_list = {};
pair_id_list = {};

% if data is not a list but a 2D array, assume that groups are in the
% columns, and that numerical_group_id_list and group_name_list are by
% column
if (size(data, 2) > 1)
	[n_rows, n_cols] = size(data);
	in_data = data;
	in_numerical_group_id_list = numerical_group_id_list;
	in_group_name_list = group_name_list;

	data = nan([numel(data)	1]);
	numerical_group_id_list = nan(size(data));
	group_name_list = cell(size(data));
	for i_col = 1 : n_cols
		cur_start_idx = (i_col - 1) * n_rows + 1;
		data(cur_start_idx : cur_start_idx - 1 + n_rows) = in_data(:, i_col);
		numerical_group_id_list(cur_start_idx : cur_start_idx - 1 + n_rows) = in_numerical_group_id_list(i_col);
		group_name_list(cur_start_idx : cur_start_idx - 1 + n_rows) = in_group_name_list(i_col);
	end
end


[unique_group_id_list, ~, unique_group_id_list_by_row_idx] = unique(numerical_group_id_list);
if length(unique_group_id_list) == 1
	disp([mfilename, ': only a single group found, no pairwise testing possible, skipping...']);
	return
end
all_group_id_combination_array = nchoosek(unique_group_id_list, 2);


% if unique_group_id_list_by_row_idx(1) == 2
% 	keyboard
% end

pair_id_array = nan(size(all_group_id_combination_array));

combination_to_delete_idx = [];
for i_combination = 1: size(all_group_id_combination_array, 1)
	cur_combination = all_group_id_combination_array(i_combination, :);
	cur_group_1_id = cur_combination(1);	% these are already the unique_group_id_list members
	cur_group_1_ldx = unique_group_id_list_by_row_idx == find(ismember(unique_group_id_list, cur_group_1_id));

	cur_group_2_id = cur_combination(2);	% these are already the unique_group_id_list members
	cur_group_2_ldx = unique_group_id_list_by_row_idx == find(ismember(unique_group_id_list, cur_group_2_id));

	% bail out if one or both groups are empty
	if ~any(cur_group_1_ldx) || ~any(cur_group_2_ldx)
		combination_to_delete_idx = [combination_to_delete_idx, i_combination];
	else
	
	group_1_name = fn_sanitize_string_as_matlab_variable_name(group_name_list{find(cur_group_1_ldx, 1, 'first')});
	group_1_data = data(cur_group_1_ldx);

	group_2_name = fn_sanitize_string_as_matlab_variable_name(group_name_list{find(cur_group_2_ldx, 1, 'first')});
	group_2_data = data(cur_group_2_ldx);

	
	[cur_test_stat_structarr, cur_report_string] = fn_statistic_test_and_report(group_1_name, group_1_data, group_2_name, group_2_data, stat_type);
	if (i_combination == 1)
		test_stat_structarr = cur_test_stat_structarr;
	else
		test_stat_structarr = [test_stat_structarr, cur_test_stat_structarr];
	end
	report_string_list(i_combination) = {cur_report_string};
	pair_id_array(i_combination, :) = cur_combination;
	pair_id_list(i_combination) = {cur_combination};	% sigstar() wants this format...
	end
end

if ~isempty(combination_to_delete_idx)
	report_string_list(combination_to_delete_idx) = [];
	pair_id_list(combination_to_delete_idx) = [];
	pair_id_array(combination_to_delete_idx, :) = [];
end

end

