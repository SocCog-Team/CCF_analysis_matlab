function [ triallog_table, record2D_table ] = fn_create_triallog_from_record2D( record2D_table, enum_struct, target_radius )
%FN_CREATE_TRIALLOG_FROM_RECORD2D Summary of this function goes here
%   for collection and alignment event selection having a two table is
%   pretty conveniebt, so construct one here


timestamps.(mfilename).start = tic;
disp(['Starting: ', mfilename]);
dbstop if error
fq_mfilename = mfilename('fullpath');


% useful but currently slow, exclude for development for now
nan_out_invalid_aims_pos = 1;	% nan out aim positions when agent was not touching
nan_out_invalid_agent_pos = 1;	% nan out agent (cursor) positions when agent was not touching
calc_and_store_distances_to_targets = 1;


triallog_table = [];


record2D_colname_list = record2D_table.Properties.VariableNames;

agent_prefix_list = {'agent0', 'agent1'};
aims_prefix_list = {'aims0', 'aims1'};

% the number of targets in a run is not fixed, so detect it...
target_prefix_list ={};
for i_col = 1 : length(record2D_colname_list)
	cur_col_name = record2D_colname_list{i_col};
	cur_target_prefix_cell = regexp(cur_col_name, '^target\d*', 'match');
	if ~isempty(cur_target_prefix_cell)
		target_prefix_list = [target_prefix_list, cur_target_prefix_cell{1}];
	end
end
target_prefix_list = unique(target_prefix_list);



start_ts = record2D_table.timestamp(1);

[unique_collection_list, first_instance_of_collection_num_idx, unique_collection_list_row_idx] = unique(record2D_table.n_finished_collections);
n_collections = length(unique_collection_list);

% build a table with relevant per collection/trial information
% COLLECTION NUMBER
triallog_table = array2table(unique_collection_list, 'VariableNames', {'collection_num'});
triallog_table = addvars(triallog_table, (unique_collection_list + 1), 'NewVariableNames', 'trial_num');	% make this 1-based and abstract from the fact that the collection number increases between collection end and reward state


% COLLECTION START / END
triallog_table = addvars(triallog_table, record2D_table.timestamp(first_instance_of_collection_num_idx), 'NewVariableNames', 'collection_start_timestamp_s');
triallog_table = addvars(triallog_table, record2D_table.timestamp([first_instance_of_collection_num_idx(2:end)-1; size(record2D_table, 1)]), 'NewVariableNames', 'collection_end_timestamp_s');	% collection is incremented between finishing the collection duration and dispensing the rewards
% having per collection indices for record2D available can be helpful down
% the road, e.g to select touch and cursor traces per collection...
triallog_table = addvars(triallog_table, first_instance_of_collection_num_idx, 'NewVariableNames', 'collection_start_record2D_idx');
triallog_table = addvars(triallog_table, [first_instance_of_collection_num_idx(2:end)-1; size(record2D_table, 1)], 'NewVariableNames', 'collection_end_record2D_idx');


% columns to add (always for A0 and B1):
% REWARD
% new_triallog_table_column_stem_list = {'_RewPulses_TASK', '_RewPulses_MANUAL', '_RewTrain_Start_ts_s', '_RewTrain_adjStart_ts_s', '_RewTrain_End_ts_s'};
%	A0_reward_train_onset, A0_n_rewards_TASK, A0_n_rewards_MANUAL	% these
%	get created from jsonl_struct.reward_trains and are added later to the
%	existing triallog_table...


% AGENT

% we need to clean up a bit. by removing the aims when an agent is not
% touching
agent0_is_touching_ldx = record2D_table.agent0_is_touching == 1;
agent1_is_touching_ldx = record2D_table.agent1_is_touching == 1;
if (nan_out_invalid_aims_pos)
	% use nan as marker for invalid positions?
	record2D_table.aims0_X(~agent0_is_touching_ldx) = nan;
	record2D_table.aims0_Y(~agent0_is_touching_ldx) = nan;
	record2D_table.aims1_X(~agent1_is_touching_ldx) = nan;
	record2D_table.aims1_Y(~agent1_is_touching_ldx) = nan;
end
if (nan_out_invalid_agent_pos)
	% use nan as marker for invalid positions?
	record2D_table.agent0_X(~agent0_is_touching_ldx) = nan;
	record2D_table.agent0_Y(~agent0_is_touching_ldx) = nan;
	record2D_table.agent1_X(~agent1_is_touching_ldx) = nan;
	record2D_table.agent1_Y(~agent1_is_touching_ldx) = nan;
end

% also add columns for each target whether aims/agents are touching a
% target, this takes a while...
if ~isempty(target_radius) && (calc_and_store_distances_to_targets)
	timestamps.(mfilename).start_on_target = tic;
	for i_target_IDX = 1 : length(target_prefix_list)
		%disp(['Processing ', target_prefix_list{i_target_IDX}]);
		cur_target_stem = target_prefix_list{i_target_IDX};

		on_target_struct = [];
		cur_target_pos_XY_list = [record2D_table.([cur_target_stem, '_X'])(:), record2D_table.([cur_target_stem, '_Y'])(:)];
		
		cur_prefix_list = {'aims0', 'agent0', 'aims1', 'agent1'};
		for i_cur_prefix = 1 : length(cur_prefix_list)
			cur_prefix = cur_prefix_list{i_cur_prefix};
			cur_new_col_name = ['distance_', cur_prefix, '_to_', cur_target_stem];
			% if isempty(on_target_struct2) || ~isfield(on_target_struct2, cur_new_col_name)
			% 	on_target_struct2.(cur_new_col_name) = logical(zeros(size(record2D_table.timestamp)));
			% end
			cur_prefix_pos_XY_list = [record2D_table.([cur_prefix, '_X'])(:), record2D_table.([cur_prefix, '_Y'])(:)];
			record2D_table.(cur_new_col_name) = vecnorm((cur_target_pos_XY_list - cur_prefix_pos_XY_list), 2, 2);	% way faster than calling norm row by row...
			record2D_table.([cur_prefix, '_on_', cur_target_stem]) = record2D_table.(cur_new_col_name) < target_radius;
		end

		% this is too slow
		% on_target_struct = [];
		% for i_row = 1 : size(record2D_table, 1)
		% 	cur_target_pos_XY = [record2D_table.([cur_target_stem, '_X'])(i_row); record2D_table.([cur_target_stem, '_Y'])(i_row)];
		% 	cur_prefix_list = {'aims0', 'agent0', 'aims1', 'agent1'};
		% 
		% 	for i_cur_prefix = 1 : length(cur_prefix_list)
			% 	cur_prefix = cur_prefix_list{i_cur_prefix};
			% 	cur_new_col_name = ['distance_', cur_prefix, '_to_', cur_target_stem];
			% 	if isempty(on_target_struct) || ~isfield(on_target_struct, cur_new_col_name)
				% 	on_target_struct.(cur_new_col_name) = double(zeros(size(record2D_table.timestamp)));
			% 	end
			% 	cur_prefix_pos_XY = [record2D_table.([cur_prefix, '_X'])(i_row); record2D_table.([cur_prefix, '_Y'])(i_row)];
			% 	if ~isnan([cur_target_pos_XY; cur_prefix_pos_XY])
				% 	on_target_struct.(cur_new_col_name)(i_row) = norm(cur_target_pos_XY - cur_prefix_pos_XY);
			% 	else
				% 	on_target_struct.(cur_new_col_name)(i_row) = nan;
			% 	end
		% 	end
		% end
		% now add columns to record2D
		% new_col_names = fieldnames(on_target_struct);
		% for i_new_cols = 1 : length(new_col_names)
		% 	record2D_table.(new_col_names{i_new_cols}) = on_target_struct.(new_col_names{i_new_cols});
		% end
	end
	timestamps.(mfilename).end_on_target = toc(timestamps.(mfilename).start_on_target);
	disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end_on_target), ' seconds.']);
end


% Trial start stop ts
% we consider a trial from start of the final pre_acquisition phase (if any) to end
% of reward phase, so we have a resting position for the harvesting agent
% at the last target before the harvested target jumps to a different
% position, so we can tie this to the target state transitions except for
% the first trial where there is no pre_acquisition epoch...
% once we have that we can aggregate information within that

% we consider a trial from start of the final pre_acquisition phase to end
% of reward phase, so we have a resting position for the harvesting agent
% at the last target

% we look for targetstate transitions from pre_acquisition to
% waiting_for_agent or collecting, for all targets and then search back for
% the start of the respective agents final hold epoch for that target









% TARGETS
% since we have no target jsonl log (yet) we need to deduce this from the 2D
% table... which is less than ideal, but....
% add the target positions (X, Y) and whether target position changed from
% previous trial or was changed in current trial



% the numeral in targetN is the sequence number, this is fixed
target_IDX_list = nan(size(target_prefix_list));
target_id_list = target_IDX_list;
target_id_name_list = {};
for i_target_IDX = 1 : length(target_prefix_list)
	cur_tagetIDX = str2double(regexprep(target_prefix_list{i_target_IDX}, 'target', ''));
	target_IDX_list(i_target_IDX) = cur_tagetIDX;
	unique_target_id = unique(record2D_table.([target_prefix_list{i_target_IDX}, '_id']));
	if ~isempty(unique_target_id) && length(unique_target_id) < 2
		target_id_list(i_target_IDX) = unique_target_id;
		target_id_name_list(i_target_IDX) = enum_struct.target_id.name_list(find(enum_struct.target_id.value_list == cur_tagetIDX));
	end
	if ~isempty(unique_target_id) && length(unique_target_id) > 1
		%target_id_list(i_target_IDX) = unique_target_id;	% we can not
		%meaning fully merge numeric id
		target_id_name_list(i_target_IDX) = strjoin(enum_struct.target_id.name_list(find(enum_struct.target_id.value_list == cur_tagetIDX)), '_');	% but we can merge names...
	end
end


% this arguably should come from a jsonl file, but since we stored the
% states in record2D we can estimate the state transition times
% collect the target state transitions and colect indices and timestamps
target_state_change_struct = [];
for i_target_IDX = 1 : length(target_prefix_list)
	disp(['Processing ', target_prefix_list{i_target_IDX}]);
	cur_tagetIDX = str2double(regexprep(target_prefix_list{i_target_IDX}, 'target', ''));
	cur_col_name = [target_prefix_list{i_target_IDX}, '_target_state'];
	cur_data_col = record2D_table.(cur_col_name);
	% mark the record2D row indices where a change in state was manifest
	diffed_cur_data_col = [0; diff(cur_data_col)];
	% now loop over all changes here...
	cur_target_state_change_idx = find(diffed_cur_data_col ~= 0);	% can be positive and negative... as long as it is not 0
	for i_target_state_change_idx = 1 : length(cur_target_state_change_idx)
		cur_change_row_idx = cur_target_state_change_idx(i_target_state_change_idx);

		cur_target_state_change_struct.target_IDX = cur_tagetIDX;
		cur_target_state_change_struct.target_name = target_prefix_list{i_target_IDX};
		cur_target_state_change_struct.target_id_name = target_id_name_list{i_target_IDX};
		cur_target_state_change_struct.tick_timestamp = record2D_table.timestamp(cur_change_row_idx);
		cur_target_state_change_struct.tick_idx = cur_change_row_idx;
		% the previous state
		cur_target_state_change_struct.old_state_ENUM_idx = record2D_table.([target_prefix_list{i_target_IDX}, '_target_state'])(cur_change_row_idx - 1); % since cur_change_row_idx ist the row after a change, the previous row wioll show the old state
		cur_target_state_change_struct.old_state_ENUM_name = enum_struct.target_state.name_list(find(enum_struct.target_state.value_list == record2D_table.([target_prefix_list{i_target_IDX}, '_target_state'])(cur_change_row_idx - 1)));
		% the current state
		cur_target_state_change_struct.new_state_ENUM_idx = record2D_table.([target_prefix_list{i_target_IDX}, '_target_state'])(cur_change_row_idx);
		cur_target_state_change_struct.new_state_ENUM_name = enum_struct.target_state.name_list(find(enum_struct.target_state.value_list == record2D_table.([target_prefix_list{i_target_IDX}, '_target_state'])(cur_change_row_idx)));

		% also deduce whether agents/aims are on the target
		% note: AIM is the actual touch position while AGENT is the
		% position of the speed-limited cursor

		cur_target_pos_XY = [record2D_table.([target_prefix_list{i_target_IDX}, '_X'])(cur_change_row_idx); record2D_table.([target_prefix_list{i_target_IDX}, '_Y'])(cur_change_row_idx)];
		prev_target_pos_XY = [record2D_table.([target_prefix_list{i_target_IDX}, '_X'])(cur_change_row_idx - 1); record2D_table.([target_prefix_list{i_target_IDX}, '_Y'])(cur_change_row_idx - 1)];

		if norm(cur_target_pos_XY - prev_target_pos_XY) < 4 * eps
			cur_target_state_change_struct.target_position_changed = 0;
		else
			cur_target_state_change_struct.target_position_changed = 1;
		end


		if ~isempty(target_radius)
			cur_target_pos_XY = [record2D_table.([target_prefix_list{i_target_IDX}, '_X'])(cur_change_row_idx); record2D_table.([target_prefix_list{i_target_IDX}, '_Y'])(cur_change_row_idx)];
			cur_prefix_list =  {'aims0', 'agent0', 'aims1', 'agent1'};
			for i_cur_prefix = 1 : length(cur_prefix_list)
				cur_prefix = cur_prefix_list{i_cur_prefix};
				cur_prefix_pos_XY = [record2D_table.([cur_prefix, '_X'])(cur_change_row_idx); record2D_table.([cur_prefix, '_Y'])(cur_change_row_idx)];

				cur_target_state_change_struct.([cur_prefix, '_on_target']) = norm(cur_target_pos_XY - cur_prefix_pos_XY) < target_radius;
				% do not interpret aimso|1 when the respective agent is not
				% touching the screen...
				if (ismember(cur_prefix, {'aims0'}) &&  record2D_table.agent0_is_touching(cur_change_row_idx) == 0) || (ismember(cur_prefix, {'aims1'}) &&  record2D_table.agent1_is_touching(cur_change_row_idx) == 0)
					cur_target_state_change_struct.([cur_prefix, '_on_target']) = 0;
				end
				% in case we inherited a NaN from naned-out aims reset to
				% zer
				if isnan(cur_target_state_change_struct.([cur_prefix, '_on_target']))
					cur_target_state_change_struct.([cur_prefix, '_on_target']) = 0;
				end

				% also check for the previous tick
				prev_target_pos_XY = [record2D_table.([target_prefix_list{i_target_IDX}, '_X'])(cur_change_row_idx - 1); record2D_table.([target_prefix_list{i_target_IDX}, '_Y'])(cur_change_row_idx - 1)];
				prev_prefix_pos_XY = [record2D_table.([cur_prefix, '_X'])(cur_change_row_idx - 1); record2D_table.([cur_prefix, '_Y'])(cur_change_row_idx - 1)];
				cur_target_state_change_struct.(['prev_', cur_prefix, '_on_target']) = norm(prev_target_pos_XY - prev_prefix_pos_XY) < target_radius;
				% do not interpret aimso|1 when the respective agent is not
				% touching the screen...
				if (ismember(cur_prefix, {'aims0'}) &&  record2D_table.agent0_is_touching(cur_change_row_idx - 1) == 0) || (ismember(cur_prefix, {'aims1'}) &&  record2D_table.agent1_is_touching(cur_change_row_idx - 1) == 0)
					cur_target_state_change_struct.(['prev_', cur_prefix, '_on_target']) = 0;
				end
				% in case we inherited a NaN from naned-out aims reset to
				% zer
				if isnan(cur_target_state_change_struct.(['prev_', cur_prefix, '_on_target']))
					cur_target_state_change_struct.(['prev_', cur_prefix, '_on_target']) = 0;
				end

			end
		end

		if isempty(target_state_change_struct)
			target_state_change_struct = cur_target_state_change_struct;
		else
			target_state_change_struct = [target_state_change_struct, cur_target_state_change_struct];
		end
		clear cur_target_state_change_struct;
	end
end
target_state_transition_table = struct2table(target_state_change_struct, 'AsArray', 1);


[sorted_target_state_transition_table_tick_idx, sorted_target_state_transition_table_idx] = sort(target_state_transition_table.tick_idx, 'ascend');

sorted_target_state_transition_table = target_state_transition_table(sorted_target_state_transition_table_idx, :);


% now find the trial start and end information by hooking into the
% transitions from initiate_reward/rewarding
% trial start: successful pre_acquistion that triggers a position shuffle

target_position_changed_ldx = sorted_target_state_transition_table.target_position_changed == 1;	% almost certain no agent or aim is on target immediately after the repositioning
%tmp = sorted_target_state_transition_table(target_position_changed_ldx, :);	

% these are valid indicators of pre_acquisition being over that means this
% target was collected and reward was dispensed
pre_acquisition_end_transition_ldx = ismember(sorted_target_state_transition_table.old_state_ENUM_name, {'pre_acquisition'}) & ismember(sorted_target_state_transition_table.new_state_ENUM_name, {'waiting_for_agent'});

% for each pre_acquisition_end_transition 

% 
initiate_reward_start_transition_ldx = ismember(sorted_target_state_transition_table.old_state_ENUM_name, {'collecting'}) & ismember(sorted_target_state_transition_table.new_state_ENUM_name, {'initiate_reward'});



%	JOINT: target position_change_times, collected_target_type (JOINT or
%	SOLO)
%	A0_collected_target_id, A0_collected_target_IDX
%	A0_collected_target_position_X, A0_collected_target_position_Y
%	A0_collected_target_collecting_state_start_ts,
%	A0_collected_target_initiate_reward_state_start_ts,
%	A0_collected_target_rewarding_state_start_ts,
%	A0_collected_target_pre_acquisition_state_start_ts

% number and sequence of targets visited by each agent position of all
% targets per position



% for debugging
%triallog_table.collection_start_timestamp_s = triallog_table.collection_start_timestamp_s - start_ts;
%triallog_table.collection_end_timestamp_s = triallog_table.collection_end_timestamp_s - start_ts;


% PER TARGET information
% needs information from the TODO target_state_changes jsonl table

% PER AGENT information, like proximity sensor/effector hand positions
% needs information from the TODO agent_state_changes jsonl table
% also extract information from DI_sampling for the proximity sensors


% coordinates of final selected target


% REWARD information (per agent) corrected start of reward train by initial_delay_ms
% needs information from the reward jsonl table


timestamps.(mfilename).end = toc(timestamps.(mfilename).start);
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end), ' seconds.']);
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end / 60), ' minutes.']);
%disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end / (60 * 60)), ' hours.']);
%disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end / (60 * 60 * 24)), ' days. Done...']);


end

