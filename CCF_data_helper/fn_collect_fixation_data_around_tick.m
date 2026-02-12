function [ prev_fix_onset_idx, prev_fix_end_idx, prev_fix_mean_XY, cur_fix_onset_idx, cur_fix_end_idx, cur_fix_mean_XY, next_fix_onset_idx, next_fix_end_idx, next_fix_mean_XY ] = fn_collect_fixation_data_around_tick( cur_fixations_struct, cur_tick_idx_list )
%FN_COLLECT_FIXATION_DATA_AROUND_TICK Summary of this function goes here
%   Detailed explanation goes here

% stuff we do not find we di not report
prev_fix_onset_idx = NaN(size(cur_tick_idx_list));
prev_fix_end_idx = NaN(size(cur_tick_idx_list));
prev_fix_mean_XY = NaN([size(cur_tick_idx_list, 1), 2]);
cur_fix_onset_idx = NaN(size(cur_tick_idx_list));
cur_fix_end_idx = NaN(size(cur_tick_idx_list));
cur_fix_mean_XY = NaN([size(cur_tick_idx_list, 1), 2]);
next_fix_onset_idx = NaN(size(cur_tick_idx_list));
next_fix_end_idx = NaN(size(cur_tick_idx_list));
next_fix_mean_XY = NaN([size(cur_tick_idx_list, 1), 2]);

% default to all NaNs for an all NaN tick_idx, as that denotes something that
% did not happen
if sum(isnan(cur_tick_idx_list)) == length(cur_tick_idx_list)
	return
end


for i_tick_idx = 1 : length(cur_tick_idx_list)
	cur_tick_idx = cur_tick_idx_list(i_tick_idx);

	% find the fixations around the current tick index
	previous_fixation_idx = find(cur_fixations_struct.fix_end_idx < cur_tick_idx, 1 ,'last');
	next_fixation_idx = find(cur_fixations_struct.fix_onset_idx > cur_tick_idx, 1 ,'first');
	if (next_fixation_idx - previous_fixation_idx == 2)
		cur_fixation_idx = previous_fixation_idx + 1;
	else
		cur_fixation_idx = [];
	end

	if ~isempty(previous_fixation_idx)
		prev_fix_onset_idx(i_tick_idx) = cur_fixations_struct.fix_onset_idx(previous_fixation_idx);
		prev_fix_end_idx(i_tick_idx) = cur_fixations_struct.fix_end_idx(previous_fixation_idx);
		prev_fix_mean_XY(i_tick_idx, :) = [cur_fixations_struct.mean_X(previous_fixation_idx), cur_fixations_struct.mean_Y(previous_fixation_idx)];
	end

	if ~isempty(cur_fixation_idx)
		cur_fix_onset_idx(i_tick_idx) = cur_fixations_struct.fix_onset_idx(cur_fixation_idx);
		cur_fix_end_idx(i_tick_idx) = cur_fixations_struct.fix_end_idx(cur_fixation_idx);
		cur_fix_mean_XY = [cur_fixations_struct.mean_X(cur_fixation_idx), cur_fixations_struct.mean_Y(cur_fixation_idx)];
	end

	if ~isempty(next_fixation_idx)
		next_fix_onset_idx(i_tick_idx) = cur_fixations_struct.fix_onset_idx(next_fixation_idx);
		next_fix_end_idx(i_tick_idx) = cur_fixations_struct.fix_end_idx(next_fixation_idx);
		next_fix_mean_XY(i_tick_idx, :) = [cur_fixations_struct.mean_X(next_fixation_idx), cur_fixations_struct.mean_Y(next_fixation_idx)];
	end

end

end

