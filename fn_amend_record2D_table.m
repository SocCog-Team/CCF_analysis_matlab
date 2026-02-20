function [ record2D_table, fixations_struct ] = fn_amend_record2D_table( record2D_table, conf_struct, request_list, max_dispersion_threshold, min_fixation_duration_threshold_ms )
%FN_AMEND_RECORD2D_TABLE Summary of this function goes here
%   Detailed explanation goes here

nan_out_invalid_aims_pos = 1;
nan_out_invalid_agent_pos = 1;
detect_agent_fixations = 1;
detect_aim_fixations = 1;

isDraw = 1;
debug = 0;

fixations_struct = [];



% what to do here?
if ~exist('request_list', 'var') || isempty(request_list)
	request_list = {'nan_out_invalid_aims_pos', 'nan_out_invalid_agent_pos', ...
		'calc_and_store_distances_to_targets', ...
		'add_per_target_changed_pos_col', ...
		'detect_agent_fixations', 'detect_aim_fixations'};
end


% for the fixation detector...
isDraw = 0;
if ~exist('max_dispersion_threshold', 'var') || isempty(max_dispersion_threshold)
	max_dispersion_threshold = conf_struct.target_radius/2; % 
end
if ~exist('min_fixation_duration_threshold_ms', 'var') || isempty(min_fixation_duration_threshold_ms)
	min_fixation_duration_threshold_ms = 100; 
end



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



% FIXUP record2D_table

% this should be uncondional as it fixes
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
	disp([mfilename, ': WARN: target_IDX column incorrect, fixing in place... should only happen in early sessions']);
	% some early record2D files have incorrect cur_target_IDX values (all 1s)
	for i_target_IDX = 1 : length(target_prefix_list)
		cur_targetIDX = str2double(regexprep(target_prefix_list{i_target_IDX}, 'target', ''));
		cur_col_name = [target_prefix_list{i_target_IDX}, '_cur_target_IDX'];
		record2D_table.(cur_col_name)(:) = cur_targetIDX;
	end
end






% we need to clean up a bit. by removing the aims when an agent is not
% touching
agent0_is_touching_ldx = record2D_table.agent0_is_touching == 1;
agent1_is_touching_ldx = record2D_table.agent1_is_touching == 1;
if ismember({'nan_out_invalid_aims_pos'}, request_list)
	% use nan as marker for invalid positions?
	record2D_table.aims0_X(~agent0_is_touching_ldx) = nan;
	record2D_table.aims0_Y(~agent0_is_touching_ldx) = nan;
	record2D_table.aims1_X(~agent1_is_touching_ldx) = nan;
	record2D_table.aims1_Y(~agent1_is_touching_ldx) = nan;
end
if ismember({'nan_out_invalid_agent_pos'}, request_list)
	% use nan as marker for invalid positions?
	record2D_table.agent0_X(~agent0_is_touching_ldx) = nan;
	record2D_table.agent0_Y(~agent0_is_touching_ldx) = nan;
	record2D_table.agent1_X(~agent1_is_touching_ldx) = nan;
	record2D_table.agent1_Y(~agent1_is_touching_ldx) = nan;
end


% also add columns for each target whether aims/agents are touching a
% target, this takes a while...

if isfield(conf_struct, 'target_radius')
	target_radius = conf_struct.target_radius;
else
	target_radius = [];
end

if ~isempty(target_radius) && ismember({'calc_and_store_distances_to_targets'}, request_list)
	%timestamps.(mfilename).start_on_target = tic;
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
	%timestamps.(mfilename).end_on_target = toc(timestamps.(mfilename).start_on_target);
	%disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end_on_target), ' seconds.']);
end



if ismember({'add_per_target_changed_pos_col'}, request_list)
	% we need this unconditionally
	for i_target_IDX = 1 : length(target_prefix_list)
		cur_targetIDX = str2double(regexprep(target_prefix_list{i_target_IDX}, 'target', ''));
		cur_target_prefix = target_prefix_list{i_target_IDX};
		cur_col_name_stem = [target_prefix_list{i_target_IDX}, '_collecting_by_'];

		% add the target change detection here, as we really only need these later on to compile per trial information
		cur_new_col_name = [cur_target_prefix, '_changed_pos'];
		cur_target_pos_XY_list = [record2D_table.([cur_target_prefix, '_X'])(:), record2D_table.([cur_target_prefix, '_Y'])(:)];
		% get the distance betwenn samples
		cur_sample_by_sample_distance = [1 ; vecnorm((cur_target_pos_XY_list(2:end, :) - cur_target_pos_XY_list(1:end-1, :)), 2, 2)]; % way faster than calling norm row by row...
		record2D_table.(cur_new_col_name) = cur_sample_by_sample_distance ~= 0;
	end
end




% now run the fixation detector
if ismember({'detect_aim_fixations'}, request_list)
	for i_aim = 1 : length(aim_prefix_list)
		cur_aim = aim_prefix_list{i_aim};
		cur_data_struct_of_arr.timestamp = record2D_table.timestamp * 1000;	% we want milliseconds
		cur_data_struct_of_arr.X = record2D_table.([cur_aim, '_X']);
		cur_data_struct_of_arr.Y = record2D_table.([cur_aim, '_Y']);
		% local override
		% max_dispersion_threshold = conf_struct.target_radius/2; 
		% min_fixation_duration_threshold_ms = 100;
		% isDraw = 1;
		cur_fixation_struct = fn_spatial_dispersion_fixation_detector(cur_data_struct_of_arr, max_dispersion_threshold, min_fixation_duration_threshold_ms, isDraw);
		record2D_table.([cur_aim, '_per_sample_fixID']) = cur_fixation_struct.per_sample_fixID;
		cur_fixation_struct = rmfield(cur_fixation_struct, 'per_sample_fixID');	% we move this into record2D already...
		fixations_struct.(cur_aim) = cur_fixation_struct;
		if (debug)
			cur_fh = figure('Name', cur_aim);
			plot(cur_fixation_struct.mean_X, cur_fixation_struct.mean_Y, 'LineWidth', 0.5, 'Marker', 'o');
			cur_ah = gca();
			axis equal
			axis square
		end
	end
end

if ismember({'detect_agent_fixations'}, request_list)
	for i_agent = 1 : length(agent_prefix_list)
		cur_agent = agent_prefix_list{i_agent};
		cur_data_struct_of_arr.timestamp = record2D_table.timestamp * 1000;	% we want milliseconds
		cur_data_struct_of_arr.X = record2D_table.([cur_agent, '_X']);
		cur_data_struct_of_arr.Y = record2D_table.([cur_agent, '_Y']);
		% local override
		% max_dispersion_threshold = conf_struct.target_radius/2; 
		% min_fixation_duration_threshold_ms = 100;
		% isDraw = 1;		
		cur_fixation_struct = fn_spatial_dispersion_fixation_detector(cur_data_struct_of_arr, max_dispersion_threshold, min_fixation_duration_threshold_ms, isDraw);
		record2D_table.([cur_agent, '_per_sample_fixID']) = cur_fixation_struct.per_sample_fixID;
		cur_fixation_struct = rmfield(cur_fixation_struct, 'per_sample_fixID');	% we move this into record2D already...
		fixations_struct.(cur_agent) = cur_fixation_struct;
		if (debug)
			cur_fh = figure('Name', cur_agent);
			plot(cur_fixation_struct.mean_X, cur_fixation_struct.mean_Y, 'LineWidth', 0.5, 'Marker', 'o');
			cur_ah = gca();
			axis equal
			axis square
		end
	end
end



end

