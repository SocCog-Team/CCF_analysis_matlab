function [ record2D_table, fixations_struct ] = fn_amend_record2D_table( record2D_table, conf_struct, request_list, max_dispersion_threshold, min_fixation_duration_threshold_ms, GAZE_OPTS_struct )
%FN_AMEND_RECORD2D_TABLE Summary of this function goes here
%   Detailed explanation goes here

nan_out_invalid_aims_pos = 1;
nan_out_invalid_agent_pos = 1;
detect_agent_fixations = 1;
detect_aim_fixations = 1;

isDraw = 1;
debug = 0;

fixations_struct = [];


timestamps.(mfilename).start = tic;


% what to do here?
if ~exist('request_list', 'var') || isempty(request_list)
	request_list = {'nan_out_invalid_aims_pos', 'nan_out_invalid_agent_pos', ...
		'calc_and_store_distances_to_targets', ...
		'add_per_target_changed_pos_col', ...
		...'detect_agent_fixations', 'detect_aim_fixations', ...
		'detect_eye_fixations', ...	% needs fixing
		'calc_and_store_gaze_distance_to_face_region', ...
		'calc_and_store_gaze_distance_to_agents', ...
		'calc_and_store_gaze_distance_to_aims', ...
		};

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
agent_prefix_list = {};
for i_col = 1 : length(record2D_colname_list)
	cur_col_name = record2D_colname_list{i_col};
	cur_agent_prefix_cell = regexp(cur_col_name, '^agent\d*', 'match');
	if ~isempty(cur_agent_prefix_cell)
		agent_prefix_list = [agent_prefix_list, cur_agent_prefix_cell{1}];
	end
end
agent_prefix_list = unique(agent_prefix_list);



% the number of targets in a run is not fixed, so detect it...
target_prefix_list = {};
for i_col = 1 : length(record2D_colname_list)
	cur_col_name = record2D_colname_list{i_col};
	cur_target_prefix_cell = regexp(cur_col_name, '^target\d*', 'match');
	if ~isempty(cur_target_prefix_cell)
		target_prefix_list = [target_prefix_list, cur_target_prefix_cell{1}];
	end
end
target_prefix_list = unique(target_prefix_list);


% the number of targets in a run is not fixed, so detect it...
eye_prefix_list = {};
for i_col = 1 : length(record2D_colname_list)
	cur_col_name = record2D_colname_list{i_col};
	cur_eye_prefix_cell = regexp(cur_col_name, '^[A|B]_(right|left|binocular)_eye', 'match');
	if ~isempty(cur_eye_prefix_cell)
		eye_prefix_list = [eye_prefix_list, cur_eye_prefix_cell{1}];
	end
end
eye_prefix_list = unique(eye_prefix_list);




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
	disp([mfilename, ': INFO: Processing requested nan_out_invalid_aims_pos']);
	% use nan as marker for invalid positions?
	record2D_table.aims0_X(~agent0_is_touching_ldx) = nan;
	record2D_table.aims0_Y(~agent0_is_touching_ldx) = nan;
	record2D_table.aims1_X(~agent1_is_touching_ldx) = nan;
	record2D_table.aims1_Y(~agent1_is_touching_ldx) = nan;
end
if ismember({'nan_out_invalid_agent_pos'}, request_list)
	disp([mfilename, ': INFO: Processing requested nan_out_invalid_agent_pos']);
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
	disp([mfilename, ': INFO: Processing requested calc_and_store_distances_to_targets']);

	%timestamps.(mfilename).start_on_target = tic;
	for i_target_IDX = 1 : length(target_prefix_list)
		%disp(['Processing ', target_prefix_list{i_target_IDX}]);
		cur_target_stem = target_prefix_list{i_target_IDX};

		cur_target_pos_XY_list = [record2D_table.([cur_target_stem, '_X'])(:), record2D_table.([cur_target_stem, '_Y'])(:)];
		%cur_prefix_list = {'aims0', 'agent0', 'aims1', 'agent1'};
		cur_prefix_list = [aim_prefix_list, agent_prefix_list, eye_prefix_list];
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


% we want also additional face positions... left and right shifted, as well
% as center down-flipped
if ~isempty(target_radius) && ismember({'calc_and_store_gaze_distance_to_face_region'}, request_list)
	disp([mfilename, ': INFO: Processing requested calc_and_store_gaze_distance_to_face_region']);

	% face center coordinates should be independent of species and side, if
	% both agents are well aligned
	face_center_x_pixel = GAZE_OPTS_struct.HP.A.x_screen_intereye_pix;
	face_center_y_pixel = GAZE_OPTS_struct.HP.A.y_screen_clostest2eye_pix;	% Note this is in EventIDE pixel coordinates, which are y-flipped compared to CCF's, so are gaze pixel coordinates

	% check the gaze sources
	valid_gaze_data_column_idx = contains(record2D_colname_list, regexpPattern('^[A|B]_(left|right|binocular)_eye_[X|Y]+'));
	valid_gaze_data_column_names = record2D_colname_list(valid_gaze_data_column_idx);

	% get rid of the Y...
	valid_gaze_source_stem_names = unique(regexprep(valid_gaze_data_column_names, '_[X|Y]', '_X'));


	% we want eventually feed in a struct of list for relevant positions,
	% for now define this here...
	ROI_center_name_list = {'facecenter', 'face_left', 'face_right'};
	ROI_center_unit_list = {'pixel', 'pixel', 'pixel'};	% so we now how to convert these...
	% here we just construct these...
	field_width = conf_struct.field_size;
	ROI_center_X_list = [GAZE_OPTS_struct.HP.A.x_screen_intereye_pix, (GAZE_OPTS_struct.HP.A.x_screen_intereye_pix - 0.5*field_width*2/3), (GAZE_OPTS_struct.HP.A.x_screen_intereye_pix + 0.5*field_width*2/3)];
	ROI_center_Y_list = [GAZE_OPTS_struct.HP.A.y_screen_clostest2eye_pix, GAZE_OPTS_struct.HP.A.y_screen_clostest2eye_pix, GAZE_OPTS_struct.HP.A.y_screen_clostest2eye_pix];

	for i_ROI = 1 : length(ROI_center_name_list)
		cur_ROI_name = ROI_center_name_list{i_ROI};
		cur_ROI_unit = ROI_center_unit_list{i_ROI};
		cur_ROI_center_X = ROI_center_X_list(i_ROI);
		cur_ROI_center_Y = ROI_center_Y_list(i_ROI);

		switch cur_ROI_unit
			case 'CCF'
				[cur_ROI_center_X_pixel, cur_ROI_center_Y_pixel] = fn_CCF_win_to_engine_pos(cur_ROI_center_X, cur_ROI_center_Y, conf_struct.field_size, conf_struct.target_radius, conf_struct.field_x_offset, conf_struct.field_y_offset);
				cur_ROI_center_Y_pixel = (conf_struct.screen_height_pixel - cur_ROI_center_Y_pixel);	% we need EventIDE convention here, not CCF/python...
				cur_ROI_center_X_CCF = cur_ROI_center_X;
				cur_ROI_center_Y_CCF = cur_ROI_center_Y;
			case 'pixel'
				% we expect pixel space later below, so just force it here
				cur_ROI_center_X_pixel = cur_ROI_center_X;
				cur_ROI_center_Y_pixel = cur_ROI_center_Y;
				[cur_ROI_center_X_CCF, cur_ROI_center_Y_CCF] = fn_CCF_engine_to_win_pos(cur_ROI_center_X_pixel, (conf_struct.screen_height_pixel - cur_ROI_center_Y_pixel), conf_struct.field_size, conf_struct.target_radius, conf_struct.field_x_offset, conf_struct.field_y_offset);

		otherwise
			error([mfilename, ': ERROR: unhandled ROI unit: ', cur_ROI_unit]);
		end

		for i_valid_gaze_stem = 1 : length(valid_gaze_source_stem_names)
			cur_gaze_stem = valid_gaze_source_stem_names{i_valid_gaze_stem};
			% now get the side:
			cur_side = cur_gaze_stem(1);

			cur_gaze_unit = 'CCF';
			if contains(cur_gaze_stem, regexpPattern('_pixel$'))
				cur_gaze_unit = 'pixel';
			elseif contains(cur_gaze_stem, regexpPattern('_dva$'))
				cur_gaze_unit = 'dva';	% this needs special care, so maybe skip it for now
				disp([mfilename, ': DVA needs separate calculations for left and right eye, for now just skip...']);
				continue
			end

			% we need this for dva
			cur_eye_side = regexp(cur_gaze_stem, '(left|right|binocular)', 'match');
			cur_eye_side = cur_eye_side{1};

			cur_prefix = regexprep(cur_gaze_stem, '_X', '');
			cur_X_col_name = cur_gaze_stem;
			cur_Y_col_name = regexprep(cur_X_col_name, '_X', '_Y');

			% the face center position
			switch cur_gaze_unit
				case 'pixel'
					cur_ROI_center_X = cur_ROI_center_X_pixel;
					cur_ROI_center_Y = cur_ROI_center_Y_pixel;
					cur_gaze_unit = ['_', cur_gaze_unit];
				case 'CCF'
					cur_ROI_center_X = cur_ROI_center_X_CCF;
					cur_ROI_center_Y = cur_ROI_center_Y_CCF;
					cur_gaze_unit = '';
			end

			cur_new_col_name = ['distance_', cur_prefix, '_to_', cur_ROI_name, cur_gaze_unit];

			cur_prefix_pos_XY_list = [record2D_table.(cur_X_col_name)(:), record2D_table.(cur_Y_col_name)(:)];
			cur_target_pos_XY_list = repmat([cur_ROI_center_X, cur_ROI_center_Y], size(cur_prefix_pos_XY_list, 1), 1);

			record2D_table.(cur_new_col_name) = vecnorm((cur_target_pos_XY_list - cur_prefix_pos_XY_list), 2, 2);	% way faster than calling norm row by row...
			%record2D_table.([cur_prefix, '_on_', cur_target_stem]) =
			%record2D_table.(cur_new_col_name) < target_radius;	% faces do not
			%have a fixed "radius", even though the human face at playing
			%distance is about 1/3 of the playing field wide, so 1/6 of playing
			%field seems reasonable radius
		end
	end
	%timestamps.(mfilename).end_on_target = toc(timestamps.(mfilename).start_on_target);
	%disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end_on_target), ' seconds.']);
end

if ismember({'calc_and_store_gaze_distance_to_agents'}, request_list)
	disp([mfilename, ': INFO: Processing requested calc_and_store_gaze_distance_to_agents']);
	% we only do this for the CCF relative space to avoid conversion to
	% pixel space
	exclude_stem_wildcard_list = {'_pixel$', '_dva$'};

	% check the gaze sources
	valid_gaze_data_column_idx = contains(record2D_colname_list, regexpPattern('^[A|B]_(left|right|binocular)_eye_[X|Y]+'));
	valid_gaze_data_column_names = record2D_colname_list(valid_gaze_data_column_idx);

	% get rid of the Y...
	valid_gaze_source_stem_names = unique(regexprep(valid_gaze_data_column_names, '_[X|Y]', '_X'));

	for i_valid_gaze_stem = 1 : length(valid_gaze_source_stem_names)
		cur_gaze_stem = valid_gaze_source_stem_names{i_valid_gaze_stem};
		if contains(cur_gaze_stem, regexpPattern(exclude_stem_wildcard_list))
			disp([mfilename, ': INFO: excluding current gaze stem (', cur_gaze_stem, ') as it matches the exclude_stem_wildcard_list']);
			continue;
		end
		cur_prefix = regexprep(cur_gaze_stem, '_X', '');
		cur_X_col_name = cur_gaze_stem;
		cur_Y_col_name = regexprep(cur_X_col_name, '_X', '_Y');

		cur_valid_gaze_stem_XY = [record2D_table.(cur_X_col_name)(:), record2D_table.(cur_Y_col_name)(:)];

		for i_agent = 1 : length(agent_prefix_list)
			cur_agent = agent_prefix_list{i_agent};
			cur_new_col_name = ['distance_', cur_prefix, '_to_', cur_agent];
			% if isempty(on_target_struct2) || ~isfield(on_target_struct2, cur_new_col_name)
			% 	on_target_struct2.(cur_new_col_name) = logical(zeros(size(record2D_table.timestamp)));
			% end
			cur_agent_pos_XY_list = [record2D_table.([cur_agent, '_X'])(:), record2D_table.([cur_agent, '_Y'])(:)];
			record2D_table.(cur_new_col_name) = vecnorm((cur_agent_pos_XY_list - cur_valid_gaze_stem_XY), 2, 2);	% way faster than calling norm row by row...
		end
	end
end

if ismember({'calc_and_store_gaze_distance_to_aims'}, request_list)
	disp([mfilename, ': INFO: Processing requested calc_and_store_gaze_distance_to_aims']);
	% we only do this for the CCF relative space to avoid conversion to
	% pixel space
	exclude_stem_wildcard_list = {'_pixel$', '_dva$'};

	% check the gaze sources
	valid_gaze_data_column_idx = contains(record2D_colname_list, regexpPattern('^[A|B]_(left|right|binocular)_eye_[X|Y]+'));
	valid_gaze_data_column_names = record2D_colname_list(valid_gaze_data_column_idx);

	% get rid of the Y...
	valid_gaze_source_stem_names = unique(regexprep(valid_gaze_data_column_names, '_[X|Y]', '_X'));

	for i_valid_gaze_stem = 1 : length(valid_gaze_source_stem_names)
		cur_gaze_stem = valid_gaze_source_stem_names{i_valid_gaze_stem};
		if contains(cur_gaze_stem, regexpPattern(exclude_stem_wildcard_list))
			disp([mfilename, ': INFO: excluding current gaze stem (', cur_gaze_stem, ') as it matches the exclude_stem_wildcard_list']);
			continue;
		end
		cur_prefix = regexprep(cur_gaze_stem, '_X', '');
		cur_X_col_name = cur_gaze_stem;
		cur_Y_col_name = regexprep(cur_X_col_name, '_X', '_Y');

		cur_valid_gaze_stem_XY = [record2D_table.(cur_X_col_name)(:), record2D_table.(cur_Y_col_name)(:)];

		for i_aim = 1 : length(aim_prefix_list)
			cur_aim = aim_prefix_list{i_aim};
			cur_new_col_name = ['distance_', cur_prefix, '_to_', cur_aim];
			% if isempty(on_target_struct2) || ~isfield(on_target_struct2, cur_new_col_name)
			% 	on_target_struct2.(cur_new_col_name) = logical(zeros(size(record2D_table.timestamp)));
			% end
			cur_aim_pos_XY_list = [record2D_table.([cur_aim, '_X'])(:), record2D_table.([cur_aim, '_Y'])(:)];
			record2D_table.(cur_new_col_name) = vecnorm((cur_aim_pos_XY_list - cur_valid_gaze_stem_XY), 2, 2);	% way faster than calling norm row by row...
		end
	end
end



if ismember({'add_per_target_changed_pos_col'}, request_list)
	disp([mfilename, ': INFO: Processing requested add_per_target_changed_pos_col']);
	% we need this unconditionally
	for i_target_IDX = 1 : length(target_prefix_list)
		cur_targetIDX = str2double(regexprep(target_prefix_list{i_target_IDX}, 'target', ''));
		cur_target_prefix = target_prefix_list{i_target_IDX};
		cur_col_name_stem = [target_prefix_list{i_target_IDX}, '_collecting_by_'];

		% add the target change detection here, as we really only need these later on to compile per trial information
		cur_new_col_name = [cur_target_prefix, '_changed_pos'];
		cur_target_pos_XY_list = [record2D_table.([cur_target_prefix, '_X'])(:), record2D_table.([cur_target_prefix, '_Y'])(:)];
		% get the distance betwenn samples
		cur_sample_by_sample_distance = [1 ; vecnorm((cur_target_pos_XY_list(2:end, :) - cur_target_pos_XY_list(1:end-1, :)), 2, 2)]; % way faster than calling norm row by row... % FIXME only set target to one in the first tick that where actually shown
		record2D_table.(cur_new_col_name) = cur_sample_by_sample_distance ~= 0;
		record2D_table.(cur_new_col_name)(isnan(cur_sample_by_sample_distance)) = false;
		if any(isnan(cur_target_pos_XY_list(1, :)))
			record2D_table.(cur_new_col_name)(1) = false;
		end
	end
end




% now run the fixation detector
if ismember({'detect_aim_fixations'}, request_list)
	for i_aim = 1 : length(aim_prefix_list)
		timestamps.(mfilename).detect_aim_fixations.(aim_prefix_list{i_aim}).start = tic;
		disp([mfilename, ': INFO: Processing requested detect_aim_fixations: ', aim_prefix_list{i_aim}]);
		cur_aim = aim_prefix_list{i_aim};
		cur_data_struct_of_arr.timestamp = record2D_table.timestamp * 1000;	% we want milliseconds
		cur_data_struct_of_arr.X = record2D_table.([cur_aim, '_X']);
		cur_data_struct_of_arr.Y = record2D_table.([cur_aim, '_Y']);
		% local override
		% max_dispersion_threshold = conf_struct.target_radius/2;
		% min_fixation_duration_threshold_ms = 100;
		% isDraw = 1;
		cur_fixation_struct = fn_spatial_dispersion_fixation_detector_CCF(cur_data_struct_of_arr, max_dispersion_threshold, min_fixation_duration_threshold_ms, isDraw);
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
		timestamps.(mfilename).detect_aim_fixations.(aim_prefix_list{i_aim}).end = toc;
		duration_s = timestamps.(mfilename).detect_aim_fixations.(aim_prefix_list{i_aim}).end - timestamps.(mfilename).detect_aim_fixations.(aim_prefix_list{i_aim}).start;
		disp(['detect_aim_fixations (', aim_prefix_list{i_aim}, ') took: ', num2str(duration_s), ' seconds.']);
	end
end

if ismember({'detect_agent_fixations'}, request_list)
	for i_agent = 1 : length(agent_prefix_list)
		disp([mfilename, ': INFO: Processing requested detect_agent_fixations: ', agent_prefix_list{i_agent}]);
		timestamps.(mfilename).detect_agent_fixations.(agent_prefix_list{i_agent}).start = tic;
		cur_agent = agent_prefix_list{i_agent};
		cur_data_struct_of_arr.timestamp = record2D_table.timestamp * 1000;	% we want milliseconds
		cur_data_struct_of_arr.X = record2D_table.([cur_agent, '_X']);
		cur_data_struct_of_arr.Y = record2D_table.([cur_agent, '_Y']);
		% local override
		% max_dispersion_threshold = conf_struct.target_radius/2;
		% min_fixation_duration_threshold_ms = 100;
		% isDraw = 1;
		cur_fixation_struct = fn_spatial_dispersion_fixation_detector_CCF(cur_data_struct_of_arr, max_dispersion_threshold, min_fixation_duration_threshold_ms, isDraw);
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
		timestamps.(mfilename).detect_agent_fixations.(agent_prefix_list{i_agent}).end = toc;
		duration_s = timestamps.(mfilename).detect_agent_fixations.(agent_prefix_list{i_agent}).end - timestamps.(mfilename).detect_agent_fixations.(agent_prefix_list{i_agent}).start;
		disp(['detect_agent_fixations (', agent_prefix_list{i_agent}, ') took: ', num2str(duration_s), ' seconds.']);
	end
end

% TODO fix max_dispersion_threshold and min_fixation_duration_threshold_ms
% for this...
if ismember({'detect_eye_fixations'}, request_list)
	for i_eye = 1 : length(eye_prefix_list)
		disp([mfilename, ': INFO: Processing requested detect_eye_fixations: ', eye_prefix_list{i_eye}]);
		timestamps.(mfilename).detect_eye_fixations.(eye_prefix_list{i_eye}).start = tic;
		cur_eye = eye_prefix_list{i_eye};

		% we only want to detect fixations once, but take the best matching
		% gaze source into account
		cur_gaze_unit_suffix_string = GAZE_OPTS_struct.gaze_unit_suffix_string;
		if ~ismember({[cur_eye, '_X', cur_gaze_unit_suffix_string]}, record2D_table.Properties.VariableNames)
			disp([mfilename, ': WARN: requested gaze suffix (', cur_gaze_unit_suffix_string, ') does not seem to exists, defaulting to field-relative CCF space']);
			cur_gaze_unit_suffix_string = '';
		end

		cur_data_struct_of_arr.timestamp = record2D_table.timestamp * 1000;	% we want milliseconds
		cur_data_struct_of_arr.X = record2D_table.([cur_eye, '_X', cur_gaze_unit_suffix_string]);
		cur_data_struct_of_arr.Y = record2D_table.([cur_eye, '_Y', cur_gaze_unit_suffix_string]);

		if contains(cur_eye, 'binocular') && ismember({[cur_eye, '_dX', cur_gaze_unit_suffix_string]}, record2D_table.Properties.VariableNames)
			cur_data_struct_of_arr.depth_dX = record2D_table.([cur_eye, '_dX', cur_gaze_unit_suffix_string]);
		end

		% do we want to exclude some samples, then do it here...
		valid_sample_ldx = [];
		invalid_sample_ldx = [];
		if ismember({[cur_eye, GAZE_OPTS_struct.gaze_selection_col_suffix_string]}, record2D_table.Properties.VariableNames)
			valid_sample_ldx = ones(size(record2D_table.([cur_eye, GAZE_OPTS_struct.gaze_selection_col_suffix_string]))) == 1;
			if isfield(GAZE_OPTS_struct, 'gaze_selection_min_threshold_value') && ~isempty(GAZE_OPTS_struct.gaze_selection_min_threshold_value)
				valid_sample_ldx(record2D_table.([cur_eye, GAZE_OPTS_struct.gaze_selection_col_suffix_string]) <= GAZE_OPTS_struct.gaze_selection_min_threshold_value) = false;
			end
			if isfield(GAZE_OPTS_struct, 'gaze_selection_max_threshold_value') && ~isempty(GAZE_OPTS_struct.gaze_selection_max_threshold_value)
				valid_sample_ldx(record2D_table.([cur_eye, GAZE_OPTS_struct.gaze_selection_col_suffix_string]) >= GAZE_OPTS_struct.gaze_selection_max_threshold_value) = false;
			end
			invalid_sample_ldx = ~valid_sample_ldx;
			cur_data_struct_of_arr.X(invalid_sample_ldx)= nan;
			cur_data_struct_of_arr.Y(invalid_sample_ldx)= nan;
			if isfield(cur_data_struct_of_arr, 'depth_dX')
				cur_data_struct_of_arr.depth_dX(invalid_sample_ldx)= nan;
			end
		end

		% DVA
		if isfield(GAZE_OPTS_struct, GAZE_OPTS_struct.fixation_detection_method) && isfield(GAZE_OPTS_struct.(GAZE_OPTS_struct.fixation_detection_method), 'max_dispersion_threshold_dva')
			cur_max_dispersion_threshold_dva = GAZE_OPTS_struct.(GAZE_OPTS_struct.fixation_detection_method).max_dispersion_threshold_dva;
		else
			cur_max_dispersion_threshold_dva = [];
		end

		% PIXEL
		if ~isempty(cur_max_dispersion_threshold_dva)
			% NOTE: this is only approximately correct around the main gaze
			% axis, the more peripheral the less accurate, but that is
			% unavoidable
			cur_max_dispersion_threshold_pixel = (tand(cur_max_dispersion_threshold_dva) * conf_struct.screen_to_eye_distance_NHP_mm) * (conf_struct.screen_width_pixel/conf_struct.screen_width_mm);
		else
			if isfield(GAZE_OPTS_struct, GAZE_OPTS_struct.fixation_detection_method) && isfield(GAZE_OPTS_struct.(GAZE_OPTS_struct.fixation_detection_method), 'max_dispersion_threshold_pixel')
				cur_max_dispersion_threshold_pixel = GAZE_OPTS_struct.(GAZE_OPTS_struct.fixation_detection_method).max_dispersion_threshold_pixel;
			else
				cur_max_dispersion_threshold_pixel = [];
			end
		end

		% CCF
		if ~isempty(cur_max_dispersion_threshold_pixel)
			% NOTE: this is only approximately correct around the main gaze
			% axis, the more peripheral the less accurate, but that is
			% unavoidable
			cur_max_dispersion_threshold_CCF = cur_max_dispersion_threshold_pixel / (conf_struct.field_size - 2 * conf_struct.target_radius * conf_struct.field_size);
		else
			if isfield(GAZE_OPTS_struct, GAZE_OPTS_struct.fixation_detection_method) && isfield(GAZE_OPTS_struct.(GAZE_OPTS_struct.fixation_detection_method), 'max_dispersion_threshold_CCF')
				cur_max_dispersion_threshold_CCF = GAZE_OPTS_struct.(GAZE_OPTS_struct.fixation_detection_method).max_dispersion_threshold_CCF;
			else
				cur_max_dispersion_threshold_CCF = [];
				error([mfilename, ': ERROR: could not find any max_dispersion_threshold...']);
			end
		end

		switch cur_gaze_unit_suffix_string
			case '_dva'
				cur_max_dispersion_threshold = cur_max_dispersion_threshold_dva;
			case '_pixel'
				cur_max_dispersion_threshold = cur_max_dispersion_threshold_pixel;
			case ''
				cur_max_dispersion_threshold = cur_max_dispersion_threshold_CCF;
		end
		cur_min_fixation_duration_threshold_ms = GAZE_OPTS_struct.(GAZE_OPTS_struct.fixation_detection_method).min_duration_threshold_ms;



		cur_fixation_struct = fn_spatial_dispersion_fixation_detector_CCF(cur_data_struct_of_arr, cur_max_dispersion_threshold, cur_min_fixation_duration_threshold_ms, isDraw);
		record2D_table.([cur_eye, '_per_sample_fixID']) = cur_fixation_struct.per_sample_fixID;
		cur_fixation_struct = rmfield(cur_fixation_struct, 'per_sample_fixID');	% we move this into record2D already...

		% also add average gaze positions for CCF space (pixel space can be easily converted from that)
		if ~isempty(cur_gaze_unit_suffix_string)
			disp([mfilename, ': INFO: adding average fixation positions in CCF space']);
			n_fixations = length(cur_fixation_struct.duration_ms);
			mean_X_CCF = nan(size(cur_fixation_struct.mean_X));
			mean_Y_CCF = nan(size(cur_fixation_struct.mean_Y));
			mean_dX_CCF = nan(size(cur_fixation_struct.mean_X));

			% conversion for dX values
			pixel_to_mm = conf_struct.screen_height_mm/conf_struct.screen_height_pixel;
			CCF_to_mm = (conf_struct.field_size - 2 * conf_struct.target_radius * conf_struct.field_size) * pixel_to_mm;


			for i_fixation = 1 : n_fixations
				cur_fixation_ldx = record2D_table.([cur_eye, '_per_sample_fixID']) == i_fixation;
				% we do not want to re-map the actual gaze data, but
				% exclude these samples from averaging...
				if ~isempty(valid_sample_ldx)
					cur_fixation_ldx = cur_fixation_ldx & valid_sample_ldx;
				end

				mean_X_CCF(i_fixation) = mean(record2D_table.([cur_eye, '_X'])(cur_fixation_ldx), 'omitnan');
				mean_Y_CCF(i_fixation) = mean(record2D_table.([cur_eye, '_Y'])(cur_fixation_ldx), 'omitnan');
				% dX only exists for binocular data...
				if contains(cur_eye, 'binocular') && ismember({[cur_eye, '_dX', cur_gaze_unit_suffix_string]}, record2D_table.Properties.VariableNames)
					mean_dX_CCF(i_fixation) = mean(record2D_table.([cur_eye, '_dX'])(cur_fixation_ldx), 'omitnan');
				end
			end
			cur_fixation_struct.mean_X_CCF = mean_X_CCF;
			cur_fixation_struct.mean_Y_CCF = mean_Y_CCF;
			cur_fixation_struct.mean_dX_CCF = mean_dX_CCF;	
		end

		fixations_struct.(cur_eye) = cur_fixation_struct;
		if (debug)
			cur_fh = figure('Name', cur_eye);
			plot(cur_fixation_struct.mean_X, cur_fixation_struct.mean_Y, 'LineWidth', 0.5, 'Marker', 'o');
			cur_ah = gca();
			axis equal
			axis square
		end
		%timestamps.(mfilename).detect_eye_fixations.(eye_prefix_list{i_eye}).end = toc();
		duration_s = toc(timestamps.(mfilename).detect_eye_fixations.(eye_prefix_list{i_eye}).start);
		disp(['detect_eye_fixations (', eye_prefix_list{i_eye}, ') took: ', num2str(duration_s), ' seconds (', num2str(floor(duration_s/(60*60))), ' hours ', num2str(floor(duration_s/60)), ' minutes ', num2str(mod(duration_s, 60)), ' seconds).']);
	end
end




timestamps.(mfilename).end = toc(timestamps.(mfilename).start);
cur_duration_s = timestamps.(mfilename).end;
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end), ' seconds (', num2str(floor(cur_duration_s/(60*60))), ' hours ', num2str(floor(cur_duration_s/60)), ' minutes ', num2str(mod(cur_duration_s, 60)), ' seconds).']);
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end / 60), ' minutes.']);


end

