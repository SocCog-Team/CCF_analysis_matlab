function [merged_sessiondir_FQN] = fn_merge_same_session_CCF_sessiondirs(sessiondir_merge_list_FQN)
%FN_MERGE_SAME_SESSION_CCF_SESSIONDIRS Merge multiple CCF session runs into one.
%   Reads raw data files from each session in the merge list, adjusts
%   collection numbers and target indices, fills inter-run gaps in AI/DI
%   samples, and writes a complete merged session directory that
%   fn_parse_CCF_data can read without modification.
%
%   sessiondir_merge_list_FQN : path to a text file listing one session
%                               directory per line. The parent directory
%                               of this file is used as the output.

dbstop if error
fq_mfilename = mfilename('fullpath');
timestamps.(mfilename).start = tic;
disp(['Starting: ', mfilename]);



% we want a clean string
here = pwd;
CCF_analysis_path = fullfile(fileparts(fq_mfilename), '..');
cd(CCF_analysis_path)
CCF_analysis_path = pwd;
cd(here);

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






% =====================================================================
%  1. INPUT HANDLING
% =====================================================================
if ~exist('sessiondir_merge_list_FQN', 'var') || isempty(sessiondir_merge_list_FQN)
	sessiondir_merge_list_FQN = {fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2025', '251219', ...
		'20251219TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir', 'merge_CCF_sessiondir_list.txt')};
	sessiondir_merge_list_FQN = {fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260319', ...	% took 7674.839 seconds
		'20260319TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir', 'merge_CCF_sessiondir_list.txt')};
	sessiondir_merge_list_FQN = {fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260319', ...	% new jsonl logic
		'20260319TNNNNNNM2.A_Elmo.B_MIXED.SCP_01.sessiondir', 'merge_CCF_sessiondir_list.txt')};
	
end

if iscell(sessiondir_merge_list_FQN)
	sessiondir_merge_list_FQN = sessiondir_merge_list_FQN{1};
end

sessiondir_merge_list = readlines(sessiondir_merge_list_FQN);
sessiondir_merge_list = sessiondir_merge_list(strlength(sessiondir_merge_list) > 0);
n_runs = length(sessiondir_merge_list);
disp([mfilename, ': merging ', num2str(n_runs), ' session directories.']);

% Output goes into the directory containing the merge list
[merged_sessiondir_FQN, ~, ~] = fileparts(sessiondir_merge_list_FQN);


% =====================================================================
%  2. LOAD RAW DATA FROM EACH SESSION
% =====================================================================
raw_data_list = cell(1, n_runs);
for i_run = 1 : n_runs
	cur_sessiondir = char(sessiondir_merge_list(i_run));
	disp([mfilename, ': loading run ', num2str(i_run), '/', num2str(n_runs), ': ', cur_sessiondir]);
	raw_data_list{i_run} = fn_load_CCF_raw_files(cur_sessiondir);
end


% =====================================================================
%  3. VERIFY ENUMS IDENTICAL
% =====================================================================
for i_run = 2 : n_runs
	if ~strcmp(raw_data_list{i_run}.enums_text, raw_data_list{1}.enums_text)
		error([mfilename, ': enums.py differs between run 1 and run ', num2str(i_run), ...
			'. Cannot merge sessions with different enum definitions.']);
	end
end
disp([mfilename, ': enums.py verified identical across all runs.']);


% =====================================================================
%  4. BUILD GLOBAL TARGET MAP
% =====================================================================
global_target_map = fn_build_global_target_map(raw_data_list);


% =====================================================================
%  5. COMPUTE COLLECTION OFFSETS
% =====================================================================
collection_offset_list = zeros(1, n_runs);
for i_run = 2 : n_runs
	prev_header = raw_data_list{i_run-1}.json_struct.record2D_header.record2D_column_names';
	prev_data = squeeze(raw_data_list{i_run-1}.h5_struct.record2D_data)';
	col_idx = find(ismember(prev_header, {'n_finished_collections'}));
	max_prev_collection = max(prev_data(:, col_idx));
	collection_offset_list(i_run) = collection_offset_list(i_run-1) + max_prev_collection + 1;
end
disp([mfilename, ': collection offsets: ', num2str(collection_offset_list)]);


% =====================================================================
%  6. MERGE record2D
% =====================================================================
merged_record2D_header = {};
merged_record2D_data_cell = cell(1, n_runs);
cumulative_score_col_name_list = {'agent0_cumulative_score', 'agent1_cumulative_score'};

for i_run = 1 : n_runs
	cur_header = raw_data_list{i_run}.json_struct.record2D_header.record2D_column_names';
	cur_data = squeeze(raw_data_list{i_run}.h5_struct.record2D_data)';

	% Remap target columns so each global slot carries a consistent target_id
	% TODO potentially keep the respective target_id set to the real
	% target_id of the subset of ticks with a valid target but use that for
	% all ticks
	[cur_header, cur_data] = fn_remap_record2D_targets(cur_header, cur_data, ...
		global_target_map.per_run_local_to_global{i_run}, ...
		global_target_map.n_global_targets, ...
		global_target_map.canonical_suffix_list);

	% Offset n_finished_collections
	nfc_col = find(ismember(cur_header, {'n_finished_collections'}));
	cur_data(:, nfc_col) = cur_data(:, nfc_col) + collection_offset_list(i_run);

	% Carry over cumulative scores so they keep increasing across runs
	for i_cs = 1 : length(cumulative_score_col_name_list)
		cs_col = find(ismember(cur_header, cumulative_score_col_name_list(i_cs)));
		if ~isempty(cs_col) && i_run > 1
			prev_data = merged_record2D_data_cell{i_run-1};
			prev_cs_col = find(ismember(merged_record2D_header, cumulative_score_col_name_list(i_cs)));
			if ~isempty(prev_cs_col)
				prev_final_score = prev_data(end, prev_cs_col);
				cur_data(:, cs_col) = cur_data(:, cs_col) + prev_final_score;
			end
		end
	end

	% Add run_idx metadata column
	cur_header{end+1} = 'run_idx';
	cur_data(:, end+1) = i_run - 1;	% python style 0-based index

	merged_record2D_data_cell{i_run} = cur_data;

	if i_run == 1
		merged_record2D_header = cur_header;
	else
		if ~isequal(cur_header, merged_record2D_header)
			error([mfilename, ': record2D headers differ after target remapping at run ', num2str(i_run)]);
		end
	end
end

merged_record2D_data = vertcat(merged_record2D_data_cell{:});

% Forward-fill spurious zeros in cumulative_score columns: any zero that
% follows a non-zero value is replaced with the last non-zero value.
% Leading zeros (before the first reward) are kept.
for i_cs = 1 : length(cumulative_score_col_name_list)
	cs_col = find(ismember(merged_record2D_header, cumulative_score_col_name_list(i_cs)));
	if ~isempty(cs_col)
		cs_values = merged_record2D_data(:, cs_col);
		last_valid = 0;
		for i_row = 1 : length(cs_values)
			if cs_values(i_row) ~= 0
				last_valid = cs_values(i_row);
			elseif last_valid ~= 0
				cs_values(i_row) = last_valid;
			end
		end
		merged_record2D_data(:, cs_col) = cs_values;
	end
end

disp([mfilename, ': merged record2D: ', num2str(size(merged_record2D_data, 1)), ' rows x ', ...
	num2str(size(merged_record2D_data, 2)), ' cols.']);


% =====================================================================
%  7. MERGE AI SAMPLES
% =====================================================================
[merged_AI_data, ~, merged_AI_header, merged_AI_idx_ts_data, merged_AI_idx_ts_header] = ...
	fn_merge_sampled_data(raw_data_list, 'AI_samples', NaN);


% =====================================================================
%  8. MERGE DI SAMPLES
% =====================================================================
[merged_DI_data, ~, merged_DI_header, merged_DI_idx_ts_data, merged_DI_idx_ts_header] = ...
	fn_merge_sampled_data(raw_data_list, 'DI_samples', 0);


% =====================================================================
%  9. MERGE JSONL FILES (streaming: read → adjust → write directly)
% =====================================================================
% --- Streaming JSONL merge: read → adjust → write, one line at a time ---
% Discover all unique JSONL filenames across runs
all_jsonl_filename_list = {};
for i_run = 1 : n_runs
	cur_dir = char(sessiondir_merge_list(i_run));
	cur_jsonl_dir_struct = dir(fullfile(cur_dir, '*.jsonl'));
	for i_f = 1 : length(cur_jsonl_dir_struct)
		all_jsonl_filename_list{end+1} = cur_jsonl_dir_struct(i_f).name;
	end
end
unique_jsonl_filename_list = unique(all_jsonl_filename_list);

for i_jn = 1 : length(unique_jsonl_filename_list)
	cur_jsonl_filename = unique_jsonl_filename_list{i_jn};
	output_FQN = fullfile(merged_sessiondir_FQN, cur_jsonl_filename);

	fid_out = fopen(output_FQN, 'w');
	if fid_out == -1
		error([mfilename, ': could not open for writing: ', output_FQN]);
	end

	n_lines_total = 0;
	for i_run = 1 : n_runs
		cur_source_FQN = fullfile(char(sessiondir_merge_list(i_run)), cur_jsonl_filename);
		if ~isfile(cur_source_FQN)
			continue
		end

		fid_in = fopen(cur_source_FQN, 'r');
		if fid_in == -1
			continue
		end

		while true
			cur_line = fgetl(fid_in);
			if isequal(cur_line, -1)
				break
			end
			if isempty(strtrim(cur_line))
				continue
			end

			cur_record = jsondecode(cur_line);

			if isfield(cur_record, 'collection_number')
				cur_record.collection_number = cur_record.collection_number + collection_offset_list(i_run);
			end

			cur_record.run_idx = int32(i_run - 1);

			fprintf(fid_out, '%s\n', jsonencode(cur_record));
			n_lines_total = n_lines_total + 1;
		end

		fclose(fid_in);
	end

	fclose(fid_out);
	disp([mfilename, ': wrote ', num2str(n_lines_total), ' lines to: ', output_FQN]);
end


% =====================================================================
%  10. MERGE CSV FILES (movement_to_target)
% =====================================================================
% _frame columns are row indices into the per-run record2D; offset them
% so they point to the correct rows in the merged record2D table.
% The matching _s columns are relative to per-run experiment start and
% will be recalculated by fn_parse_CCF_data from record2D timestamps
% using the corrected _frame/_tick_idx values, so they need no adjustment.
record2D_row_offset_list = zeros(1, n_runs);
for i_run = 2 : n_runs
	record2D_row_offset_list(i_run) = record2D_row_offset_list(i_run-1) ...
		+ size(merged_record2D_data_cell{i_run-1}, 1);
end
disp([mfilename, ': record2D row offsets: ', num2str(record2D_row_offset_list)]);

merged_csv = struct();
merged_movement = [];
for i_run = 1 : n_runs
	if isfield(raw_data_list{i_run}.csv_struct, 'movement_to_target')
		cur_table = raw_data_list{i_run}.csv_struct.movement_to_target;

		% Offset cycle (maps to trial_num / collection_num)
		if ismember({'cycle'}, cur_table.Properties.VariableNames)
			cur_table.cycle = cur_table.cycle + collection_offset_list(i_run);
		end

		% Offset all _frame columns (record2D row indices)
		col_name_list = cur_table.Properties.VariableNames;
		frame_col_ldx = endsWith(col_name_list, '_frame');
		for i_fc = find(frame_col_ldx)
			cur_col_name = col_name_list{i_fc};
			cur_values = cur_table.(cur_col_name);
			valid_ldx = ~isnan(cur_values);
			cur_table.(cur_col_name)(valid_ldx) = cur_values(valid_ldx) + record2D_row_offset_list(i_run);
		end

		cur_table.run_idx = repmat(int32(i_run - 1), size(cur_table, 1), 1);
		if isempty(merged_movement)
			merged_movement = cur_table;
		else
			merged_movement = [merged_movement; cur_table];
		end
	end
end
if ~isempty(merged_movement)
	merged_csv.movement_to_target = merged_movement;
end


% =====================================================================
%  11. BUILD MANIFEST
% =====================================================================
manifest = struct();
manifest.created = datestr(now, 'yyyy-mm-ddTHH:MM:SS');
manifest.merge_list_FQN = sessiondir_merge_list_FQN;
manifest.n_runs = n_runs;
manifest.collection_offset_list = collection_offset_list;

source_sessions_list = [];
for i_run = 1 : n_runs
	cur_entry.run_idx = i_run - 1;
	cur_entry.sessiondir_FQN = raw_data_list{i_run}.source_dir_FQN;
	cur_entry.session_id = raw_data_list{i_run}.session_id;
	cur_entry.agent_A_name = raw_data_list{i_run}.agent_A_name;
	cur_entry.agent_B_name = raw_data_list{i_run}.agent_B_name;
	cur_entry.CCF_pair = raw_data_list{i_run}.CCF_pair;
	cur_entry.CCF_run = raw_data_list{i_run}.CCF_run;
	cur_entry.collection_offset = collection_offset_list(i_run);

	if isfield(raw_data_list{i_run}.json_struct, 'conf')
		cur_entry.conf = raw_data_list{i_run}.json_struct.conf;
	end

	if isempty(source_sessions_list)
		source_sessions_list = cur_entry;
	else
		source_sessions_list(end+1) = cur_entry;
	end
end
manifest.source_sessions = source_sessions_list;
manifest.global_target_map_n_targets = global_target_map.n_global_targets;
manifest.global_target_map_unique_ids = global_target_map.unique_id_list;


% =====================================================================
%  12. ASSEMBLE OUTPUT STRUCT AND WRITE
% =====================================================================
merged_data_struct = struct();
merged_data_struct.record2D_header = merged_record2D_header;
merged_data_struct.record2D_data = merged_record2D_data;

merged_data_struct.AI_samples_data = merged_AI_data;
merged_data_struct.AI_samples_header = merged_AI_header;
merged_data_struct.AI_samples_idx_ts_data = merged_AI_idx_ts_data;
merged_data_struct.AI_samples_idx_ts_header = merged_AI_idx_ts_header;

merged_data_struct.DI_samples_data = merged_DI_data;
merged_data_struct.DI_samples_header = merged_DI_header;
merged_data_struct.DI_samples_idx_ts_data = merged_DI_idx_ts_data;
merged_data_struct.DI_samples_idx_ts_header = merged_DI_idx_ts_header;

merged_data_struct.jsonl = struct();	% JSONL files already written by streaming merge
merged_data_struct.csv = merged_csv;
merged_data_struct.enums_text = raw_data_list{1}.enums_text;

% Use first run's conf as the top-level conf for fn_parse_CCF_data compatibility
if isfield(raw_data_list{1}.json_struct, 'conf')
	merged_data_struct.conf = raw_data_list{1}.json_struct.conf;
else
	merged_data_struct.conf = struct();
end

merged_data_struct.manifest = manifest;

% Generate a merged session ID from the directory name
[~, merged_dir_name] = fileparts(merged_sessiondir_FQN);
merged_data_struct.session_id = ['merged_', merged_dir_name];
merged_data_struct.session_id = merged_dir_name;	% we already have a marker in the ID string, e.g. '20251219TNNNNNNM.A_Elmo.B_MIXED.SCP_01', the NNNNNNM


fn_write_merged_CCF_session(merged_sessiondir_FQN, merged_data_struct);

disp([mfilename, ': merge complete. Output: ', merged_sessiondir_FQN]);


timestamps.(mfilename).end = toc(timestamps.(mfilename).start);
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end), ' seconds.']);
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end / 60), ' minutes.']);

end


% =====================================================================
%  LOCAL HELPERS
% =====================================================================

function merged_table = fn_merge_one_jsonl_table(merged_table, cur_table, collection_offset, run_idx_0based)
%FN_MERGE_ONE_JSONL_TABLE Offset collection_number, add run_idx, and concatenate.

if isempty(cur_table) || size(cur_table, 1) == 0
	return
end

if ismember({'collection_number'}, cur_table.Properties.VariableNames)
	cur_table.collection_number = cur_table.collection_number + collection_offset;
end
cur_table.run_idx = repmat(int32(run_idx_0based), size(cur_table, 1), 1);

if isempty(merged_table)
	merged_table = cur_table;
else
	merged_table = [merged_table; cur_table];
end

end
