function [global_target_map] = fn_build_global_target_map(raw_data_list)
%FN_BUILD_GLOBAL_TARGET_MAP Build consistent global target slot assignment across runs.
%   The merged table requires each global targetN to carry the same
%   target_id throughout. Since the same target_id can occupy multiple
%   slots within one run, the mapping key is (target_id, occurrence),
%   where occurrence is the rank among slots with that id (sorted by
%   local target index).
%
%   Returns a struct with:
%     n_global_targets          - total number of global target slots
%     canonical_suffix_list     - union of all target column suffixes
%     per_run_local_to_global   - cell of containers.Map (local_idx -> global_idx)
%     global_slot_info          - struct array with target_id and occurrence per slot

timestamps.(mfilename).start = tic;
disp(['Starting: ', mfilename]);
dbstop if error

n_runs = length(raw_data_list);


% =====================================================================
%  1. Extract per-run (local_idx, dominant_target_id) pairs and suffixes
% =====================================================================
per_run_local_idx_list = cell(1, n_runs);
per_run_dominant_id_list = cell(1, n_runs);
all_suffixes = {};

for i_run = 1 : n_runs
	cur_raw = raw_data_list{i_run};
	cur_local_idx_list = [];
	cur_dominant_id_list = [];

	if ~isfield(cur_raw.json_struct, 'record2D_header') || ~isfield(cur_raw.h5_struct, 'record2D_data')
		disp([mfilename, ': WARN: run ', num2str(i_run), ' has no record2D data.']);
		per_run_local_idx_list{i_run} = [];
		per_run_dominant_id_list{i_run} = [];
		continue
	end

	header_list = cur_raw.json_struct.record2D_header.record2D_column_names';
	data_array = squeeze(cur_raw.h5_struct.record2D_data)';

	% Collect target column suffixes and identify targetN_id columns
	for i_col = 1 : length(header_list)
		tokens = regexp(header_list{i_col}, '^target(\d+)(_.+)$', 'tokens');
		if ~isempty(tokens)
			all_suffixes{end+1} = tokens{1}{2};

			% Only process _id columns to get the dominant id per slot
			if strcmp(tokens{1}{2}, '_id')
				local_idx = str2double(tokens{1}{1});
				id_values = data_array(:, i_col);
				valid_ids = id_values(~isnan(id_values));
				if ~isempty(valid_ids)
					dominant_id = mode(valid_ids);
				else
					dominant_id = NaN;
				end
				cur_local_idx_list(end+1) = local_idx;
				cur_dominant_id_list(end+1) = dominant_id;
			end
		end
	end

	% Sort by local_idx so occurrence numbering is deterministic
	[cur_local_idx_list, sort_order] = sort(cur_local_idx_list);
	cur_dominant_id_list = cur_dominant_id_list(sort_order);

	per_run_local_idx_list{i_run} = cur_local_idx_list;
	per_run_dominant_id_list{i_run} = cur_dominant_id_list;
end

canonical_suffix_list = unique(all_suffixes, 'stable');


% =====================================================================
%  2. Determine how many global slots each target_id needs
% =====================================================================
all_ids = [];
for i_run = 1 : n_runs
	all_ids = [all_ids, per_run_dominant_id_list{i_run}];
end
unique_id_list = unique(all_ids(~isnan(all_ids)), 'stable');

% For each unique id, find the max number of simultaneous slots across runs
max_occurrences = zeros(size(unique_id_list));
for i_uid = 1 : length(unique_id_list)
	for i_run = 1 : n_runs
		n_occ = sum(per_run_dominant_id_list{i_run} == unique_id_list(i_uid));
		max_occurrences(i_uid) = max(max_occurrences(i_uid), n_occ);
	end
end


% =====================================================================
%  3. Assign global indices: (target_id, occurrence) -> global_idx
% =====================================================================
global_slot_target_id = [];
global_slot_occurrence = [];

for i_uid = 1 : length(unique_id_list)
	for i_occ = 0 : max_occurrences(i_uid) - 1
		global_slot_target_id(end+1) = unique_id_list(i_uid);
		global_slot_occurrence(end+1) = i_occ;
	end
end

n_global_targets = length(global_slot_target_id);


% =====================================================================
%  4. Build per-run local_idx -> global_idx mapping
% =====================================================================
per_run_local_to_global = cell(1, n_runs);

for i_run = 1 : n_runs
	local_idx_list = per_run_local_idx_list{i_run};
	dominant_id_list = per_run_dominant_id_list{i_run};
	local_to_global = containers.Map('KeyType', 'double', 'ValueType', 'double');

	% Track how many times each id has been assigned so far in this run
	id_occurrence_counter = containers.Map('KeyType', 'double', 'ValueType', 'double');

	for i_t = 1 : length(local_idx_list)
		cur_local_idx = local_idx_list(i_t);
		cur_tid = dominant_id_list(i_t);

		if isnan(cur_tid)
			continue
		end

		% Determine which occurrence of this id we're at
		if id_occurrence_counter.isKey(cur_tid)
			cur_occ = id_occurrence_counter(cur_tid);
			id_occurrence_counter(cur_tid) = cur_occ + 1;
		else
			cur_occ = 0;
			id_occurrence_counter(cur_tid) = 1;
		end

		% Find the matching global slot
		for i_gs = 1 : n_global_targets
			if global_slot_target_id(i_gs) == cur_tid && global_slot_occurrence(i_gs) == cur_occ
				local_to_global(cur_local_idx) = i_gs - 1;   % 0-based global index
				break
			end
		end
	end

	per_run_local_to_global{i_run} = local_to_global;

	% Diagnostic
	mapping_str_parts = {};
	for i_t = 1 : length(local_idx_list)
		cur_lidx = local_idx_list(i_t);
		if local_to_global.isKey(cur_lidx)
			mapping_str_parts{end+1} = ['target', num2str(cur_lidx), ...
				'(id=', num2str(dominant_id_list(i_t)), ...
				')->global', num2str(local_to_global(cur_lidx))];
		end
	end
	disp([mfilename, ': run ', num2str(i_run), ' mapping: ', strjoin(mapping_str_parts, ', ')]);
end


% =====================================================================
%  5. Package output
% =====================================================================
global_target_map.n_global_targets = n_global_targets;
global_target_map.canonical_suffix_list = canonical_suffix_list;
global_target_map.per_run_local_to_global = per_run_local_to_global;
global_target_map.unique_id_list = unique_id_list;
global_target_map.global_slot_target_id = global_slot_target_id;
global_target_map.global_slot_occurrence = global_slot_occurrence;

disp([mfilename, ': ', num2str(n_global_targets), ' global target slots from ', ...
	num2str(length(unique_id_list)), ' unique target_ids across ', num2str(n_runs), ' runs.']);

timestamps.(mfilename).end = toc(timestamps.(mfilename).start);
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end), ' seconds.']);

end
