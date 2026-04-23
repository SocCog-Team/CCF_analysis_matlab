function [] = fn_write_merged_CCF_session(output_dir_FQN, merged_data_struct)
%FN_WRITE_MERGED_CCF_SESSION Write merged CCF data to disk in the original file format.
%   Creates a complete session directory that fn_parse_CCF_data can read
%   without modification. Writes h5 + json header files, jsonl, conf,
%   enums, sessionID, csv, and the merge manifest.

timestamps.(mfilename).start = tic;
disp(['Starting: ', mfilename]);
dbstop if error

if ~isfolder(output_dir_FQN)
	mkdir(output_dir_FQN);
	disp([mfilename, ': created output directory: ', output_dir_FQN]);
end


% ===== record2D =====
if ~isempty(merged_data_struct.record2D_data)
	fn_write_h5_dataset(fullfile(output_dir_FQN, 'record2D.h5'), ...
		merged_data_struct.record2D_data, true);

	header_s.record2D_column_names = merged_data_struct.record2D_header;
	fn_write_json_file(fullfile(output_dir_FQN, 'record2D_header.json'), header_s);
	disp([mfilename, ': wrote record2D.h5 (', ...
		num2str(size(merged_data_struct.record2D_data, 1)), ' rows x ', ...
		num2str(size(merged_data_struct.record2D_data, 2)), ' cols)']);
end


% ===== AI_samples =====
if ~isempty(merged_data_struct.AI_samples_data)
	fn_write_h5_dataset(fullfile(output_dir_FQN, 'AI_samples.h5'), ...
		merged_data_struct.AI_samples_data, false);
	fn_write_json_file(fullfile(output_dir_FQN, 'AI_samples_header.json'), ...
		merged_data_struct.AI_samples_header);

	fn_write_h5_dataset(fullfile(output_dir_FQN, 'AI_samples_idx_ts.h5'), ...
		merged_data_struct.AI_samples_idx_ts_data, false);
	fn_write_json_file(fullfile(output_dir_FQN, 'AI_samples_idx_ts_header.json'), ...
		merged_data_struct.AI_samples_idx_ts_header);
	disp([mfilename, ': wrote AI_samples.h5 (', ...
		num2str(size(merged_data_struct.AI_samples_data, 1)), ' samples)']);
end


% ===== DI_samples =====
if ~isempty(merged_data_struct.DI_samples_data)
	fn_write_h5_dataset(fullfile(output_dir_FQN, 'DI_samples.h5'), ...
		merged_data_struct.DI_samples_data, false);
	fn_write_json_file(fullfile(output_dir_FQN, 'DI_samples_header.json'), ...
		merged_data_struct.DI_samples_header);

	fn_write_h5_dataset(fullfile(output_dir_FQN, 'DI_samples_idx_ts.h5'), ...
		merged_data_struct.DI_samples_idx_ts_data, false);
	fn_write_json_file(fullfile(output_dir_FQN, 'DI_samples_idx_ts_header.json'), ...
		merged_data_struct.DI_samples_idx_ts_header);
	disp([mfilename, ': wrote DI_samples.h5 (', ...
		num2str(size(merged_data_struct.DI_samples_data, 1)), ' samples)']);
end


% ===== JSONL files =====
% Each field is either a flat table (homogeneous file) or a struct with
% sub-fields per record type (heterogeneous file). Heterogeneous files
% are written by interleaving all sub-tables sorted by timestamp.
jsonl_field_list = fieldnames(merged_data_struct.jsonl);
for i_jsonl = 1 : length(jsonl_field_list)
	cur_name = jsonl_field_list{i_jsonl};
	cur_data = merged_data_struct.jsonl.(cur_name);
	cur_output_FQN = fullfile(output_dir_FQN, [cur_name, '.jsonl']);

	if istable(cur_data)
		if ~isempty(cur_data)
			fn_write_jsonl_file(cur_output_FQN, cur_data);
		end
	elseif isstruct(cur_data)
		fn_write_heterogeneous_jsonl_file(cur_output_FQN, cur_data);
	end
end


% ===== CSV files =====
if isfield(merged_data_struct, 'csv') && ~isempty(merged_data_struct.csv)
	csv_field_list = fieldnames(merged_data_struct.csv);
	for i_csv = 1 : length(csv_field_list)
		cur_name = csv_field_list{i_csv};
		cur_table = merged_data_struct.csv.(cur_name);
		if ~isempty(cur_table)
			writetable(cur_table, fullfile(output_dir_FQN, [cur_name, '.csv']));
			disp([mfilename, ': wrote ', cur_name, '.csv']);
		end
	end
end


% ===== conf.json =====
if isfield(merged_data_struct, 'conf') && ~isempty(merged_data_struct.conf)
	fn_write_json_file(fullfile(output_dir_FQN, 'conf.json'), merged_data_struct.conf);
	disp([mfilename, ': wrote conf.json']);
end


% ===== merged_conf.jsonl =====
if isfield(merged_data_struct, 'conf_list') && ~isempty(merged_data_struct.conf_list)
	conf_jsonl_FQN = fullfile(output_dir_FQN, 'merged_conf.jsonl');
	fid = fopen(conf_jsonl_FQN, 'w');
	if fid == -1
		error([mfilename, ': could not open for writing: ', conf_jsonl_FQN]);
	end
	for i_conf = 1 : length(merged_data_struct.conf_list)
		fprintf(fid, '%s\n', jsonencode(merged_data_struct.conf_list{i_conf}));
	end
	fclose(fid);
	disp([mfilename, ': wrote merged_conf.jsonl (', ...
		num2str(length(merged_data_struct.conf_list)), ' entries)']);
end


% ===== enums.py =====
if isfield(merged_data_struct, 'enums_text') && ~isempty(merged_data_struct.enums_text)
	fid = fopen(fullfile(output_dir_FQN, 'enums.py'), 'w');
	fwrite(fid, merged_data_struct.enums_text);
	fclose(fid);
	disp([mfilename, ': wrote enums.py']);
end


% ===== sessionID =====
if isfield(merged_data_struct, 'session_id') && ~isempty(merged_data_struct.session_id)
	session_id_FQN = fullfile(output_dir_FQN, [merged_data_struct.session_id, '.sessionID']);
	fid = fopen(session_id_FQN, 'w');
	% content: the merged session directory path (use Linux-style forward slashes)
	merged_path_linux = strrep(output_dir_FQN, '\', '/');
	fwrite(fid, merged_path_linux);
	fclose(fid);
	disp([mfilename, ': wrote ', merged_data_struct.session_id, '.sessionID']);
end


% ===== merge_manifest.json =====
if isfield(merged_data_struct, 'manifest') && ~isempty(merged_data_struct.manifest)
	fn_write_json_file(fullfile(output_dir_FQN, 'merge_manifest.json'), merged_data_struct.manifest);
	disp([mfilename, ': wrote merge_manifest.json']);
end


timestamps.(mfilename).end = toc(timestamps.(mfilename).start);
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end), ' seconds.']);

end



% =====================================================================
%  LOCAL HELPERS
% =====================================================================

function fn_write_h5_dataset(h5_FQN, data_array, add_leading_dim)
%FN_WRITE_H5_DATASET Write a numeric array to an HDF5 file as dataset /data.
%   data_array is (n_rows x n_cols) in MATLAB convention.
%   The file is written so that fn_parse_CCF_data's h5read + squeeze + '
%   pipeline recovers the original (n_rows x n_cols) table.
%
%   add_leading_dim: if true, stores as (1 x n_cols x n_rows) matching
%   the Python (1, n_rows, n_cols) convention used for record2D.

if isfile(h5_FQN)
	delete(h5_FQN);
end

transposed = data_array';   % (n_cols x n_rows)

if add_leading_dim
	write_data = reshape(transposed, [1, size(transposed, 1), size(transposed, 2)]);
	h5create(h5_FQN, '/data', size(write_data), 'Datatype', 'double');
else
	write_data = transposed;
	h5create(h5_FQN, '/data', size(write_data), 'Datatype', 'double');
end

h5write(h5_FQN, '/data', write_data);

end


function fn_write_json_file(json_FQN, data)
%FN_WRITE_JSON_FILE Write a struct or cell array as a JSON file.

json_text = jsonencode(data);
% Pretty-print: add newlines after commas at top level (best effort)
json_text = strrep(json_text, ',"', sprintf(',\n"'));

fid = fopen(json_FQN, 'w');
if fid == -1
	error(['fn_write_json_file: could not open: ', json_FQN]);
end
fwrite(fid, json_text);
fclose(fid);

end


function fn_write_heterogeneous_jsonl_file(output_FQN, data_struct)
%FN_WRITE_HETEROGENEOUS_JSONL_FILE Write a struct-of-tables as a single JSONL file.
%   Each sub-field is a table (one record type). Records from all types
%   are interleaved by timestamp. Each JSON line gets a 'record_type'
%   field so the reader can reconstruct the struct-of-tables on load.

sub_names = fieldnames(data_struct);

% Convert all sub-tables to struct arrays in one shot per type, then
% collect into a flat struct array with sort keys — avoids per-row table indexing.
all_structs = [];
all_sort_keys = [];

for i_sub = 1 : length(sub_names)
	cur_sub_name = sub_names{i_sub};
	cur_data = data_struct.(cur_sub_name);

	if isstruct(cur_data) && ~istable(cur_data)
		if isscalar(cur_data)
			cur_data = struct2table(cur_data);
		else
			cur_data = struct2table(cur_data, 'AsArray', true);
		end
	end

	if ~istable(cur_data) || isempty(cur_data)
		continue
	end

	% Bulk convert table to struct array
	cur_struct_array = table2struct(cur_data);
	n_rows = length(cur_struct_array);

	% Add record_type field to all entries at once
	[cur_struct_array.record_type] = deal(cur_sub_name);

	% Extract sort keys (vectorized)
	if ismember('timestamp_s', cur_data.Properties.VariableNames)
		cur_sort_keys = cur_data.timestamp_s;
	elseif ismember('timestamp', cur_data.Properties.VariableNames)
		cur_sort_keys = cur_data.timestamp;
	else
		cur_sort_keys = (1:n_rows)' + (i_sub - 1) * 1e9;
	end

	% Encode each struct to a JSON string (one per row)
	cur_json_lines = cell(n_rows, 1);
	for i_row = 1 : n_rows
		cur_json_lines{i_row} = jsonencode(cur_struct_array(i_row));
	end

	if isempty(all_sort_keys)
		all_sort_keys = cur_sort_keys(:);
		all_structs = cur_json_lines;
	else
		all_sort_keys = [all_sort_keys; cur_sort_keys(:)];
		all_structs = [all_structs; cur_json_lines];
	end
end

if isempty(all_structs)
	disp(['fn_write_heterogeneous_jsonl_file: WARN: no data to write to: ', output_FQN]);
	return
end

% Sort by timestamp and write
[~, sort_idx] = sort(all_sort_keys);
all_structs = all_structs(sort_idx);

fid = fopen(output_FQN, 'w');
if fid == -1
	error(['fn_write_heterogeneous_jsonl_file: could not open: ', output_FQN]);
end

for i_row = 1 : length(all_structs)
	fprintf(fid, '%s\n', all_structs{i_row});
end

fclose(fid);
disp(['fn_write_heterogeneous_jsonl_file: wrote ', num2str(length(all_structs)), ...
	' lines to: ', output_FQN]);

end
