function [] = fn_analyze_face_gaze_per_session(cur_CCF_runfolder_FQN_list)
%FN_ANALYZE_FACE_GAZE_PER_SESSION Summary of this function goes here
%   Detailed explanation goes here

% TODO:
%	add distance betwenn gaze and agents and aims to record2D
%	 change to one row per stateXcycle and vergence type add the cycle
%	 number and state name to the table, as well as the vergence type

timestamps.(mfilename).start = tic;
disp(['Starting: ', mfilename]);
dbstop if error
fq_mfilename = mfilename('fullpath');
debug = 0;

% control variables
show_2D_fixations = 0;	% first variant, show 2D fixation positions for a specific epoch, splitting out near/far


% if we run this directly for testing we want/need this to be in the
% path...
if ~exist('cur_CCF_runfolder_FQN_list', 'var')
	CCF_analysis_path = fullfile('C:', 'SCP_CODE', 'CCF_analysis_matlab');
	% delete existing paths containing the calling directory
	% this is a work around for matlab's inability to detect changed files on
	% most network shares
	if ~isempty(strfind(path, [CCF_analysis_path, pathsep]))
		path_string = path;
		disp('Current directory already in the path; deleting all subdirectories from the path to work around network share issues...');
		% turn the path into cell array
		while length(path_string) > 0
			[cur_path_item, remain] = strtok(path_string, ';:');
			path_string = remain(2:end);
			if ~isempty(strfind(cur_path_item, CCF_analysis_path))
				rmpath(cur_path_item);
			end
		end
	end
	% now add them again
	addpath(genpath(CCF_analysis_path));
end


out_dir = fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', 'CCF', 'GAZE_ANALYSIS');
plotting_options_struct = fn_BoS_ephys_default_plotting_options;
% overrides
plotting_options_struct.format_string_list = {'.png', '.fig'};



if ~exist('cur_CCF_runfolder_FQN_list', 'var') || isempty(cur_CCF_runfolder_FQN_list)
	cur_CCF_runfolder_FQN_list = { ...
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2025', '251219', '20251219TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% re-run with correct scaling
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260204', '20260204TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% correct scaling
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260206', '20260206TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% correct scaling
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260306', '20260306TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260312', '20260312TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260319', '20260319TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% first session with monkey gaze data...
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260320', '20260320TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% session with gaze data, but with broken calibration data, take calibration from 260319
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260325', '20260325TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260326', '20260326TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260402', '20260402TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260403', '20260403TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260409', '20260409TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 12
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260423', '20260423TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 13
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260424', '20260424TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	5 14
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260428', '20260428TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	5 14
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260429', '20260429TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	5 14
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260430', '20260430TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	5 14
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260501', '20260501TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	5 14
		};

	%cur_CCF_runfolder_FQN_list = cur_CCF_runfolder_FQN_list(end); % clear up to 7
%	cur_CCF_runfolder_FQN_list = cur_CCF_runfolder_FQN_list(6:end); % clear up to 7
%	cur_CCF_runfolder_FQN_list = cur_CCF_runfolder_FQN_list(end); % clear up to 7
	cur_CCF_runfolder_FQN_list = cur_CCF_runfolder_FQN_list(6:end); % clear up to 7

	only_process_gaze_calibration = 0;
	if (only_process_gaze_calibration)
		% the gaze calibration sessions...
		cur_CCF_runfolder_FQN_list = { ...
			...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260319', '20260319T110006.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% first session with monkey gaze data...
			...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260320', '20260320TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% the calibration routine was broken, this session uses the calibration from 260319 instead
			...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260326', '20260326T103026.A_Elmo.B_NONE.SCP_01.sessiondir'), ...
			...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260326', '20260326T103026.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 12
			...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260402', '20260402T100142.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 12
			...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260403', '20260403T093508.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 12
			...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260409', '20260409T100642.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 12
			...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260423', '20260423T102851.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 13
			...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260424', '20260424T101945.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 13
			...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260428', '20260428T102602.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 13
			...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260429', '20260429T100042.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 13
			...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260430', '20260430T090028.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 13
			...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260501', '20260501T085455.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 13
			};
	end
	% use a file picker to select the desired folder
end

if ~iscell(cur_CCF_runfolder_FQN_list)
	cur_CCF_runfolder_FQN_list = {cur_CCF_runfolder_FQN_list};
end

% loop over the sessions to do your thing...
for i_runfolder = 1 : length(cur_CCF_runfolder_FQN_list)
	cur_CCF_runfolder_FQN = cur_CCF_runfolder_FQN_list{i_runfolder};
	disp(['Processing: ', cur_CCF_runfolder_FQN]);

	[~, proto_varname_session_id, tmp_ext] = fileparts(cur_CCF_runfolder_FQN);
	if ~strcmp(tmp_ext, '.sessiondir')
		error([mfilename, ': WARN: session folder does not end in .sessiondir...']);
	end
	cur_sessionID = proto_varname_session_id;
	varname_session_id = fn_sanitize_value_as_matlab_variable_name(proto_varname_session_id, 1 ,1);
	timestamps.(mfilename).(varname_session_id).start = tic;


	% we need per sesson-run information about the approximate position of
	% the partner's face





	% loading current session
	disp('Parsing current session CCF data, might take a while');
	[triallog_table, record_struct, record2D_table, sorted_target_state_transition_table, AI_samples_struct, DI_samples_struct, json_struct, h5_struct, txt_struct, jsonl_struct, enum_struct, fixations_struct, orig_GAZE_OPTS_struct] = fn_parse_CCF_data( cur_CCF_runfolder_FQN );

	% clean up triallog_table
	triallog_table_remove_row_ldx = ismember(triallog_table.col_targ_id_name, {'None'}) | isnan(triallog_table.col_targ_IDX) | ismember(triallog_table.collection_type, {'None'});
	triallog_table(triallog_table_remove_row_ldx, :) = [];

	% this should ideally be added in the parsing function...
	if ~ismember({'sessionID'}, triallog_table.Properties.VariableNames)
		triallog_table.sessionID = repmat({cur_sessionID}, size(triallog_table, 1), 1);
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




	% convenience mappings
	GAZE_OPTS_struct = orig_GAZE_OPTS_struct;	% TODO automate this
	conf_struct = json_struct.conf_dot_json;
	%
	ROI_center_name_list = {'facecenter', 'face_left', 'face_right'};
	ROI_color_list = {[231, 41, 138]/255, [217, 95, 2]/255, [27, 158, 119]/255}; % this should be separated out by near/far?


	ROI_center_unit_list = {'pixel', 'pixel', 'pixel'};	% so we now how to convert these...
	% here we just construct these...
	field_width = conf_struct.field_size;
	ROI_center_X_list = [GAZE_OPTS_struct.HP.A.x_screen_intereye_pix, (GAZE_OPTS_struct.HP.A.x_screen_intereye_pix - 0.5*field_width*2/3), (GAZE_OPTS_struct.HP.A.x_screen_intereye_pix + 0.8*field_width*2/6)];
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


				ROI_center_X_list_pixel(i_ROI) = cur_ROI_center_X_pixel;
				ROI_center_Y_list_pixel(i_ROI) = cur_ROI_center_Y_pixel;
				ROI_center_X_list(i_ROI) = cur_ROI_center_X_CCF;
				ROI_center_Y_list(i_ROI) = cur_ROI_center_Y_CCF;
			otherwise
				error([mfilename, ': ERROR: unhandled ROI unit: ', cur_ROI_unit]);
		end
	end

	face_ROI.names = ROI_center_name_list;
	face_ROI.colors = ROI_color_list;
	face_ROI.center_XY_pixel = [ROI_center_X_list_pixel', ROI_center_Y_list_pixel'];
	face_ROI.center_XY = [ROI_center_X_list', ROI_center_Y_list'];

	% map face position to session and run, assume facecenter, unless
	% otherwise defined, also assume facecenter for solo_0/solo_1 for
	% simplicity...

	if ismember({'src_run_idx'}, triallog_table.Properties.VariableNames)
		unique_src_run_idx = unique(triallog_table.src_run_idx, 'stable');
		unique_src_run_idx(unique_src_run_idx == 0) = [];
	else
		unique_src_run_idx = 1;
	end
	n_src_runs = length(unique_src_run_idx);


	% to do potentially move this per session+run information to a
	% different file/table
	paper_blocked = 0;
	switch proto_varname_session_id
		case '20260423TNNNNNNM.A_Elmo.B_MIXED.SCP_01'
			paper_blocked = 1;
			per_run_face_ROI_idx = repmat(find(ismember(face_ROI.names, {'facecenter'})), n_src_runs, 1);

		case '20260424TNNNNNNM.A_Elmo.B_MIXED.SCP_01'
			paper_blocked = 1;
			per_run_face_ROI_idx = repmat(find(ismember(face_ROI.names, {'facecenter'})), n_src_runs, 1);

		case '20260428TNNNNNNM.A_Elmo.B_MIXED.SCP_01'
			per_run_face_ROI_idx = repmat(find(ismember(face_ROI.names, {'face_right'})), n_src_runs, 1);

		case '20260429TNNNNNNM.A_Elmo.B_MIXED.SCP_01'
			per_run_face_ROI_idx = repmat(find(ismember(face_ROI.names, {'face_right'})), n_src_runs, 1);

		case '20260430TNNNNNNM.A_Elmo.B_MIXED.SCP_01'
			per_run_face_ROI_idx = [find(ismember(face_ROI.names, {'face_right'})); find(ismember(face_ROI.names, {'facecenter'})); find(ismember(face_ROI.names, {'facecenter'}))];

		case '20260501TNNNNNNM.A_Elmo.B_MIXED.SCP_01'
			per_run_face_ROI_idx = [find(ismember(face_ROI.names, {'face_right'})); find(ismember(face_ROI.names, {'face_left'})); find(ismember(face_ROI.names, {'facecenter'}))];

		otherwise
			% assume the partner normally sits opposite to the monkey...
			% note we default to facecenter even for solo right now
			per_run_face_ROI_idx = repmat(find(ismember(face_ROI.names, {'facecenter'})), n_src_runs, 1);
	end


	% now add the partner face center positpion and paper_block information
	% to the triallog_table and record2D_table
	% TODO also add A_s face position
	record2D_table.B_facecenter_X = face_ROI.center_XY(per_run_face_ROI_idx(record2D_table.run_idx + 1), 1);
	record2D_table.B_facecenter_Y = face_ROI.center_XY(per_run_face_ROI_idx(record2D_table.run_idx + 1), 2);
	record2D_table.paper_blocked = zeros([size(record2D_table, 1) 1]) + paper_blocked;	% TODO change to per run parameter?

	triallog_table.B_facecenter_XY = face_ROI.center_XY(per_run_face_ROI_idx(triallog_table.src_run_idx), :);
	triallog_table.paper_blocked = zeros([size(triallog_table, 1) 1]) + paper_blocked;	% TODO change to per run parameter?



	% define a relevant time window per trial

	% threshold fixations into near and far based on mean_dX_CCF, look at
	% the histogram to define this threshold empirically
	%figure('Name', 'mean_dX_CCF');
	%histogram(fixations_struct.A_binocular_eye.mean_dX_CCF, 100)
	mean_dX_CCF_threshold = 0.05;	%(values smaller near fixation, values larger far fixations)
	near_fixation_ldx = fixations_struct.A_binocular_eye.mean_dX_CCF <= mean_dX_CCF_threshold;
	far_fixation_ldx = fixations_struct.A_binocular_eye.mean_dX_CCF > mean_dX_CCF_threshold;

	% sample based
	min_gaze_confidence = 0.85;%
	gaze_src_col_name_stem = 'A_binocular_eye';
	valid_gaze_sample_ldx = record2D_table.([gaze_src_col_name_stem, '_confidence']) >= min_gaze_confidence;
	near_gaze_sample_ldx = record2D_table.([gaze_src_col_name_stem, '_dX']) <= mean_dX_CCF_threshold;
	far_gaze_sample_ldx = record2D_table.([gaze_src_col_name_stem, '_dX']) > mean_dX_CCF_threshold;



	% TODO iterate over epochs:
	% acquisition period: target collection period: reward_period,
	% pre_acquisiton

	% exclude cycles longer than X seconds
	max_cycle_duration_s = 10;
	cycle_duration_list = triallog_table.cycle_end_s - triallog_table.cycle_start_s;
	exclude_cycle_ldx =  cycle_duration_list > max_cycle_duration_s;
	exclude_tick_ldx = record2D_table.timestamp > 0;

	% invert logic to exclude by default
	for i_cycle = 1 : length(exclude_cycle_ldx)
		if ~exclude_cycle_ldx(i_cycle)
			cur_trial_start_tick_idx = triallog_table.cycle_start_tick_idx(i_cycle);
			cur_trial_end_tick_idx = triallog_table.cycle_end_tick_idx(i_cycle) ;
			if (cur_trial_start_tick_idx > 0) && (cur_trial_end_tick_idx > 0)
				exclude_tick_ldx(cur_trial_start_tick_idx:cur_trial_end_tick_idx) = false;
			end
		end
	end

	% create by collection type ldx lists...



	% now create the tick_ldx for the different epochs and store
	% TODO iterate over epochs:
	% acquisition period: target collection period: reward_period,
	% pre_acquisiton

	target_state_col_ldx = contains(triallog_table.Properties.VariableNames, regexpPattern('^col_targ_\w*_tick_idx$'));
	target_state_end_col_ldx = contains(triallog_table.Properties.VariableNames, regexpPattern('^col_targ_\w*_end_tick_idx$'));
	target_state_start_col_ldx = target_state_col_ldx & ~target_state_end_col_ldx;


	target_state_start_name_list = triallog_table.Properties.VariableNames(target_state_start_col_ldx);
	target_state_end_name_list = triallog_table.Properties.VariableNames(target_state_end_col_ldx);
	target_state_name_list = regexprep(target_state_start_name_list, '_tick_idx', '');
	additional_state_name_list = {'Acquisition'};	% these do not map fully onto target states
	additional_state_start_tick_idx_col_name_list = {'PDD_onset_tick_idx'};
	additional_state_end_col_tick_idx_name_list = {'collecting_by_agent_start_tick_idx'};

	all_epoch_name_list = [target_state_name_list, additional_state_name_list];
	short_all_epoch_name_list = fn_shorten_object_name_list(all_epoch_name_list);


	n_states = length(target_state_name_list) + length(additional_state_name_list);
	% use this to pick the per state valid samples
	per_state_valid_tick_idx_ldx_array = false([size(record2D_table, 1), n_states]);
	per_state_valid_tick_idx_per_cycle_idx_array = zeros([size(record2D_table, 1), n_states]);
	per_tick_sessionID_cycle_list = fn_generate_key_from_selected_table_columns_CCF( {'sessionID', 'cycle'}, record2D_table, '_' );	% TODO add sessionID and cycle_num to record2D_table

	%per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray = cell([size(per_tick_sessionID_cycle_list, 1), n_states]);
	per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray = repmat({'EXCLUDE'}, size(per_tick_sessionID_cycle_list, 1), n_states);



	reference_object_position_stem_list = [aim_prefix_list, agent_prefix_list, target_prefix_list, 'B_facecenter'];	% for gaze_to_object_mapping_rule all this is fine, but for closest_object_within_threshold this is less fine
	reference_object_position_stem_list = [target_prefix_list, 'B_facecenter'];	% use for closest_object_within_threshold
	% we want/need to test for each samp;le whether it is close
	% enough to any object to be cpunted as on that object
	% for now do not assign things exclusively (by picking the closest if multiple objects qualify)
	reference_object_position_stem_closeness_threshold_list = [zeros(size(aim_prefix_list)) + 0.1, zeros(size(agent_prefix_list)) + conf_struct.agent_radius*2, zeros(size(target_prefix_list)) + conf_struct.target_radius*2, 1/7];

	template_per_trial_ref_object_table = table;
	ref_data_col = nan(size(triallog_table.collection_num));
	for i_ref_object = 1 : length(reference_object_position_stem_list)
		prefix = [];
		suffix = [];
		cur_object_name = [prefix, gaze_src_col_name_stem, '_on_', reference_object_position_stem_list{i_ref_object}, suffix];
		template_per_trial_ref_object_table.(cur_object_name) = ref_data_col;
	end

	timestamps.(mfilename).per_cycle_proportion_count_loop.start = tic;
	all_false_tick_ldx = false([size(record2D_table, 1), 1]);

	version_string = 'v.005';
	target_state_exclusion_list = {'col_targ_initiate_reward'};% skip these states, col_targ_initiate_reward should only last 1 cycle...
	gaze_to_object_mapping_rule = 'closest_object_within_threshold';	% all: each gaze sample is counted for all below threshold distance objects ; closest_within_threshold: pick the closest object fullfilling the threshold condition


	GazePropCount_subhash_list = { ...
		DataHash(version_string), ...						% if the record2D data changed, play it save and recompute things
		DataHash(target_state_exclusion_list), ...
		DataHash(additional_state_name_list), ...
		DataHash(additional_state_start_tick_idx_col_name_list), ...
		DataHash(additional_state_end_col_tick_idx_name_list), ...
		DataHash(triallog_table), ...
		DataHash(record2D_table), ...
		DataHash(reference_object_position_stem_list),...
		DataHash(reference_object_position_stem_closeness_threshold_list), ...
		DataHash(gaze_to_object_mapping_rule), ...
		};
	% hash of hashes...
	GazePropCount_hash = DataHash(GazePropCount_subhash_list);
	GazePropCount_cache_FQN = fullfile(out_dir, ['GazePropCount_cache_', proto_varname_session_id, '_', GazePropCount_hash, '.mat']);

	redo_GazePropCount_cache = 0;
	if isfile(GazePropCount_cache_FQN) && ~(redo_GazePropCount_cache)
		% load this
		disp([mfilename, ': INFO: loading GazePropCount_cache_FQN from cache: ', GazePropCount_cache_FQN]);
		load(GazePropCount_cache_FQN, 'gaze_on_object_prop_count_table', 'per_state_valid_tick_idx_per_cycle_idx_array', 'per_state_valid_tick_idx_ldx_array', 'per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray');
	else


		% accumulate as struct, later convert to table 
		gaze_on_object_prop_count_struct = [];

		for i_target_state = 1 : length(all_epoch_name_list)
			cur_target_state = all_epoch_name_list{i_target_state};
			cur_epoch_name = cur_target_state;
			disp([mfilename, ': INFO: Processing: ', cur_target_state]);

			if ismember({cur_target_state}, target_state_exclusion_list)
				disp([mfilename, ': INFO: current cur_target_state on exclusion list, skipping: ', cur_target_state]);
				continue
			end


			if ismember({cur_target_state}, target_state_name_list)
				cur_target_state_start_tick_idx_list = triallog_table.([cur_target_state, '_tick_idx']);
				cur_target_state_end_tick_idx_list = triallog_table.([cur_target_state, '_end_tick_idx']);
			else
				cur_additional_epoch_name_ldx = ismember(additional_state_name_list, {cur_target_state});
				cur_target_state_start_tick_idx_list = triallog_table.(additional_state_start_tick_idx_col_name_list{cur_additional_epoch_name_ldx});
				cur_target_state_end_tick_idx_list = triallog_table.(additional_state_end_col_tick_idx_name_list{cur_additional_epoch_name_ldx});
			end

			for i_cycle = 1 : length(cur_target_state_start_tick_idx_list)
				% exclude bad cycles
				cur_target_state_start_tick_idx = cur_target_state_start_tick_idx_list(i_cycle);
				cur_target_state_end_tick_idx = cur_target_state_end_tick_idx_list(i_cycle);
				cur_cycle_state_duration_nticks = cur_target_state_end_tick_idx - cur_target_state_start_tick_idx;

				if isnan(cur_target_state_start_tick_idx) || isnan(cur_target_state_end_tick_idx) || (cur_target_state_start_tick_idx == 0) || (cur_target_state_end_tick_idx == 0)
					disp([mfilename, ': INFO: excluded cycle (', cur_target_state,'): ', num2str(i_cycle)]);
					continue
				end
				cur_target_stateXcycle_tick_ldx = all_false_tick_ldx;
				cur_target_stateXcycle_tick_ldx(cur_target_state_start_tick_idx:cur_target_state_end_tick_idx) = true;

				% this can be used for 2D plots... to exclude specific
				% cycles
				per_state_valid_tick_idx_ldx_array(cur_target_state_start_tick_idx:cur_target_state_end_tick_idx, i_target_state) = true;
				per_state_valid_tick_idx_per_cycle_idx_array(cur_target_state_start_tick_idx:cur_target_state_end_tick_idx, i_target_state) = triallog_table.trial_num(i_cycle);

				per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray(cur_target_state_start_tick_idx:cur_target_state_end_tick_idx, i_target_state) = per_tick_sessionID_cycle_list(cur_target_state_start_tick_idx:cur_target_state_end_tick_idx);



				% now figure out the per stateXcycle fixation percentages on
				% the different objects per trial, also for different gaze
				% sample types (near and far...
				cur_cycle_valid_gaze_tick_ldx = cur_target_stateXcycle_tick_ldx & valid_gaze_sample_ldx;	% let"s exclude untrustworthy gaze samples...

				
				cur_vergence_subset_string = 'allFixations';
				cur_gaze_samples_on_object_struct = fn_calculate_gaze_sample_count_and_proportions_per_object(record2D_table(cur_cycle_valid_gaze_tick_ldx, :), gaze_src_col_name_stem, reference_object_position_stem_list, reference_object_position_stem_closeness_threshold_list, gaze_to_object_mapping_rule, [], []);
				cur_gaze_samples_on_object_struct.cycle = triallog_table.trial_num(i_cycle);
				cur_gaze_samples_on_object_struct.sessionID = cur_sessionID;
				cur_gaze_samples_on_object_struct.epoch = fn_shorten_object_name_list(cur_epoch_name, [], []);
				cur_gaze_samples_on_object_struct.vergence = cur_vergence_subset_string;
				if isempty(gaze_on_object_prop_count_struct)
					gaze_on_object_prop_count_struct = cur_gaze_samples_on_object_struct;
				else
					gaze_on_object_prop_count_struct(end+1) = cur_gaze_samples_on_object_struct;
				end


				cur_vergence_subset_string = 'nearFixations';
				cur_gaze_samples_on_object_struct = fn_calculate_gaze_sample_count_and_proportions_per_object(record2D_table(cur_cycle_valid_gaze_tick_ldx & near_gaze_sample_ldx, :), gaze_src_col_name_stem, reference_object_position_stem_list, reference_object_position_stem_closeness_threshold_list, gaze_to_object_mapping_rule, [], []);
				cur_gaze_samples_on_object_struct.cycle = triallog_table.trial_num(i_cycle);
				cur_gaze_samples_on_object_struct.sessionID = cur_sessionID;
				cur_gaze_samples_on_object_struct.epoch = fn_shorten_object_name_list(cur_epoch_name, [], []);
				cur_gaze_samples_on_object_struct.vergence = cur_vergence_subset_string;
				if isempty(gaze_on_object_prop_count_struct)
					gaze_on_object_prop_count_struct = cur_gaze_samples_on_object_struct;
				else
					gaze_on_object_prop_count_struct(end+1) = cur_gaze_samples_on_object_struct;
				end

				cur_vergence_subset_string = 'farFixations';
				cur_gaze_samples_on_object_struct = fn_calculate_gaze_sample_count_and_proportions_per_object(record2D_table(cur_cycle_valid_gaze_tick_ldx & far_gaze_sample_ldx, :), gaze_src_col_name_stem, reference_object_position_stem_list, reference_object_position_stem_closeness_threshold_list, gaze_to_object_mapping_rule, [], []);
				cur_gaze_samples_on_object_struct.cycle = triallog_table.trial_num(i_cycle);
				cur_gaze_samples_on_object_struct.sessionID = cur_sessionID;
				cur_gaze_samples_on_object_struct.epoch = fn_shorten_object_name_list(cur_epoch_name, [], []);
				cur_gaze_samples_on_object_struct.vergence = cur_vergence_subset_string;
				if isempty(gaze_on_object_prop_count_struct)
					gaze_on_object_prop_count_struct = cur_gaze_samples_on_object_struct;
				else
					gaze_on_object_prop_count_struct(end+1) = cur_gaze_samples_on_object_struct;
				end
			end
		end

		gaze_on_object_prop_count_table = struct2table(gaze_on_object_prop_count_struct, 'AsArray', 1);

		% delete existing cache files to avoid these lingering around
		cache_wildcard_dir_string = regexprep(GazePropCount_cache_FQN, GazePropCount_hash, '*');	% construct the dir wildcard string
		existing_GazePropCount_cache_FQN_dirstruct = dir(cache_wildcard_dir_string);
		for i_tmp_cache_FQN = 1 : length(existing_GazePropCount_cache_FQN_dirstruct)
			delete(fullfile(existing_GazePropCount_cache_FQN_dirstruct(i_tmp_cache_FQN).folder, existing_GazePropCount_cache_FQN_dirstruct(i_tmp_cache_FQN).name));
		end
		%  save record2D_table and fixations_struct
		disp([mfilename, ': INFO: saving existing_GazePropCount_cache as cache: ', GazePropCount_cache_FQN]);
		save(GazePropCount_cache_FQN, 'gaze_on_object_prop_count_table', 'per_state_valid_tick_idx_per_cycle_idx_array', 'per_state_valid_tick_idx_ldx_array', 'per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray');
	end


	cur_duration_s = toc(timestamps.(mfilename).per_cycle_proportion_count_loop.start);
	disp([mfilename, ': Collecting per cycle and state gaze proportions took: ', num2str(cur_duration_s), ' seconds (', num2str(floor(cur_duration_s/(60*60))), ' hours ', num2str(floor(mod(cur_duration_s, 3600)/60)), ' minutes ', num2str(mod(cur_duration_s, 60)), ' seconds).']);


	% just pre process all
	%continue


	% define trial_sets
	dyadic_cycle_ldx = ismember(triallog_table.collection_type, {'joint', 'single'});
	solo_cycle_ldx = ismember(triallog_table.collection_type, {'solo_0', 'solo_1'});
	invalid_cycle_ldx = ismember(triallog_table.collection_type, {'None'});
	dyadic_solo_list = {'dyadic', 'solo', 'None'};
	cur_dyadic_solo_idx = zeros(size(dyadic_cycle_ldx));
	cur_dyadic_solo_idx(dyadic_cycle_ldx) = find(ismember(dyadic_solo_list, {'dyadic'}));
	cur_dyadic_solo_idx(solo_cycle_ldx) = find(ismember(dyadic_solo_list, {'solo'}));
	cur_dyadic_solo_idx(invalid_cycle_ldx) = find(ismember(dyadic_solo_list, {'None'}));
	%cur_dyadic_solo_idx(cur_dyadic_solo_idx == 0) = find(ismember(dyadic_solo_list, {'None'}));

	triallog_table.solo_dyadic = dyadic_solo_list(cur_dyadic_solo_idx)';


	invalid_cycle_ldx = ismember(triallog_table.collection_type, {'None'});
	valid_cycle_ldx = ~invalid_cycle_ldx & ~exclude_cycle_ldx;


	% plot far fixations and proportions of samples for dyadic

	% we likely should collect and merge the relevant data structures
	% across sessions to allow merging sessions.


	plot_2d_and_object_proportions = 1;
	if (plot_2d_and_object_proportions)

		plot_set_ldx_list = {dyadic_cycle_ldx, solo_cycle_ldx};
		plot_set_include_regexplist_list = {'dyadic', 'solo'};
		%plot_set_include_regexplist_list = {'solo'};

		% which epochs to show in which sequence
		sorted_col_set_list = {'Acquisition', 'CTS_collecting', 'CTS_rewarding', 'CTS_pre_acquisition'};
		sorted_row_set_list = {'nearFixations', 'farFixations'};

		% figure out which cycles to include per plot from triallog
		cur_key_col_list = {'sessionID', 'solo_dyadic'};
		[ plot_key_list, plot_existing_keyfields_ldx, plot_unique_keys, plot_data_row_key_idx_arr, plot_unique_keys_count_list ] = fn_generate_key_from_selected_table_columns_CCF(cur_key_col_list, triallog_table, '_');

		% triallog effective cycle_number (
		cur_key_col_list = {'sessionID', 'trial_num'};
		[triallog_cycle_key_list, triallog_cycle_existing_keyfields_ldx, triallog_cycle_unique_keys, triallog_cycle_data_row_key_idx_arr, triallog_cycle_unique_keys_count_list ] = fn_generate_key_from_selected_table_columns_CCF(cur_key_col_list, triallog_table, '_');
		

		% gaze_on_object_prop_count_table effective cycle_number (
		cur_key_col_list = {'sessionID', 'cycle'};
		[goopc_table_cycle_key_list, goopc_table__cycle_existing_keyfields_ldx, goopc_table_cycle_unique_keys, goopc_table_cycle_data_row_key_idx_arr, goopc_table_cycle_unique_keys_count_list ] = fn_generate_key_from_selected_table_columns_CCF(cur_key_col_list, gaze_on_object_prop_count_table, '_');



		% figure out which columns
		cur_key_col_list = {'epoch'};
		[ col_key_list, col_existing_keyfields_ldx, col_unique_keys, col_data_row_key_idx_arr, col_unique_keys_count_list ] = fn_generate_key_from_selected_table_columns_CCF(cur_key_col_list, gaze_on_object_prop_count_table, '_');
		n_cols = length(col_unique_keys_count_list);
		if exist('sorted_col_set_list', 'var') && ~isempty(sorted_col_set_list)
			n_cols = length(sorted_col_set_list);
		end


		% figure out which rows
		cur_key_col_list = {'vergence'};
		[ row_key_list, row_existing_keyfields_ldx, row_unique_keys, row_data_row_key_idx_arr, row_unique_keys_count_list ] = fn_generate_key_from_selected_table_columns_CCF(cur_key_col_list, gaze_on_object_prop_count_table, '_');
		n_rows = length(row_unique_keys_count_list);
		if exist('sorted_col_set_list', 'var') && ~isempty(sorted_col_set_list)
			n_rows = length(sorted_row_set_list);
		end
		% we also want to step through these as additional rows
		panel_request_list = {'gaze2D_per_epoch', 'gaze_on_object_proportion'};
		n_panels = length(panel_request_list);

		for i_plot = 1 : length(plot_unique_keys)
			cur_plot_set = plot_unique_keys{i_plot};
			disp([mfilename, ': INFO: Procession plot: ', cur_plot_set]);			
			if ~contains(cur_plot_set, regexpPattern(plot_set_include_regexplist_list))
				disp([mfilename, ': INFO: current plot set does not contain plot_set_include_regexplist_list, skipping: ', cur_plot_set]);
				continue
			end

			cur_plot_set_ldx = plot_data_row_key_idx_arr == i_plot;
			% the actual cycle numers to include
			cur_plot_set_cycle_list = triallog_table.trial_num(cur_plot_set_ldx & valid_cycle_ldx);
			
			% use the full cycle IDs including the session name
			cur_triallog_cycle_key_list = triallog_cycle_key_list(cur_plot_set_ldx & valid_cycle_ldx);

			% now translate to gaze_on_object_prop_count_table_ldx
			cur_plot_data_row_ldx = ismember(gaze_on_object_prop_count_table.cycle, cur_plot_set_cycle_list);

			% now translate to gaze_on_object_prop_count_table_ldx
			cur_plot_data_row_ldx = ismember(goopc_table_cycle_key_list, cur_triallog_cycle_key_list);



			% create a new figure
			cur_figure_stem = cur_plot_set;
			cur_fh = figure('Name', cur_figure_stem, 'visible', plotting_options_struct.figure_visibility_string);
			n_panel_cols = n_cols;
			n_panel_rows = n_rows * n_panels;	% here we want to use the rows for panels and the actual row type

			plot_width_cm = (plotting_options_struct.panel_width_cm * n_panel_cols);
			plot_height_cm = (plotting_options_struct.panel_height_cm * n_panel_rows);
			output_rect = fn_set_figure_outputpos_and_size(cur_fh, plotting_options_struct.margin_cm, plotting_options_struct.margin_cm, plot_width_cm, plot_height_cm, 1.0, 'portrait', 'inch');

			cur_fh_th = tiledlayout(cur_fh, n_panel_rows, n_panel_cols, 'TileSpacing', 'Compact', 'Padding', 'Compact');
			cur_ah_list = [];


			%[cur_target_state, '_', cur_vergence_subset_string, '_']
			% use this for columns

			for i_col = 1 : n_cols
				cur_col = i_col;
				if exist('sorted_col_set_list', 'var') && ~isempty(sorted_col_set_list)
					cur_col_name = sorted_col_set_list{i_col};
					cur_col_data_row_ldx = col_data_row_key_idx_arr == (find(ismember(col_unique_keys, {cur_col_name})));
				else
					% unsorted default
					cur_col_name = col_unique_keys{i_col};
					cur_col_data_row_ldx = col_data_row_key_idx_arr == i_col;
				end

				% to find the XY data for gaze2D_per_epoch
				% TODO: make tghis fot for merged sessions where the cycle
				% number alone is not sufficient
				cur_epoch_idx = find(ismember(short_all_epoch_name_list, {cur_col_name}));
				%cur_col_per_state_valid_tick_idx_per_cycle_idx_array = per_state_valid_tick_idx_per_cycle_idx_array(:, cur_epoch_idx);
				%cur_col_ticks_in_cycles_and_epochs_ldx = ismember(per_state_valid_tick_idx_per_cycle_idx_array(:, cur_epoch_idx), cur_plot_set_cycle_list);

				% use sessionID cycles instead as that allows to operate on
				% merged sessions...
				cur_col_per_state_valid_tick_sessionID_cycle_per_cycle_idx_list = per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray(:, cur_epoch_idx);
				cur_col_ticks_in_cycles_and_epochs_ldx = ismember(cur_col_per_state_valid_tick_sessionID_cycle_per_cycle_idx_list, cur_triallog_cycle_key_list);% this is costlier than the other methiod, but allows merrging sessions across days

	
				% use vergence
				for i_row = 1 : n_rows
					cur_row = i_row;
					if exist('sorted_row_set_list', 'var') && ~isempty(sorted_row_set_list)
						cur_row_name = sorted_row_set_list{i_row};
						cur_row_data_row_ldx = row_data_row_key_idx_arr == (find(ismember(row_unique_keys, {cur_row_name})));
					else
						% unsorted default
						cur_row_name = row_unique_keys{i_row};
						cur_row_data_row_ldx = row_data_row_key_idx_arr == i_row;
					end
		
					coolbar = cool(256);
					switch cur_row_name
						case 'allFixations'
							cur_vergence_gaze_sample_ldx = true(size(cur_col_ticks_in_cycles_and_epochs_ldx));
							fixation_color = [10, 200, 10]/255;
						case 'nearFixations'
							cur_vergence_gaze_sample_ldx = near_gaze_sample_ldx;
							fixation_color = coolbar(1, :);
						case 'farFixations'
							cur_vergence_gaze_sample_ldx = far_gaze_sample_ldx;
							fixation_color = coolbar(end, :);
					end

					cur_panel_gaze_sample_ldx = cur_col_ticks_in_cycles_and_epochs_ldx & cur_vergence_gaze_sample_ldx;

					for i_panel = 1 : n_panels
						cur_panel_row = ((cur_row - 1) * n_panels) + i_panel;
						cur_panel_type = panel_request_list{i_panel};

						% navigate to the intended tile
						cur_tilelocation = ((cur_panel_row - 1) * n_cols) + cur_col;

						% just select where to place the tile... that mapping needs
						cur_ah = nexttile(cur_fh_th, cur_tilelocation);
						cur_ah_list(end+1) = cur_ah;


						switch cur_panel_type
							case 'gaze2D_per_epoch'
								fixation_alpha = 0.025;
								face_ROI_radius = 1/7;

								hold on
								plot([0 1 1 0 0], [0 0 1 1 0], 'Color', [0 0 0], 'LineWidth', 1, 'DisplayName', 'Playing field');

								
								unique_B_face_center_list = unique([record2D_table.B_facecenter_X(cur_col_ticks_in_cycles_and_epochs_ldx), record2D_table.B_facecenter_Y(cur_col_ticks_in_cycles_and_epochs_ldx)], 'row');

								for i_unique_B_face_center = 1 : size(unique_B_face_center_list, 1)
									cur_face_ROI_center_XY = unique_B_face_center_list(i_unique_B_face_center, :);

									% find the current center_XY to pick up
									% the correct name
									cur_face_ROI_idx = find(ismember(face_ROI.center_XY, cur_face_ROI_center_XY, 'rows'));

									if ~paper_blocked
										cur_vh = viscircles(cur_face_ROI_center_XY, face_ROI_radius, 'Color', [0.7 0.7 0.7]);	% , 'DisplayName', 'Partner''s face'
									else
										cur_vh = viscircles(cur_face_ROI_center_XY, face_ROI_radius, 'Color', [0.7 0.7 0.7], 'LineStyle', '--');
									end
									set(cur_vh.Children(1), 'DisplayName', face_ROI.names{cur_face_ROI_idx});
								end

								color_by_face_center = 1;
								if (color_by_face_center) && size(unique_B_face_center_list, 1) > 1
									for i_unique_B_face_center = 1 : size(unique_B_face_center_list, 1)
										cur_face_ROI_center_XY = unique_B_face_center_list(i_unique_B_face_center, :);
										cur_face_ROI_idx = find(ismember(face_ROI.center_XY, cur_face_ROI_center_XY, 'rows'));
										cur_face_ROI_name = face_ROI.names{cur_face_ROI_idx};
										cur_record2D_table_face_center_XY = [record2D_table.B_facecenter_X, record2D_table.B_facecenter_Y];
										cur_face_ROI_tick_ldx = ismember(cur_record2D_table_face_center_XY, cur_face_ROI_center_XY, 'rows');
										cur_color = face_ROI.colors{cur_face_ROI_idx};

										if sum(cur_panel_gaze_sample_ldx & cur_face_ROI_tick_ldx) > 0
											cur_gaze2D_sh = scatter(cur_ah, record2D_table.([gaze_src_col_name_stem, '_X'])(cur_panel_gaze_sample_ldx & cur_face_ROI_tick_ldx),  record2D_table.([gaze_src_col_name_stem, '_Y'])(cur_panel_gaze_sample_ldx & cur_face_ROI_tick_ldx), 'filled', 'DisplayName', cur_row_name, 'SizeData', 3, 'MarkerEdgeColor', cur_color, 'MarkerFaceColor', cur_color, 'MarkerFaceAlpha', fixation_alpha, 'MarkerEdgeAlpha', fixation_alpha);
										end
									end
								else	
									if sum(cur_panel_gaze_sample_ldx) > 0
										cur_gaze2D_sh = scatter(cur_ah, record2D_table.([gaze_src_col_name_stem, '_X'])(cur_panel_gaze_sample_ldx),  record2D_table.([gaze_src_col_name_stem, '_Y'])(cur_panel_gaze_sample_ldx), 'filled', 'DisplayName', cur_row_name, 'SizeData', 3, 'MarkerEdgeColor', fixation_color, 'MarkerFaceColor', fixation_color, 'MarkerFaceAlpha', fixation_alpha, 'MarkerEdgeAlpha', fixation_alpha);
									end
								end

								axis equal
								hold off

								xlabel(cur_ah,'Azimuth [relative]', 'Interpreter', 'none', 'FontSize', plotting_options_struct.labelfontsize);
								ylabel(cur_ah, 'Elevation [relative]', 'Interpreter', 'none', 'FontSize', plotting_options_struct.labelfontsize)
								title(cur_ah, [cur_col_name], 'Interpreter', 'none', 'FontSize', plotting_options_struct.titlefontsize);
								%subtitle(cur_ah, [cur_plot_set], 'Interpreter', 'none', 'FontSize', plotting_options_struct.subtitlefontsize);
								subtitle(cur_ah, regexprep(cur_row_name, 'Fixations', ' Fixations'), 'Interpreter', 'none', 'FontSize', plotting_options_struct.subtitlefontsize);
								%subtitle(cur_ah, ['Partner position: ', cur_face_ROI_name, ' ', cur_set_name, ' trials around ', cur_col_name], 'Interpreter', 'none');
								%legend('Location','southeast');

								set(gca, 'XLim', [-0.2, 1.2]);
								set(gca, 'YLim', [-0.1, 1.3]);
								
								if (cur_col == 1)
									[matching_entry_ldx, non_matching_entry_ldx, matching_entry_idx] = fn_find_object_by_field_regexp( cur_ah.Children, 'Type', {'^scatter', '^line'});
									cur_lh = legend(cur_ah.Children(matching_entry_idx), 'Interpreter', 'none');
									cur_lh = legend(cur_ah, 'Location', 'southeast', 'FontSize', plotting_options_struct.legendfontsize, 'Box', 'off', 'Interpreter', 'none');
									cur_ah.Legend.ItemTokenSize=[10,15];	% reduce the length of the displayed line segment in the legen
								end

							case 'gaze_on_object_proportion'
								gaze_on_object_proportion.MarkerFaceAlpha = 0.5;
								gaze_on_object_proportion.MarkerEdgeAlpha = 0.5;
								gaze_on_object_proportion.data_col_name_list = {...
									...'A_binocular_eye_on_aims0_PCT',...
									...'A_binocular_eye_on_aims1_PCT', ...
									...'A_binocular_eye_on_agent0_PCT',...
									...'A_binocular_eye_on_agent1_PCT', ...
									'A_binocular_eye_on_target0_PCT', ...
									'A_binocular_eye_on_target1_PCT', ...
									'A_binocular_eye_on_target2_PCT', ...
									'A_binocular_eye_on_target3_PCT', ...
									'A_binocular_eye_on_target4_PCT', ...
									'A_binocular_eye_on_B_facecenter_PCT', ...
									};
									
								% find all relevant rows in gaze_on_object_prop_count_table
								cur_selected_set_ldx = cur_plot_data_row_ldx & cur_col_data_row_ldx & cur_row_data_row_ldx;
									
								cur_data_array = nan([sum(cur_selected_set_ldx), length(gaze_on_object_proportion.data_col_name_list)]);
								cur_xvec_array = cur_data_array;
								cur_name_vec = cell(size(gaze_on_object_proportion.data_col_name_list));


								add_all_target_fix_pct_col = 1;
								only_include_all_target_fix_pct = 1;

								all_target_fix_PCT_col = zeros([length(find(cur_selected_set_ldx)), 1]);	% for closest target we can synthesize the all target column by adding the individual target percentages


								for i_data_col = 1 : length(gaze_on_object_proportion.data_col_name_list)
									data_col_name = gaze_on_object_proportion.data_col_name_list{i_data_col};
									cur_data = gaze_on_object_prop_count_table.(data_col_name)(cur_selected_set_ldx);
									cur_X_vec = ones(size(cur_data)) * i_data_col;
									cur_data_array(:, i_data_col) = cur_data;
									cur_xvec_array(:, i_data_col) = cur_X_vec;
									cur_name_vec{i_data_col} = regexprep(regexprep(data_col_name, 'A_binocular_eye_on_', ''), '_PCT', '');
									cur_name_vec{i_data_col} = regexprep(cur_name_vec{i_data_col}, 'B_facecenter', 'face');
									% get the proper target type
									if (contains(cur_name_vec(i_data_col), regexpPattern('target[0-9]'))) && ~isempty(cur_data)

										all_target_fix_PCT_col = all_target_fix_PCT_col + cur_data;

										% get the cycle/trial number
										cur_cycle = gaze_on_object_prop_count_table.cycle(find(cur_selected_set_ldx, 1, 'first'));
										% get record2D tick index from
										% triallog for that cycle
										cur_tick_idx = triallog_table.collection_start_tick_idx(find(triallog_table.trial_num == cur_cycle, 1 , 'first'));
										cur_target_id = record2D_table.([cur_name_vec{i_data_col}, '_id'])(cur_tick_idx);
										% see enum_struct.target_id.name_list'
										switch cur_target_id
											case 0	% cooperative_targets_type_0
												cur_name_vec{i_data_col} = 'coop_A';
											case 1	% cooperative_targets_type_1
												cur_name_vec{i_data_col} = 'coop_B';
											case 2	% competitive_targets
												cur_name_vec{i_data_col} = 'comp';
											case 3 % punishing_targets
												cur_name_vec{i_data_col} = 'pun';
											case 4	% solo_targets_type_0
												cur_name_vec{i_data_col} = 'Solo_A';
											case 5	% solo_targets_type_1
												cur_name_vec{i_data_col} = 'Solo_B';
										end
									end
								end

								ignore_target_col_ldx = false(size(cur_name_vec));
								if (add_all_target_fix_pct_col)
									% we add this as first column
									cur_data_array = [all_target_fix_PCT_col, cur_data_array];
									cur_xvec_array(:, end+1) = ones(size(cur_data)) * length(gaze_on_object_proportion.data_col_name_list) + 1;
									cur_name_vec = ['Targets', cur_name_vec];
									
									% if we only want aggregate target
									% fixations remove the inividual target
									% columns
									ignore_target_col_ldx = false(size(cur_name_vec));

									if (only_include_all_target_fix_pct)
										ignore_target_col_ldx = ismember(cur_name_vec, {'coop_A', 'coop_B', 'comp', 'pun', 'Solo_A', 'Solo_B', 'target0', 'target1', 'target2', 'target3', 'target4', 'target5', 'target6', 'target7', 'target8', 'target9'});
									end
								end

								include_col_ldx = ~ignore_target_col_ldx;

								% shape down to included columns
								if any(ignore_target_col_ldx)
									cur_name_vec(ignore_target_col_ldx) = [];
									cur_data_array(:, ignore_target_col_ldx) = [];
									% this next one just gives the x values
									% which we want to increment from 1
									cur_xvec_array = cur_xvec_array(:, 1:sum(include_col_ldx));
								end
								
								% now do some statistics across the
								% selected columns?



								hold on
								if ~all(isnan(cur_data_array(:)))
									swarmchart(cur_ah, cur_xvec_array, cur_data_array, 'filled', 'MarkerFaceAlpha', gaze_on_object_proportion.MarkerFaceAlpha, 'MarkerEdgeAlpha', gaze_on_object_proportion.MarkerEdgeAlpha, 'DisplayName', ['prop' '_', cur_row_name], 'SizeData', 3);
									boxplot(cur_ah, cur_data_array, 'Symbol','');	% show no outliers, as we already show a swarmplot
								

									%xlabel(cur_ah,'gaze target', 'Interpreter', 'none', 'FontSize', plotting_options_struct.labelfontsize);
									xticklabels(cur_name_vec)
									ylabel(cur_ah, 'Proportion of gaze samples [%]', 'Interpreter', 'none', 'FontSize', plotting_options_struct.labelfontsize)
									%title(cur_ah, [cur_col_name], 'Interpreter', 'none', 'FontSize', plotting_options_struct.titlefontsize);
									%subtitle(cur_ah, '', 'Interpreter', 'none', 'FontSize', plotting_options_struct.subitlefontsize);
								end

							otherwise
								error([mfilename, ': ERROR: unkown cur_panel_type: ', cur_panel_type]);
						end

					end

				end
			end

			title(cur_fh_th, [cur_figure_stem, ', N_cycles : ', num2str(length(cur_plot_set_cycle_list))], 'Interpreter', 'none', 'FontSize', plotting_options_struct.titlefontsize+2);

			cur_out_FQN = fullfile(out_dir, 'per_session', [cur_figure_stem, '.', gaze_src_col_name_stem, '.', 'gaze2D_gaze_prop', '.pdf']);
			disp(['Saving figure as: ', cur_out_FQN]);
			write_out_figure(cur_fh, cur_out_FQN, [], [], plotting_options_struct.format_string_list);
		end
	end





	if (show_2D_fixations)
		% find relevant fixations around events
		ref_event_col_stem_name = 'col_targ_initiate_reward'; % either tick_idx or start_s
		gaze_epoch_duration_s = 2;

		ref_event_start_s_list = triallog_table.([ref_event_col_stem_name, '_start_s']);
		ref_event_start_tick_idx_list = triallog_table.([ref_event_col_stem_name, '_tick_idx']);
		ref_event_end_s_list = ref_event_start_s_list + gaze_epoch_duration_s;
		ref_event_end_tick_idx_list = nan(size(ref_event_end_s_list));

		fixID_in_ref_epoch_cell = cell(size(ref_event_end_tick_idx_list));
		for i_ref_event_end_s = 1 : length(ref_event_end_s_list)
			[min_val, closest_row_idx] = min(abs(record2D_table.timestamp - ref_event_end_s_list(i_ref_event_end_s)));

			% lets not spill into the next cycle...
			if (closest_row_idx > triallog_table.trial_end_tick_idx(i_ref_event_end_s))
				closest_row_idx = triallog_table.trial_end_tick_idx(i_ref_event_end_s);
			end

			ref_event_end_tick_idx_list(i_ref_event_end_s) = closest_row_idx;

			if isnan(ref_event_start_tick_idx_list(i_ref_event_end_s)) || isnan(ref_event_end_tick_idx_list(i_ref_event_end_s))
				fixID_in_ref_epoch = [];
			else
				fixID_in_ref_epoch = unique(record2D_table.A_binocular_eye_per_sample_fixID(ref_event_start_tick_idx_list(i_ref_event_end_s) : ref_event_end_tick_idx_list(i_ref_event_end_s)));
			end
			fixID_in_ref_epoch(fixID_in_ref_epoch == 0) = [];
			fixID_in_ref_epoch_cell{i_ref_event_end_s} = fixID_in_ref_epoch;
		end



		% here we do not care about actual runs, but want to merge all trials
		% per face position?
		[unique_per_run_face_ROI_idx, ~, unique_per_run_face_ROI_idx_row_idx] = unique(per_run_face_ROI_idx, 'stable');

		for i_unique_per_run_face_ROI = 1 : length(unique_per_run_face_ROI_idx)
			cur_unique_per_run_face_ROI_idx = unique_per_run_face_ROI_idx(i_unique_per_run_face_ROI);
			cur_src_run_ldx = unique_per_run_face_ROI_idx_row_idx == i_unique_per_run_face_ROI;
			cur_src_run_idx_in_set = unique_src_run_idx(cur_src_run_ldx);
			cur_src_run_set_cycle_ldx = ismember(triallog_table.src_run_idx, cur_src_run_idx_in_set);	% this excludes "bad/empty" cycles

			cur_face_ROI_idx = cur_unique_per_run_face_ROI_idx;
			cur_face_ROI_name = face_ROI.names{cur_face_ROI_idx};
			cur_face_ROI_center_XY_pixel = face_ROI.center_XY_pixel(cur_face_ROI_idx, :);
			cur_face_ROI_center_XY = face_ROI.center_XY(cur_face_ROI_idx, :);

			cycle_sets.names = {'dyadic', 'solo'};
			cycle_sets.set_ldx_list = {dyadic_cycle_ldx & cur_src_run_set_cycle_ldx, solo_cycle_ldx & cur_src_run_set_cycle_ldx};

			for i_cycle_sets = 1 : length(cycle_sets.names)
				cur_set_name = cycle_sets.names{i_cycle_sets};
				cur_cycles_in_set_ldx = cycle_sets.set_ldx_list{i_cycle_sets};


				% fixations in current set and ref_epoch
				fixations_in_cur_set = fixID_in_ref_epoch_cell(cur_cycles_in_set_ldx);
				cur_fixID_in_current_set_ldx = false(size(near_fixation_ldx));
				for i_cycle = 1 : length(fixations_in_cur_set)
					cur_fixIDs = fixations_in_cur_set{i_cycle};
					cur_fixID_in_current_set_ldx(cur_fixIDs) = true;
				end


				cur_fh = figure('Name', [proto_varname_session_id, ' Fixation position, partner ', cur_face_ROI_name, ' ', cur_set_name, ' trials around ', ref_event_col_stem_name]);
				fixation_color = [10, 200, 10]/255;
				coolbar = cool(256);
				near_fix_color = coolbar(1, :);
				far_fix_color = coolbar(end, :);
				fixation_alpha = 0.1;
				face_ROI_radius = 1/6;

				hold on
				plot([0 1 1 0 0], [0 0 1 1 0], 'Color', [0 0 0], 'LineWidth', 1, 'DisplayName', 'Playing field');
				if ~paper_blocked
					viscircles(cur_face_ROI_center_XY, face_ROI_radius, 'Color', [0.7 0.7 0.7]);	% , 'DisplayName', 'Partner''s face'
				else
					viscircles(cur_face_ROI_center_XY, face_ROI_radius, 'Color', [0.7 0.7 0.7], 'LineStyle', '--');
				end

				cur_fixation_ldx = cur_fixID_in_current_set_ldx & (near_fixation_ldx | far_fixation_ldx);
				%scatter(fixations_struct.A_binocular_eye.mean_X_CCF(cur_fixation_ldx),
				%fixations_struct.A_binocular_eye.mean_Y_CCF(cur_fixation_ldx), 'filled', 'SizeData', 15, 'MarkerEdgeColor', fixation_color, 'MarkerFaceColor', fixation_color, 'MarkerFaceAlpha', fixation_alpha, 'MarkerEdgeAlpha', fixation_alpha);
				cur_fixation_ldx = cur_fixID_in_current_set_ldx & near_fixation_ldx;
				scatter(fixations_struct.A_binocular_eye.mean_X_CCF(cur_fixation_ldx), fixations_struct.A_binocular_eye.mean_Y_CCF(cur_fixation_ldx), 'filled', 'DisplayName', 'near','SizeData', 15, 'MarkerEdgeColor', near_fix_color, 'MarkerFaceColor', near_fix_color, 'MarkerFaceAlpha', fixation_alpha, 'MarkerEdgeAlpha', fixation_alpha);
				cur_fixation_ldx = cur_fixID_in_current_set_ldx & far_fixation_ldx;
				scatter(fixations_struct.A_binocular_eye.mean_X_CCF(cur_fixation_ldx), fixations_struct.A_binocular_eye.mean_Y_CCF(cur_fixation_ldx), 'filled', 'DisplayName', 'far', 'SizeData', 15, 'MarkerEdgeColor', far_fix_color, 'MarkerFaceColor', far_fix_color, 'MarkerFaceAlpha', fixation_alpha, 'MarkerEdgeAlpha', fixation_alpha);
				axis equal
				hold off
				cur_ah = gca();

				xlabel(cur_ah,'Azimuth [relative]');
				ylabel(cur_ah, 'Elevation [relative]')
				title(cur_ah, ['Fixations near/far: ', proto_varname_session_id], 'Interpreter', 'none');
				subtitle(cur_ah, ['Partner position: ', cur_face_ROI_name, ' ', cur_set_name, ' trials around ', ref_event_col_stem_name], 'Interpreter', 'none');
				%legend('Location','southeast');

				[matching_entry_ldx, non_matching_entry_ldx, matching_entry_idx] = fn_find_object_by_field_regexp( cur_ah.Children, 'Type', {'^scatter'});

				legend(cur_ah.Children(matching_entry_idx), 'Interpreter', 'none');
				legend(cur_ah, 'Location', 'southeast', 'FontSize', plotting_options_struct.legendfontsize, 'Box', 'off', 'Interpreter', 'none');
				cur_ah.Legend.ItemTokenSize=[10,15];	% reduce the length of the displayed line segment in the legend

				cur_out_FQN = fullfile(out_dir, 'per_session', [proto_varname_session_id, '.', cur_face_ROI_name, '.', cur_set_name, '.', ref_event_col_stem_name, '']);
				disp(['Saving figure as: ', cur_out_FQN]);
				write_out_figure(cur_fh, cur_out_FQN);

			end
		end
	end

	%separtely collection types for dyadic/single and solo_0/solo_1, exclude 'None'


	% now first plot a 2D histogram of gaze positions (as scatter with transparency)

	% now select the subset of trials from triallog_table where no target
	% was displayed over the face

	% now restrict to relevant task epoch

	% restrict to runs	triallog_table.src_run_idx


	timestamps.(mfilename).(varname_session_id).end = toc(timestamps.(mfilename).(varname_session_id).start);
	cur_duration_s = timestamps.(mfilename).(varname_session_id).end;
	disp([mfilename, ': ', proto_varname_session_id, ' took: ', num2str(timestamps.(mfilename).(varname_session_id).end), ' seconds (', num2str(floor(cur_duration_s/(60*60))), ' hours ', num2str(floor(rem(cur_duration_s, 3600)/60)), ' minutes ', num2str(mod(cur_duration_s, 60)), ' seconds).']);
end


% final end...
timestamps.(mfilename).end = toc(timestamps.(mfilename).start);
cur_duration_s = timestamps.(mfilename).end;
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end), ' seconds (', num2str(floor(cur_duration_s/(60*60))), ' hours ', num2str(floor(rem(cur_duration_s, 3600)/60)), ' minutes ', num2str(mod(cur_duration_s, 60)), ' seconds).']);

end

