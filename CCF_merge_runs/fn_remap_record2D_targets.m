function [remapped_header, remapped_data] = fn_remap_record2D_targets(header_list, data_array, local_to_global_map, n_global_targets, canonical_suffix_list)
%FN_REMAP_RECORD2D_TARGETS Remap target columns so each global slot has a consistent target_id.
%   Uses the local_to_global_map (from fn_build_global_target_map) to
%   permute target column groups. The canonical_suffix_list ensures all
%   runs produce identical column layouts. Missing slots/suffixes → NaN.
%
%   header_list           : 1×N cell of column names from one run
%   data_array            : (n_rows × N) numeric array from one run
%   local_to_global_map   : containers.Map  local_target_idx -> global_target_idx
%   n_global_targets      : total number of global target slots
%   canonical_suffix_list : ordered cell of target column suffixes

dbstop if error

n_rows = size(data_array, 1);

% --- Index source target columns by (local_idx, suffix) ---
is_target_col_ldx = false(1, length(header_list));
max_local_idx = -1;

for i_col = 1 : length(header_list)
	tokens = regexp(header_list{i_col}, '^target(\d+)(_.+)$', 'tokens');
	if ~isempty(tokens)
		is_target_col_ldx(i_col) = true;
		max_local_idx = max(max_local_idx, str2double(tokens{1}{1}));
	end
end

% Build lookup: source_col_map{local_idx+1}(suffix) = column index
source_col_map = cell(1, max(max_local_idx + 1, 0));
for i_t = 0 : max_local_idx
	source_col_map{i_t + 1} = containers.Map('KeyType', 'char', 'ValueType', 'double');
end

for i_col = 1 : length(header_list)
	tokens = regexp(header_list{i_col}, '^target(\d+)(_.+)$', 'tokens');
	if ~isempty(tokens)
		local_idx = str2double(tokens{1}{1});
		suffix = tokens{1}{2};
		source_col_map{local_idx + 1}(suffix) = i_col;
	end
end


% --- Build output: non-target columns, then global target columns ---
non_target_col_idx = find(~is_target_col_ldx);
remapped_header = header_list(non_target_col_idx);
remapped_data = data_array(:, non_target_col_idx);

n_target_cols = n_global_targets * length(canonical_suffix_list);
target_header_block = cell(1, n_target_cols);
target_data_block = NaN(n_rows, n_target_cols);
out_col = 0;

% Invert the map: for each global slot, which local idx feeds it?
global_to_local = NaN(1, n_global_targets);
local_keys = local_to_global_map.keys;
for i_k = 1 : length(local_keys)
	g_idx = local_to_global_map(local_keys{i_k});
	global_to_local(g_idx + 1) = local_keys{i_k};   % +1 for MATLAB indexing
end

for i_global = 0 : n_global_targets - 1
	source_local_idx = global_to_local(i_global + 1);
	has_source = ~isnan(source_local_idx) && (source_local_idx <= max_local_idx) ...
		&& ~isempty(source_col_map{source_local_idx + 1});

	for i_suf = 1 : length(canonical_suffix_list)
		out_col = out_col + 1;
		cur_suffix = canonical_suffix_list{i_suf};
		target_header_block{out_col} = ['target', num2str(i_global), cur_suffix];

		if has_source && source_col_map{source_local_idx + 1}.isKey(cur_suffix)
			src_col = source_col_map{source_local_idx + 1}(cur_suffix);
			target_data_block(:, out_col) = data_array(:, src_col);
		end
	end
end

remapped_header = [remapped_header, target_header_block];
remapped_data = [remapped_data, target_data_block];

end
