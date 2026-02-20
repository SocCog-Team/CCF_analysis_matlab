function [ cur_output ] = fn_per_collection_2D_reach_and_fix_analysis( triallog_table, record2D_table,  conf_struct, enum_struct, fixations_AOS, reach_sources_list, gaze_sources_list, fixation_sources_list, plot_opts )
%FN_PER_COLLECTION_2D_REACH_AND_FIX_ANALYSIS Summary of this function goes here
%   Detailed explanation goes here
cur_output = [];
	
% loop over the trials and plot target positions and types (maybe add
% previous and nex target position as well
% add all members in reach_sources_list
record2D_colname_list = record2D_table.Properties.VariableNames;


% the number of aims in a run is not fixed, so detect it...
aim_prefix_list ={};
for i_col = 1 : length(record2D_colname_list)
	cur_col_name = record2D_colname_list{i_col};
	cur_aim_prefix_cell = regexp(cur_col_name, '^aims\d*', 'match');
	if ~isempty(cur_aim_prefix_cell)
		aim_prefix_list = [aim_prefix_list, cur_aim_prefix_cell{1}];
	end
end
aim_prefix_list = unique(aim_prefix_list);


% the number of agents in a run is not fixed, so detect it...
agent_prefix_list ={};
for i_col = 1 : length(record2D_colname_list)
	cur_col_name = record2D_colname_list{i_col};
	cur_agent_prefix_cell = regexp(cur_col_name, '^agent\d*', 'match');
	if ~isempty(cur_agent_prefix_cell)
		agent_prefix_list = [agent_prefix_list, cur_agent_prefix_cell{1}];
	end
end
agent_prefix_list = unique(agent_prefix_list);



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
	cur_col_end_tick_idx = triallog_table.col_targ_initiate_reward_tick_idx(i_collection);
	
	% get the target positions at cur_col_end_tick_idx
	




	cur_fh = figure('Name', ['Trial ', num2str(cur_trial_num)]);

	% TODO size the figure

	frame_h = plot([0, 0, 1, 1], [0, 1, 1, 0], 'Color', [0 0 0], 'LineWidth', 1.0);
	cur_ah = gca();
	axis(cur_ah, 'equal');
	axis(cur_ah, 'square');
	xticks(cur_ah, [0, 1]);	% remove
	yticks(cur_ah, [0, 1]);	% remove
	hold on

	% now add the targets
	for i_target_IDX = 1 : length(target_prefix_list)
		cur_target_prefix = target_prefix_list{i_target_IDX};
		cur_targetIDX = str2double(regexprep(target_prefix_list{i_target_IDX}, 'target', ''));

		cur_target_id = record2D_table.([cur_target_prefix, '_id'])(cur_col_end_tick_idx);
		cur_target_id_name = enum_struct.target_id.name_list{find(enum_struct.target_id.value_list == cur_target_id)};
		cur_color = color_struct.(cur_target_id_name);
		cur_radius = conf_struct.target_radius;
		cur_center =  [record2D_table.([cur_target_prefix, '_X'])(cur_col_end_tick_idx), record2D_table.([cur_target_prefix, '_Y'])(cur_col_end_tick_idx)];
		cur_rect_pos = [record2D_table.([cur_target_prefix, '_X'])(cur_col_end_tick_idx) - cur_radius, record2D_table.([cur_target_prefix, '_Y'])(cur_col_end_tick_idx) - cur_radius, 2 * cur_radius, 2 * cur_radius];

		cur_target_h = rectangle(cur_ah, 'Position', cur_rect_pos, 'Curvature', [1,1], 'FaceColor', cur_color, 'EdgeColor', [0 0 0]);
		daspect([1,1,1]);

	end






end	

end

