function [ triallog_table ] = fn_create_triallog_from_record2D( record2D_table, enum_struct )
%FN_CREATE_TRIALLOG_FROM_RECORD2D Summary of this function goes here
%   for collection and alignment event selection having a two table is
%   pretty conveniebt, so construct one here


triallog_table = [];


start_ts = record2D_table.timestamp(1);

[unique_collection_list, first_instance_of_collection_num_idx, unique_collection_list_row_idx] = unique(record2D_table.n_finished_collections);
n_collections = length(unique_collection_list);

% build a table with relevant per collection/trial information
% COLLECTION NUMBER
triallog_table = array2table(unique_collection_list, 'VariableNames', {'collection_num'});
triallog_table = addvars(triallog_table, (unique_collection_list + 1), 'NewVariableNames', 'trial_num');	% make this 1-based and abstract from the fact that the collection number increases between collection end and reward state


% COLLECTION START / END
triallog_table = addvars(triallog_table, record2D_table.timestamp(first_instance_of_collection_num_idx), 'NewVariableNames', 'collection_start_timestamp_s');
triallog_table = addvars(triallog_table, record2D_table.timestamp([first_instance_of_collection_num_idx(2:end)-1; size(record2D_table, 1)]), 'NewVariableNames', 'collection_end_timestamp_s');
% having per collection indices for record2D available can be helpful down
% the road, e.g to select touch and cursor traces per collection...
triallog_table = addvars(triallog_table, first_instance_of_collection_num_idx, 'NewVariableNames', 'collection_start_record2D_idx');
triallog_table = addvars(triallog_table, [first_instance_of_collection_num_idx(2:end)-1; size(record2D_table, 1)], 'NewVariableNames', 'collection_end_record2D_idx');


% columns to add (always for A0 and B1):
%	A0_reward_train_onset, A0_n_rewards_TASK, A0_n_rewards_MANUAL	% these
%
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



end

