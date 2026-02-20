function [ cur_output ] = fn_per_collection_2D_reach_and_fix_analysis( triallog_table, record2D_table,  conf_struct, enum_struct, fixations_AOS, reach_sources_list, gaze_sources_list, fixation_sources_list, plot_opts )
%FN_PER_COLLECTION_2D_REACH_AND_FIX_ANALYSIS Summary of this function goes here
%   Detailed explanation goes here
cur_output = [];
	
% loop over the trials and plot target positions and types (maybe add
% previous and nex target position as well
% add all members in reach_sources_list
record2D_colname_list = record2D_table.Properties.VariableNames;
triallog_colname_list = triallog_table.Properties.VariableNames;

% constant parameters
final_pre_acquisition_epock_n_ticks = floor(conf_struct.pre_acquisition_time_s *  conf_struct.updates_ps);

collected_target_types = triallog_table.col_targ_id_name

color_struct.competitive_targets = [1 1 1];		% white
color_struct.cooperative_targets_type_0 = [250, 114 44]/255;	% orange
color_struct.cooperative_targets_type_1 = [87, 117, 189]/255;	% blue




n_collections = size(triallog_table, 1);
for i_collection = 1 : n_collections
	cur_collection_num = triallog_table.collection_num(i_collection);
	cur_trial_num = triallog_table.trial_num(i_collection);
	

	% trial start: pre_acquisition perdiod before target appears (taken from photodiode)
	% instead we could take trial_start_tick_idx whic is the transitiomn
	% from pre_acquisition to waiting_for_agent, but that is not well
	% synchronized to the actual target position change, while
	% PDD_onset_tick_idx is
	cur_col_start_tick_idx = triallog_table.PDD_onset_tick_idx(i_collection) - final_pre_acquisition_epock_n_ticks;
	cur_col_start_tick_idx = max([1, cur_col_start_tick_idx]);	% make sue the index starts at the beginning

	% end this with the end of the collection when we initiate the reward
	cur_col_end_tick_idx = triallog_table.col_targ_initiate_reward_tick_idx;
	
	% get the target positions at cur_col_end_tick_idx




	cur_fh = figure('Name', ['Trial ', num2str(cur_trial_num)]);

	% TODO size the figure










end	

end

