function [ triallog_table ] = fn_collect_fixations_around_tick_idx_lists( triallog_table, fixations_struct, record2D_table, tick_idx_col_name_list, tick_idx_ext)
%FN_COLLECT_FIXATIONS_AROUND_TICK_IDX_LIST Summary of this function goes here
%   Detailed explanation goes here
% TODO:
%	1) optionally use the fiaxtion source's XY position at each
%	tick_idx_col_name_list item instead of traying to go for the next
%	fixation
%	2) optionally pass in validity ranges for valid prev/next fixations,
%	e.g. to force them to happen within the same cycle

triallog_table = triallog_table;

% TODO detect relevant aim/agent events, like fixation onset and fixation
% offset and add timestamp, tick and XY to table
if ~isempty(fixations_struct)
	n_trials = size(triallog_table, 1);
	triallog_column_name_list = triallog_table.Properties.VariableNames;
	fixations_struct_col_name_list = fieldnames(fixations_struct);	% aims and agents for which we have the desired information


	% here do this for all included state transitions
	for i_tick_idx_col_name = 1 : length(tick_idx_col_name_list)
		full_cur_tick_idx_col_name = tick_idx_col_name_list{i_tick_idx_col_name};
		disp([mfilename, ': Processing: ', full_cur_tick_idx_col_name]);
		%cur_target_state_col_name = ['col_targ_', cur_target_state_name, '_tick_idx'];


		%tick_idx_ext = '_tick_idx';
		cur_tick_idx_col_name = regexprep(full_cur_tick_idx_col_name, tick_idx_ext, '');


		if ismember({full_cur_tick_idx_col_name}, triallog_column_name_list)
		% get the reference tick_idx
		%cur_state_change_tick_idx = triallog_table.(cur_target_state_col_name)(i_trial);
		cur_state_change_tick_idx_list = triallog_table.(full_cur_tick_idx_col_name);


		% we need an invalid timestamp, so make the last value a NaN
		% note there can already be existing NaNs... but this is less
		% work than searching for a NaN index
		tmp_tick_timestamp_list = [record2D_table.timestamp; NaN];

		for i_fix_source = 1 : length(fixations_struct_col_name_list)
			cur_fix_source_name = fixations_struct_col_name_list{i_fix_source};

			switch(cur_fix_source_name)
				case {'aims0', 'agent0'}
					out_cur_fix_source_name = ['A_', cur_fix_source_name(1:end-1)];
				case {'aims1', 'agent1'}
					out_cur_fix_source_name = ['B_', cur_fix_source_name(1:end-1)];
				otherwise
					if contains(cur_fix_source_name, regexpPattern('^A_'))
						% already side-prefixed
					elseif contains(cur_fix_source_name, regexpPattern('^B_'))
						% already side-prefixed
					else
						error([mfilename, ': unknown cur_fix_source_name: ', cur_fix_source_name, ', can not prefix the side string.']);
					end
			end

			[prev_fix_onset_idx, prev_fix_end_idx, prev_fix_mean_XY, cur_fix_onset_idx, cur_fix_end_idx, cur_fix_mean_XY, next_fix_onset_idx, next_fix_end_idx, next_fix_mean_XY] = fn_collect_fixation_data_around_tick(fixations_struct.(cur_fix_source_name), cur_state_change_tick_idx_list);

			% previous fixation
			mod_prev_fix_onset_idx = prev_fix_onset_idx;
			mod_prev_fix_onset_idx(isnan(prev_fix_onset_idx)) = length(tmp_tick_timestamp_list);
			mod_prev_fix_end_idx = prev_fix_end_idx;
			mod_prev_fix_end_idx(isnan(prev_fix_end_idx)) = length(tmp_tick_timestamp_list);


			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_prev_fix_onset_s']) = tmp_tick_timestamp_list(mod_prev_fix_onset_idx);
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_prev_fix_onset_tick_idx']) = prev_fix_onset_idx;
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_prev_fix_end_s']) = tmp_tick_timestamp_list(mod_prev_fix_end_idx);
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_prev_fix_end_tick_idx']) = prev_fix_end_idx;
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_prev_fix_mean_XY']) = prev_fix_mean_XY;
			%triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_prev_next_reach_pos']) = cell(size(prev_fix_end_idx));	% relative position of the next fixation...

			% now get the fixation following the prev fixation to
			% determine the miovement
			tmp_next_fix_XY = cur_fix_mean_XY;	% if these do not exist they are NaNs
			no_cur_fix_ldx = isnan(prev_fix_onset_idx);	% so find the NaNs
			tmp_next_fix_XY(no_cur_fix_ldx) = next_fix_mean_XY(no_cur_fix_ldx); % and replace with the next_fixation (might also be all NaNs)

			% extract the relative position information of a reach
			[categorical_LeftRight, categorical_UpDown, deltaXY, polarThetaRho, polarDegDist] = fn_categorize_reach_from_start_and_end_XY(prev_fix_mean_XY, tmp_next_fix_XY);
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_prev_fix_next_reach_dXY']) = deltaXY;	% relative position of the next fixation...
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_prev_fix_next_reach_DegDist']) = polarDegDist;	% relative position of the next fixation...
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_prev_fix_next_reach_catLR']) = categorical_LeftRight;	% relative position of the next fixation...
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_prev_fix_next_reach_catUD']) = categorical_UpDown;	% relative position of the next fixation...


			% current fixation
			mod_cur_fix_onset_idx = cur_fix_onset_idx;
			mod_cur_fix_onset_idx(isnan(cur_fix_onset_idx)) = length(tmp_tick_timestamp_list);
			mod_cur_fix_end_idx = cur_fix_end_idx;
			mod_cur_fix_end_idx(isnan(cur_fix_end_idx)) = length(tmp_tick_timestamp_list);

			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_cur_fix_onset_s']) = tmp_tick_timestamp_list(mod_cur_fix_onset_idx);
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_cur_fix_onset_tick_idx']) = cur_fix_onset_idx;
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_cur_fix_end_s']) = tmp_tick_timestamp_list(mod_cur_fix_end_idx);
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_cur_fix_end_tick_idx']) = cur_fix_end_idx;
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_cur_fix_mean_XY']) = cur_fix_mean_XY;
			%triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_cur_next_reach_pos']) = cell(size(cur_fix_end_idx));	% relative position of the next fixation...


			% extract the relative position information of a reach
			[categorical_LeftRight, categorical_UpDown, deltaXY, polarThetaRho, polarDegDist] = fn_categorize_reach_from_start_and_end_XY(cur_fix_mean_XY, next_fix_mean_XY);
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_cur_fix_next_reach_dXY']) = deltaXY;	% relative position of the next fixation...
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_cur_fix_next_reach_DegDist']) = polarDegDist;	% relative position of the next fixation...
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_cur_fix_next_reach_catLR']) = categorical_LeftRight;	% relative position of the next fixation...
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_cur_fix_next_reach_catUD']) = categorical_UpDown;	% relative position of the next fixation...



			% next fixation
			mod_next_fix_onset_idx = next_fix_onset_idx;
			mod_next_fix_onset_idx(isnan(next_fix_onset_idx)) = length(tmp_tick_timestamp_list);
			mod_next_fix_end_idx = next_fix_end_idx;
			mod_next_fix_end_idx(isnan(next_fix_end_idx)) = length(tmp_tick_timestamp_list);

			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_next_fix_onset_s']) = tmp_tick_timestamp_list(mod_next_fix_onset_idx);
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_next_fix_onset_tick_idx']) = next_fix_onset_idx;
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_next_fix_end_s']) = tmp_tick_timestamp_list(mod_next_fix_end_idx);
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_next_fix_end_tick_idx']) = next_fix_end_idx;
			triallog_table.([out_cur_fix_source_name, '_', cur_tick_idx_col_name, '_next_fix_mean_XY']) = next_fix_mean_XY;
		end
		else
			disp([mfilename, ': requested column not in trilalog_table: ', full_cur_tick_idx_col_name]);
		end
	end
	%end

	% also classify whether a movement resulted in left/0/right up/0/down
	% movements
else
	disp('Empty fixation_struct, nothing to do...');
end



end

