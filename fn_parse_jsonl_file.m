function [ parsed_data_table ] = fn_parse_jsonl_file( jsonl_FQN )
%FN_PARSE_JSONL_FILE Summary of this function goes here
%   Detailed explanation goes here

parsed_data_table = [];
debug = 0;

try
	disp(['Parsing: ', jsonl_FQN]);
	[cur_jsonl_fd, errmsg] = fopen(jsonl_FQN);
	%get the first line
	cur_line = fgetl(cur_jsonl_fd);
	decoded_struct = jsondecode(cur_line);
	%parsed_data_table = struct2table(decoded_struct, 'AsArray', true);
	count = 1;
	while ~isempty(cur_line)
		count = count + 1;
		if (debug)
			disp(['Line: ', num2str(count)]);
		end
		cur_line = fgetl(cur_jsonl_fd);
		% if count == 1129
		% 	disp('Doh...')
		% end
		if (cur_line == -1)
			break
		end
		cur_decoded_struct = jsondecode(cur_line);
		decoded_struct(end+1) = cur_decoded_struct;
	end

	parsed_data_table = struct2table(decoded_struct, 'AsArray', true);

catch ME
	ME
	% if a jsonl contains records of different types we need to take more
	% care
	if strcmp(ME.identifier, 'MATLAB:heterogeneousStrucAssignment')
		
		existing_type_string_list = {};
		existing_sanitized_type_string_list = {};
		decoded_struct = [];
		disp([mfilename, ': INFO: current jsonl contains records with different structure, try to parse each type individually.']);
		try
			disp(['Parsing: ', jsonl_FQN]);
			[cur_jsonl_fd, errmsg] = fopen(jsonl_FQN);
			%get the first line
			cur_line = fgetl(cur_jsonl_fd);
			cur_decoded_struct = jsondecode(cur_line);
			% these come from python in the wrong orientation to stack up
			% nicely...
			if isfield(cur_decoded_struct, 'norm_pos')
				cur_decoded_struct.norm_pos = cur_decoded_struct.norm_pos';
			end
			cur_type_string = cur_decoded_struct.type;
			existing_type_string_list(end+1) = {cur_type_string};
			existing_sanitized_type_string_list(end+1) = {fn_sanitize_string_as_matlab_variable_name(cur_type_string)};
			cur_subtable_name = existing_sanitized_type_string_list{ismember(existing_type_string_list, {cur_type_string})};
			decoded_struct.(cur_subtable_name) = cur_decoded_struct;

			%parsed_data_table = struct2table(decoded_struct, 'AsArray', true);
			count = 1;
			while ~isempty(cur_line)
				count = count + 1;
				if (debug)
					disp(['Line: ', num2str(count)]);
				end
				cur_line = fgetl(cur_jsonl_fd);
				% if count == 1129
				% 	disp('Doh...')
				% end
				if (cur_line == -1)
					break
				end
				cur_decoded_struct = jsondecode(cur_line);
				% we want these to lineup well 
				if isfield(cur_decoded_struct, 'norm_pos')
					cur_decoded_struct.norm_pos = cur_decoded_struct.norm_pos';
				end

				cur_type_string = cur_decoded_struct.type;
				% encountered a new type_string
				if ~(ismember(existing_type_string_list, {cur_type_string}))
					existing_type_string_list(end+1) = {cur_type_string};
					existing_sanitized_type_string_list(end+1) = {fn_sanitize_string_as_matlab_variable_name(cur_type_string)};
				end
				cur_subtable_name = existing_sanitized_type_string_list{ismember(existing_type_string_list, {cur_type_string})};
				if ~isfield(decoded_struct, cur_subtable_name)
					decoded_struct.(cur_subtable_name) = cur_decoded_struct;
				else
					decoded_struct.(cur_subtable_name)(end+1) = cur_decoded_struct;
				end
			end

			decoded_struct_fieldnames = fieldnames(decoded_struct);
			for i_subtable = 1 : length(decoded_struct_fieldnames)
				cur_subtable_name = decoded_struct_fieldnames{i_subtable};
				parsed_data_table.(cur_subtable_name) = struct2table(decoded_struct.(cur_subtable_name), 'AsArray', true);
			end
		catch ME2
			ME2
		end
	else
		disp(['Encountered unexpected exception: ']);
		ME
	end
end
