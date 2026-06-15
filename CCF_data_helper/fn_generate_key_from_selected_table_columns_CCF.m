function [ key_list, existing_keyfields_ldx, unique_keys, data_row_key_idx_arr, unique_keys_count_list ] = fn_generate_key_from_selected_table_columns_CCF( keyfield_list, data, key_field_separator_string )
%FN_GENERATE_KEY_FROM_SELECTED_TABLE_COLUMNS Summary of this function goes here
%   Detailed explanation goes here
% if sorted_key_list is specified return only these fields in that order

key_list = [];
existing_keyfields_ldx = [];
unique_keys = [];
data_row_key_idx_arr = [];
unique_keys_count_list = [];

if nargout == 5
	count_unique_keys = 1;
else
	count_unique_keys = 0;
end

% allow [] to use the default and '' to request no separator
if ~exist('key_field_separator_string', 'var') || (isempty(key_field_separator_string) && ~ischar(key_field_separator_string))
	key_field_separator_string = ' & ';
end


cur_data_class = class(data);
switch cur_data_class
	case 'struct'
		data_fieldnames = fieldnames(data);
		existing_keyfields_ldx = ismember(data_fieldnames, keyfield_list);
		n_rows = size(data, 2);
		n_cols = length(fieldnames(data));
		% ATTENTION this is rough.... but as a first measure just convert
		% this to a table...
		data = struct2table(data);
	case 'table'
		data_fieldnames = fieldnames(data);
		existing_keyfields_ldx = ismember(data_fieldnames, keyfield_list);
		[n_rows, n_cols] = size(data);
	case 'double'
		% needs care, and
		error('Numeric array data not handled yet');
		[n_rows, n_cols] = size(data);
	otherwise
		error([mfilename, ': unhandled class for data: ', cur_data_class]);
end
% data can be a table or a structure array (or potentially data array)


if any(existing_keyfields_ldx)
	existing_keyfield_names = data_fieldnames(ismember(data_fieldnames, keyfield_list));
	key_list = cell([n_rows, 1]);
	proto_key_list = data(:, ismember(data_fieldnames, keyfield_list));
	proto_key_type_list = varfun(@class, proto_key_list, 'OutputFormat', 'cell');
	if ~all(ismember(proto_key_type_list,{'cell'}))
		numeric_proto_col_idx = find(ismember(proto_key_type_list,{'double'}));
		for i_numeric_proto_col_idx = 1 : length(numeric_proto_col_idx)
			%proto_key_list.(existing_keyfield_names{numeric_proto_col_idx(i_numeric_proto_col_idx)}) = cellstr(num2str(proto_key_list.(existing_keyfield_names{numeric_proto_col_idx(i_numeric_proto_col_idx)}), '%.5g'));
			cur_keyfield_name = existing_keyfield_names{numeric_proto_col_idx(i_numeric_proto_col_idx)};
			cur_numeric_col = proto_key_list.(cur_keyfield_name);
			proto_key_list.(cur_keyfield_name) = arrayfun(@(x) sprintf('%.10g', x), cur_numeric_col, 'UniformOutput', false);
		end
		logical_proto_col_idx = find(ismember(proto_key_type_list,{'logical'}));
		for i_logical_proto_col_idx = 1 : length(logical_proto_col_idx)
			%proto_key_list.(existing_keyfield_names{logical_proto_col_idx(i_logical_proto_col_idx)}) = cellstr(num2str(proto_key_list.(existing_keyfield_names{logical_proto_col_idx(i_logical_proto_col_idx)}), '%d'));
			cur_keyfield_name = existing_keyfield_names{logical_proto_col_idx(i_logical_proto_col_idx)};
			cur_logical_col = proto_key_list.(cur_keyfield_name);
			proto_key_list.(cur_keyfield_name) = arrayfun(@(x) sprintf('%d', x), cur_logical_col, 'UniformOutput', false);
		end
	end
	proto_key_list = proto_key_list{:, :};
	% now merge all fields...

	% sort the fields according to keyfield_list order
	orig_proto_key_list = proto_key_list;
	for i_keyfield = 1 : length(keyfield_list)
		cur_keyfield_name = keyfield_list{i_keyfield};
		cur_keyfield_in_proto_keylist_col_idx = find(ismember(existing_keyfield_names, {cur_keyfield_name}));
		proto_key_list(:, i_keyfield) = orig_proto_key_list(:, cur_keyfield_in_proto_keylist_col_idx);
	end


% %%% TODO consider using JOIN instead of looping explicitly
% if size(cur_input_list) ~= size(selection_list)
% 	selection_list = selection_list';
% end
% if size(cur_input_list) ~= size(selection_list)
% 	errror([mfilename, ': dimension mismatch between cur_input_list and selection_list...']);
% end
% merged_list = join([cur_input_list; selection_list], '_', 1)
% 

	% if (length(key_list) > 1)
	% 	for i_row = 1 : length(key_list)
		% 	key_list{i_row} = strjoin(proto_key_list(i_row, :), key_field_separator_string);	% we should make sure the separator does not naturally occur in any of the fields...
	% 	end
	% else
	% 	% this is a degenerate case when called with a single element
	% 	key_list = proto_key_list{1};
	for i_row = 1 : n_rows
		key_list{i_row} = strjoin(proto_key_list(i_row, :), key_field_separator_string);	% we should make sure the separator does not naturally occur in any of the fields...
	end
	[unique_keys, ~, data_row_key_idx_arr] = unique(key_list);
else
	error('No key defined, none of the keyfield_list members exist');
end

if count_unique_keys
	n_keys = length(unique_keys);
	unique_keys_count_list = nan(size(unique_keys));
	for i_key = 1 : n_keys
		unique_keys_count_list(i_key) = sum(data_row_key_idx_arr == i_key);
	end
end



end

