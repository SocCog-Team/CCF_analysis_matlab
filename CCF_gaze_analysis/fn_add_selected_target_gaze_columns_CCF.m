function [ out_struct ] = fn_add_selected_target_gaze_columns_CCF( ...
	in_struct, triallog_row, sample_src_col_name_stem, target_prefix_list)

out_struct = in_struct;

selected_target_idx = triallog_row.col_targ_IDX;
out_struct.selected_target_IDX = selected_target_idx;
out_struct.selected_target_name = triallog_row.col_targ_id_name{1};

if isnan(selected_target_idx)
	out_struct.([sample_src_col_name_stem, '_on_selected_target_N']) = nan;
	out_struct.([sample_src_col_name_stem, '_on_selected_target_PCT']) = nan;
	out_struct.([sample_src_col_name_stem, '_on_other_targets_N']) = nan;
	out_struct.([sample_src_col_name_stem, '_on_other_targets_PCT']) = nan;
	return
end

selected_target_stem = ['target', num2str(selected_target_idx)];

selected_N = getfield(out_struct, [sample_src_col_name_stem, '_on_', selected_target_stem, '_N']);
selected_PCT = getfield(out_struct, [sample_src_col_name_stem, '_on_', selected_target_stem, '_PCT']);

other_N = 0;
other_PCT = 0;

for i_target = 1:numel(target_prefix_list)
	cur_target_stem = target_prefix_list{i_target};

	if strcmp(cur_target_stem, selected_target_stem)
		continue
	end

	other_N_field = [sample_src_col_name_stem, '_on_', cur_target_stem, '_N'];
	other_PCT_field = [sample_src_col_name_stem, '_on_', cur_target_stem, '_PCT'];

	other_N = other_N + out_struct.(other_N_field);
	other_PCT = other_PCT + out_struct.(other_PCT_field);
end

out_struct.([sample_src_col_name_stem, '_on_selected_target_N']) = selected_N;
out_struct.([sample_src_col_name_stem, '_on_selected_target_PCT']) = selected_PCT;
out_struct.([sample_src_col_name_stem, '_on_other_targets_N']) = other_N;
out_struct.([sample_src_col_name_stem, '_on_other_targets_PCT']) = other_PCT;
end