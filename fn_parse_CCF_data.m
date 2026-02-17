function [ triallog_table, record_struct, record2D_struct, AI_samples_struct, DI_samples_struct, json_struct, h5_struct, txt_struct, jsonl_struct, enum_struct ] = fn_parse_CCF_data( cur_CCF_runfolder_FQN_list )
%FN_PARSE_CCF_DATA Summary of this function goes here
%   Detailed explanation goes here
%
% TODO implement looping over a base folder and pick the runfolders
% automatically
%	create a per collection table that lists relevant events per collection
%	(aka "trial") for visual events as well as touch events and reward
%	events...






data_struct_list = struct();
json_struct_list = struct();
h5_struct_list = struct();
txt_struct_list = struct();
jsonl_struct_list = struct();

%data_struct = [];

record_struct = [];
record2D_struct = [];
AI_samples_struct = [];
DI_samples_struct = [];

json_struct = [];
h5_struct = [];
txt_struct = [];
jsonl_struct = [];
enum_struct = [];

timestamps.(mfilename).start = tic;
disp(['Starting: ', mfilename]);
dbstop if error
fq_mfilename = mfilename('fullpath');
debug = 0;

% what threshold to use to detect up from down, with Mike Walsh's caltech
% detector and the level output mac is ~3.3 Volts, while low is at 0 if the
% gain set correctly
photodiode_AI_analog_threshold_V = 2.5;	% give it some slack



if ~exist('cur_CCF_runfolder_FQN_list', 'var') || isempty(cur_CCF_runfolder_FQN_list)
	% (venv_py3.10) root@LC38836:/home/smoeller@dpz.lokal/SCP_CODE/TASKS/foraging_task_2_NHP/src#
	CCF_recordings_folder_FQN = fullfile('~', 'SCP_CODE', 'TASKS', 'foraging_task_2_NHP', 'recordings');
	cur_CCF_runfolder_FQN_list = fullfile(CCF_recordings_folder_FQN, '101_000', '0');
	%cur_CCF_runfolder_FQN_list = fullfile(CCF_recordings_folder_FQN, '101_000', '0');
	cur_CCF_runfolder_FQN_list = fullfile(CCF_recordings_folder_FQN, '102_000', '4');
	cur_CCF_runfolder_FQN_list = fullfile(CCF_recordings_folder_FQN, '109_002', '0');
	cur_CCF_runfolder_FQN_list = fullfile(CCF_recordings_folder_FQN, '000_000', '19');

	% CCF_data_base_path = fullfile('/', 'Users', 'smoeller', 'DPZ', 'taskcontroller', 'CODE', 'CCF', 'CCF_RECORDINGS', 'recordings');
	% CCF_data_base_path = fullfile('/', 'Volumes', 'snd', 'taskcontroller', 'SCP_DATA', 'SCP-CTRL-01', 'CCF', 'recordings');
	% cur_CCF_runfolder_FQN_list = fullfile(CCF_data_base_path, '001_101', '28');
	% cur_CCF_runfolder_FQN_list = fullfile(CCF_data_base_path, '100_101', '3');
	% 
	% cur_CCF_runfolder_FQN_list = fullfile('/', 'Volumes', 'snd', 'taskcontroller', 'SCP_DATA', 'SCP-CTRL-01', 'CCF', 'recordings', '001_100', '7');

	% Y:\SCP_DATA\SCP-CTRL-01\SESSIONLOGS\2025\251205\20251205T185226.A_NONE.B_NONE.SCP_01.sessiondir\TDT\SCP_DAG_v26_PZ5ms-251205-185203
	cur_CCF_runfolder_FQN_list = {...
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2025', '251205', '20251205T185226.A_NONE.B_NONE.SCP_01.sessiondir') ...
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2025', '251216', '20251216T114536.A_NONE.B_NONE.SCP_01.sessiondir') ...
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260204', '20260204T104914.A_Elmo.B_JL.SCP_01.sessiondir') ...
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260204', '20260204T112256.A_Elmo.B_JL.SCP_01.sessiondir') ...		
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260204', '20260204T115759.A_Elmo.B_JL.SCP_01.sessiondir') ...
		};
	%cur_CCF_runfolder_FQN_list = fullfile(CCF_recordings_folder_FQN, '000_000', '19');

	% use a file picker to select the desired folder
end


if ~iscell(cur_CCF_runfolder_FQN_list)
	cur_CCF_runfolder_FQN_list = {cur_CCF_runfolder_FQN_list};
end

for i_runfolder = 1 : length(cur_CCF_runfolder_FQN_list)
	cur_CCF_runfolder_FQN = cur_CCF_runfolder_FQN_list{i_runfolder};
	disp(['Processing: ', cur_CCF_runfolder_FQN]);
	% what files do we have here
	json_dir_struct = dir(fullfile(cur_CCF_runfolder_FQN, '*.json'));
	h5_dir_struct = dir(fullfile(cur_CCF_runfolder_FQN, '*.h5'));
	txt_dir_struct = dir(fullfile(cur_CCF_runfolder_FQN, '*.txt'));
	sessionID_dir_struct = dir(fullfile(cur_CCF_runfolder_FQN, '*.sessionID'));
	jsonl_dir_struct = dir(fullfile(cur_CCF_runfolder_FQN, '*.jsonl'));

	% the python enums:
	enum_struct = fn_extract_python_enums(fullfile(cur_CCF_runfolder_FQN, 'enums.py'));


	% the json files
	for i_json_FQN = 1 : length(json_dir_struct)
		cur_json_name = json_dir_struct(i_json_FQN).name;
		if (debug)
			disp(['Processing: ', cur_json_name]);
		end
		cur_json_FQN = [json_dir_struct(i_json_FQN).folder, filesep, json_dir_struct(i_json_FQN).name];
		[~, cur_json_name] = fileparts(json_dir_struct(i_json_FQN).name);
		% this will likely fail for complex or (too) large json files...
		tmp_string_data = fileread(cur_json_FQN);
		if ~isempty(tmp_string_data)
			json_struct.(cur_json_name) = jsondecode(tmp_string_data);
		else
			disp([cur_json_name, ' contained no data, skipping...']);
		end
	end

	% the json files
	for i_jsonl_FQN = 1 : length(jsonl_dir_struct)
		cur_jsonl_name = json_dir_struct(i_jsonl_FQN).name;
		if (debug)
			disp(['Processing: ', cur_jsonl_name]);
		end
		cur_jsonl_FQN = [jsonl_dir_struct(i_jsonl_FQN).folder, filesep, jsonl_dir_struct(i_jsonl_FQN).name];
		[~, cur_jsonl_name] = fileparts(jsonl_dir_struct(i_jsonl_FQN).name);
		% this will likely fail for complex or (too) large json files...
		tmp_string_data = fileread(cur_jsonl_FQN);
		if ~isempty(tmp_string_data)
			%parsed_jsonl = fn_parse_jsonl_file(cur_jsonl_FQN);
			jsonl_struct.(cur_jsonl_name) = fn_parse_jsonl_file(cur_jsonl_FQN);
		else
			disp([cur_jsonl_name, ' contained no data, skipping...']);
		end
	end


	% load the sessionID
	session_id = [];
	if ~isempty(sessionID_dir_struct)
		session_id = extractBefore(sessionID_dir_struct.name, '.sessionID');
		CCF_session_dir_FQN = fileread(fullfile(sessionID_dir_struct.folder, sessionID_dir_struct.name));
		CCF_session_dir_FQN_elements = split(strtrim(CCF_session_dir_FQN), '/');	% this is coming from Linux so forward slash
		CCF_run = CCF_session_dir_FQN_elements{end};
		CCF_pair = CCF_session_dir_FQN_elements{end-1};
	end


	for i_h5_FQN = 1 : length(h5_dir_struct)
		cur_h5_name = h5_dir_struct(i_h5_FQN).name;
		if (debug)
			disp(['Processing: ', cur_h5_name]);
		end
		cur_h5_FQN = [json_dir_struct(i_h5_FQN).folder, filesep, h5_dir_struct(i_h5_FQN).name];
		[~, cur_h5_name] = fileparts(h5_dir_struct(i_h5_FQN).name);

		cur_file_info = dir(cur_h5_FQN);
		if cur_file_info.bytes < 97
			disp([mfilename, ': H5 file too small, probably corrupted, skipping: ', cur_h5_FQN])
			continue
		end

		try 
			cur_h5info = h5info(cur_h5_FQN);
		catch ME
			ME
			disp([mfilename, ': H5 file probably corrupted, skipping: ', cur_h5_FQN])
			continue
		end

		for i_h5_dataset = 1 : length(cur_h5info.Datasets)
			cur_h5_dataset_name =  cur_h5info.Datasets.Name;
			cur_data = h5read(cur_h5_FQN, ['/', cur_h5_dataset_name]);	% hdf5 datasets start with / apparently

			if contains(cur_h5_FQN, 'record2D.h5')
				% this has a leading dimension of size 1
				cur_data = squeeze(cur_data);
			end

			if ~isempty(cur_data)
				% python arrays have flipped dimensionality, but we want
				% named columns
				h5_struct.([cur_h5_name, '_', cur_h5_dataset_name]) = cur_data;
			else
				disp([cur_h5_name, ' (' , cur_h5_dataset_name, ') contained no data, skipping...']);
			end
		end
	end



%figure; plot(h5_struct.AI_samples_data(1,:)');

%tmp = h5_struct.DI_samples_data(1,:)';
%figure; plot(h5_struct.DI_samples_data(1,:)');
%tmp_1 = bitget(tmp, 1);
%figure; plot(tmp_1);

%tmp_2 = bitget(tmp, 2);
%figure; plot(tmp_2);




	if ~isempty(h5_struct) && ismember({'record_data'}, fieldnames(h5_struct))
		% create a proper header for the data and reshape to 2D table...
		record_struct.header = {};
		[dim1, dim2, dim3] = size(h5_struct.record_data);	% dim1 X, Y, additional data, dim2; entries: 
		n_cols = dim1 * dim2;
		n_rows = dim3;

		record_struct.table = reshape(h5_struct.record_data, n_cols, n_rows)';
		record_struct.header = {'aim_0_X_rel', 'aim_0_Y_rel', 'tick_timestamp_sec', 'aim_1_X_rel', 'aim_1_Y_rel', '', 'agent_0_X', 'agent_0_Y', 'cumulative_score_0', 'agent_1_X', 'agent_1_Y', ''};
		n_agent_cols = 12;
		n_cols_per_entity = 3;
		n_targets = (n_cols - n_agent_cols)/3;
		for i_targets = 1 : n_targets
			cur_target_id_col_idx = (n_agent_cols + ((i_targets - 1) * n_cols_per_entity) + n_cols_per_entity);
			cur_target_id = unique(record_struct.table(:, cur_target_id_col_idx));
			if length(cur_target_id) ~= 1
				error('flattening 3D table failed, please investigate why');
			end
			record_struct.header(end+1) = {['target_', num2str(cur_target_id), '_X_rel']};
			record_struct.header(end+1) = {['target_', num2str(cur_target_id), '_Y_rel']};
			record_struct.header(end+1) = {['target_', num2str(cur_target_id), '_ID']};
		end
		
	else
		disp(['No data record_data found in ', cur_CCF_runfolder_FQN]);
	end
	
	% record2D
	if ~isempty(h5_struct) && ismember({'record2D_data'}, fieldnames(h5_struct))
		% create a proper header for the data and reshape to 2D table...
		record2D_struct.header = json_struct.record2D_header.record2D_column_names';
		record2D_struct.table = squeeze(h5_struct.record2D_data)';
		record2D_table = array2table(record2D_struct.table, 'VariableNames', record2D_struct.header);


		request_list = {'nan_out_invalid_aims_pos', 'nan_out_invalid_agent_pos', ...
		'calc_and_store_distances_to_targets', ...
		'detect_agent_fixations', 'detect_aim_fixations', ...	% needs fixing
		};

		max_dispersion_threshold = json_struct.conf.target_radius/2; % potentially define this in millimeter?
		min_fixation_duration_threshold_ms = 100; 
		[record2D_table, fixations_struct] = fn_amend_record2D_table(record2D_table, json_struct.conf, request_list, max_dispersion_threshold, min_fixation_duration_threshold_ms);


	else
		disp(['No record2D data found in ', cur_CCF_runfolder_FQN]);
	end

	% extract collection/trial start/stop timestamps from record2D

	
	% process record2D to create a triallog table (as matlab table)
	if ~isempty(record2D_struct)
		if isfield(json_struct, 'conf')
			target_radius = json_struct.conf.target_radius;
		else
			target_radius = [];
		end
		[triallog_table, record2D_table, sorted_target_state_transition_table] = fn_create_triallog_from_record2D(record2D_table, enum_struct, target_radius);
		% We need this later...
		[first2second_time_conversion_struct, second2first_time_conversion_struct, time_conversion_struct] = fn_create_timing_conversion_struct('CCF_timestamps', triallog_table.collection_start_s, 'CCF_ticks', triallog_table.collection_start_tick_idx);
	end

	% add the reward information per collection
	if ~isempty(jsonl_struct) && isfield(jsonl_struct, 'reward_trains')
		% attention collection number is increased just before reward is
		% dispensed, so the reward collection number is offset by +1 for
		% reason TASK, while offset by +0 for reason MANUAL
		triallog_table = fn_add_reward_information_to_triallog(triallog_table, jsonl_struct.reward_trains);
	end


	if isfield(h5_struct, 'DI_samples_data') && ~isempty(h5_struct.DI_samples_data)
		% DI_samples
		[DI_samples_timestamp_list, DI_samples_struct, DI_timing_fh] = fn_estimate_per_sample_timestamps_for_h5table('DI_samples', h5_struct, json_struct);
		fn_save_figure(DI_timing_fh, cur_CCF_runfolder_FQN, 'DI_sampling_timestamp_control_plot.pdf');
		% convert the bit lines into individual columns in a ddition to the
		% full DI word
		DI_word = DI_samples_struct.table;
		for i_bitline = 1 : length(DI_samples_struct.header)
			DI_samples_struct.table(:, 1+i_bitline) = bitget(DI_word, i_bitline);
		end
		DI_samples_struct.header = ['DI_word', DI_samples_struct.header];

		mean_DI_sampling_interval_s =  mean(diff(DI_samples_timestamp_list));
		DI_samples_table = fn_convert_header_table_timestamp_list_struct_to_table(DI_samples_struct);
		DI_samples_collection_num_list = fn_create_feature_list_from_id_start_end_ts_lists(DI_samples_timestamp_list, triallog_table.collection_num, triallog_table.collection_start_s, [triallog_table.collection_start_s(2:end) - (0.1 * mean_DI_sampling_interval_s); triallog_table.collection_end_s(end)]);
		DI_samples_table = addvars(DI_samples_table, DI_samples_collection_num_list, 'NewVariableNames', 'collection_num');
	end


	if isfield(h5_struct, 'AI_samples_data') && ~isempty(h5_struct.AI_samples_data)
		% add session timestamps to sampled data
		% AI_samples
		[AI_samples_timestamp_list, AI_samples_struct, AI_timing_fh] = fn_estimate_per_sample_timestamps_for_h5table('AI_samples', h5_struct, json_struct);
		fn_save_figure(AI_timing_fh, cur_CCF_runfolder_FQN, 'AI_sampling_timestamp_control_plot.pdf');
		mean_AI_sampling_interval_s =  mean(diff(AI_samples_timestamp_list));
		AI_samples_table = fn_convert_header_table_timestamp_list_struct_to_table(AI_samples_struct);
		AI_samples_collection_num_list = fn_create_feature_list_from_id_start_end_ts_lists(AI_samples_timestamp_list, triallog_table.collection_num, triallog_table.collection_start_s, [triallog_table.collection_start_s(2:end) - (0.1 * mean_AI_sampling_interval_s); triallog_table.collection_end_s(end)]);
		AI_samples_table = addvars(AI_samples_table, AI_samples_collection_num_list, 'NewVariableNames', 'collection_num');

		% process the photodiode information and correct the timing in the
		% jsonl table
		% extract the photodiode onset/offset timestamps and add to
		% per_collection_table
		onset_offset_events_struct = fn_extract_event_ts_from_photodiode_AI_samples( AI_samples_timestamp_list, AI_samples_table.MSD_LCD_level, AI_samples_collection_num_list, photodiode_AI_analog_threshold_V);

		% add columns to the for PDD_onset_timestamp_s and
		% PDD_offset_timestamp_s for the matching collection
		% numbers
		triallog_table = addvars(triallog_table, nan(size(triallog_table.collection_start_s)), nan(size(triallog_table.collection_start_s)), 'NewVariableNames', {'PDD_onset_s', 'PDD_offset_s'});
		triallog_table.PDD_onset_s(onset_offset_events_struct.pd_block_onset_collection_num_list + 1) = onset_offset_events_struct.pd_block_onset_s_list;
		triallog_table.PDD_onset_tick_idx = fn_convert_time_between_named_timebases(triallog_table.PDD_onset_s, time_conversion_struct, 'CCF_timestamps', 'CCF_ticks');
		triallog_table.PDD_onset_tick_idx = round(triallog_table.PDD_onset_tick_idx);

		% the times when CCF thought the stiumuls changed.. that is the tick_idx when the backend/target repositioned itself.
		%	 fromn then it takes time to percolate to the ui/target state
		%	 change, rendering and transmission to the OLED and final
		%	 display on the screen
		any_target_changed_pos_ldx = record2D_table.target0_changed_pos | record2D_table.target1_changed_pos | record2D_table.target2_changed_pos;
		any_target_changed_pos_idx = find(any_target_changed_pos_ldx);

		% he next is correct, but these are lagging behind by a numbre of
		% samples as we first increase the collection counter before we
		% change the stimulus...
		%triallog_table.PDD_offset_timestamp_s(onset_offset_events_struct.pd_block_offset_collection_num_list + 1) = onset_offset_events_struct.pd_block_offset_s_list;
		% so we account that for the pd_block_onset_collection_num_list as
		% otherwise in each collection the offset preceds the onset (which is technically correct, but undesired here for the per collection table)
		triallog_table.PDD_offset_s(onset_offset_events_struct.pd_block_onset_collection_num_list + 1) = onset_offset_events_struct.pd_block_offset_s_list;
		triallog_table.PDD_offset_tick_idx = fn_convert_time_between_named_timebases(triallog_table.PDD_offset_s, time_conversion_struct, 'CCF_timestamps', 'CCF_ticks');
		triallog_table.PDD_offset_tick_idx = round(triallog_table.PDD_offset_tick_idx);

	end


	% add reach/gaze position data to the triallog_table
	tmp_state_name_list = [enum_struct.target_state.name_list'; sorted_target_state_transition_table.new_state_ENUM_name];
	[unique_target_state_name_list, ~, proto_unique_target_state_name_list_row_idx] = unique(tmp_state_name_list, 'stable');
	tick_idx_list_list = cell(size(unique_target_state_name_list));
	for i_target_states = 2 : length(unique_target_state_name_list)
		cur_target_state_name = unique_target_state_name_list{i_target_states};
		cur_target_state_col_name = ['col_targ_', cur_target_state_name, '_tick_idx'];
		tick_idx_list_list(i_target_states) = {cur_target_state_col_name};
	end
	tick_idx_list_list(1) = [];	% we started from entry 2 to skip NONE
	tick_idx_list_list = [tick_idx_list_list; 'PDD_onset_tick_idx'];
	tick_idx_ext = '_tick_idx';
	[ triallog_table ] = fn_collect_fixations_around_tick_idx_lists( triallog_table, fixations_struct, record2D_table, tick_idx_list_list, tick_idx_ext);






	% now calculate the distances between the entities and add to table or
	% add as new table

	if ~isempty(h5_struct)
		% quick and dirty reward and collection estimation
		% these are co9rrected for the offset if diff()
		A0.collection_magnitude_tick_ldx = [false; diff(record2D_struct.table(:, ismember(record2D_struct.header, {'agent0_cumulative_score'})))];
		B1.collection_magnitude_tick_ldx = [false; diff(record2D_struct.table(:, ismember(record2D_struct.header, {'agent1_cumulative_score'})))];
		A0.collection_ldx = A0.collection_magnitude_tick_ldx > 0;
		B1.collection_ldx = B1.collection_magnitude_tick_ldx > 0;
		A0.n_collections = sum(A0.collection_ldx);
		B1.n_collections = sum(B1.collection_ldx);
		A0.n_pulses = sum(A0.collection_magnitude_tick_ldx);
		B1.n_pulses = sum(B1.collection_magnitude_tick_ldx);
		
		% THIS is WRONG, as it only reports for agent0, needs a proper per
		% target report
		[unique_reward_magnitudes_A, ~, unique_reward_magnitudes_A_row_idx] = unique(A0.collection_magnitude_tick_ldx);
		[unique_reward_magnitudes_B, ~, unique_reward_magnitudes_B_row_idx] = unique(B1.collection_magnitude_tick_ldx);
		% count the occurrances
		total_collections = record2D_struct.table(end, ismember(record2D_struct.header, {'n_finished_collections'}));
		total_duration_s = record2D_struct.table(end, ismember(record2D_struct.header, {'timestamp'})) - record2D_struct.table(1, ismember(record2D_struct.header, {'timestamp'}));

		disp(['sessionID: ', session_id, '; CCF pair code: ', CCF_pair, '; CCF run number: ', CCF_run]);
		disp(['duration [sec]: ', num2str(total_duration_s, '%0.0f'), '; total collections: ', num2str(total_collections), '; CA: ', num2str(A0.n_collections), '; CB: ', num2str(B1.n_collections), '; pulses: RA: ', num2str(A0.n_pulses), '; RB: ', num2str(B1.n_pulses)]);



		% add a per target report: target ID target type, n collections (A:,
		% B), n_rewards (A, B)


		% Note, this will fail for different targets with equal reward
		% magnitude...
		% for this we need to calcuulate distances between agents and targets

		% TODO replace by iterating over targets
		for i_unique_rewards_A = 1 : length(unique_reward_magnitudes_A)
			cur_reward_magnitude_A = unique_reward_magnitudes_A(i_unique_rewards_A);
			%disp(['Reward magnitude ', num2str(cur_reward_magnitude)]);
			if cur_reward_magnitude_A == 0
				%disp('Reward magnitude 0, skipping');
				continue
			end
			cur_reward_magnitude_A_n_collections = sum(unique_reward_magnitudes_A_row_idx == i_unique_rewards_A);
			cur_reward_magnitude_A_n_collections_ratio = cur_reward_magnitude_A_n_collections / total_collections;
			disp(['A0: Reward magnitude ', num2str(cur_reward_magnitude_A), '; n_colllections: ', num2str(cur_reward_magnitude_A_n_collections), ' of ', num2str(total_collections), ': ', num2str(100*cur_reward_magnitude_A_n_collections_ratio, '%0.1f'), '%']);
		end
		for i_unique_rewards_B = 1 : length(unique_reward_magnitudes_B)
			cur_reward_magnitude_B = unique_reward_magnitudes_B(i_unique_rewards_B);
			%disp(['Reward magnitude ', num2str(cur_reward_magnitude)]);
			if cur_reward_magnitude_B == 0
				%disp('Reward magnitude 0, skipping');
				continue
			end
			cur_reward_magnitude_B_n_collections = sum(unique_reward_magnitudes_B_row_idx == i_unique_rewards_B);
			cur_reward_magnitude_B_n_collections_ratio = cur_reward_magnitude_B_n_collections / total_collections;
			disp(['B1: Reward magnitude ', num2str(cur_reward_magnitude_B), '; n_colllections: ', num2str(cur_reward_magnitude_B_n_collections), ' of ', num2str(total_collections), ': ', num2str(100*cur_reward_magnitude_B_n_collections_ratio, '%0.1f'), '%']);
		end
	end

	if i_runfolder == 1
		%data_struct_list = data_struct;
		json_struct_list = json_struct;
		h5_struct_list = h5_struct;
		txt_struct_list = txt_struct;
	else
		%data_struct_list(end+1) = data_struct;
		json_struct_list(end+1) = json_struct;
		h5_struct_list(end+1) = h5_struct;
		txt_struct_list(end+1) = txt_struct;
	end

end


timestamps.(mfilename).end = toc(timestamps.(mfilename).start);
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end), ' seconds.']);
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end / 60), ' minutes.']);
%disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end / (60 * 60)), ' hours.']);
%disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end / (60 * 60 * 24)), ' days. Done...']);


end


function [] = fn_save_figure(figure_handle, data_path, name_string)

if ~isempty(figure_handle)
	if ismember(exist('write_out_figure'), [2,4])
		write_out_figure(figure_handle, fullfile(data_path, name_string));
	else
		exportgraphics(figure_handle, fullfile(cur_path, fullfile(data_path, name_string)), 'BackgroundColor', 'none', 'ContentType', 'vector');
	end
	close(figure_handle);
end

return
end



function  out_table = fn_convert_header_table_timestamp_list_struct_to_table( in_struct )
out_table = [];

if length(in_struct.header) ~= size(in_struct.table, 2)
	error([mfilename, ': data array has more columns than the column name list, investigate...']);
end

out_table = array2table(in_struct.table, 'VariableNames', in_struct.header);

% now add the timestamp_list
%out_table.timestamp_s = in_struct.timestamp_list;
out_table = addvars(out_table, in_struct.timestamp_list, 'Before', 1, 'NewVariableNames', 'timestamp_s');

end



