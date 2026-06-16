function [ sanitized_string, long_sanitized_string ] = fn_sanitize_string_as_matlab_variable_name( raw_string )
%FN_SANITIZE_STRING_AS_MATLAB_VARIABLE_NAME Summary of this function goes here

sanitized_string = [];
long_sanitized_string = [];
in_raw_string = raw_string;

if ~iscell(raw_string)
	string_list = {raw_string};
else
	string_list = raw_string;
end

out_list = cell(size(string_list));


for i_string = 1 : length(string_list)
	raw_string = string_list{i_string};
	

	% we will catch this later... andin theory we might actually shorten
	% the string...
	% if length(raw_string) > 64
	% 	disp('Input string is longer then the max. 64 characters matlab uses as variable name.');
	% 	disp(raw_string);
	% 	sanitized_string = [];
	% 	return
	% end
	
	
	% some characters are not really helpful inside matlab variable names, so
	% replace them with something that should not cause problems
	taboo_char_list =		{' ', '\-', '\.', '\=', '\/', '\+', '\*', ':', ...
		'^_', '^0', '^1', '^2', '^3', '^4', '^5', '^6', '^7', '^8', '^9', ... % caret ^ matched only on first character
		'@', '&'};
	replacement_char_list = {'_', '_', '_dot_', '_eq_', '_', 'Plus', 'x', '_C_', ...
		'US', 'Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', ...
		'_at_', '_and_'};
	
	% and some characters are not permitted as first char, like underscores or
	% numbers
	taboo_first_char_list = {'^_', '^0', '^1', '^2', '^3', '^4', '^5', '^6', '^7', '^8', '^9'};
	replacement_first_char_list = {'US', 'Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', ... % replacements for the first character only
		};
	
	sanitized_string = raw_string;

	
	for i_taboo_char = 1: length(taboo_char_list)
		current_taboo_string = taboo_char_list{i_taboo_char};
		current_replacement_string = replacement_char_list{i_taboo_char};
		% with regular expressions escape special meaning, we are after
		% simple character replacements here
		sanitized_string = regexprep(sanitized_string, current_taboo_string, current_replacement_string);
	end
	
	
	if (strcmp(raw_string, ' '))
		sanitized_string = 'EmptyString';
		disp('Found empty string as column/variable name, replacing with "EmptyString"...');
	end
	
	if length(sanitized_string) > 64
		disp('Proto-output string is longer then the max. 64 characters matlab uses as variable name.');
		disp(sanitized_string);
		long_sanitized_string = sanitized_string;
		sanitized_string = [];
		return
	end
	out_list(i_string) = {sanitized_string};
end

if iscell(in_raw_string)
	sanitized_string = out_list;
end

long_sanitized_string = sanitized_string;


return
end

