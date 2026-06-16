function [ sanitized_value_name ] = fn_sanitize_value_as_matlab_variable_name( raw_value, is_first_char_valid, check_variable_length )
%FN_SANITIZE_VALUE_AS_MATLAB_VARIABLE_NAME Summary of this function goes here
%   Detailed explanation goes here
% some characters are not really helpful inside matlab variable names, so
% replace them with something that should not cause problems
taboo_char_list =		{' ', '-', '.', '=', ',', '<', '>', ':', '&'};
replacement_char_list = {'_', '_minus_', '_dot_', '_eq_', '_comma_', '_lt_', '_gt_', '_colon_', '_and_'};

% in addition disallow these carachters as first char of the sanitized_value_name
taboo_first_char_list = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '_', '-'};
replacement_first_char_list = {'Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'US', 'MINUS_'};


if ~exist('is_first_char_valid', 'var') || isempty(is_first_char_valid)
	is_first_char_valid = 0;
end

% what to do with the length of the variable, as matlab only allow
% namelengthmax characters as identifiers
if ~exist('check_variable_length', 'var') || isempty(check_variable_length)
	check_variable_length = 0;
end



sanitized_value_name = raw_value;

if isnumeric(sanitized_value_name)
	sanitized_value_name = num2str(sanitized_value_name);
end

% remove leading and trailing whitespace
sanitized_value_name = strtrim(sanitized_value_name);

if (is_first_char_valid)
	% check first character to not be a number
	taboo_first_char_idx = find(ismember(taboo_first_char_list, sanitized_value_name(1)));
	if ~isempty(taboo_first_char_idx)
		sanitized_value_name = [replacement_first_char_list{taboo_first_char_idx}, sanitized_value_name(2:end)];
	end
end




for i_taboo_char = 1: length(taboo_char_list)
	current_taboo_string = taboo_char_list{i_taboo_char};
	current_replacement_string = replacement_char_list{i_taboo_char};
	current_taboo_processed = 0;
	
	if strcmp(sanitized_value_name(1), current_taboo_string)
		remain = [current_replacement_string, sanitized_value_name(2:end)];
	else
		remain = sanitized_value_name;
	end
	tmp_string = '';
	while (~current_taboo_processed)
		[token, remain] = strtok(remain, current_taboo_string);
		tmp_string = [tmp_string, token, current_replacement_string];
		if isempty(remain)
			current_taboo_processed = 1;
			% we add one superfluous replaceent string at the end, so
			% remove that
			tmp_string = tmp_string(1:end-length(current_replacement_string));
		end
	end
	sanitized_value_name = tmp_string;
end

% check for length
if (check_variable_length)
	if(length(sanitized_value_name) > namelengthmax)
		error(['sanitized_value_name (''', sanitized_value_name, ''') exceeds matlab''s length limit of ', num2str(namelengthmax), ' characters.']);
	end
end

return
end

