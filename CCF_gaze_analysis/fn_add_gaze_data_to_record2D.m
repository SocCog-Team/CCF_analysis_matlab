function [ data_table ] = fn_add_gaze_data_to_record2D(data_table, gaze_table_struct, tracker_type, CCF_config, include_regexp_list, request_list)
%FN_ADD_GAZE_DATA_TO_RECORD2D Summary of this function goes here
%   Detailed explanation goes here

% TODO
%	allow for multiple gaze sources here... and alloow for A and B

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


added_source_stem_list = {};
output_source_stem_list = {};

output_source_stem_list = {};

for i_gaze_subtable = 1 : length(include_idx)
	cur_gaze_subtable_name = gaze_subtable_list{include_idx(i_gaze_subtable)};

	output_source_stem = fn_shorten_subtable_name_to_stem(cur_gaze_subtable_name);

	added_source_stem_list{i_gaze_subtable} = cur_gaze_subtable_name;
	output_source_stem_list{i_gaze_subtable} = output_source_stem;

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
		error([mfilename, ': ERROR: no registered gaze data found, please fix, unregistered data likely is not useful.']);
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

	if ismember({'registered_pixel_pos'}, cur_gaze_subtable_col_names)
		cur_interpolated_norm_pos = interp1(cur_gaze_subtable.(gaze_timestamp_col_name), cur_gaze_subtable.registered_pixel_pos, data_table.timestamp, norm_pos_interp_method_string);
		data_table.([output_source_stem, '_X_pixel']) = cur_interpolated_norm_pos(:, 1);
		data_table.([output_source_stem, '_Y_pixel']) = cur_interpolated_norm_pos(:, 2);
	end

	if ismember({'registered_dva_pos'}, cur_gaze_subtable_col_names)
		cur_interpolated_norm_pos = interp1(cur_gaze_subtable.(gaze_timestamp_col_name), cur_gaze_subtable.registered_dva_pos, data_table.timestamp, norm_pos_interp_method_string);
		data_table.([output_source_stem, '_X_dva']) = cur_interpolated_norm_pos(:, 1);
		data_table.([output_source_stem, '_Y_dva']) = cur_interpolated_norm_pos(:, 2);
	end


	interpolated_diameter = interp1(cur_gaze_subtable.(gaze_timestamp_col_name), cur_gaze_subtable.diameter, data_table.timestamp, diameter_interp_method_string);
	data_table.([output_source_stem, '_pupildiameter']) = interpolated_diameter;

	interpolated_confidence = interp1(cur_gaze_subtable.(gaze_timestamp_col_name), cur_gaze_subtable.confidence, data_table.timestamp, confidence_interp_method_string);
	data_table.([output_source_stem, '_confidence']) = interpolated_confidence;
end


% TODO potentially synthesize binocular data (including the x-delta) to get
% a proxy for vergence

if ismember({'synthesize_binocular_gaze_data'}, request_list)
	disp([mfilename, ': INFO: Processing requested synthesize_binocular_gaze_data']);
	% we simply take the average positions and ppupil diameter and add the minimum of the
	% confidence and th

	data_table_col_name_list =  data_table.Properties.VariableNames;

	% find the sets and loop over them...
	right_source_ldx = contains(output_source_stem_list, regexpPattern('_right_'));
	right_source_idx = find(right_source_ldx);

	for i_right_source = 1 : length(right_source_idx)
		cur_right_output_stem_cell = output_source_stem_list(right_source_idx(i_right_source));
		cur_right_output_stem = cur_right_output_stem_cell{1};
		cur_left_output_stem = regexprep(cur_right_output_stem, 'right', 'left');
		cur_binocular_stem = regexprep(cur_right_output_stem, 'right', 'binocular');


		%get all the XY units
		proto_output_stem_ldx  = contains(data_table_col_name_list, regexpPattern([cur_right_output_stem, '_X']));
		cur_source_right_all_unit_list = data_table_col_name_list(proto_output_stem_ldx);

		for i_cur_right_unit = 1 : length(cur_source_right_all_unit_list)
			cur_right_unit_col_name = cur_source_right_all_unit_list{i_cur_right_unit};
			cur_left_unit_col_name = regexprep(cur_right_unit_col_name, 'right', 'left');
			cur_binocular_col_name = regexprep(cur_right_unit_col_name, 'right', 'binocular');

			% the right version of this has t exist, so we only check the
			% matching left
			if ismember({cur_left_unit_col_name}, data_table_col_name_list)
				% X
				data_table.(cur_binocular_col_name) = mean([data_table.(cur_right_unit_col_name) , data_table.(cur_left_unit_col_name)], 2);
				% Y
				data_table.(regexprep(cur_binocular_col_name, 'X', 'Y')) = mean([data_table.(regexprep(cur_right_unit_col_name, 'X', 'Y')) , data_table.(regexprep(cur_left_unit_col_name, 'X', 'Y'))], 2);
				% the X delta
				if strcmp(cur_right_output_stem(1), 'A')
					data_table.(regexprep(cur_binocular_col_name, 'X', 'dX')) = data_table.(cur_right_unit_col_name) - data_table.(cur_left_unit_col_name);
				elseif strcmp(cur_right_output_stem(1), 'B')
					data_table.(regexprep(cur_binocular_col_name, 'X', 'dX')) = data_table.(cur_left_unit_col_name) - data_table.(cur_right_unit_col_name);
				else
					error([mfilename, ': ERROR: unknown side string: ', cur_right_output_stem(1)]);
				end

			else
				disp([mfilename, ': WARN:  could not find column: ', cur_left_unit_col_name]);
			end
		end

		% we take the minimal confidence of the current inputs, as the
		% synthesised binocular data is nevre better than the worst
		if ismember({[cur_right_output_stem, '_confidence']}, data_table_col_name_list) && ismember({[cur_left_output_stem, '_confidence']}, data_table_col_name_list)
			data_table.([cur_binocular_stem, '_confidence']) = min([data_table.([cur_right_output_stem, '_confidence']), data_table.([cur_left_output_stem, '_confidence'])], [], 2);
		end

		% for pupildiamter we simply take the mean, as we expect all
		% relevant pupil changes to be symmetric, note that the
		% pupildiameters are not calibrated and hence are not identical for
		% both cameras
		if ismember({[cur_right_output_stem, '_pupildiameter']}, data_table_col_name_list) && ismember({[cur_left_output_stem, '_pupildiameter']}, data_table_col_name_list)
			data_table.([cur_binocular_stem, '_pupildiameter']) = mean([data_table.([cur_right_output_stem, '_pupildiameter']), data_table.([cur_left_output_stem, '_pupildiameter'])], 2);
		end
	end
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

