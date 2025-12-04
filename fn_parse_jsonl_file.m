function [ parsed_data_table ] = fn_parse_jsonl_file( jsonl_FQN )
%FN_PARSE_JSONL_FILE Summary of this function goes here
%   Detailed explanation goes here

parsed_data_table = [];

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
		disp(['Line: ', num2str(count)]);
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
end

