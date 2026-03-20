function [ data_table ] = fn_add_gaze_data_to_record2D(data_table, gaze_table_struct, tracker_type, CCF_config, include_regexp_list)
%FN_ADD_GAZE_DATA_TO_RECORD2D Summary of this function goes here
%   Detailed explanation goes here

data_table = data_table;

gaze_subtable_list = fieldnames(gaze_table_struct);

include_ldx = false(size(gaze_subtable_list));
% filter these with wildcard_string(s)
for i_include_regexp = 1: length(include_regexp_list)
	cur_include_regexp = include_regexp_list{i_include_regexp};
	match_ldx = contains(gaze_subtable_list, regexpPattern(cur_include_regexp));
	include_ldx(match_ldx) = true;
end

include_idx = find(include_ldx);



for i_gaze_subtable = 1 : length(include_idx)
	cur_gaze_subtable_name = gaze_subtable_list{include_idx(i_gaze_subtable)};

	output_source_stem = fn_shorten_subtable_name_to_stem(cur_gaze_subtable_name);

	cur_gaze_subtable = gaze_table_struct.(cur_gaze_subtable_name);

	cur_gaze_subtable_col_names = cur_gaze_subtable.Properties.VariableNames;

	% used corrected timestamps if available, otherwise fall back to
	% receive timestamps
	if ismember({'corrected_local_timestamps'}, cur_gaze_subtable_col_names)
		gaze_timestamp_col_name = 'corrected_local_timestamps';
	else
		gaze_timestamp_col_name = 'receive_timestamp_s';
	end

	% use registered data, otherwise error out?
	if ismember({'registered_norm_pos'}, cur_gaze_subtable_col_names)
		gaze_XY_data_col_name = 'registered_norm_pos';
	else
		gaze_XY_data_col_name = 'norm_pos';
		error([mfilename, ': ERROR: no registered gaze data found, please fix, unreguistered data likely is not useful.']);
	end


	% Now, use the corrected timestamps and registered norm_pos data (as well
	% as confidence and diameter) and add these to the record2D table,
	% trying to match/interpolate the record2D timestamps...
	% matlab's interp1 function basically does what we want\

	% we might want to use different methods for norm_pos, diameter and
	% confidence
	norm_pos_interp_method_string = 'nearest';
	diameter_interp_method_string = 'nearest';
	confidence_interp_method_string = 'nearest';

	interpolated_norm_pos = interp1(cur_gaze_subtable.(gaze_timestamp_col_name), cur_gaze_subtable.(gaze_XY_data_col_name), data_table.timestamp, norm_pos_interp_method_string);
	data_table.([output_source_stem, '_X']) = interpolated_norm_pos(:, 1);
	data_table.([output_source_stem, '_Y']) = interpolated_norm_pos(:, 2);

	interpolated_diameter = interp1(cur_gaze_subtable.(gaze_timestamp_col_name), cur_gaze_subtable.diameter, data_table.timestamp, diameter_interp_method_string);
	data_table.([output_source_stem, '_pupildiameter']) = interpolated_diameter;

	interpolated_confidence = interp1(cur_gaze_subtable.(gaze_timestamp_col_name), cur_gaze_subtable.confidence, data_table.timestamp, confidence_interp_method_string);
	data_table.([output_source_stem, '_confidence']) = interpolated_confidence;
end	


end


function [ cur_short_name ] = fn_shorten_subtable_name_to_stem( cur_name )
% ATTENTION this will currently squish 2d and 3d, so make sure to only add
% one of those

cur_short_name = cur_name; % default to no renaming

% the original names
cur_long_name_list = {...
	'A0_pupillabs_pupil_dot_0_dot_2d', ...
	'A0_pupillabs_pupil_dot_1_dot_2d', ...
	'A0_pupillabs_pupil_dot_0_dot_3d', ...
	'A0_pupillabs_pupil_dot_1_dot_3d', ...
	'B1_pupillabs_pupil_dot_0_dot_2d', ...
	'B1_pupillabs_pupil_dot_1_dot_2d', ...
	'B1_pupillabs_pupil_dot_0_dot_3d', ...
	'B1_pupillabs_pupil_dot_1_dot_3d', ...
};
% shorter, cleaer names
cur_short_name_list = {...
	'A_right_eye', ...
	'A_left_eye', ...
	'A_right_eye', ...
	'A_left_eye', ...
	'B_right_eye', ...
	'B_left_eye', ...
	'B_right_eye', ...
	'B_left_eye', ...
};


cur_long_name_idx = find(ismember(cur_long_name_list, {cur_name}));

if length(cur_long_name_idx) > 0
	cur_short_name = cur_short_name_list{cur_long_name_idx};
end

end

