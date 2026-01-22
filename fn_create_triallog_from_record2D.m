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

% FIXUP record2D_table

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
	end
	timestamps.(mfilename).end_on_target = toc(timestamps.(mfilename).start_on_target);
	%disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end_on_target), ' seconds.']);
end

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
	unique_target_IDX = unique(record2D_table.([target_prefix_list{i_target_IDX}, '_id']));
	if ~isempty(unique_target_IDX) && length(unique_target_IDX) < 2
		target_id_list(i_target_IDX) = unique_target_IDX;
		% target_id can change for special targets, so we need to extract
		% that trial by trial...
		cur_target_IDX_unique_target_id_list = unique(record2D_table.(['target', num2str(cur_tagetIDX), '_id']));
		target_id_name_list(i_target_IDX) = enum_struct.target_id.name_list(find(enum_struct.target_id.value_list == cur_target_IDX_unique_target_id_list));
	end
	if ~isempty(unique_target_IDX) && length(unique_target_IDX) > 1
		%target_id_list(i_target_IDX) = unique_target_id;	% we can not
		%meaning fully merge numeric id
		target_id_name_list(i_target_IDX) = strjoin(enum_struct.target_id.name_list(find(enum_struct.target_id.value_list == cur_target_IDX_unique_target_id_list)), '_');	% but we can merge names...
	end
end


% find *_cur_target_IDX and check whether these are wrong (that is do not match the target)
MATCH_cur_target_IDX_idx = find(contains(record2D_colname_list, ["target" + digitsPattern + "_cur_target_IDX"]));
cur_target_IDX_cols_need_fixup = 0;
for i_match_col = 1 : length(MATCH_cur_target_IDX_idx)
	cur_last_cur_target_IDX_value = record2D_table.(record2D_colname_list{MATCH_cur_target_IDX_idx(i_match_col)})(1);
	if cur_last_cur_target_IDX_value ~= (i_match_col - 1)
		cur_target_IDX_cols_need_fixup = 1;
		break
	end
end

if (cur_target_IDX_cols_need_fixup)
	% some early record2D files have incorrect cur_target_IDX values (all 1s)
	for i_target_IDX = 1 : length(target_prefix_list)
		cur_tagetIDX = str2double(regexprep(target_prefix_list{i_target_IDX}, 'target', ''));
		cur_col_name = [target_prefix_list{i_target_IDX}, '_cur_target_IDX'];
		record2D_table.(cur_col_name)(:) = cur_tagetIDX;
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
		% we do have targets that can change the id every other trial so
		% collect the curent id for each state transition
		cur_target_id = record2D_table.(['target', num2str(cur_tagetIDX), '_id'])(cur_change_row_idx);
		target_id_name_cell = enum_struct.target_id.name_list(find(enum_struct.target_id.value_list == cur_target_id));
		cur_target_state_change_struct.target_id = cur_target_id;
		cur_target_state_change_struct.target_id_name = target_id_name_cell{1};

		cur_target_state_change_struct.tick_timestamp = record2D_table.timestamp(cur_change_row_idx);
		cur_target_state_change_struct.tick_idx = cur_change_row_idx;
		% the previous state
		cur_target_state_change_struct.old_state_ENUM_idx = record2D_table.([target_prefix_list{i_target_IDX}, '_target_state'])(cur_change_row_idx - 1); % since cur_change_row_idx ist the row after a change, the previous row will show the old state
		cur_target_state_change_struct.old_state_ENUM_name = enum_struct.target_state.name_list(find(enum_struct.target_state.value_list == record2D_table.([target_prefix_list{i_target_IDX}, '_target_state'])(cur_change_row_idx - 1)));
		% the current state
		cur_target_state_change_struct.new_state_ENUM_idx = record2D_table.([target_prefix_list{i_target_IDX}, '_target_state'])(cur_change_row_idx);
		cur_target_state_change_struct.new_state_ENUM_name = enum_struct.target_state.name_list(find(enum_struct.target_state.value_list == record2D_table.([target_prefix_list{i_target_IDX}, '_target_state'])(cur_change_row_idx)));

		cur_target_state_change_struct.cur_collection_num = record2D_table.n_finished_collections(cur_change_row_idx);	% we want these to map to trials...

		% also deduce whether agents/aims are on the target
		% note: AIM is the actual touch position while AGENT is the
		% position of the speed-limited cursor

		cur_target_pos_XY = [record2D_table.([target_prefix_list{i_target_IDX}, '_X'])(cur_change_row_idx); record2D_table.([target_prefix_list{i_target_IDX}, '_Y'])(cur_change_row_idx)];
		prev_target_pos_XY = [record2D_table.([target_prefix_list{i_target_IDX}, '_X'])(cur_change_row_idx - 1); record2D_table.([target_prefix_list{i_target_IDX}, '_Y'])(cur_change_row_idx - 1)];

		cur_target_state_change_struct.cur_target_pos_XY = cur_target_pos_XY;
		cur_target_state_change_struct.prev_tick_target_pos_XY = prev_target_pos_XY;

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

target_position_changed_ldx = sorted_target_state_transition_table.target_position_changed == 1;	% almost certain no agent or aim is on target immediately after the repositioning but note this is the the logical change of target position for actual changes look at the PDD train onsets
%tmp = sorted_target_state_transition_table(target_position_changed_ldx, :);	

% these are valid indicators of pre_acquisition being over that means this
% target was collected and reward was dispensed
pre_acquisition_end_transition_ldx = ismember(sorted_target_state_transition_table.old_state_ENUM_name, {'pre_acquisition'}) & ismember(sorted_target_state_transition_table.new_state_ENUM_name, {'waiting_for_agent'});

% we can look at the target_id_name to figure out which agents where
% involved

% for each pre_acquisition_end_transition 

% this should catch one inituiate reward for all collection periods except
% the last
% this is when reward magnitudes are assiigned to so we can look into the record2D trow to figure out which agent was rewarded (two agents can be on a comp target but only one will get rewarded and we want to know who...) 
initiate_reward_start_transition_ldx = ismember(sorted_target_state_transition_table.old_state_ENUM_name, {'collecting'}) & ismember(sorted_target_state_transition_table.new_state_ENUM_name, {'initiate_reward'});
initiate_reward_start_transition_idx = find(initiate_reward_start_transition_ldx);


% pre allocate a few columns, pre allocate as NaN so unassigned trial
% values are standing out
triallog_table.collected_target_IDX = nan(size(triallog_table.collection_num));
triallog_table.collected_target_id = nan(size(triallog_table.collection_num));
triallog_table.collected_target_id_name = cell(size(triallog_table.collection_num));
triallog_table.collected_target_position_XY = nan([size(triallog_table.collection_num, 1), 2]);

% this need some finesse to cover a meaningfull period
triallog_table.trial_start_timestamp_s = nan(size(triallog_table.collection_num));
triallog_table.trial_end_timestamp_s = nan(size(triallog_table.collection_num));
triallog_table.trial_start_tick_idx = nan(size(triallog_table.collection_num));
triallog_table.trial_end_tick_idx = nan(size(triallog_table.collection_num));

triallog_table.collected_by_A = nan(size(triallog_table.collection_num));
triallog_table.collected_by_B = nan(size(triallog_table.collection_num));
triallog_table.collection_type = cell(size(triallog_table.collection_num));

triallog_table.Reward_A = nan(size(triallog_table.collection_num));
triallog_table.Reward_B = nan(size(triallog_table.collection_num));

% first is NONE and that should not exist
for i_target_states = 2 : length(enum_struct.target_state.name_list)
	cur_target_state_name = enum_struct.target_state.name_list{i_target_states};
	triallog_table.(['collected_target_', cur_target_state_name, '_start_s']) = nan(size(triallog_table.collection_num));
	triallog_table.(['collected_target_', cur_target_state_name, '_tick_idx']) = nan(size(triallog_table.collection_num));
end


% this is the rewarded target (as only that will be in initiate_reward state), so we can make a few assumptions
for i_initiate_reward_start_transition = 1 : length(initiate_reward_start_transition_idx)
	cur_initiate_reward_start_transition_idx = initiate_reward_start_transition_idx(i_initiate_reward_start_transition);

	sorted_target_state_transition_table(cur_initiate_reward_start_transition_idx, :)
	cur_collection_num = sorted_target_state_transition_table.cur_collection_num(cur_initiate_reward_start_transition_idx);
	
	% get the true index into the triallog table
	cur_trial_num = cur_collection_num; % initiate_reward happens after the co;llection counter is increased, and that starts with zero
	if ~(cur_trial_num == i_initiate_reward_start_transition)
		disp('Should this happen? Please, investigate...');
		keyboard
	end

	cur_target_IDX = sorted_target_state_transition_table.target_IDX(cur_initiate_reward_start_transition_idx);
	triallog_table.collected_target_IDX(cur_trial_num) = cur_target_IDX;
	triallog_table.collected_target_id(cur_trial_num) = sorted_target_state_transition_table.target_id(cur_initiate_reward_start_transition_idx);

	cur_record2D_idx = sorted_target_state_transition_table.tick_idx(cur_initiate_reward_start_transition_idx);
	cur_targetid_name = sorted_target_state_transition_table.target_id_name{i_initiate_reward_start_transition};
	triallog_table.collected_target_id_name(cur_trial_num) = {cur_targetid_name};

	% the collected target position
	triallog_table.collected_target_position_XY(cur_trial_num, :) = sorted_target_state_transition_table.cur_target_pos_XY{cur_initiate_reward_start_transition_idx};


	% add the timestamps and record2D_idx for all state transitions of the
	% collected target

	% target_state 1 is NONE...
	for i_target_states = 2 : length(enum_struct.target_state.name_list)
		cur_target_state_name = enum_struct.target_state.name_list{i_target_states};

		%collecting and wait_for_agent can repeat, so only pick the last



		triallog_table.(['collected_target_', cur_target_state_name, '_start_s'])(cur_trial_num)
		triallog_table.(['collected_target_', cur_target_state_name, '_tick_idx'])(cur_trial_num)
	end




	% these can be used as a heuristic to deduce which agent was
	% collecting, but ideally the record2D table should add this
	% information explicitly, as both agents can hold the same position
	% ansd still only one might be meaningfully collecting...
	% however competitive_targets and punishing_targets currently only
	% apply to the collecting agent

	% this comes from the target definitions for the collected target, so
	% should be correct until we introduce the changing cooperative target
	% again
	triallog_table.Reward_A(cur_trial_num) = record2D_table.(['target', num2str(cur_target_IDX), '_rewA0'])(cur_record2D_idx);
	triallog_table.Reward_B(cur_trial_num) = record2D_table.(['target', num2str(cur_target_IDX), '_rewB1'])(cur_record2D_idx);

	

	switch cur_targetid_name
		case {'cooperative_targets_type_0', 'cooperative_targets_type_1'}
			triallog_table.collection_type(cur_trial_num) = {'joint'};
			triallog_table.collected_by_A(cur_trial_num) = 1;
			triallog_table.collected_by_B(cur_trial_num) = 1;

		case {'competitive_targets', 'punishing_targets'}
			triallog_table.collection_type(cur_trial_num) = {'single'};
			% figure out the collecting agent, this is ambiguous
			if (triallog_table.Reward_A(cur_trial_num) > 0) && (triallog_table.Reward_B(cur_trial_num) == 0)
				triallog_table.collected_by_A(cur_trial_num) = 1;
				triallog_table.collected_by_B(cur_trial_num) = 0;
			elseif (triallog_table.Reward_A(cur_trial_num) == 0) && (triallog_table.Reward_B(cur_trial_num) > 0)
				triallog_table.collected_by_A(cur_trial_num) = 0;
				triallog_table.collected_by_B(cur_trial_num) = 1;
			else
				error([mfilename, ': this is not supposed to happen, please investigate...']);
			end

		case {'solo_targets_type_0'}
			triallog_table.collection_type(cur_trial_num) = {'solo_0'};
			triallog_table.collected_by_A(cur_trial_num) = 1;
			triallog_table.collected_by_B(cur_trial_num) = 0;

		case {'solo_targets_type_1'}
			triallog_table.collection_type(cur_trial_num) = {'solo_1'};
			triallog_table.collected_by_A(cur_trial_num) = 0;
			triallog_table.collected_by_B(cur_trial_num) = 1;
	end

	% find the previous pre_acquisition start if it exists (is missing for the first trial) 
	% trial_start_timestamp_s
	cur_transition_search_idx = cur_initiate_reward_start_transition_idx;
	while true
		cur_transition_search_idx = cur_transition_search_idx - 1;
		%check whether we reached the begining
		if cur_transition_srearch_idx == 0
			% use the first timestamp, or nan?
			triallog_table.trial_start_timestamp_s(cur_trial_num) = record2D_table.timestamp(1);
			triallog_table.trial_start_tick_idx(cur_trial_num) = 1;
			break
		end
		% we are looking for the previous pre_acquisition to end
		if 	(contains(sorted_target_state_transition_table.old_state_ENUM_name(cur_transition_search_idx), 'pre_acquisition') && contains(sorted_target_state_transition_table.new_state_ENUM_name(cur_transition_search_idx), 'waiting_for_agent'))

			triallog_table.trial_start_timestamp_s(cur_trial_num) = sorted_target_state_transition_table.tick_timestamp(cur_transition_search_idx);
			triallog_table.trial_start_tick_idx(cur_trial_num) = sorted_target_state_transition_table.tick_idx(cur_transition_search_idx);
			break
		end
	end

	% currently trial_end_timestamp_s(N) equals
	% trial_start_timestamp_s(N+1), that is we have no 
	% find the end of the current reward phase
	%trial_end_timestamp_s
	cur_transition_search_idx = cur_initiate_reward_start_transition_idx;
	while true
		cur_transition_search_idx = cur_transition_search_idx + 1;
		%check whether we reached the end
		if cur_transition_srearch_idx > size(sorted_target_state_transition_table, 1)
			% use the first timestamp, or nan?
			triallog_table.trial_end_timestamp_s(cur_trial_num) = record2D_table.timestamp(end);
			triallog_table.trial_end_tick_idx(cur_trial_num) = size(record2D_table, 1);
			break
		end
		% we want a specific transition for the current IDX
		if (sorted_target_state_transition_table.collected_target_IDX(cur_transition_search_idx) == sorted_target_state_transition_table.collected_target_IDX(cur_initiate_reward_start_transition_idx)) ...
			&& (contains(sorted_target_state_transition_table.old_state_ENUM_name(cur_transition_search_idx), 'rewarding') && contains(sorted_target_state_transition_table.new_state_ENUM_name(cur_transition_search_idx), 'pre_acquisition'))
			triallog_table.trial_end_timestamp_s(cur_trial_num) = sorted_target_state_transition_table.tick_timestamp(cur_transition_search_idx);
			triallog_table.trial_end_tick_idx(cur_trial_num) = sorted_target_state_transition_table.tick_idx(cur_transition_search_idx);
			break
		end
	end






end
%triallog_table


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

