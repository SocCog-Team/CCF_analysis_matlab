function [ record2D_table ] = fn_amend_record2D_table( record2D_table, conf_struct )
%FN_AMEND_RECORD2D_TABLE Summary of this function goes here
%   Detailed explanation goes here

nan_out_invalid_aims_pos = 1;
nan_out_invalid_agent_pos = 1;
detect_agent_fixations = 1;
detect_aim_fixations = 1;


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


% the number of aims in a run is not fixed, so detect it...
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

% now run the fixation detector

if (detect_agent_fixations)
	for i_aim = 1 : length(aim_prefix_list)
		cur_aim = aim_prefix_list{i_aim};
		cur_data_struct_of_arr.timestamp = record2D_table.timestamp * 1000;	% we want milliseconds
		cur_data_struct_of_arr.X = record2D_table.([cur_aim, '_X']);
		cur_data_struct_of_arr.Y = record2D_table.([cur_aim, '_Y']);

 [ fixation ] = fn_spatial_dispersion_fixation_detector(data_struct_of_arr, max_dispersion_threshold, min_fixation_duration_threshold_ms, isDraw)
	end

end



end

