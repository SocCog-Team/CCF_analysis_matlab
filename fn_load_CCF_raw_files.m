function [raw_data] = fn_load_CCF_raw_files(cur_CCF_sessiondir_FQN)
%FN_LOAD_CCF_RAW_FILES Load all raw CCF data files from a session directory.
%   Returns a struct containing h5, json, jsonl, enum, sessionID, csv, and
%   txt data without any derived processing (no table amendments, no
%   triallog creation). This is the loading-only stage that can be shared
%   between fn_parse_CCF_data and the session merge workflow.

timestamps.(mfilename).start = tic;
disp(['Starting: ', mfilename, ' for: ', cur_CCF_sessiondir_FQN]);
dbstop if error
fq_mfilename = mfilename('fullpath');

raw_data = struct();
raw_data.source_dir_FQN = cur_CCF_sessiondir_FQN;

raw_data.json_struct = struct();
raw_data.h5_struct = struct();
raw_data.jsonl_struct = struct();
raw_data.txt_struct = struct();
raw_data.csv_struct = struct();
raw_data.enum_struct = [];
raw_data.enums_text = '';
raw_data.session_id = '';
raw_data.CCF_pair = '';
raw_data.CCF_run = '';
raw_data.agent_A_name = 'unknown';
raw_data.agent_B_name = 'unknown';


% --- Discover files ---
json_dir_struct = dir(fullfile(cur_CCF_sessiondir_FQN, '*.json'));
h5_dir_struct = dir(fullfile(cur_CCF_sessiondir_FQN, '*.h5'));
txt_dir_struct = dir(fullfile(cur_CCF_sessiondir_FQN, '*.txt'));
sessionID_dir_struct = dir(fullfile(cur_CCF_sessiondir_FQN, '*.sessionID'));
jsonl_dir_struct = dir(fullfile(cur_CCF_sessiondir_FQN, '*.jsonl'));
csv_dir_struct = dir(fullfile(cur_CCF_sessiondir_FQN, '*.csv'));


% --- Enums ---
enums_FQN = fullfile(cur_CCF_sessiondir_FQN, 'enums.py');
if isfile(enums_FQN)
	raw_data.enum_struct = fn_extract_python_enums(enums_FQN);
	raw_data.enums_text = fileread(enums_FQN);
end


% --- Session ID and CCF pair/run ---
if ~isempty(sessionID_dir_struct)
	raw_data.session_id = extractBefore(sessionID_dir_struct.name, '.sessionID');
	CCF_session_dir_content = fileread(fullfile(sessionID_dir_struct.folder, sessionID_dir_struct.name));
	CCF_session_dir_elements = split(strtrim(CCF_session_dir_content), '/');
	raw_data.CCF_run = CCF_session_dir_elements{end};
	raw_data.CCF_pair = CCF_session_dir_elements{end-1};
end


% --- Parse agent names from sessiondir folder name ---
% Expected pattern: YYYYMMDDTHHMMSS.A_<name>.B_<name>.SCP_01.sessiondir
[~, sessiondir_name] = fileparts(cur_CCF_sessiondir_FQN);
agent_A_tokens = regexp(sessiondir_name, '\.A_([^.]+)\.', 'tokens');
agent_B_tokens = regexp(sessiondir_name, '\.B_([^.]+)\.', 'tokens');
if ~isempty(agent_A_tokens)
	raw_data.agent_A_name = agent_A_tokens{1}{1};
end
if ~isempty(agent_B_tokens)
	raw_data.agent_B_name = agent_B_tokens{1}{1};
end


% --- JSON files ---
for i_json = 1 : length(json_dir_struct)
	cur_json_FQN = fullfile(json_dir_struct(i_json).folder, json_dir_struct(i_json).name);
	[~, cur_json_name] = fileparts(json_dir_struct(i_json).name);

	% currently the calibration files have to many dots...
	if ~isvarname(cur_json_name)
		%cur_json_name = matlab.lang.makeValidName(cur_json_name,'ReplacementStyle','hex');
		cur_json_name = matlab.lang.makeValidName(cur_json_name,'ReplacementStyle','underscore');
	end
	tmp_string_data = fileread(cur_json_FQN);
	if ~isempty(tmp_string_data)
		raw_data.json_struct.(cur_json_name) = jsondecode(tmp_string_data);
	else
		disp([mfilename, ': INFO: ', cur_json_name, ' empty, skipping.']);
	end
end


% --- H5 files ---
for i_h5 = 1 : length(h5_dir_struct)
	cur_h5_FQN = fullfile(h5_dir_struct(i_h5).folder, h5_dir_struct(i_h5).name);
	[~, cur_h5_name] = fileparts(h5_dir_struct(i_h5).name);
	cur_file_info = dir(cur_h5_FQN);
	if cur_file_info.bytes < 97
		disp([mfilename, ': WARN: H5 file too small, skipping: ', cur_h5_FQN]);
		continue
	end

	try
		cur_h5info = h5info(cur_h5_FQN);
	catch ME
		ME
		disp([mfilename, ': WARN: H5 file probably corrupted, skipping: ', cur_h5_FQN]);
		continue
	end

	for i_ds = 1 : length(cur_h5info.Datasets)
		cur_ds_name = cur_h5info.Datasets(i_ds).Name;
		cur_data = h5read(cur_h5_FQN, ['/', cur_ds_name]);
		if contains(cur_h5_FQN, 'record2D.h5')
			cur_data = squeeze(cur_data);
		end
		if ~isempty(cur_data)
			raw_data.h5_struct.([cur_h5_name, '_', cur_ds_name]) = cur_data;
		end
	end
end


% --- JSONL files ---
for i_jsonl = 1 : length(jsonl_dir_struct)
	cur_jsonl_FQN = fullfile(jsonl_dir_struct(i_jsonl).folder, jsonl_dir_struct(i_jsonl).name);
	[~, cur_jsonl_name] = fileparts(jsonl_dir_struct(i_jsonl).name);
	tmp_string_data = fileread(cur_jsonl_FQN);
	if ~isempty(tmp_string_data)
		raw_data.jsonl_struct.(cur_jsonl_name) = fn_parse_jsonl_file(cur_jsonl_FQN);
	else
		disp([mfilename, ': INFO: ', cur_jsonl_name, ' empty, skipping.']);
	end
end


% --- TXT files ---
for i_txt = 1 : length(txt_dir_struct)
	cur_txt_FQN = fullfile(txt_dir_struct(i_txt).folder, txt_dir_struct(i_txt).name);
	[~, cur_txt_name] = fileparts(txt_dir_struct(i_txt).name);
	cur_txt_name = matlab.lang.makeValidName(cur_txt_name);
	raw_data.txt_struct.(cur_txt_name) = fileread(cur_txt_FQN);
end


% --- CSV files ---
for i_csv = 1 : length(csv_dir_struct)
	cur_csv_FQN = fullfile(csv_dir_struct(i_csv).folder, csv_dir_struct(i_csv).name);
	[~, cur_csv_name] = fileparts(csv_dir_struct(i_csv).name);
	cur_csv_name = matlab.lang.makeValidName(cur_csv_name);
	if isfile(cur_csv_FQN)
		raw_data.csv_struct.(cur_csv_name) = readtable(cur_csv_FQN);
	end
end


timestamps.(mfilename).end = toc(timestamps.(mfilename).start);
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end), ' seconds.']);

end
