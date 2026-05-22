function [] = fn_analyze_face_gaze_per_session(cur_CCF_runfolder_FQN_list)
%FN_ANALYZE_FACE_GAZE_PER_SESSION Summary of this function goes here
%   Detailed explanation goes here

% TODO:
%	add distance betwenn gaze and agents and aims to record2D


timestamps.(mfilename).start = tic;
disp(['Starting: ', mfilename]);
dbstop if error
fq_mfilename = mfilename('fullpath');
debug = 0;


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
	cur_CCF_runfolder_FQN_list = cur_CCF_runfolder_FQN_list(6:end); % clear up to 7
	%cur_CCF_runfolder_FQN_list = cur_CCF_runfolder_FQN_list(end); % clear up to 7

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
		error([mfilename, ': WARN: session folder dies not end in .sessiondir...']);
	end
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



	% convenience mappings
	GAZE_OPTS_struct = orig_GAZE_OPTS_struct;	% TODO automate this
	conf_struct = json_struct.conf_dot_json;
	%
	ROI_center_name_list = {'facecenter', 'face_left', 'face_right'};
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
		case '20260424TNNNNNNM.A_Elmo.B_MIXED.SCP_01'
			paper_blocked = 1;

		case '20260428TNNNNNNM.A_Elmo.B_MIXED.SCP_01'
			per_run_face_ROI_idx = repmat(find(ismember(face_ROI.names, {'face_right'})), n_src_runs, 1);

		case '20260429TNNNNNNM.A_Elmo.B_MIXED.SCP_01'
			per_run_face_ROI_idx = repmat(find(ismember(face_ROI.names, {'face_right'})), n_src_runs, 1);

		case '20260430TNNNNNNM.A_Elmo.B_MIXED.SCP_01'
			per_run_face_ROI_idx = [find(ismember(face_ROI.names, {'face_right'})); find(ismember(face_ROI.names, {'facecenter'}))];

		case '20260501TNNNNNNM.A_Elmo.B_MIXED.SCP_01'
			per_run_face_ROI_idx = [find(ismember(face_ROI.names, {'face_right'})); find(ismember(face_ROI.names, {'face_left'}))];

		otherwise
			% assume the partner normally sits opposite to the monkey...
			per_run_face_ROI_idx = repmat(find(ismember(face_ROI.names, {'facecenter'})), n_src_runs, 1);	
	end


	% now add the partner face center positpion and paper_block information
	% to the triallog_table and record2D_table
	% TODO also add A_s face position
	record2D_table.B_face_center_X = face_ROI.center_XY(per_run_face_ROI_idx(record2D_table.run_idx + 1), 1);
	record2D_table.B_face_center_Y = face_ROI.center_XY(per_run_face_ROI_idx(record2D_table.run_idx + 1), 2);
	record2D_table.paper_blocked = zeros([size(record2D_table, 1) 1]) + paper_blocked;	% TODO change to per run parameter?

	triallog_table.B_face_center_XY = face_ROI.center_XY(per_run_face_ROI_idx(triallog_table.src_run_idx), :);
	triallog_table.paper_blocked = zeros([size(triallog_table, 1) 1]) + paper_blocked;	% TODO change to per run parameter?



	% define a relevant time window per trial

	% threshold fixations into near and far based on mean_dX_CCF, look at
	% the histogram to define this threshold empirically
	%figure('Name', 'mean_dX_CCF');
	%histogram(fixations_struct.A_binocular_eye.mean_dX_CCF, 100)
	mean_dX_CCF_threshold = 0.05;	%(values smaller near fixation, values larger far fixations)
	near_fixation_ldx = fixations_struct.A_binocular_eye.mean_dX_CCF <= mean_dX_CCF_threshold;
	far_fixation_ldx = fixations_struct.A_binocular_eye.mean_dX_CCF > mean_dX_CCF_threshold;


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

	n_states = length(target_state_name_list);
	% use this to pick the per state valid samples
	per_state_valid_tick_idx_ldx_array = false([size(triallog_table, 1), n_states]);


	for i_target_state = 1 : length(target_state_name_list)
		cur_target_state = target_state_name_list{i_target_state};
		
		cur_target_state_start_tick_idx_list = triallog_table.([cur_target_state, '_tick_idx']);
		cur_target_state_end_tick_idx_list = triallog_table.([cur_target_state, '_end_tick_idx']);

		for i_cycle = 1 : length(cur_target_state_start_tick_idx_list)
			% exclude bad cycles
			cur_target_state_start_tick_idx = cur_target_state_start_tick_idx_list(i_cycle);
			cur_target_state_end_tick_idx = cur_target_state_end_tick_idx_list(i_cycle);
			cur_cycle_state_duration_nticks = cur_target_state_end_tick_idx - cur_target_state_start_tick_idx;
			
			if isnan(cur_target_state_start_tick_idx) || isnan(cur_target_state_end_tick_idx) || (cur_target_state_start_tick_idx == 0) || (cur_target_state_end_tick_idx == 0)
				disp([mfilename, ': INFO: excluded cycle (', cur_target_state,'): ', num2str(i_cycle)]);
				continue
			end

			% this can be used for 2D plots...
			per_state_valid_tick_idx_ldx_array(cur_target_state_start_tick_idx:cur_target_state_end_tick_idx, i_target_state) = true;

			% now figure out the per stateXcycle fixation percentages on
			% the 
			


		end
	end




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




	% define trial_sets
	dyadic_cycle_ldx = ismember(triallog_table.collection_type, {'joint', 'single'});
	solo_cycle_ldx = ismember(triallog_table.collection_type, {'solo_0', 'solo_1'});
	invalid_cycle_ldx = ismember(triallog_table.collection_type, {'None'});

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

			cur_out_FQN = fullfile(out_dir, 'per_session', [proto_varname_session_id, '.', cur_face_ROI_name, '.', cur_set_name, '.', ref_event_col_stem_name, '.pdf']);
			disp(['Saving figure as: ', cur_out_FQN]);
			write_out_figure(cur_fh, cur_out_FQN);
		
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
	disp([mfilename, ': ', proto_varname_session_id, ' took: ', num2str(timestamps.(mfilename).(varname_session_id).end), ' seconds (', num2str(floor(cur_duration_s/(60*60))), ' hours ', num2str(floor(mod(cur_duration_s, 3600)/60)), ' minutes ', num2str(mod(cur_duration_s, 60)), ' seconds).']);
end


% final end...
timestamps.(mfilename).end = toc(timestamps.(mfilename).start);
cur_duration_s = timestamps.(mfilename).end;
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end), ' seconds (', num2str(floor(cur_duration_s/(60*60))), ' hours ', num2str(floor(cur_duration_s/60)), ' minutes ', num2str(mod(cur_duration_s, 60)), ' seconds).']);

end

