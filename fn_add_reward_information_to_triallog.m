function [triallog_table] = fn_add_reward_information_to_triallog(triallog_table, reward_trains_table)
%FN_ADD_REWARD_INFORMATION_TO_TRIALLOG Summary of this function goes here
%   Detailed explanation goes here

% attention collection number is increased just before reward is
% dispensed, so the reward collection number is offset by +1 for
% reason TASK, while offset by +0 for reason MANUAL

% for all agents
% we want the reward magnitude (n pulses)

verbose = 0;


% get the relevant collections
[unique_collections, ~, unique_collections_row_idx] = unique(reward_trains_table.collection_number);

% get the relevant subsets
unique_sides_names = unique(reward_trains_table.side);
%RewA_ldx = ismember(reward_trains_table.side, {'A'};
%RewB_ldx = ismember(reward_trains_table.side, {'B'};
reason_TASK_ldx = ismember(reward_trains_table.reason, {'TASK'});
reason_MANUAL_ldx = ismember(reward_trains_table.reason, {'MANUAL'});

force_include_side_list = {'A', 'B'};
side_list = union(unique_sides_names, force_include_side_list);
force_include_reason_list = {'TASK', 'MANUAL'};

% the list of column stems we want to add per side
new_triallog_table_column_stem_list = {'_RewPulses_TASK', '_RewPulses_MANUAL', '_RewTrain_Start_ts_s', '_RewTrain_adjStart_ts_s', '_RewTrain_End_ts_s'};


% treat the agents separately
for i_side = 1 : length(side_list)
	cur_side = side_list{i_side};
	cur_side_row_ldx = ismember(reward_trains_table.side, {cur_side});

	for i_new_col = 1 : length(new_triallog_table_column_stem_list)
		cur_col_stem = new_triallog_table_column_stem_list{i_new_col};
		cur_col_name = [cur_side, cur_col_stem];

		% unassigned timestamps default to nan, for pulse count the default
		% is simply zero
		if contains(cur_col_stem, '_ts_s') && contains(cur_col_stem, '_RewTrain_')
			triallog_table.(cur_col_name) = nan(size(triallog_table.collection_num));
		elseif contains(cur_col_stem, '_RewPulses_')
			triallog_table.(cur_col_name) = zeros(size(triallog_table.collection_num));
		else
			error('What shall we do here?');
		end

		%loop over the collections to find the correct one
		for i_collection_num = 1 : length(unique_collections_row_idx)
			cur_collection_ldx = unique_collections_row_idx == i_collection_num;
			if any(cur_collection_ldx)
				cur_reward_collection_num = unique_collections(i_collection_num);
				cur_reward_trial_num = cur_reward_collection_num;
				cur_triallog_trial_num_idx = find(triallog_table.trial_num == cur_reward_trial_num);
				cur_side_collection_num_ldx = cur_side_row_ldx & cur_collection_ldx;
				
				if any(cur_side_collection_num_ldx)
				switch cur_col_stem
					case '_RewPulses_TASK'
						cur_reward_table_row_ldx = cur_side_collection_num_ldx & reason_TASK_ldx;
						if sum(cur_reward_table_row_ldx) == 1
							cur_value = sum(reward_trains_table.n_pulses(cur_reward_table_row_ldx));
						elseif (sum(cur_reward_table_row_ldx) > 1)
							error('Should not happen investiigate');
						else
							cur_value = 0;
						end

					case '_RewPulses_MANUAL'
						cur_reward_table_row_ldx = cur_side_collection_num_ldx & reason_MANUAL_ldx;
						if any(cur_reward_table_row_ldx)
							cur_value = sum(reward_trains_table.n_pulses(cur_reward_table_row_ldx));
						else
							cur_value = 0;
						end

					case '_RewTrain_Start_ts_s'
						cur_reward_table_row_ldx = cur_side_collection_num_ldx & reason_TASK_ldx;
						if sum(cur_reward_table_row_ldx) == 1
							cur_value = reward_trains_table.start_timestamp_s(cur_reward_table_row_ldx);
						elseif (sum(cur_reward_table_row_ldx) > 1)
							error('Should not happen investiigate');
						else
							cur_value = NaN;
						end

					case '_RewTrain_adjStart_ts_s'
						cur_reward_table_row_ldx = cur_side_collection_num_ldx & reason_TASK_ldx;
						if sum(cur_reward_table_row_ldx) == 1
							cur_value = reward_trains_table.start_timestamp_s(cur_reward_table_row_ldx) + (reward_trains_table.initial_delay_ms(cur_reward_table_row_ldx) / 1000);
						elseif (sum(cur_reward_table_row_ldx) > 1)
							error('Should not happen investiigate');
						else
							cur_value = NaN;
						end

					case '_RewTrain_End_ts_s'
						cur_reward_table_row_ldx = cur_side_collection_num_ldx & reason_TASK_ldx;
						if sum(cur_reward_table_row_ldx) == 1
							cur_value = reward_trains_table.end_timestamp_s(cur_reward_table_row_ldx);
						elseif (sum(cur_reward_table_row_ldx) > 1)
							error('Should not happen investiigate');
						else
							cur_value = NaN;
						end

					otherwise
						error([mfilename, ': unhandled cur_col_stem: ', cur_col_stem]);
				end
				triallog_table.(cur_col_name)(cur_triallog_trial_num_idx) = cur_value;
				else
					if (verbose)
						disp(['No reward for current collection_num and side: ', cur_side]);
					end
				end

			else
				if (verbose)
					disp(['No reward for current  unique_collections_row_idx: ', num2str(i_collection_num)]);
				end
			end
		end

	end
end

end

