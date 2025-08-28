function [ data_struct, json_struct, h5_struct, txt_struct ] = fn_parse_CCF_data( cur_CCF_runfolder_FQN_list )
%FN_PARSE_CCF_DATA Summary of this function goes here
%   Detailed explanation goes here
%
% TODO implement looping over a base folder and pick the runfolders
% automatically

data_struct_list = struct();
json_struct_list = struct();
h5_struct_list = struct();
txt_struct_list = struct();

data_struct = [];
json_struct = [];
h5_struct = [];
txt_struct = [];


dbstop if error
debug = 0;

if ~exist('CCF_run_folder_FQN_list', 'var') || isempty(CCF_run_folder_FQN_list)
	% (venv_py3.10) root@LC38836:/home/smoeller@dpz.lokal/SCP_CODE/TASKS/foraging_task_2_NHP/src#
	CCF_recordings_folder_FQN = fullfile('~', 'SCP_CODE', 'TASKS', 'foraging_task_2_NHP', 'recordings');
	cur_CCF_runfolder_FQN_list = fullfile(CCF_recordings_folder_FQN, '001_101', '3');

	CCF_data_base_path = fullfile('/', 'Users', 'smoeller', 'DPZ', 'taskcontroller', 'CODE', 'CCF', 'CCF_RECORDINGS', 'recordings');
	CCF_data_base_path = fullfile('/', 'Volumes', 'snd', 'taskcontroller', 'SCP_DATA', 'SCP-CTRL-01', 'CCF', 'recordings');
	cur_CCF_runfolder_FQN_list = fullfile(CCF_data_base_path, '001_101', '28');
	cur_CCF_runfolder_FQN_list = fullfile(CCF_data_base_path, '100_101', '3');

	cur_CCF_runfolder_FQN_list = fullfile('/', 'Volumes', 'snd', 'taskcontroller', 'SCP_DATA', 'SCP-CTRL-01', 'CCF', 'recordings', '001_100', '7');

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

	for i_h5_FQN = 1 : length(h5_dir_struct)
		cur_h5_name = h5_dir_struct(i_h5_FQN).name;
		if (debug)
			disp(['Processing: ', cur_h5_name]);
		end
		cur_h5_FQN = [json_dir_struct(i_h5_FQN).folder, filesep, h5_dir_struct(i_h5_FQN).name];
		[~, cur_h5_name] = fileparts(h5_dir_struct(i_h5_FQN).name);

		cur_h5info = h5info(cur_h5_FQN);

		for i_h5_dataset = 1 : length(cur_h5info.Datasets)
			cur_h5_dataset_name =  cur_h5info.Datasets.Name;
			cur_data = h5read(cur_h5_FQN, ['/', cur_h5_dataset_name]);	% hdf5 datasets start with / apparently
			if ~isempty(cur_data)
				h5_struct.([cur_h5_name, '_', cur_h5_dataset_name]) = cur_data;
			else
				disp([cur_h5_name, ' (' , cur_h5_dataset_name, ') contained no data, skipping...']);
			end
		end
	end

	if ~isempty(h5_struct) && length(fieldnames(h5_struct)) == 1 && ismember(fieldnames(h5_struct), {'record_data'})
		% create a proper header for the data and reshape to 2D table...
		data_struct.header = {};
		[dim1, dim2, dim3] = size(h5_struct.record_data);	% dim1 X, Y, additional data, dim2; entries: 
		n_cols = dim1 * dim2;
		n_rows = dim3;

		data_struct.table = reshape(h5_struct.record_data, n_cols, n_rows)';
		data_struct.header = {'aim_0_X_rel', 'aim_0_Y_rel', 'tick_timestamp_sec', 'aim_1_X_rel', 'aim_1_Y_rel', '', 'agent_0_X', 'agent_0_Y', 'cumulative_score_0', 'agent_1_X', 'agent_1_Y', ''};
		n_agent_cols = 12;
		n_cols_per_entity = 3;
		n_targets = (n_cols - n_agent_cols)/3;
		for i_targets = 1 : n_targets
			cur_target_id_col_idx = (n_agent_cols + ((i_targets - 1) * n_cols_per_entity) + n_cols_per_entity);
			cur_target_id = unique(data_struct.table(:, cur_target_id_col_idx));
			if length(cur_target_id) ~= 1
				error('flattening 3D table failed, please investigate why');
			end
			data_struct.header(end+1) = {['target_', num2str(cur_target_id), '_X_rel']};
			data_struct.header(end+1) = {['target_', num2str(cur_target_id), '_Y_rel']};
			data_struct.header(end+1) = {['target_', num2str(cur_target_id), '_ID']};
		end
	else
		disp(['No data found in ', cur_CCF_runfolder_FQN]);
	end

	% now calculate the distances between the entities and add to table or
	% add as new table

	if ~isempty(h5_struct)
		% quick and dirty reward
		reward_differences = diff(data_struct.table(:, ismember(data_struct.header, {'cumulative_score_0'})));
		[unique_reward_magnitudes, ~, unique_reward_magnitudes_row_idx] = unique(reward_differences);
		% count the occurrances
		total_collections = sum(reward_differences >= 1);

		% Note, this will fail for different targets with equal reward
		% magnitude...
		% for this we need to calcuulate distances between agents and targets
		for i_unique_rewards = 1 : length(unique_reward_magnitudes)
			cur_reward_magnitude = unique_reward_magnitudes(i_unique_rewards);
			%disp(['Reward magnitude ', num2str(cur_reward_magnitude)]);
			if cur_reward_magnitude == 0
				%disp('Reward magnitude 0, skipping');
				continue
			end
			cur_reward_magnitude_n_collections = sum(unique_reward_magnitudes_row_idx == i_unique_rewards);
			cur_reward_magnitude_n_collections_ratio = cur_reward_magnitude_n_collections / total_collections;
			disp(['Reward magnitude ', num2str(cur_reward_magnitude), '; n_colllections: ', num2str(cur_reward_magnitude_n_collections), ' of ', num2str(total_collections), ': ', num2str(100*cur_reward_magnitude_n_collections_ratio, '%0.1f'), '%']);

		end
	end

	if i_runfolder == 1
		data_struct_list = data_struct;
		json_struct_list = json_struct;
		h5_struct_list = h5_struct;
		txt_struct_list = txt_struct;
	else
		data_struct_list(end+1) = data_struct;
		json_struct_list(end+1) = json_struct;
		h5_struct_list(end+1) = h5_struct;
		txt_struct_list(end+1) = txt_struct;
	end

end

end

