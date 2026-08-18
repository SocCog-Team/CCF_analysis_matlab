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
show_cycle_spatial_trajectories = 0;	% one tiled figure per sessionID x cycle (epochs x source rows)
show_cycle_spatial_trajectories_xsession = 0;	% one tiled figure per sessionID x cycle (epochs x source rows)
cycle_spatial_plot_sessionID_cycle_ldx = [];	% [] = all cycles; or logical/numeric index into unique sessionID_cycle keys
cycle_spatial_source_stem_regexp_list = {'^aims[01]_X$', '^agent[01]_X$', '^[AB]_binocular_eye_X$'};
cycle_spatial_source_row_name_list = {'hands', 'cursors', 'gaze'};
cycle_spatial_goopc_pct_col_regexp_list = { ...
	'^A_binocular_eye_on_target[0-4]_PCT$', ...
	'^A_binocular_eye_on_B_facecenter_PCT$', ...
	'^A_binocular_eye_on_aims[01]_PCT$', ...
	...'^A_binocular_eye_on_aims[01]_PCT$', ...
	};
cycle_spatial_goopc_bar_vergence_list = {'nearFixations', 'farFixations'};
plot_2d_and_object_proportions = 0;
plot_2d_and_object_proportions_xsession = 1;
perform_dyadic_solo_comparison = 0;
perform_dyadic_solo_comparison_xsession = 1;
dyadic_solo_significance_test_method = 'ranksum';      % 'glme' | 'ranksum' | 'ttest'
dyadic_solo_significance_label_mode = 'direction'; % 'stars' | 'direction'

% if we run this directly for testing we want/need this to be in the
% path...
by_host_DirectoriesStruct = GetDirectoriesByHostName('local_code');
if ~exist('cur_CCF_runfolder_FQN_list', 'var')
	CCF_analysis_path = fullfile(by_host_DirectoriesStruct.local.SCP_CODE_BaseDir , 'CCF_analysis_matlab');
	% delete existing paths containing the calling directory
	% this is a work around for matlab's inability to detect changed files on
	% most network shares
	if ~isempty(strfind(path, [CCF_analysis_path, pathsep]))
		path_string = path;
		disp('Current directory already in the path; deleting all subdirectories from the path to work around network share issues...');
		% turn the path into cell array
		while length(path_string) > 0
			[cur_path_item, remain] = strtok(path_string, pathsep);
			path_string = remain(2:end);
			if ~isempty(strfind(cur_path_item, CCF_analysis_path))
				rmpath(cur_path_item);
			end
		end
	end
	% now add them again
	addpath(genpath(CCF_analysis_path));
end

[SESSIONLOGS_dir, cur_SCP_DATA_BaseDir] = fn_get_SESSIONLOGS_dir_for_host();

out_dir = fullfile(SESSIONLOGS_dir, 'CCF', 'GAZE_ANALYSIS');
plotting_options_struct = fn_BoS_ephys_default_plotting_options;
% overrides
plotting_options_struct.format_string_list = {'.png', '.fig'};
plotting_options_struct.color_struct = fn_define_color_struct_CCF();
close_plots_automatically = 1;
plotting_options_struct.figure_visibility_string = 'off';	% invisible figures should be faster...

if ~exist('cur_CCF_runfolder_FQN_list', 'var') || isempty(cur_CCF_runfolder_FQN_list)
	cur_CCF_runfolder_FQN_list = { ...
		fullfile(SESSIONLOGS_dir, '2025', '251219', '20251219TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	%  1: re-run with correct scaling
		fullfile(SESSIONLOGS_dir, '2026', '260204', '20260204TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	%  2: correct scaling
		fullfile(SESSIONLOGS_dir, '2026', '260206', '20260206TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	%  3: correct scaling
		fullfile(SESSIONLOGS_dir, '2026', '260306', '20260306TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	%  4:
		fullfile(SESSIONLOGS_dir, '2026', '260312', '20260312TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	%  5:
		fullfile(SESSIONLOGS_dir, '2026', '260319', '20260319TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	%  6: first session with monkey gaze data...
		fullfile(SESSIONLOGS_dir, '2026', '260320', '20260320TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	%  7: session with gaze data, but with broken calibration data, take calibration from 260319
		fullfile(SESSIONLOGS_dir, '2026', '260325', '20260325TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	%  8:
		fullfile(SESSIONLOGS_dir, '2026', '260326', '20260326TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	%  9:
		fullfile(SESSIONLOGS_dir, '2026', '260402', '20260402TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 10:
		fullfile(SESSIONLOGS_dir, '2026', '260403', '20260403TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 11:
		fullfile(SESSIONLOGS_dir, '2026', '260409', '20260409TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 12:
		fullfile(SESSIONLOGS_dir, '2026', '260423', '20260423TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 13:
		fullfile(SESSIONLOGS_dir, '2026', '260424', '20260424TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	5 14:
		fullfile(SESSIONLOGS_dir, '2026', '260428', '20260428TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	5 15:
		fullfile(SESSIONLOGS_dir, '2026', '260429', '20260429TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	5 16:
		fullfile(SESSIONLOGS_dir, '2026', '260430', '20260430TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	5 17:
		fullfile(SESSIONLOGS_dir, '2026', '260501', '20260501TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	5 18:
		};

	%cur_CCF_runfolder_FQN_list = cur_CCF_runfolder_FQN_list(end); % clear up to 7
	%	cur_CCF_runfolder_FQN_list = cur_CCF_runfolder_FQN_list(6:end); % clear up to 7
	%	cur_CCF_runfolder_FQN_list = cur_CCF_runfolder_FQN_list(end); % clear up to 7
	cur_CCF_runfolder_FQN_list = cur_CCF_runfolder_FQN_list(6:end); % clear up to 7

	%cur_CCF_runfolder_FQN_list = cur_CCF_runfolder_FQN_list(6:7); % clear up to 7
	%cur_CCF_runfolder_FQN_list = cur_CCF_runfolder_FQN_list(end-1:end); % clear up to 7
	%cur_CCF_runfolder_FQN_list = cur_CCF_runfolder_FQN_list([6 7 8 9 10 11 12 13 14 17 18]); % clear up to 7


	only_process_gaze_calibration = 0;
	if (only_process_gaze_calibration)
		% the gaze calibration sessions...
		cur_CCF_runfolder_FQN_list = { ...
			...fullfile(SESSIONLOGS_dir, '2026', '260319', '20260319T110006.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% first session with monkey gaze data...
			...fullfile(SESSIONLOGS_dir, '2026', '260320', '20260320TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% the calibration routine was broken, this session uses the calibration from 260319 instead
			...fullfile(SESSIONLOGS_dir, '2026', '260326', '20260326T103026.A_Elmo.B_NONE.SCP_01.sessiondir'), ...
			...fullfile(SESSIONLOGS_dir, '2026', '260326', '20260326T103026.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 12
			...fullfile(SESSIONLOGS_dir, '2026', '260402', '20260402T100142.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 12
			...fullfile(SESSIONLOGS_dir, '2026', '260403', '20260403T093508.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 12
			...fullfile(SESSIONLOGS_dir, '2026', '260409', '20260409T100642.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 12
			...fullfile(SESSIONLOGS_dir, '2026', '260423', '20260423T102851.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 13
			...fullfile(SESSIONLOGS_dir, '2026', '260424', '20260424T101945.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 13
			...fullfile(SESSIONLOGS_dir, '2026', '260428', '20260428T102602.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 13
			...fullfile(SESSIONLOGS_dir, '2026', '260429', '20260429T100042.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 13
			...fullfile(SESSIONLOGS_dir, '2026', '260430', '20260430T090028.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 13
			...fullfile(SESSIONLOGS_dir, '2026', '260501', '20260501T085455.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 13
			};
	end
	% use a file picker to select the desired folder
end

if ~iscell(cur_CCF_runfolder_FQN_list)
	cur_CCF_runfolder_FQN_list = {cur_CCF_runfolder_FQN_list};
end

% config
max_cycle_duration_s = 10;	% exclude cycles longer than this
mean_dX_CCF_threshold = 0.05;	%(values smaller near fixation, values larger far fixations)
% sample based
min_gaze_confidence = 0.50;	% for binocular dominated by the eye with lower signal
valid_X_range = [-0.1, 1.1];	% add some margin around the playing field for valid samples
valid_Y_range = [-0.1, 1.1];	% add some margin around the playing field for valid samples

gaze_src_col_name_stem = 'A_binocular_eye';

additional_state_name_list = {'Acquisition'};	% these do not map fully onto target states
additional_state_start_tick_idx_col_name_list = {'PDD_onset_tick_idx'};
additional_state_end_col_tick_idx_name_list = {'collecting_by_agent_start_tick_idx'};




% collector struct for the individual session data
xsession.sessiondir_list = {};
xsession.sessionID_list = {};
xsession.gaze_on_object_prop_count_table = [];
xsession.per_state_valid_tick_idx_per_cycle_idx_array = [];
xsession.per_state_valid_tick_idx_ldx_array = [];
xsession.per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray = [];
xsession.record2D_table = [];
xsession.triallog_table = [];
xsession.per_run_face_ROI_idx = [];

% loop over the sessions to do your thing...
for i_runfolder = 1 : length(cur_CCF_runfolder_FQN_list)
	cur_CCF_runfolder_FQN = cur_CCF_runfolder_FQN_list{i_runfolder};
	disp(['Processing: ', cur_CCF_runfolder_FQN]);

	[~, proto_varname_session_id, tmp_ext] = fileparts(cur_CCF_runfolder_FQN);
	if ~strcmp(tmp_ext, '.sessiondir')
		error([mfilename, ': WARN: session folder does not end in .sessiondir...']);
	end

	xsession.sessiondir_list(end+1) = {cur_CCF_runfolder_FQN};

	cur_sessionID = proto_varname_session_id;
	varname_session_id = fn_sanitize_value_as_matlab_variable_name(proto_varname_session_id, 1 ,1);
	timestamps.(mfilename).(varname_session_id).start = tic;

	xsession.sessionID_list(end+1) = {cur_sessionID};

	% we need per sesson-run information about the approximate position of
	% the partner's face





	% loading current session
	disp('Parsing current session CCF data, might take a while');
	%[triallog_table, record_struct, record2D_table, sorted_target_state_transition_table, AI_samples_struct, DI_samples_struct, json_struct, h5_struct, txt_struct, jsonl_struct, enum_struct, fixations_struct, orig_GAZE_OPTS_struct] = fn_parse_CCF_data( cur_CCF_runfolder_FQN );
	[triallog_table, record_struct, record2D_table, sorted_target_state_transition_table, AI_samples_struct, DI_samples_struct, json_struct, h5_struct, txt_struct, jsonl_struct, enum_struct, fixations_struct, orig_GAZE_OPTS_struct] = fn_parse_CCF_data( cur_CCF_runfolder_FQN );

	% to save memory...
	superfluous_varaiable_list = {'record_struct', 'AI_samples_struct', 'DI_samples_struct', 'h5_struct', 'txt_struct', 'jsonl_struct'};
	clear(superfluous_varaiable_list{:});



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
	% this needs the conf_struct so can npot be done statically outside
	% the loop
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

	% to estimate the expected fixations on the face by chance we want to
	% fraction of the face ROI arae to the toalf included playing field
	% area
	face_ROI.radius = 1/7;	% radius of the face ROI in relative CCF units
	face_ROI.area = (face_ROI.radius)^2 * pi;
	face_ROI.included_playing_field_area = diff(valid_X_range) * diff(valid_Y_range);
	face_ROI.face_ratio_of_included_playing_field_PCT = 100 * face_ROI.area / face_ROI.included_playing_field_area;

	xsession.face_ROI = face_ROI;	% this is alwys the same but to keep thjings simple just re-assign on each iteration

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
			per_run_face_ROI_idx(end) = 1;

		case '20260429TNNNNNNM.A_Elmo.B_MIXED.SCP_01'
			per_run_face_ROI_idx = repmat(find(ismember(face_ROI.names, {'face_right'})), n_src_runs, 1);
			per_run_face_ROI_idx(end) = 1;

		case '20260430TNNNNNNM.A_Elmo.B_MIXED.SCP_01'
			per_run_face_ROI_idx = [find(ismember(face_ROI.names, {'face_right'})); find(ismember(face_ROI.names, {'facecenter'})); find(ismember(face_ROI.names, {'facecenter'}))];

		case '20260501TNNNNNNM.A_Elmo.B_MIXED.SCP_01'
			per_run_face_ROI_idx = [find(ismember(face_ROI.names, {'face_right'})); find(ismember(face_ROI.names, {'face_left'})); find(ismember(face_ROI.names, {'facecenter'}))];

		otherwise
			% assume the partner normally sits opposite to the monkey...
			% note we default to facecenter even for solo right now
			per_run_face_ROI_idx = repmat(find(ismember(face_ROI.names, {'facecenter'})), n_src_runs, 1);
	end

	if isempty(xsession.per_run_face_ROI_idx)
		xsession.per_run_face_ROI_idx = per_run_face_ROI_idx;
	else
		xsession.per_run_face_ROI_idx = [xsession.per_run_face_ROI_idx; per_run_face_ROI_idx];
	end


	% now add the partner face center positpion and paper_block information
	% to the triallog_table and record2D_table
	% TODO also add A_s face position
	record2D_table.B_facecenter_X = face_ROI.center_XY(per_run_face_ROI_idx(record2D_table.run_idx + 1), 1);
	record2D_table.B_facecenter_Y = face_ROI.center_XY(per_run_face_ROI_idx(record2D_table.run_idx + 1), 2);
	record2D_table.paper_blocked = zeros([size(record2D_table, 1) 1]) + paper_blocked;	% TODO change to per run parameter?

	triallog_table.B_facecenter_XY = face_ROI.center_XY(per_run_face_ROI_idx(triallog_table.src_run_idx), :);
	triallog_table.paper_blocked = zeros([size(triallog_table, 1) 1]) + paper_blocked;	% TODO change to per run parameter?


	if isempty(xsession.record2D_table)
		xsession.record2D_table = record2D_table;
	else
		xsession.record2D_table = [xsession.record2D_table; record2D_table];
	end



	% exclude cycles longer than X seconds
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


	% define trial_sets
	dyadic_cycle_ldx = ismember(triallog_table.collection_type, {'joint', 'single'});
	solo_cycle_ldx = ismember(triallog_table.collection_type, {'solo_0', 'solo_1'});
	invalid_cycle_ldx = ismember(triallog_table.collection_type, {'None'});
	dyadic_solo_list = {'dyadic', 'solo', 'None'};
	cur_dyadic_solo_idx = zeros(size(dyadic_cycle_ldx));
	cur_dyadic_solo_idx(dyadic_cycle_ldx) = find(ismember(dyadic_solo_list, {'dyadic'}));
	cur_dyadic_solo_idx(solo_cycle_ldx) = find(ismember(dyadic_solo_list, {'solo'}));
	cur_dyadic_solo_idx(invalid_cycle_ldx) = find(ismember(dyadic_solo_list, {'None'}));
	cur_dyadic_solo_idx(cur_dyadic_solo_idx == 0) = find(ismember(dyadic_solo_list, {'None'}));
	triallog_table.solo_dyadic = dyadic_solo_list(cur_dyadic_solo_idx)';


	invalid_cycle_ldx = ismember(triallog_table.collection_type, {'None'});
	valid_cycle_ldx = ~invalid_cycle_ldx & ~exclude_cycle_ldx;

	if isempty(xsession.triallog_table)
		xsession.triallog_table = triallog_table;
	else
		xsession.triallog_table = [xsession.triallog_table; triallog_table];
	end



	% define a relevant time window per trial

	% threshold fixations into near and far based on mean_dX_CCF, look at
	% the histogram to define this threshold empirically
	%figure('Name', 'mean_dX_CCF');
	%histogram(fixations_struct.A_binocular_eye.mean_dX_CCF, 100)
	%mean_dX_CCF_threshold = 0.05;	%(values smaller near fixation, values larger far fixations)
	near_fixation_ldx = fixations_struct.A_binocular_eye.mean_dX_CCF <= mean_dX_CCF_threshold;
	far_fixation_ldx = fixations_struct.A_binocular_eye.mean_dX_CCF > mean_dX_CCF_threshold;

	% sample based
	%min_gaze_confidence = 0.85;%
	%gaze_src_col_name_stem = 'A_binocular_eye';
	valid_gaze_sample_ldx = record2D_table.([gaze_src_col_name_stem, '_confidence']) >= min_gaze_confidence;

	%% to check/select min_gaze_confidence use:
	%cur_fh = figure();
	%set(cur_fh, "Visible", 'On');
	%hh = histogram(record2D_table.([gaze_src_col_name_stem, '_confidence']), 1000);

	% 20260615 agred with igor, we only want to count samples on the paying
	% field and 10% around it
	valid_gaze_sample_ldx = valid_gaze_sample_ldx & record2D_table.([gaze_src_col_name_stem, '_X']) >= valid_X_range(1) & record2D_table.([gaze_src_col_name_stem, '_X']) <= valid_X_range(2);
	valid_gaze_sample_ldx = valid_gaze_sample_ldx & record2D_table.([gaze_src_col_name_stem, '_Y']) >= valid_Y_range(1) & record2D_table.([gaze_src_col_name_stem, '_Y']) <= valid_Y_range(2);

	near_gaze_sample_ldx = record2D_table.([gaze_src_col_name_stem, '_dX']) <= mean_dX_CCF_threshold;
	far_gaze_sample_ldx = record2D_table.([gaze_src_col_name_stem, '_dX']) > mean_dX_CCF_threshold;



	% TODO iterate over epochs:
	% acquisition period: target collection period: reward_period,
	% pre_acquisiton

	% % exclude cycles longer than X seconds
	% max_cycle_duration_s = 10;
	% cycle_duration_list = triallog_table.cycle_end_s - triallog_table.cycle_start_s;
	% exclude_cycle_ldx =  cycle_duration_list > max_cycle_duration_s;
	% exclude_tick_ldx = record2D_table.timestamp > 0;
	%
	% % invert logic to exclude by default
	% for i_cycle = 1 : length(exclude_cycle_ldx)
	% 	if ~exclude_cycle_ldx(i_cycle)
	% 	cur_trial_start_tick_idx = triallog_table.cycle_start_tick_idx(i_cycle);
	% 	cur_trial_end_tick_idx = triallog_table.cycle_end_tick_idx(i_cycle) ;
	% 	if (cur_trial_start_tick_idx > 0) && (cur_trial_end_tick_idx > 0)
	% 	exclude_tick_ldx(cur_trial_start_tick_idx:cur_trial_end_tick_idx) = false;
	% 	end
	% 	end
	% end

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
	% additional_state_name_list = {'Acquisition'};	% these do not map fully onto target states
	% additional_state_start_tick_idx_col_name_list = {'PDD_onset_tick_idx'};
	% additional_state_end_col_tick_idx_name_list = {'collecting_by_agent_start_tick_idx'};

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
	reference_object_position_stem_closeness_threshold_list = [zeros(size(aim_prefix_list)) + 0.05, zeros(size(agent_prefix_list)) + conf_struct.agent_radius*1.5, zeros(size(target_prefix_list)) + conf_struct.target_radius*1.5, face_ROI.radius];


	reference_object_position_stem_list = [target_prefix_list, 'B_facecenter'];	% use for closest_object_within_threshold
	reference_object_position_stem_closeness_threshold_list = [zeros(size(target_prefix_list)) + conf_struct.target_radius*1.5, face_ROI.radius];

	% 20260515 agrred with Igor:
	reference_object_position_stem_list = [	aim_prefix_list, ...
											target_prefix_list, ...
											'B_facecenter'];	% use for closest_object_within_threshold
	reference_object_position_stem_closeness_threshold_list = [	zeros(size(aim_prefix_list)) + conf_struct.target_radius*2*1.1, ...
																zeros(size(target_prefix_list)) + conf_struct.target_radius*1.5, ...
																face_ROI.radius];


	% we want/need to test for each sample whether it is close
	% enough to any object to be cpunted as on that object
	% for now do not assign things exclusively (by picking the closest if multiple objects qualify)

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

	version_string = 'v.010';
	target_state_exclusion_list = {'col_targ_initiate_reward'};% skip these states, col_targ_initiate_reward should only last 1 cycle...
	gaze_to_object_mapping_rule = 'all';	% all: each gaze sample is counted for all below threshold distance objects ; closest_within_threshold: pick the closest object fullfilling the threshold condition


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
				% add some aggregate columns: aims_total, agents_total,
				% target_total, selected_target, nonselected_targets
				cur_gaze_samples_on_object_struct = fn_add_selected_target_gaze_columns_CCF( cur_gaze_samples_on_object_struct, triallog_table(i_cycle, :), gaze_src_col_name_stem, target_prefix_list);

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
				cur_gaze_samples_on_object_struct = fn_add_selected_target_gaze_columns_CCF( cur_gaze_samples_on_object_struct, triallog_table(i_cycle, :), gaze_src_col_name_stem, target_prefix_list);

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
				cur_gaze_samples_on_object_struct = fn_add_selected_target_gaze_columns_CCF( cur_gaze_samples_on_object_struct, triallog_table(i_cycle, :), gaze_src_col_name_stem, target_prefix_list);

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

	% combine across sessions
	if isempty(xsession.gaze_on_object_prop_count_table)
		xsession.gaze_on_object_prop_count_table = gaze_on_object_prop_count_table;
	else
		xsession.gaze_on_object_prop_count_table = [xsession.gaze_on_object_prop_count_table; gaze_on_object_prop_count_table];
	end

	if isempty(xsession.per_state_valid_tick_idx_per_cycle_idx_array)
		xsession.per_state_valid_tick_idx_per_cycle_idx_array = per_state_valid_tick_idx_per_cycle_idx_array;
	else
		xsession.per_state_valid_tick_idx_per_cycle_idx_array = [xsession.per_state_valid_tick_idx_per_cycle_idx_array; per_state_valid_tick_idx_per_cycle_idx_array];
	end


	if isempty(xsession.per_state_valid_tick_idx_ldx_array)
		xsession.per_state_valid_tick_idx_ldx_array = per_state_valid_tick_idx_ldx_array;
	else
		xsession.per_state_valid_tick_idx_ldx_array = [xsession.per_state_valid_tick_idx_ldx_array; per_state_valid_tick_idx_ldx_array];
	end

	if isempty(xsession.per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray)
		xsession.per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray = per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray;
	else
		xsession.per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray = [xsession.per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray; per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray];
	end






	% just pre process all
	%continue



	% plot far fixations and proportions of samples for dyadic

	% we likely should collect and merge the relevant data structures
	% across sessions to allow merging sessions.



	if (plot_2d_and_object_proportions)

		% sample based, recreate here to avoid having to collect in
		% xsession (we need to also define these per session earlier for the proportion calculations)
		%min_gaze_confidence = 0.85;%
		%gaze_src_col_name_stem = 'A_binocular_eye';
		valid_gaze_sample_ldx = record2D_table.([gaze_src_col_name_stem, '_confidence']) >= min_gaze_confidence;

		% 20260615 agred with igor, we only want to count samples on the paying
		% field and 10% around it
		valid_gaze_sample_ldx = valid_gaze_sample_ldx & record2D_table.([gaze_src_col_name_stem, '_X']) >= valid_X_range(1) & record2D_table.([gaze_src_col_name_stem, '_X']) <= valid_X_range(2);
		valid_gaze_sample_ldx = valid_gaze_sample_ldx & record2D_table.([gaze_src_col_name_stem, '_Y']) >= valid_Y_range(1) & record2D_table.([gaze_src_col_name_stem, '_Y']) <= valid_Y_range(2);

		near_gaze_sample_ldx = record2D_table.([gaze_src_col_name_stem, '_dX']) <= mean_dX_CCF_threshold;
		far_gaze_sample_ldx = record2D_table.([gaze_src_col_name_stem, '_dX']) > mean_dX_CCF_threshold;

		% repeat so we have this for the merged data as well instead of
		% collectiong it in xsession....
		target_state_col_ldx = contains(triallog_table.Properties.VariableNames, regexpPattern('^col_targ_\w*_tick_idx$'));
		target_state_end_col_ldx = contains(triallog_table.Properties.VariableNames, regexpPattern('^col_targ_\w*_end_tick_idx$'));
		target_state_start_col_ldx = target_state_col_ldx & ~target_state_end_col_ldx;
		target_state_start_name_list = triallog_table.Properties.VariableNames(target_state_start_col_ldx);
		target_state_end_name_list = triallog_table.Properties.VariableNames(target_state_end_col_ldx);
		target_state_name_list = regexprep(target_state_start_name_list, '_tick_idx', '');
		all_epoch_name_list = [target_state_name_list, additional_state_name_list];
		short_all_epoch_name_list = fn_shorten_object_name_list(all_epoch_name_list);




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
		% n_cols = length(col_unique_keys);
		% if exist('sorted_col_set_list', 'var') && ~isempty(sorted_col_set_list)
		% 	n_cols = length(sorted_col_set_list);
		% end


		% figure out which rows
		cur_key_col_list = {'vergence'};
		[ row_key_list, row_existing_keyfields_ldx, row_unique_keys, row_data_row_key_idx_arr, row_unique_keys_count_list ] = fn_generate_key_from_selected_table_columns_CCF(cur_key_col_list, gaze_on_object_prop_count_table, '_');
		% n_rows = length(row_unique_keys);
		% if exist('sorted_col_set_list', 'var') && ~isempty(sorted_col_set_list)
		% 	n_rows = length(sorted_row_set_list);
		% end
		% we also want to step through these as additional rows
		panel_request_list = {'gaze2D_per_epoch', 'gaze_on_object_proportion'};
		% n_panels = length(panel_request_list);

		target_ignore_list = {'coop_A', 'coop_B', 'comp', 'pun', 'Solo_A', 'Solo_B', 'target0', 'target1', 'target2', 'target3', 'target4', 'target5', 'target6', 'target7', 'target8', 'target9', 'Targets'};
		aggregation_type_string = 'per_session';

		[cur_plot_fh_list, per_session_panel_index_struct_arr] = fn_plot_by_plot_col_row_panel_sets( ...
			triallog_table, valid_cycle_ldx, triallog_cycle_key_list, record2D_table, valid_gaze_sample_ldx, per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray, ...
			gaze_on_object_prop_count_table, goopc_table_cycle_key_list, near_gaze_sample_ldx, far_gaze_sample_ldx, ...
			target_ignore_list, face_ROI, ...
			panel_request_list, short_all_epoch_name_list, gaze_src_col_name_stem, ...
			plot_unique_keys, plot_set_include_regexplist_list, plot_data_row_key_idx_arr, ...
			col_unique_keys, sorted_col_set_list, col_data_row_key_idx_arr, ...
			row_unique_keys, sorted_row_set_list, row_data_row_key_idx_arr, ...
			aggregation_type_string, out_dir, plotting_options_struct );

		if (perform_dyadic_solo_comparison)
			[per_session_dyadic_solo_stats_table, per_session_dyadic_solo_meta] = ...
				fn_fit_dyadic_vs_solo_gaze_glme(per_session_panel_index_struct_arr, gaze_on_object_prop_count_table, 0.05, 1, 1, 0, dyadic_solo_significance_test_method);
			if ~isempty(per_session_dyadic_solo_stats_table)
				stats_out_dir = fullfile(out_dir, aggregation_type_string);
				if ~isfolder(stats_out_dir), mkdir(stats_out_dir); end
				save(fullfile(stats_out_dir, 'dyadic_vs_solo_stats_glmm.mat'), 'per_session_dyadic_solo_stats_table', 'per_session_dyadic_solo_meta');
				writetable(per_session_dyadic_solo_stats_table, fullfile(stats_out_dir, 'dyadic_vs_solo_stats_glmm.csv'));
				fn_plot_dyadic_solo_paired_objects(per_session_panel_index_struct_arr, gaze_on_object_prop_count_table, per_session_dyadic_solo_stats_table, aggregation_type_string, out_dir, plotting_options_struct, sorted_col_set_list, sorted_row_set_list, target_ignore_list, dyadic_solo_significance_label_mode, dyadic_solo_significance_test_method);
			end
		end

		% cur_plot_fh_list can be quite large
		if (close_plots_automatically) || strcmp(plotting_options_struct.figure_visibility_string, 'off')
			close all;
		end


		if show_cycle_spatial_trajectories
			cur_plotting_options_struct = plotting_options_struct;
			cur_plotting_options_struct.format_string_list = {'.pdf'};
			%cur_plotting_options_struct.figure_visibility_string = 'On';
			%cycle_spatial_goopc_bar_vergence_list = {'nearFixations', 'farFixations'};

			%max_subset_cycles = 40;	% how many subsets to pick per cycle
			%shuffled_cycle_idx = randperm(size(triallog_table, 1)); % thids might still might conttain indices too large for imndividual subsets, but we clean this later in fn_plot_cycle_spatial_trajectories_per_epoch
			%cycle_spatial_plot_sessionID_cycle_ldx = shuffled_cycle_idx(1:min(max_subset_cycles, size(triallog_table, 1)));
			%cycle_spatial_plot_sessionID_cycle_ldx = [1000, 1050, 2000];
			
			fn_plot_cycle_spatial_trajectories_per_epoch( ...
				record2D_table, ...
				triallog_table, ...
				per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray, ...
				short_all_epoch_name_list, ...
				valid_gaze_sample_ldx, ...
				face_ROI, ...
				target_prefix_list, ...
				conf_struct.target_radius, ...
				cycle_spatial_source_stem_regexp_list, ...
				cur_plotting_options_struct, ...
				sorted_col_set_list, ...
				valid_X_range, ...
				valid_Y_range, ...
				aggregation_type_string, ...
				fullfile(out_dir, aggregation_type_string, cur_sessionID, 'per_cycle'), ...
				cycle_spatial_plot_sessionID_cycle_ldx, ...
				cycle_spatial_source_row_name_list, ...
				gaze_on_object_prop_count_table, ...
				goopc_table_cycle_key_list, ...
				cycle_spatial_goopc_pct_col_regexp_list, ...
				cycle_spatial_goopc_bar_vergence_list);
		end
		if (close_plots_automatically) || strcmp(plotting_options_struct.figure_visibility_string, 'off')
			close all;
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

				if (close_plots_automatically) || strcmp(plotting_options_struct.figure_visibility_string, 'off')
					close all;
				end
			end
		end
	end

	%separtely collection types for dyadic/single and solo_0/solo_1, exclude 'None'


	% now first plot a 2D histogram of gaze positions (as scatter with transparency)

	% now select the subset of trials from triallog_table where no target
	% was displayed over the face

	% now restrict to relevant task epoch

	% restrict to runs	triallog_table.src_run_idx

	% now merge the relevant data of all sessions:



	timestamps.(mfilename).(varname_session_id).end = toc(timestamps.(mfilename).(varname_session_id).start);
	cur_duration_s = timestamps.(mfilename).(varname_session_id).end;
	disp([mfilename, ': ', proto_varname_session_id, ' took: ', num2str(timestamps.(mfilename).(varname_session_id).end), ' seconds (', num2str(floor(cur_duration_s/(60*60))), ' hours ', num2str(floor(rem(cur_duration_s, 3600)/60)), ' minutes ', num2str(mod(cur_duration_s, 60)), ' seconds).']);
end

if (plot_2d_and_object_proportions_xsession)
	% sample based, recreate here to avoid having to collect in
	% xsession (we need to also define these per session earlier for the proportion calculations)
	%min_gaze_confidence = 0.85;%
	%gaze_src_col_name_stem = 'A_binocular_eye';
	valid_gaze_sample_ldx = xsession.record2D_table.([gaze_src_col_name_stem, '_confidence']) >= min_gaze_confidence;
	% 20260615 agred with igor, we only want to count samples on the paying
	% field and 10% around it
	valid_gaze_sample_ldx = valid_gaze_sample_ldx & xsession.record2D_table.([gaze_src_col_name_stem, '_X']) >= valid_X_range(1) & xsession.record2D_table.([gaze_src_col_name_stem, '_X']) <= valid_X_range(2);
	valid_gaze_sample_ldx = valid_gaze_sample_ldx & xsession.record2D_table.([gaze_src_col_name_stem, '_Y']) >= valid_Y_range(1) & xsession.record2D_table.([gaze_src_col_name_stem, '_Y']) <= valid_Y_range(2);


	near_gaze_sample_ldx = xsession.record2D_table.([gaze_src_col_name_stem, '_dX']) <= mean_dX_CCF_threshold;
	far_gaze_sample_ldx = xsession.record2D_table.([gaze_src_col_name_stem, '_dX']) > mean_dX_CCF_threshold;

	cycle_duration_list = xsession.triallog_table.cycle_end_s - xsession.triallog_table.cycle_start_s;
	exclude_cycle_ldx =  cycle_duration_list > max_cycle_duration_s;
	exclude_tick_ldx = xsession.record2D_table.timestamp > 0;

	% invert logic to exclude by default
	for i_cycle = 1 : length(exclude_cycle_ldx)
		if ~exclude_cycle_ldx(i_cycle)
			cur_trial_start_tick_idx = xsession.triallog_table.cycle_start_tick_idx(i_cycle);
			cur_trial_end_tick_idx = xsession.triallog_table.cycle_end_tick_idx(i_cycle) ;
			if (cur_trial_start_tick_idx > 0) && (cur_trial_end_tick_idx > 0)
				exclude_tick_ldx(cur_trial_start_tick_idx:cur_trial_end_tick_idx) = false;
			end
		end
	end

	invalid_cycle_ldx = ismember(xsession.triallog_table.collection_type, {'None'});
	valid_cycle_ldx = ~invalid_cycle_ldx & ~exclude_cycle_ldx;



	% repeat so we have this for the merged data as well instead of
	% collectiong it in xsession....
	target_state_col_ldx = contains(xsession.triallog_table.Properties.VariableNames, regexpPattern('^col_targ_\w*_tick_idx$'));
	target_state_end_col_ldx = contains(xsession.triallog_table.Properties.VariableNames, regexpPattern('^col_targ_\w*_end_tick_idx$'));
	target_state_start_col_ldx = target_state_col_ldx & ~target_state_end_col_ldx;
	target_state_start_name_list = xsession.triallog_table.Properties.VariableNames(target_state_start_col_ldx);
	target_state_end_name_list = xsession.triallog_table.Properties.VariableNames(target_state_end_col_ldx);
	target_state_name_list = regexprep(target_state_start_name_list, '_tick_idx', '');
	all_epoch_name_list = [target_state_name_list, additional_state_name_list];
	short_all_epoch_name_list = fn_shorten_object_name_list(all_epoch_name_list);

	% TODO remove cycles where the confederate collected the competitive
	% target from the set

	%plot_set_ldx_list = {dyadic_cycle_ldx, solo_cycle_ldx};
	plot_set_include_regexplist_list = {'dyadic', 'solo'};
	%plot_set_include_regexplist_list = {'solo'};

	% which epochs to show in which sequence
	sorted_col_set_list = {'Acquisition', 'CTS_collecting', 'CTS_rewarding', 'CTS_pre_acquisition'};
	sorted_row_set_list = {'nearFixations', 'farFixations'};

	% figure out which cycles to include per plot from triallog
	cur_key_col_list = {'solo_dyadic'};% was {'sessionID', 'trial_num'}; but for xsession we do not want per-session plots...
	%cur_key_col_list = {'solo_dyadic', 'B_facecenter_XY'};% was {'sessionID', 'trial_num'}; but for xsession we do not want per-session plots...

	[ plot_key_list, plot_existing_keyfields_ldx, plot_unique_keys, plot_data_row_key_idx_arr, plot_unique_keys_count_list ] = fn_generate_key_from_selected_table_columns_CCF(cur_key_col_list, xsession.triallog_table, '_');

	% triallog effective cycle_number (
	cur_key_col_list = {'sessionID', 'trial_num'};
	[triallog_cycle_key_list, triallog_cycle_existing_keyfields_ldx, triallog_cycle_unique_keys, triallog_cycle_data_row_key_idx_arr, triallog_cycle_unique_keys_count_list ] = fn_generate_key_from_selected_table_columns_CCF(cur_key_col_list, xsession.triallog_table, '_');


	% gaze_on_object_prop_count_table effective cycle_number (
	cur_key_col_list = {'sessionID', 'cycle'};
	[goopc_table_cycle_key_list, goopc_table__cycle_existing_keyfields_ldx, goopc_table_cycle_unique_keys, goopc_table_cycle_data_row_key_idx_arr, goopc_table_cycle_unique_keys_count_list ] = fn_generate_key_from_selected_table_columns_CCF(cur_key_col_list, xsession.gaze_on_object_prop_count_table, '_');



	% figure out which columns7
	cur_key_col_list = {'epoch'};
	[ col_key_list, col_existing_keyfields_ldx, col_unique_keys, col_data_row_key_idx_arr, col_unique_keys_count_list ] = fn_generate_key_from_selected_table_columns_CCF(cur_key_col_list, xsession.gaze_on_object_prop_count_table, '_');
	% n_cols = length(col_unique_keys);
	% if exist('sorted_col_set_list', 'var') && ~isempty(sorted_col_set_list)
	% 	n_cols = length(sorted_col_set_list);
	% end


	% figure out which rows
	cur_key_col_list = {'vergence'};
	[ row_key_list, row_existing_keyfields_ldx, row_unique_keys, row_data_row_key_idx_arr, row_unique_keys_count_list ] = fn_generate_key_from_selected_table_columns_CCF(cur_key_col_list, xsession.gaze_on_object_prop_count_table, '_');
	% n_rows = length(row_unique_keys);
	% if exist('sorted_col_set_list', 'var') && ~isempty(sorted_col_set_list)
	% 	n_rows = length(sorted_row_set_list);
	% end
	% we also want to step through these as additional rows
	panel_request_list = {'gaze2D_per_epoch', 'gaze_on_object_proportion'};
	% n_panels = length(panel_request_list);

	target_ignore_list = {'coop_A', 'coop_B', 'comp', 'pun', 'Solo_A', 'Solo_B', 'target0', 'target1', 'target2', 'target3', 'target4', 'target5', 'target6', 'target7', 'target8', 'target9', 'Targets'};
	aggregation_type_string = 'across_sessions';

	xsession_target_prefix_list = {};
	xsession_record2D_colname_list = xsession.record2D_table.Properties.VariableNames;
	for i_col = 1 : length(xsession_record2D_colname_list)
		cur_target_prefix_cell = regexp(xsession_record2D_colname_list{i_col}, '^target\d*', 'match');
		if ~isempty(cur_target_prefix_cell)
			xsession_target_prefix_list = [xsession_target_prefix_list, cur_target_prefix_cell{1}]; %#ok<AGROW>
		end
	end
	xsession_target_prefix_list = unique(xsession_target_prefix_list);

	[cur_plot_fh_list, xsession_panel_index_struct_arr] = fn_plot_by_plot_col_row_panel_sets( ...
		xsession.triallog_table, valid_cycle_ldx, triallog_cycle_key_list, xsession.record2D_table, valid_gaze_sample_ldx, xsession.per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray, ...
		xsession.gaze_on_object_prop_count_table, goopc_table_cycle_key_list, near_gaze_sample_ldx, far_gaze_sample_ldx, ...
		target_ignore_list, xsession.face_ROI, ...
		panel_request_list, short_all_epoch_name_list, gaze_src_col_name_stem, ...
		plot_unique_keys, plot_set_include_regexplist_list, plot_data_row_key_idx_arr, ...
		col_unique_keys, sorted_col_set_list, col_data_row_key_idx_arr, ...
		row_unique_keys, sorted_row_set_list, row_data_row_key_idx_arr, ...
		aggregation_type_string, out_dir, plotting_options_struct );

	if (perform_dyadic_solo_comparison_xsession)
		%cur_plotting_options_struct.figure_visibility_string = 'On';
		dyadic_solo_significance_test_method = 'glme';      % 'glme' | 'ranksum' | 'ttest'
		dyadic_solo_significance_label_mode = 'direction'; % 'stars' | 'direction'

		[xsession_dyadic_solo_stats_table, xsession_dyadic_solo_meta] = ...
			fn_fit_dyadic_vs_solo_gaze_glme(xsession_panel_index_struct_arr, xsession.gaze_on_object_prop_count_table, 0.05, 1, 1, 0, dyadic_solo_significance_test_method);
		if ~isempty(xsession_dyadic_solo_stats_table)
			stats_out_dir = fullfile(out_dir, aggregation_type_string);
			if ~isfolder(stats_out_dir), mkdir(stats_out_dir); end
			save(fullfile(stats_out_dir, 'dyadic_vs_solo_stats_glmm.mat'), 'xsession_dyadic_solo_stats_table', 'xsession_dyadic_solo_meta');
			writetable(xsession_dyadic_solo_stats_table, fullfile(stats_out_dir, 'dyadic_vs_solo_stats_glmm.csv'));
			fn_plot_dyadic_solo_paired_objects(xsession_panel_index_struct_arr, xsession.gaze_on_object_prop_count_table, xsession_dyadic_solo_stats_table, aggregation_type_string, out_dir, plotting_options_struct, sorted_col_set_list, sorted_row_set_list, target_ignore_list, dyadic_solo_significance_label_mode, dyadic_solo_significance_test_method);
		end
	end

	% cur_plot_fh_list can be quite large
	if (close_plots_automatically) || strcmp(plotting_options_struct.figure_visibility_string, 'off')
		close all;
	end

	if show_cycle_spatial_trajectories_xsession
		cur_plotting_options_struct = plotting_options_struct;
		cur_plotting_options_struct.format_string_list = {'.pdf'};

		fn_plot_cycle_spatial_trajectories_per_epoch( ...
			xsession.record2D_table, ...
			xsession.triallog_table, ...
			xsession.per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray, ...
			short_all_epoch_name_list, ...
			valid_gaze_sample_ldx, ...
			xsession.face_ROI, ...
			xsession_target_prefix_list, ...
			conf_struct.target_radius, ...
			cycle_spatial_source_stem_regexp_list, ...
			cur_plotting_options_struct, ...
			sorted_col_set_list, ...
			valid_X_range, ...
			valid_Y_range, ...
			aggregation_type_string, ...
			fullfile(out_dir, aggregation_type_string, 'per_cycle'), ...
			cycle_spatial_plot_sessionID_cycle_ldx, ...
			cycle_spatial_source_row_name_list, ...
			xsession.gaze_on_object_prop_count_table, ...
			goopc_table_cycle_key_list, ...
			cycle_spatial_goopc_pct_col_regexp_list, ...
			cycle_spatial_goopc_bar_vergence_list);
	end
	if (close_plots_automatically) || strcmp(plotting_options_struct.figure_visibility_string, 'off')
		close all;
	end
end

% final end...
timestamps.(mfilename).end = toc(timestamps.(mfilename).start);
cur_duration_s = timestamps.(mfilename).end;
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end), ' seconds (', num2str(floor(cur_duration_s/(60*60))), ' hours ', num2str(floor(rem(cur_duration_s, 3600)/60)), ' minutes ', num2str(mod(cur_duration_s, 60)), ' seconds).']);

end

