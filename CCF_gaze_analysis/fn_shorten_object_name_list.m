function [ short_object_name_list ] = fn_shorten_object_name_list( object_name_list, prefix, suffix )
%FN_SHORTEN_OBJECT_NAME_LIST Summary of this function goes here
%   Detailed explanation goes here


if ~exist('prefix', 'var')
	prefix = [];
end

if ~exist('suffix', 'var')
	suffix = [];
end


input_is_cell = 1;
if ~iscell(object_name_list) && (ischar(object_name_list) || isstring(object_name_list))
	input_is_cell = 0;
	object_name_list= {object_name_list};
end

short_object_name_list = cell(size(object_name_list));


long_motive_list = {'^col_targ_', ...
	'waiting_for_agent', ...
	};
short_motive_list = {'CTS_', ...
	'wait4agent', ...
	};


for i_name = 1 : length(object_name_list)
	cur_name = object_name_list{i_name};

	for i_long_motive = 1 : length(long_motive_list)
		cur_name = regexprep(cur_name, long_motive_list{i_long_motive}, short_motive_list{i_long_motive});
	end


	out_name = [prefix, cur_name, suffix];


	if length(out_name) > namelengthmax
		disp('WARN: name too long: ', out_name);
	end
	short_object_name_list{i_name} = out_name;

end

if ~input_is_cell
	short_object_name_list = short_object_name_list{1};
end

end

