function [ registration_struct, version_string, version ] = fn_gaze_recalibrator_v02_CCF(cur_CCF_runfolder_FQN, gaze_data, calibration_tick_table, gaze_tracker_logfile_FQN, CCF_conf, tracker_type, velocity_threshold_pixels_per_sample, saccade_allowance_time_ms, acceptable_radius_pix, transformationType, polynomial_degree, lwm_N)
%FN_GAZE_RECALIBRATOR Analyse simple dot following gaze mapping data to
%generate better registration matrices to convert "raw" gaze data into
%eventIDE pixel coordinates
%   The main idea behind this function is to first associate known target
%   positions with gaze samples when the subject fixated that target and
%   then use these as control point pairs to feed matlab's fitgeotrans
%   function to get mapping "tforms" that allow to get a better
%   registration between measured sample coordinates and "real" screen
%   coordinates.
% CHANGES:
%	switch from ad hoc definition of calbration sets to evaluating the new
%	calibration_set_ID_idx field in the parsed tracker files...
%	This is not backward compatible so merits a new function to keep the
%	old tested one around...


%TODO:
%	save tform matrices. reg.affine.eyelink.Right_Eye_Raw.tform ...
%		as sessinID.subject.gaze_registration.mat in the days directory, so
%		../../
%	allow unsupervised run, if mouse point mat file already exists
%	use set(gca(), 'YDir', 'reversed') instead of the manual conversion
%	between eventIDE and matlab coordinates (also look at the getpoints()
%	call.
%
%	add the data column names to the registration structs...

% 2026 CCF:
%	clean up by removing eyelink
%	is mouse inversion still needed, if not remove..


tictoc_timestamp_list.(mfilename).start = tic;
disp(['Starting: ', mfilename]);
dbstop if error
fq_mfilename = mfilename('fullpath');
mfilepath = fileparts(fq_mfilename);

registration_struct = struct();

version = 3;
version_string = ['v', num2str(version, '%02d')];
if strcmp(tracker_type, 'version')
	disp([mfilename, ': only version string requested...']);
	return
end


% eventIDE sets the top left corner as (0,0), matlab sets the bottom left
% corner to (0,0) to make the up down directions in matlab appear correct
% we need to adjust the eventide values prior to display into the matlab
% coordinate system by using the following formula:
%	matlab_y_value = (eventide_y_value * -1) + eventide_screen_height_pix
eventide_screen_height_pix = 1080;
cluster_center_color = [255 140 0]/256;
target_color_spec = [0 0 1];
sample_color_spec = [1 0 0];
DefaultAxesType = 'BoS_manuscript';
output_rect_fraction = 1;
DefaultPaperSizeType = 'europe_landscape';

debug = 0;
% exclude samples with higher instantaneous veolicity than this value, this
% will allow to reject samples during saccades
if ~exist('velocity_threshold_pixels_per_sample', 'var') || isempty(velocity_threshold_pixels_per_sample)
	switch tracker_type
		case 'eyelink'
			velocity_threshold_pixels_per_sample = 0.05;
		case 'pupillabs'
			velocity_threshold_pixels_per_sample = 0.5; % TODO needs fixing
	end
end



% how many milliseconds to ignore after the onset of a new fixation target,
% to allow the subject to saccade to the new target
if ~exist('saccade_allowance_time_ms', 'var') || isempty(saccade_allowance_time_ms)
	saccade_allowance_time_ms = 0.200;	% CCF uses timestamps in seconds
end

% this defines the radius in pixels around the center of the cluster
% selector for the tested gaze target positions
if ~exist('acceptable_radius_pix', 'var') || isempty(acceptable_radius_pix)
	switch tracker_type
		case 'eyelink'
			acceptable_radius_pix = 10;
		case 'pupillabs'
			acceptable_radius_pix = 20;	% TODO needes fixing
			acceptable_radius_pix = 20 / CCF_conf.field_width_pixel;	% TODO needes fixing
			
	end
end

% this defines the registration method to use to generate the mapping
% between identified sample positions and corresponding target positions
if ~exist('transformationType', 'var') || isempty(transformationType)
	% transformationType = 'affine';
	% 	transformationType = 'polynomial';
	% default to all
	%transformationType = {'affine', 'polynomial', 'pwl', 'lwm'};
	% only affine and polynomial work somewhat reliably
	transformationType = {'affine', 'polynomial'};
end

% make sure things are as expected
if ~iscell(transformationType)
	transformationType_list = {transformationType};
else
	transformationType_list = transformationType;
end




% this defines the registration method to use to generate the mapping
% between identified sample positions and corresponding target positions
if ~exist('polynomial_degree', 'var') || isempty(polynomial_degree)
	polynomial_degree = 2;
end

% this defines the registration method to use to generate the mapping
% between identified sample positions and corresponding target positions
if ~exist('lwm_N', 'var') || isempty(lwm_N)
	lwm_N = 10;
end



% %if ~exist('gaze_tracker_logfile_FQN', 'var') || isempty(gaze_tracker_logfile_FQN)
% if isempty(gaze_tracker_logfile_FQN)
% 	[gaze_tracker_logfile_name, gaze_tracker_logfile_path] = uigetfile('*.trackerlog.*', 'Select gaze calibration trackerlogfile');
% 	gaze_tracker_logfile_FQN = fullfile(gaze_tracker_logfile_path, gaze_tracker_logfile_name);
% end

%[gaze_tracker_logfile_path, gaze_tracker_logfile_name, gaze_tracker_logfile_ext] = fileparts(gaze_tracker_logfile_FQN);

[~, session_ID, session_ID_ext] = fileparts(cur_CCF_runfolder_FQN);
gaze_tracker_logfile_path = cur_CCF_runfolder_FQN;

% different gaze tracker produce different tracker log files, to handle
% these differences allow the user to explicitly specify the type
if ~exist('tracker_type', 'var') || isempty(tracker_type)
	if ~isempty(regexpi(gaze_tracker_logfile_name, 'eyelink'))
		tracker_type = 'eyelink';
	end
	if ~isempty(regexpi(gaze_tracker_logfile_name, 'pupillabs'))
		tracker_type = 'pupillabs';
		error([mfilename, ': Tracker type pupillabs not implemented yet.']);
	end
end

% common information
% this column contains the different calibration sets, for pupil labs these
% are the different cameras and reconstruction methods, for eyelink these
% are simply all rows.
calibration_set_ID_idx_colname = 'calibration_setID_idx';
calibration_set_ID_idx_unique_list_name = 'calibration_setID_sanitized'; % these can be used as Matlab variable names
nonvar_calibration_set_ID_idx_unique_list_name = 'calibration_setID'; % these can be used as Matlab variable names


% define tracker specific information
switch(tracker_type)
	case 'eyelink'
		error([mfilename, ': ERROR: eyelink tracking/calibration not implemented yet for CCF']);
		% collect the names of data columns containing registerable data
		% get these as pairs of aligned X and Y
		gaze_col_name_list.stem = {'Right_Eye_Raw', 'Left_Eye_Raw'};
		gaze_col_name_list.X = {'Right_Eye_Raw_X', 'Left_Eye_Raw_X'};
		gaze_col_name_list.Y = {'Right_Eye_Raw_Y', 'Left_Eye_Raw_Y'};
% 			% if single columns contain multiple data types (like for pupillabs data)
% 			gaze_col_name_list.gaze_typeID_col_name = '';
% 			gaze_col_name_list.valid_gaze_typeID_values = [];
		out_of_bounds_marker_value = -32768;
		confidence_col_name = [];	% set the column index for a column containing cofidence data for the gaze tracker
		min_confidence = 0;		% only include sample with confidence >= min_confidence
	case 'pupillabs'
		% here we have different data row types,
		% Sample_Type_idx: Pupil, World Gaze, Fiducial Gaze
		% Fiducial_Surface_idx: the name of a surface (string)
		% Source_ID_idx: 0, pupil0, 1: pupil1, 2: World Gaze, 3: Surface(N?)
		
		% two eye cameras, world
		% collect the names of data columns containing registerable data
		% get these as pairs of aligned X and Y
		gaze_col_name_list.stem = {''};
		gaze_col_name_list.X = {'Raw_X'};
		gaze_col_name_list.Y = {'Raw_Y'};
		gaze_col_name_list.XY = {'norm_pos'};
% 			% these next will fill in the former
% 			gaze_col_name_list.stem_list = {'Pupil0_2d', 'Pupil0_pye3d', 'Pupil1_2d', 'Pupil1_pye3d', 'WorldGaze2', 'FiducialGaze3'};
% 			gaze_col_name_list.X_list = {'Raw_X', 'Raw_X', 'Raw_X', 'Raw_X', 'Raw_X', 'Raw_X'};
% 			gaze_col_name_list.Y_list = {'Raw_Y', 'Raw_Y', 'Raw_Y', 'Raw_Y', 'Raw_Y', 'Raw_Y'};
% 		
% 			% if single columns contain multiple data types (like for pupillabs data)
% 			gaze_col_name_list.gaze_typeID_col_name = 'Source_ID';	% note this will fail for multiple surfcaes/fiducial gaze sets in one file
% 			% attention needs as much fields as stem_list
% 			gaze_col_name_list.valid_gaze_typeID_values = [0, 0, 1, 1, 2, 3];	% 0, 1 -> Pupil, 2 World Gaze; 3 Fiducial Gaze
		out_of_bounds_marker_value = -32768;
		confidence_col_name = 'confidence';	% set the column index for a column containing confidence data for the gaze tracker
		min_confidence = 0.05;		% only include sample with confidence >= min_confidence

		% we need to convert the requested pixel value to a relative value
		req_velocity_threshold_pixels_per_sample = velocity_threshold_pixels_per_sample;
		velocity_threshold_pixels_per_sample = req_velocity_threshold_pixels_per_sample / CCF_conf.field_height_pixel;

	otherwise
		error(['tracker_type: ', tracker_type, ' not yet supported.']);
end

gaze_subtable_list = fieldnames(gaze_data);

[gaze_tracker_logfile_dir, gaze_tracker_logfile_name, gaze_tracker_logfile_ext] = fileparts(gaze_tracker_logfile_FQN);


% now run this separately for A0 and B1 instances...
A0_set_ldx = contains(gaze_subtable_list, regexpPattern('^A0_'));
B1_set_ldx = contains(gaze_subtable_list, regexpPattern('^B1_'));

set_idx_list = {find(A0_set_ldx), find(B1_set_ldx)};
set_Side_list = {'A', 'B'};
for i_set = 1 : length(set_Side_list)
	side = set_Side_list{i_set};
	cur_set_idx = set_idx_list{i_set};
	

	if isempty(cur_set_idx)
		disp([mfilename, ': INFO: no subtables found for side ', side]);
		continue
	end

	sessionID = fn_get_sessionID_from_SCP_path(cur_CCF_runfolder_FQN, '.sessiondir');
	%[side, tracker_elementID] = fn_get_side_from_tracker_logfile_name(gaze_tracker_logfile_FQN);
	%tracker_elementID = [gaze_tracker_logfile_name, '_', side];
	tracker_elementID = gaze_tracker_logfile_name;
	subject_name = fn_get_subject_name_for_side(sessionID, side);

	% prepare storing the meta information to the output file
	%registration_struct.info.gaze_tracker_logfile_FQN = gaze_tracker_logfile_FQN;
	registration_struct.info.sessionID = sessionID;
	registration_struct.info.side = side;
	registration_struct.info.tracker_elementID = tracker_elementID;
	registration_struct.info.subject_name = subject_name;
	registration_struct.info.tracker_type = tracker_type;
	registration_struct.info.velocity_threshold_pixels_per_sample = velocity_threshold_pixels_per_sample;
	registration_struct.info.saccade_allowance_time_ms = saccade_allowance_time_ms;
	registration_struct.info.acceptable_radius_pix = acceptable_radius_pix;
	registration_struct.info.transformationType_list = transformationType_list;
	registration_struct.info.polynomial_degree = polynomial_degree;

%	% load the data	(might take a while)
%	data_struct = fnParseEventIDETrackerLog_v01(gaze_tracker_logfile_FQN, ';', [], []);
%	ds_colnames = data_struct.cn;
%
%	% check for empty data and skip
%	if (size(data_struct.data, 1) < 2)
%		disp([mfilename, ': Trackerlog file empty: ', gaze_tracker_logfile_FQN]);
%		return
%	end

	sanitized_calibration_set_ID_names = gaze_subtable_list(cur_set_idx);
	n_calibration_set_IDs = length(sanitized_calibration_set_ID_names);
%	calibration_set_ID_idx_data_col_idx = data_struct.cn.(calibration_set_ID_idx_colname);

%	nonvar_calibration_set_ID_names = data_struct.unique_lists.(nonvar_calibration_set_ID_idx_unique_list_name);
	nonvar_calibration_set_ID_names = sanitized_calibration_set_ID_names;


	% construct the output name
	%OLD_output_mat_filename = ['GAZEREGv02.SID_', sessionID, '.SIDE_', side, '.SUBJECTID_', subject_name, '.', tracker_type, '.TRACKERELEMENTID_', tracker_elementID, '.mat'];
	output_mat_filename = ['GAZEREG', version_string, '.SESSIONID_', sessionID, '.SIDEID_', side, '.SUBJECTID_', subject_name, '.TRACKERID_', tracker_type, '.ELEMENTID_', tracker_elementID, '.mat'];


	for i_calibration_set_ID = 1 : n_calibration_set_IDs
		cur_sanitized_calibration_set_ID_name = sanitized_calibration_set_ID_names{i_calibration_set_ID};
		sideless_cur_sanitized_calibration_set_ID_name = regexprep(regexprep(cur_sanitized_calibration_set_ID_name, 'A0_pupillabs_', ''), 'B1_pupillabs_', '');
		cur_gaze_data_table = gaze_data.(cur_sanitized_calibration_set_ID_name);
		ds_colnames = fn_get_column_name_indices_struct(cur_gaze_data_table.Properties.VariableNames);


		% get the current calibration set row idx
		cur_calibration_set_name = cur_sanitized_calibration_set_ID_name;
		cur_nonvar_calibration_set_name = nonvar_calibration_set_ID_names{i_calibration_set_ID};

		disp(['Current calibration set (', tracker_type, '): ', cur_sanitized_calibration_set_ID_name]);
		%cur_calibration_set_ID_row_idx = find(data_struct.data(:, calibration_set_ID_idx_data_col_idx) == i_calibration_set_ID);
		cur_calibration_set_ID_row_idx = (1:1:size(cur_gaze_data_table, 1));


	%	disp(['Processing data column: ', gaze_col_name_list.stem{1}]);

		% take the best available time stamps from the tracker file
		if isfield(ds_colnames, 'corrected_local_timestamp')
			timestamp_list = cur_gaze_data_table.corrected_local_timestamps(cur_calibration_set_ID_row_idx);
		else
		% correct timestamps?
			[ col_header, corrected_local_timestamp_list ] = fn_correct_remote_network_timestamps( tracker_elementID, cur_gaze_data_table.receive_timestamp_s, cur_gaze_data_table.timestamp, cur_CCF_runfolder_FQN);
			cur_gaze_data_table.(col_header) = corrected_local_timestamp_list;
			timestamp_list = cur_gaze_data_table.corrected_local_timestamps(cur_calibration_set_ID_row_idx);
			%timestamp_list = cur_gaze_data_table.receive_timestamp_s(cur_calibration_set_ID_row_idx);
		end
		
		% resort by timestamp
		[sorted_timestamp_list, timestamp_sort_idx] = sort(timestamp_list);
		if ~isequal(sorted_timestamp_list, timestamp_list)
			data_struct.data = data_struct.data(timestamp_sort_idx, :);
			timestamp_list = sorted_timestamp_list;
		end


		% extract the columns with the eventIDE coordinates for fixation target and the gaze data
		target_timestamp_list = calibration_tick_table.timestamp_s;
		fix_target_x_list = calibration_tick_table.target_x_norm(:);
		fix_target_y_list = calibration_tick_table.target_y_norm(:);

		target_visible_ldx = (calibration_tick_table.target_visible) == 1;
		fix_target_x_list(~target_visible_ldx) = NaN;
		fix_target_y_list(~target_visible_ldx) = NaN;
		N_invisible_target_ticks = sum(~target_visible_ldx);

		% now find target changes (position changes or target off)
		norm_XY_list = [calibration_tick_table.target_x_norm, calibration_tick_table.target_y_norm];
		% this works but each NaNs triggers its own new distabnce run
		naned_norm_XY_list(~target_visible_ldx, :) = repmat([NaN, NaN], N_invisible_target_ticks, 1);
		% instead use an out of bounds marker, so we get invisibility
		% streches detected like target positions
		norm_XY_list(~target_visible_ldx, :) = repmat([out_of_bounds_marker_value, out_of_bounds_marker_value], N_invisible_target_ticks, 1);
		
		target_changed_on_tick_ldx = vecnorm((norm_XY_list(1:end-1, :) - norm_XY_list(2:end, :)), 2, 2);
		if (target_changed_on_tick_ldx(1) == 0)
			target_changed_on_tick_ldx = [1; target_changed_on_tick_ldx];
		else
			error('should not happen...');
		end
		target_changed_on_tick_ldx = target_changed_on_tick_ldx > 0;

		% Now we loop through the tick timestamps and find the nearest
		% gaze timestamps and start inserting the target position data (X, Y, visible)

		target_changed_on_tick_start_idx = find(target_changed_on_tick_ldx);
		target_changed_on_tick_end_idx = (target_changed_on_tick_start_idx-1);
		target_changed_on_tick_end_idx(target_changed_on_tick_end_idx < 1) =[];
		if target_changed_on_tick_end_idx(end) < length(target_changed_on_tick_ldx)
			target_changed_on_tick_end_idx(end+1) =  length(target_changed_on_tick_ldx);
		end

		target_changed_on_tick_start_s = target_timestamp_list(target_changed_on_tick_start_idx);
		target_changed_on_tick_end_s = target_timestamp_list(target_changed_on_tick_end_idx);
		target_XY_pos_list = norm_XY_list(target_changed_on_tick_start_idx, :);


		% these are by tick, but we want this information by sample...
		% so we want to add them to the cur_gaze_data_table

		% now make this the same size as cur_gaze_data_table
		target_timestamp_list = cur_gaze_data_table.receive_timestamp_s;
		fix_target_x_list = nan(size(cur_gaze_data_table.receive_timestamp_s));
		fix_target_y_list = nan(size(cur_gaze_data_table.receive_timestamp_s));
		fix_target_visible_list = false(size(cur_gaze_data_table.receive_timestamp_s));
		
		for i_target_change = 1 : length(target_changed_on_tick_start_s)
			cur_target_changed_on_tick_start_s = target_changed_on_tick_start_s(i_target_change);
			cur_target_changed_on_tick_end_s = target_changed_on_tick_end_s(i_target_change);
			cur_XY_pos = target_XY_pos_list(i_target_change, :);

			first_sample_of_cur_target_pos_idx = find(target_timestamp_list >= cur_target_changed_on_tick_start_s, 1, 'first');
			last_sample_of_cur_target_pos_idx = find(target_timestamp_list <= cur_target_changed_on_tick_end_s, 1, 'last');
			fix_target_x_list(first_sample_of_cur_target_pos_idx:last_sample_of_cur_target_pos_idx) = cur_XY_pos(1);
			fix_target_y_list(first_sample_of_cur_target_pos_idx:last_sample_of_cur_target_pos_idx) = cur_XY_pos(2);

			fix_target_visible_list(first_sample_of_cur_target_pos_idx:last_sample_of_cur_target_pos_idx) = true;
		end




		% This only works if the eventIDE calbibration is for the same space
		% for eyelink, both eyes come from the same camera and hence will work
		% reasonably well with the same eventIDE offset and gain, good enough to
		% allow to see the actual data points, but for Pupil labs that only works
		% for the row_type/Sample Type/SourceID that was used for the calibration
		% as all SourceID "live" in different spaces... so we need a general
		% alignment before we collect the points

		switch(tracker_type)
			case 'eyelink'
				% % extract the columns with the eventIDE coordinates for the gaze data
				% % these are not guaranteed to employ the final/best eventIDE linear
				% % registration "matrix" yet.
				% eventide_gaze_x_list = data_struct.data(cur_calibration_set_ID_row_idx, ds_colnames.Gaze_X);
				% eventide_gaze_y_list = data_struct.data(cur_calibration_set_ID_row_idx, ds_colnames.Gaze_Y);
				% 
				% % extract the final calibration values
				% calibration.gain_x = data_struct.data(end, ds_colnames.GLM_Coefficients_GainX);
				% calibration.gain_y = data_struct.data(end, ds_colnames.GLM_Coefficients_GainY);
				% calibration.offset_x = data_struct.data(end, ds_colnames.GLM_Coefficients_OffsetX);
				% calibration.offset_y = data_struct.data(end, ds_colnames.GLM_Coefficients_OffsetY);
				% 
				% % extract the GLM data for all samples
				% calibration_gain_x_list = data_struct.data(cur_calibration_set_ID_row_idx, ds_colnames.GLM_Coefficients_GainX);
				% calibration_gain_y_list = data_struct.data(cur_calibration_set_ID_row_idx, ds_colnames.GLM_Coefficients_GainY);
				% calibration_offset_x_list = data_struct.data(cur_calibration_set_ID_row_idx, ds_colnames.GLM_Coefficients_OffsetX);
				% calibration_offset_y_list = data_struct.data(cur_calibration_set_ID_row_idx, ds_colnames.GLM_Coefficients_OffsetY);
				% % undo all variable calibration to get back to something resembling the
				% % tracker's raw gaze values
				% raw_eventide_gaze_x_list = (eventide_gaze_x_list ./ calibration_gain_x_list) - calibration_offset_x_list;
				% raw_eventide_gaze_y_list = (eventide_gaze_y_list ./ calibration_gain_y_list) - calibration_offset_y_list;
				% % apply the final eventIDE GLM calibration matrix to all samples, as that
				% % should be at least acceptable. Note, we only do this so loading and
				% % displaying gaze and target data in the same plot looks reasonable and
				% % that we can approximate the instantaneous velocity.
				% cal_eventide_gaze_x_list = (raw_eventide_gaze_x_list + calibration.offset_x) .* calibration.gain_x;
				% cal_eventide_gaze_y_list = (raw_eventide_gaze_y_list + calibration.offset_y) .* calibration.gain_y;
			case 'pupillabs'
				% the calibration trick only works for the SourceID that was
				% actually used and calibrated by eventIDE, the other IDs are in
				% quite different spaces, so need to be treated differently
				% and the logfile does not unambiguosly tell which SourceID was
				% used anyway, so try to find a generic method to get the scaling
				% roughly correct...

%				raw_eventide_gaze_x_list = data_struct.data(cur_calibration_set_ID_row_idx, ds_colnames.(gaze_col_name_list.X{1}));
%				raw_eventide_gaze_y_list = data_struct.data(cur_calibration_set_ID_row_idx, ds_colnames.(gaze_col_name_list.Y{1}));

				raw_eventide_gaze_x_list = cur_gaze_data_table.norm_pos(cur_calibration_set_ID_row_idx, 1);
				raw_eventide_gaze_y_list = cur_gaze_data_table.norm_pos(cur_calibration_set_ID_row_idx, 2);

				% manually select the matching peaks in fix_target_x_list and
				% raw_eventide_gaze_x_list to get an estimate of gain and offset
				% adjustments required to align raw_eventide_gaze with eventIDE's
				% screen pixel space.

				% raw values of zero or ones are suspicious for the pupil cameras
				% and the world camera but should be okay for surfaces
				exclude_samples_idx = [];
				exclude_samples_idx = union(exclude_samples_idx, find(cur_gaze_data_table.confidence <= min_confidence));


				% get some starting points...
				switch sideless_cur_sanitized_calibration_set_ID_name
					case {'pupil_dot_1_dot_2d', 'pupil_dot_0_dot_2d', 'pupil_dot_1_dot_3d', 'pupil_dot_0_dot_3d'}
						mov_space_range_X = [0, 1.0];	% could be [0, 1] but the very edges are dubious
						mov_space_range_Y = [0, 1.0];	% could be [0, 1] but the very edges are dubious

						% for surfaces try
						% this depends on the size of the surface in relaton to the
						% world gaze, but here just extend the surface width in either direction
					%	mov_space_range_X = [-1.0, 2.0];
					%	mov_space_range_Y = [-1.0, 2.0];
					%	exclude_samples_idx = [];
					otherwise
						disp([mfilename, ': WARN:, no initial mov space range defined for pupillabs topic', sideless_cur_sanitized_calibration_set_ID_name]);
						mov_space_range_X = [0, 1.0];	% could be [0, 1] but the very edges are dubious
						mov_space_range_Y = [0, 1.0];	% could be [0, 1] but the very edges are dubious
				end


				% as first approximation, just scale the mov_space_range to screen
				% for CCF we use a relative scale based on the playing
				% field
				% pixel range [0 1920], [0, 1080]
				
				% the space of the target positions...
				ref_space_range_X = [0, 1];
				ref_space_range_Y = [0, 1];

				% try naively to just scale mov_space_range into screen_pixel_range
				% these factors convert from mov to screen: mov * gain - offset
				calibration.gain_x = (ref_space_range_X(2) - ref_space_range_X(1)) / (mov_space_range_X(2) - mov_space_range_X(1));
				calibration.gain_y = (ref_space_range_Y(2) - ref_space_range_Y(1)) / (mov_space_range_Y(2) - mov_space_range_Y(1));
				calibration.offset_x = -mov_space_range_X(1) + (ref_space_range_X(1) * ((mov_space_range_X(2) - mov_space_range_X(1)) * 1/ (ref_space_range_X(2) - ref_space_range_X(1))));
				calibration.offset_y = -mov_space_range_Y(1) + (ref_space_range_Y(1) * ((mov_space_range_Y(2) - mov_space_range_Y(1)) * 1/ (ref_space_range_Y(2) - ref_space_range_Y(1))));


				%% fancy semi-automatic method?
				%cal_eventide_gaze_x_list = fn_calc_and_apply_gain_and_offset_adjustments_between_vectors(fix_target_x_list, screen_pixel_range_X, raw_eventide_gaze_x_list, mov_space_range_X, fullfile(gaze_tracker_logfile_path, [gaze_col_name_list.stem, '.X.fixation_dots.gain_offset.mat']));
				%cal_eventide_gaze_y_list = fn_calc_and_apply_gain_and_offset_adjustments_between_vectors(fix_target_y_list, screen_pixel_range_Y, raw_eventide_gaze_y_list, mov_space_range_Y, fullfile(gaze_tracker_logfile_path, [gaze_col_name_list.stem, '.Y.fixation_dots.gain_offset.mat']));

				% we need something approximating cal_eventide_gaze_x_list, cal_eventide_gaze_y_list
				cal_eventide_gaze_x_list = (raw_eventide_gaze_x_list + calibration.offset_x) .* calibration.gain_x;
				cal_eventide_gaze_y_list = (raw_eventide_gaze_y_list + calibration.offset_y) .* calibration.gain_y;

				% try to adjust that the average positions match between fix and
				% mov

				valid_sample_ldx = ~isnan(fix_target_x_list) &  ~isnan(fix_target_y_list) & (fix_target_x_list > out_of_bounds_marker_value) & (fix_target_y_list > out_of_bounds_marker_value);
				valid_sample_idx = find(valid_sample_ldx);
				%valid_sample_idx = union(find(fix_target_x_list ~= 0), find(fix_target_y_list ~= 0));
				valid_sample_idx = setdiff(valid_sample_idx, exclude_samples_idx);

				fix_mean_x = mean(fix_target_x_list(valid_sample_idx));
				fix_mean_y = mean(fix_target_y_list(valid_sample_idx));

				mov_mean_x = mean(cal_eventide_gaze_x_list(valid_sample_idx));
				mov_mean_y = mean(cal_eventide_gaze_y_list(valid_sample_idx));

				% align the mean x and y positions for better display later
				cal_eventide_gaze_x_list = cal_eventide_gaze_x_list + (fix_mean_x - mov_mean_x);
				cal_eventide_gaze_y_list = cal_eventide_gaze_y_list + (fix_mean_y - mov_mean_y);

			otherwise
				error(['tracker_type: ', tracker_type, ' not yet supported.']);
		end

		% calculate the pixel displacement between consecutive samples
		displacement_x_list = diff(cal_eventide_gaze_x_list);
		displacement_x_list(end+1) = NaN;	% we want the displacement for all samples so that all indices match

		displacement_y_list = diff(cal_eventide_gaze_y_list);
		displacement_y_list(end+1) = NaN;	% we want the displacement for all samples so that all indices match


		if (sum(displacement_x_list, 'omitnan') == 0 && sum(displacement_y_list, 'omitnan') == 0)
			disp([mfilename, ': data file seems to contain a constant fixation position, skipping...']);
			return
		end

		% now calculate the total displacement as euclidean distance in 2D
		% for any fixed sampling rate this velocity in pixels/sample correlates
		% strongly with the instantaneous velocity in pixel/time
		per_sample_euclidean_displacement_pix_list = sqrt((((displacement_x_list).^2) + ((displacement_y_list).^2)));
		if (debug)
			histogram(per_sample_euclidean_displacement_pix_list, (0.00:0.001:1.0));
		end

		% this is the "real" velocity in per time units
		sample_period_ms = unique(diff(timestamp_list));
		velocity_pix_ms = per_sample_euclidean_displacement_pix_list / fn_robust_mean(sample_period_ms);


		% index samples with instantaneous volicity below and above the threshold
		low_velocity_samples_idx = find(per_sample_euclidean_displacement_pix_list <= velocity_threshold_pixels_per_sample);
		high_velocity_samples_idx = find(per_sample_euclidean_displacement_pix_list > velocity_threshold_pixels_per_sample);

		% find consecutive samples with below velocity_threshold_pixels_per_sample
		% changes
		fixation_points_idx_diff = diff(low_velocity_samples_idx);
		fixation_points_idx_diff(end+1) = 10; % the value does not matter as long as it is >1 for the next line
		tmp_lidx = fixation_points_idx_diff <= 1;
		% these idx have >= 2 samples of below threshold velocity -> proto
		% fixations instead of saccades.
		fixation_samples_idx = low_velocity_samples_idx(tmp_lidx);
		fixation_target_visible_sample_idx = find(fix_target_visible_list); %points that are visible


		% extract the FixationTarget information by sample
		fixation_target.by_sample.header = {'FixationPointX', 'FixationPointY', 'FixationPointID', 'timestamp', 'FixationPointVisible'};
		fixation_target.by_sample.cn = local_get_column_name_indices(fixation_target.by_sample.header);
		FTBS_cn = fixation_target.by_sample.cn;

		fixation_target.by_sample.table = zeros([length(cur_calibration_set_ID_row_idx), length(fixation_target.by_sample.header)]);
		fixation_target.by_sample.table(:, 1:2) = [fix_target_x_list, fix_target_y_list];
		fixation_target.by_sample.table(:, FTBS_cn.FixationPointID) = -1; % faster than NaN and also not a valid index
		fixation_target.by_sample.table(:, FTBS_cn.timestamp) = target_timestamp_list;
		fixation_target.by_sample.table(:, FTBS_cn.FixationPointVisible) = fix_target_visible_list;


		% assign an ID to each fixation target positio
		% now find the unique displayed fixation target positions
		existing_fixation_target_x_y_coordinate_list = unique(fixation_target.by_sample.table(:, 1:2), 'rows');
		existing_fixation_target_x_y_coordinate_list = unique(fixation_target.by_sample.table(valid_sample_ldx, 1:2), 'rows');

		

		if size(existing_fixation_target_x_y_coordinate_list, 1) < 3
			disp([mfilename, ': less than 3 calibration positions recorded, calibration impossible, skipping...']);
			return
		end

		% % find and exclude NaNs (these should not exist here, but if they do treat them properly)
		% nan_2d_idx = isnan(existing_fixation_target_x_y_coordinate_list);
		% nan_row_idx = find(sum(nan_2d_idx, 2));
		% if ~isempty(nan_row_idx)
		% 	existing_fixation_target_x_y_coordinate_list(nan_row_idx, :) = [];
		% end


		zero_offset = 0;	% handle absence of the no fixation target displayed condition gracefully
		for i_fixation_target_x_y_coordinate = 1 : length(existing_fixation_target_x_y_coordinate_list)
			current_target_ID = i_fixation_target_x_y_coordinate - zero_offset;
			if existing_fixation_target_x_y_coordinate_list(i_fixation_target_x_y_coordinate, :) == [out_of_bounds_marker_value, out_of_bounds_marker_value]
				zero_offset = 1;
				current_target_ID = i_fixation_target_x_y_coordinate - zero_offset;
			end
			current_target_ID_lidx = fixation_target.by_sample.table(:, FTBS_cn.FixationPointX) == existing_fixation_target_x_y_coordinate_list(i_fixation_target_x_y_coordinate, 1) ...
				& fixation_target.by_sample.table(:, FTBS_cn.FixationPointY) == existing_fixation_target_x_y_coordinate_list(i_fixation_target_x_y_coordinate, 2);
			fixation_target.by_sample.table(current_target_ID_lidx, FTBS_cn.FixationPointID) = current_target_ID;
		end

		% clean up un assigned points, assume zero
		unassigned_samples_idx = find(fixation_target.by_sample.table(:, FTBS_cn.FixationPointID) == -1);
		if ~isempty(unassigned_samples_idx)
			fixation_target.by_sample.table(unassigned_samples_idx, FTBS_cn.FixationPointID) = 0;
		end

		% now find the transitions between fixation target position (also on/off transitions)
		switch_list = diff(fixation_target.by_sample.table(:, FTBS_cn.FixationPointID)); % a switch results in a change of the FixationPointID
		preswitch_trial_idx = find(switch_list ~= 0);	% these are the indices of the trials just before a transition
		switch_trial_idx = preswitch_trial_idx + 1;		% these are the indices of the trials just after a transition
		% allow existence or absence of no fixation_target displayed samples
		unique_fixation_targets = unique(fixation_target.by_sample.table(:, FTBS_cn.FixationPointID));
		nonzero_unique_fixation_target_idx = find(unique_fixation_targets);

		% intialize tables
		targetstart_ts_idx = [1; switch_trial_idx];
		targetend_ts_idx = [preswitch_trial_idx; size(fixation_target.by_sample.table, 1)];
		good_target_sample_points_lidx = false([size(fixation_target.by_sample.table, 1), 1]);
		fixation_target_position_table = zeros([length(nonzero_unique_fixation_target_idx), 2]);

		% collect sample indices while targets are displayed (for at least
		% saccade_allowance_time_ms)
		for i_switch = 1 : length(targetstart_ts_idx)
			current_start_idx = targetstart_ts_idx(i_switch);
			current_end_idx = targetend_ts_idx(i_switch);
			current_start_ts = timestamp_list(current_start_idx);
			current_end_ts = timestamp_list(current_end_idx);
			current_target_ID = fixation_target.by_sample.table(current_start_idx, FTBS_cn.FixationPointID);
			current_target_duration = current_end_ts - current_start_ts;

			% get the fixation target's cordinates
			current_target_x = fixation_target.by_sample.table(current_start_idx, FTBS_cn.FixationPointX);
			current_target_y = fixation_target.by_sample.table(current_start_idx, FTBS_cn.FixationPointY);
			if current_target_duration >= saccade_allowance_time_ms
				%found a long enough target display duration
				% find the start_idx
				offset_start_ts = current_start_ts + saccade_allowance_time_ms;
				proto_offset_start_idx_list = find(timestamp_list >= offset_start_ts);
				offset_start_idx = proto_offset_start_idx_list(1);
				good_target_sample_points_lidx(offset_start_idx: current_end_idx) = true;
			end
			% store the coordinates in the reduced table
			if current_target_ID > 0
				fixation_target_position_table(current_target_ID, :) = [current_target_x, current_target_y];
			end

		end

		good_target_sample_points_lidx(~fix_target_visible_list) = false;
		good_target_sample_points_lidx(fix_target_x_list == out_of_bounds_marker_value) = false;
		good_target_sample_points_lidx(fix_target_y_list == out_of_bounds_marker_value) = false;



		% list of target samples with required minimal presentation duration
		good_target_sample_points_idx = find(good_target_sample_points_lidx);
		bad_target_sample_points_idx = find(good_target_sample_points_lidx == 0);

		% especially the pupil labs tracker estimates its own confidence, so use
		% this.
		if isfield(ds_colnames, confidence_col_name)
			good_confidence_sample_points_idx = find(cur_gaze_data_table.(confidence_col_name) >= min_confidence);
			good_target_sample_points_idx = intersect(good_target_sample_points_idx, good_confidence_sample_points_idx);
			% also exclude points from the edge of the pupil and world camera,
			% these are unlikely real useful samples
			good_target_sample_points_idx = setdiff(good_target_sample_points_idx, exclude_samples_idx);
		end


		% plot the different sample classes in different colors
		target_and_cluster_postions_fh = figure('Name', ['Roberta''s gaze visualizer: ', gaze_tracker_logfile_name, gaze_tracker_logfile_ext]);
		fnFormatDefaultAxes(DefaultAxesType);
		[output_rect] = fnFormatPaperSize(DefaultPaperSizeType, gcf, output_rect_fraction);
		set(target_and_cluster_postions_fh, 'Units', 'centimeters', 'Position', output_rect, 'PaperPosition', output_rect);


		%cur_axis_ah = plot(fix_target_x_list(:), fn_convert_eventide2_matlab_coord(fix_target_y_list(:)),'s','MarkerSize',10,'MarkerFaceColor',[1 0 0]);
		cur_axis_ah = plot(fix_target_x_list(good_target_sample_points_lidx), fix_target_y_list(good_target_sample_points_lidx),'s','MarkerSize',10,'MarkerFaceColor',[1 0 0]);
		%set(gca(), 'XLim', [(960-300) (960+300)], 'YLim', [(1080-500-200) (1080-500+400)]);
		%set(gca(), 'XLim', [(960-600) (960+600)], 'YLim', [(1080-500-300) (1080-500+500)]);
		cur_ah = gca();

		set(cur_ah, 'XLim', [0-2*CCF_conf.target_radius 1+2*CCF_conf.target_radius], 'YLim', [0-2*CCF_conf.target_radius 1+2*CCF_conf.target_radius]);
		
		title(['Calibration set ID: ', cur_sanitized_calibration_set_ID_name, ' (', cur_calibration_set_name, ')'], 'Interpreter', 'none', 'FontSize', 12);
		subtitle([' '], 'FontSize', 12);% we will update this later

		hold on
		% full traces all points with lines in between
		plot(cur_ah, cal_eventide_gaze_x_list(:), cal_eventide_gaze_y_list(:),'b','LineWidth', 1, 'Color', [0.8 0.8 0.8])
		% blue fixation points
		plot(cur_ah, cal_eventide_gaze_x_list(fixation_samples_idx), cal_eventide_gaze_y_list(fixation_samples_idx), 'LineWidth', 1, 'LineStyle', 'none', 'Color', 'b', 'Marker', '.', 'Markersize', 1);
		% magenta, points exceeding the velocity threshold
		plot(cur_ah, cal_eventide_gaze_x_list(low_velocity_samples_idx), cal_eventide_gaze_y_list(low_velocity_samples_idx), 'LineWidth', 1, 'LineStyle', 'none', 'Color', 'm', 'Marker', '.', 'Markersize', 1);
		% points immediately after fixation point onsets, when the sunbject can not fixate
		plot(cur_ah, cal_eventide_gaze_x_list(bad_target_sample_points_idx), cal_eventide_gaze_y_list(bad_target_sample_points_idx), 'LineWidth', 1, 'LineStyle', 'none', 'Color', 'r', 'Marker', '.', 'Markersize', 1);
		% surviving points
		plot(cur_ah, cal_eventide_gaze_x_list(fixation_target_visible_sample_idx), cal_eventide_gaze_y_list(fixation_target_visible_sample_idx), 'LineWidth', 1, 'LineStyle', 'none', 'Color', [0 0.6 0], 'Marker', '.', 'Markersize', 1);
		%CLEAN-UP CURSOR

		%TODO:
		%	during selection of the cloud centers mark those samples acquired while
		%	the respective fixation target was visible


		% for fancier registrations try to presere

		% see whether points already exist?
		cluster_center_list_fqn = fullfile(gaze_tracker_logfile_path, 'fixation_target_cluster_centers.mat');

		% save to the current directory
		if isfile(fullfile(gaze_tracker_logfile_path, output_mat_filename))
			tmp = load(fullfile(gaze_tracker_logfile_path, output_mat_filename), 'out_registration_struct');
			if isfield(tmp, 'out_registration_struct') ...
					&& isfield(tmp.out_registration_struct, cur_calibration_set_name) ...
					&& isfield(tmp.out_registration_struct.(cur_calibration_set_name), 'registration_struct') ...
					&& isfield(tmp.out_registration_struct.(cur_calibration_set_name).registration_struct, 'reg_data') ...
					&& isfield(tmp.out_registration_struct.(cur_calibration_set_name).registration_struct.reg_data, 'x_y_mouse_y_flipped')
				x_y_mouse_y_flipped = tmp.out_registration_struct.(cur_calibration_set_name).registration_struct.reg_data.x_y_mouse_y_flipped;
				save(cluster_center_list_fqn, 'x_y_mouse_y_flipped');
			end
		end

		if exist(cluster_center_list_fqn, 'file')
			load(cluster_center_list_fqn);
		else
			% pre allocate
			x_y_mouse_y_flipped = nan([length(nonzero_unique_fixation_target_idx), 2]);
		end

		% manually select all cluster centers
		for i_fix_target = 1 : length(find(unique_fixation_targets))
			unique_fixation_target_id = unique_fixation_targets(nonzero_unique_fixation_target_idx(i_fix_target));

			% 		title(cur_calibration_set_name, 'Interpreter', 'none', 'FontSize', 12);
			% 		subtitle(['Select the center of the gaze sample cloud belonging to fixation target ', num2str(unique_fixation_target_id), ', press enter after selection. (use delete to erase)'], 'FontSize', 12);
			subtitle(['Select the center of the gaze sample cloud belonging to fixation target ', num2str(unique_fixation_target_id), ', press enter after selection. (use delete to erase)'], 'FontSize', 12);

			% plot the samples acquired while the current fixation position was
			% visible.
			current_target_ID_idx = find(fixation_target.by_sample.table(:, FTBS_cn.FixationPointID) == unique_fixation_target_id);
			cur_fixation_target_visible_sample_idx = intersect(fixation_target_visible_sample_idx, current_target_ID_idx);
			plot(cur_ah,cal_eventide_gaze_x_list(cur_fixation_target_visible_sample_idx), fn_convert_eventide2_matlab_coord(cal_eventide_gaze_y_list(cur_fixation_target_visible_sample_idx)), 'LineWidth', 1, 'LineStyle', 'none', 'Color', [0 1.0 0], 'Marker', '.', 'Markersize', 1);

			plot(cur_ah, fixation_target_position_table(unique_fixation_target_id, 1), fn_convert_eventide2_matlab_coord(fixation_target_position_table(unique_fixation_target_id, 2)), 'LineWidth', 2, 'LineStyle', 'none', 'Color', 'r', 'Marker', '+', 'Markersize', 10);

			% if there is a stored cluster center for this fixation target, display
			% this
			if ~isnan(x_y_mouse_y_flipped(i_fix_target, 1)) || ~isnan(x_y_mouse_y_flipped(i_fix_target, 2))
				plot(cur_ah, x_y_mouse_y_flipped(i_fix_target, 1), x_y_mouse_y_flipped(i_fix_target, 2), 'LineWidth', 2, 'LineStyle', 'none', 'Color', [0 0 0.5], 'Marker', '+', 'Markersize', 10);
				stored_tmp_x_list = x_y_mouse_y_flipped(i_fix_target, 1);
				stored_tmp_y_list = x_y_mouse_y_flipped(i_fix_target, 2);
			else
				stored_tmp_x_list = [];
				stored_tmp_y_list = [];
			end
			% select a new cluster center
			[tmp_x_list, tmp_y_list]= getpts;
			if isempty(tmp_x_list)
				tmp_x_list = NaN;
				tmp_y_list = NaN;
				% keep the stored points if the user did not select new valid
				% points
				if ~isempty(stored_tmp_x_list)
					tmp_x_list = stored_tmp_x_list;
				end
				if ~isempty(stored_tmp_y_list)
					tmp_y_list = stored_tmp_y_list;
				end
			end

			% getpts returns matlab coordinates, indicate that with the _flipped
			% suffix
			x_y_mouse_y_flipped(i_fix_target, 1) = tmp_x_list(end);
			x_y_mouse_y_flipped(i_fix_target, 2) = tmp_y_list(end);

			if ~isnan(tmp_x_list(end)) && ~isnan(tmp_y_list(end))
				% make the highlighted points
				plot(cur_ah, cal_eventide_gaze_x_list(cur_fixation_target_visible_sample_idx), fn_convert_eventide2_matlab_coord(cal_eventide_gaze_y_list(cur_fixation_target_visible_sample_idx)), 'LineWidth', 1, 'LineStyle', 'none', 'Color', [0 0.6 0], 'Marker', '.', 'Markersize', 1);
				plot(cur_ah, fixation_target_position_table(unique_fixation_target_id, 1), fn_convert_eventide2_matlab_coord(fixation_target_position_table(unique_fixation_target_id, 2)), 'LineWidth', 2, 'LineStyle', 'none', 'Color', 'r', 'Marker', '+', 'Markersize', 10);

				plot(cur_ah, fixation_target_position_table(unique_fixation_target_id, 1), fn_convert_eventide2_matlab_coord(fixation_target_position_table(unique_fixation_target_id, 2)), 'LineWidth', 2, 'LineStyle', 'none', 'Color', [0.8 0 0], 'Marker', '+', 'Markersize', 10);
				plot(cur_ah, x_y_mouse_y_flipped(i_fix_target, 1), x_y_mouse_y_flipped(i_fix_target, 2), 'LineWidth', 2, 'LineStyle', 'none', 'Color', cluster_center_color, 'Marker', 'x', 'Markersize', 10);
				% show the
				tmp_radius = acceptable_radius_pix;
				tmp_diameter = 2 * tmp_radius;
				rectangle('Position',[x_y_mouse_y_flipped(i_fix_target, 1)-tmp_radius x_y_mouse_y_flipped(i_fix_target, 2)-tmp_radius tmp_diameter tmp_diameter],'Curvature',[1,1], 'EdgeColor', cluster_center_color, 'LineWidth', 1);
				%daspect([1,1,1])
			else
				disp(['No (valid) coordinates selected for the last target position (', num2str(unique_fixation_target_id), ')']);
			end
		end
		hold off
		%xlim([(960-300) (960+300)]);
		%ylim ([(1080-500-200) (1080-500+400)]);

		%set(gca(), 'XLim', [(960-600) (960+600)], 'YLim', [(1080-500-300) (1080-500+500)]);
		set(cur_ah, 'XLim', [0-2*CCF_conf.target_radius 1+2*CCF_conf.target_radius], 'YLim', [0-2*CCF_conf.target_radius 1+2*CCF_conf.target_radius]);


		%axis equal

		write_out_figure(target_and_cluster_postions_fh, fullfile(gaze_tracker_logfile_path, ['gazeregistration.target_and_cluster_postions.', cur_calibration_set_name, '.pdf']));
		% save the current set of selected cluster centers in matlab coordinates.
		save(cluster_center_list_fqn, 'x_y_mouse_y_flipped');
		% the getpts coordinates are in matlab convention, so convert into eventIDE
		% space
		x_y_mouse = [x_y_mouse_y_flipped(:, 1), fn_convert_eventide2_matlab_coord(x_y_mouse_y_flipped(:,2))];
		%x_y_mouse = [x_y_mouse_y_flipped(:, 1),
		%fn_convert_eventide2_matlab_coord(x_y_mouse_y_flipped(:,2), [], [], 'backward')]; % same as above

		registration_struct.reg_data.x_y_mouse_y_flipped = x_y_mouse_y_flipped;
		registration_struct.reg_data.x_y_mouse = x_y_mouse;



		% pre allocate
		euclidean_distance_array = zeros([size(cal_eventide_gaze_x_list, 1), length(nonzero_unique_fixation_target_idx)]);
		% calculate the distance of each sample to each fixation target position as
		% selected with getpts, so the center positions of the gaze clusters
		% assigned to each fixation position.
		for i_fix_target = 1 : length(find(unique_fixation_targets))
			unique_fixation_target_id = unique_fixation_targets(nonzero_unique_fixation_target_idx(i_fix_target));
			euclidean_distance_array(:, unique_fixation_target_id) = sqrt(((cal_eventide_gaze_x_list - x_y_mouse(unique_fixation_target_id, 1)).^2 ) + ...
				((cal_eventide_gaze_y_list - x_y_mouse(unique_fixation_target_id, 2)).^2 ));
			if (debug)
				figure_h = figure('Name', ['FixationTarget_', num2str(unique_fixation_target_id), '; ', cur_nonvar_calibration_set_name]);
				histogram(euclidean_distance_array(:, unique_fixation_target_id), (0.00:0.001:1.0));
			end
		end

		% find those samples that are close enough to the selected target position
		% cluster center points and are from the correct epochs
		points_close_2_fixation_centers_idx = [];
		distance_gaze_2_target_pix = [];
		for i_fix_target = 1 : length(find(unique_fixation_targets))
			unique_fixation_target_id = unique_fixation_targets(nonzero_unique_fixation_target_idx(i_fix_target));
			% all smaples close enough to the current slected cluster center
			close_points_idx = find(euclidean_distance_array(:, unique_fixation_target_id) <= acceptable_radius_pix);
			% all points when the corresponding target was actually displayed
			current_target_samples_idx = find(fixation_target.by_sample.table(:, FTBS_cn.FixationPointID) == unique_fixation_target_id);
			% just the subset of trials where the samples where close enough to the
			% displayed target's cluster center
			current_points_idx = intersect(close_points_idx, current_target_samples_idx);
			distance_gaze_2_target_pix = [distance_gaze_2_target_pix; euclidean_distance_array(current_points_idx, unique_fixation_target_id)];
			points_close_2_fixation_centers_idx = [points_close_2_fixation_centers_idx; current_points_idx];
		end
		% these are unsorted, so get them in temporal order
		points_close_2_fixation_centers_idx = sort(points_close_2_fixation_centers_idx);
		good_points_close_2_fixation_centers_idx = intersect(good_target_sample_points_idx, points_close_2_fixation_centers_idx);


		% just plot the selected target samples that are close enough to the
		% cluster centers
		tmp_target_selected_samples = [fixation_target.by_sample.table(good_points_close_2_fixation_centers_idx, FTBS_cn.FixationPointX) fn_convert_eventide2_matlab_coord(fixation_target.by_sample.table(good_points_close_2_fixation_centers_idx, FTBS_cn.FixationPointY))];
		tmp_gaze_selected_samples = [cal_eventide_gaze_x_list(good_points_close_2_fixation_centers_idx) fn_convert_eventide2_matlab_coord(cal_eventide_gaze_y_list(good_points_close_2_fixation_centers_idx))];


		% plot the different sample classes in different colors
		selected_samples_fh = figure('Name', ['selected_samples: ', cur_nonvar_calibration_set_name]);
		fnFormatDefaultAxes(DefaultAxesType);
		[output_rect] = fnFormatPaperSize(DefaultPaperSizeType, gcf, output_rect_fraction);
		set(gcf(), 'Units', 'centimeters', 'Position', output_rect, 'PaperPosition', output_rect);

		selected_samples_ah = fn_plot_selected_samples_over_targets(...
			fixation_target.by_sample.table(cur_calibration_set_ID_row_idx, FTBS_cn.FixationPointX), fn_convert_eventide2_matlab_coord(fixation_target.by_sample.table(cur_calibration_set_ID_row_idx, FTBS_cn.FixationPointY)), good_points_close_2_fixation_centers_idx, target_color_spec, ...
			cal_eventide_gaze_x_list(:), fn_convert_eventide2_matlab_coord(cal_eventide_gaze_y_list(:)), good_points_close_2_fixation_centers_idx, sample_color_spec);
		title([cur_nonvar_calibration_set_name, ': raw samples selected for calibration'], 'Interpreter', 'none', 'Fontsize', 12);
		write_out_figure(selected_samples_fh, fullfile(gaze_tracker_logfile_path, ['gazeregistration.selected_samples.', cur_calibration_set_name, '.pdf']));



		% select list of target x and y and gaze x and y values for all sample
		% points with euclidean_distance <= acceptable_radius_pix, and
		% euclidean_distance-in_time <= velocity_threshold_pixels_per_sample

		selected_samples_idx = (1:1:size(euclidean_distance_array, 1))';
		selected_samples_idx = intersect(selected_samples_idx, good_points_close_2_fixation_centers_idx);
		% this here is pixel distance between samples over time!
		selected_samples_idx = intersect(selected_samples_idx, find(per_sample_euclidean_displacement_pix_list <= velocity_threshold_pixels_per_sample));
		% only samples xx ms after target onset
		selected_samples_idx = intersect(selected_samples_idx, good_target_sample_points_idx);
		% exclude the epochs witout a displayed target
		selected_samples_idx = intersect(selected_samples_idx, find(fixation_target.by_sample.table(:, 3)));

		% re-register the eventIDE gaze columns and display raw and re-registered
		% selected samples

		% plot the different sample classes in different colors
		selected_samples_ed_fh = figure('Name', ['selected_samples euclidean displacement histogram: ', cur_nonvar_calibration_set_name]);
		fnFormatDefaultAxes(DefaultAxesType);
		[output_rect] = fnFormatPaperSize(DefaultPaperSizeType, gcf, output_rect_fraction);
		set(gcf(), 'Units', 'centimeters', 'Position', output_rect, 'PaperPosition', output_rect);	histogram(per_sample_euclidean_displacement_pix_list(intersect(good_target_sample_points_idx, find(fixation_target.by_sample.table(:, 3)))), (0.00:0.005:5.0));

		title([cur_nonvar_calibration_set_name, ': euclidean displacement histogram'], 'Interpreter', 'none', 'Fontsize', 12);
		write_out_figure(selected_samples_ed_fh, fullfile(gaze_tracker_logfile_path, ['gazeregistration.selected_samples.euclidean_dispacement_histogram.', cur_calibration_set_name, '.pdf']));

		% moving (matlab coordinates)
		all_gaze_selected_samples = [cal_eventide_gaze_x_list(:) cal_eventide_gaze_y_list(:)];
		gaze_selected_samples = all_gaze_selected_samples(selected_samples_idx, :);
		% fixed (malab coordinates)
		all_target_selected_samples = [fixation_target.by_sample.table(cur_calibration_set_ID_row_idx, FTBS_cn.FixationPointX) fixation_target.by_sample.table(cur_calibration_set_ID_row_idx, FTBS_cn.FixationPointY)];
		target_selected_samples = all_target_selected_samples(selected_samples_idx, :);




		for i_transformationType = 1 : length(transformationType_list)
			transformationType = transformationType_list{i_transformationType};

			% for pwl/lwm try to only select the selectd samples closest to the
			% respective cluster center/ the cluster median position
			cur_selected_samples_pwl_lwm_idx = [];
			for i_fix_target = 1 : length(find(unique_fixation_targets))
				unique_fixation_target_id = unique_fixation_targets(nonzero_unique_fixation_target_idx(i_fix_target));
				current_fixation_target_samples_idx = find(fixation_target.by_sample.table(:, FTBS_cn.FixationPointID) == unique_fixation_target_id);
				valid_samples_for_current_fixtargID = intersect(selected_samples_idx, current_fixation_target_samples_idx);
				if ~isempty(valid_samples_for_current_fixtargID)
					% find the sample closest to the current cluster center
					[min_dist, closest_point_idx_idx] = min(euclidean_distance_array(valid_samples_for_current_fixtargID, unique_fixation_target_id));
					cur_selected_samples_pwl_lwm_idx = [cur_selected_samples_pwl_lwm_idx, valid_samples_for_current_fixtargID(closest_point_idx_idx)];
				end
			end
			n_control_points = length(cur_selected_samples_pwl_lwm_idx);

			transformationType_string = transformationType;
			output_degree_string = '';
			% calculate the registration
			switch (transformationType)
				case 'polynomial'
					if (n_control_points < 15) && polynomial_degree == 4
						polynomial_degree = polynomial_degree - 1;
					end
					if (n_control_points < 10) && polynomial_degree == 3
						polynomial_degree = polynomial_degree - 1;
					end
					% for polynomial_degree we need 6 control points but simply fail
					transformationType_string = [transformationType_string, ' (degree: ', num2str(polynomial_degree),')'];
					output_degree_string = ['.', num2str(polynomial_degree)];
					tform = fn_fitgeotrans(target_selected_samples, gaze_selected_samples, transformationType, polynomial_degree);
				case 'pwl'
					tform = fn_fitgeotrans(all_target_selected_samples(cur_selected_samples_pwl_lwm_idx, :), all_gaze_selected_samples(cur_selected_samples_pwl_lwm_idx, :), transformationType);
				case 'lwm'
					% lwm needs sensibly spaced control points, does not work yet
					if 	lwm_N > n_control_points
						disp(['Selected number of lwm control points (', num2str(lwm_N),') larger than number of control point pairs (', num2str(n_control_points), '). Reducing to ', num2str(n_control_points)]);
						lwm_N = n_control_points;
					end
					transformationType_string = [transformationType_string, ' (n: ', num2str(lwm_N),')'];
					output_degree_string = ['.', num2str(lwm_N)];
					tform = fn_fitgeotrans(all_target_selected_samples(cur_selected_samples_pwl_lwm_idx, :), all_gaze_selected_samples(cur_selected_samples_pwl_lwm_idx, :), transformationType, lwm_N); % polynomial_degree is N
				otherwise
					tform = fn_fitgeotrans(target_selected_samples, gaze_selected_samples, transformationType);
			end

			if ~isempty(tform)
				% apply the registration to the whole x y data series
				registered_gaze_selected_samples = transformPointsInverse(tform, [cal_eventide_gaze_x_list cal_eventide_gaze_y_list]);

				% show results
				cur_data_name = 'eventIDE_Gaze';
				cur_data_fh = figure('Name', [cur_data_name, ': Re-registration, (', transformationType_string, ')']);
				fnFormatDefaultAxes(DefaultAxesType);
				[output_rect] = fnFormatPaperSize(DefaultPaperSizeType, gcf, output_rect_fraction);
				set(gcf(), 'Units', 'centimeters', 'Position', output_rect, 'PaperPosition', output_rect);

				selected_samples_ah = fn_plot_selected_and_reregistered_samples_over_targets(...
					fixation_target.by_sample.table(cur_calibration_set_ID_row_idx, FTBS_cn.FixationPointX), fn_convert_eventide2_matlab_coord(fixation_target.by_sample.table(cur_calibration_set_ID_row_idx, FTBS_cn.FixationPointY)), selected_samples_idx, target_color_spec, ...
					cal_eventide_gaze_x_list(:), fn_convert_eventide2_matlab_coord(cal_eventide_gaze_y_list(:)), selected_samples_idx, [1 0 0], ...
					registered_gaze_selected_samples(:, 1), fn_convert_eventide2_matlab_coord(registered_gaze_selected_samples(:, 2)), selected_samples_idx, [0 1 0]);
				title([cur_nonvar_calibration_set_name, '; ', cur_data_name, ': ', transformationType_string], 'Interpreter', 'None', 'FontSize', 12);
				write_out_figure(cur_data_fh, fullfile(gaze_tracker_logfile_path, ['gazeregistration.', tracker_type, '.re-registered', '.', cur_calibration_set_name, '.', transformationType, output_degree_string, '.', cur_data_name, '.pdf']));
			end

			%TODO: write out tform with associated information


			for i_date_col_stem = 1 : length(gaze_col_name_list.stem)
				current_data_col_name = gaze_col_name_list.stem{i_date_col_stem};

				if isempty(current_data_col_name) && isfield(gaze_col_name_list, 'XY')
					cur_X_col_name = gaze_col_name_list.XY{1};
					cur_Y_col_name = gaze_col_name_list.XY{1};
					norm_pos_X_idx = 1;
					norm_pos_Y_idx = 2;
				else
					cur_X_col_name = gaze_col_name_list.X{i_date_col_stem};
					cur_Y_col_name = gaze_col_name_list.Y{i_date_col_stem};
				end

				% make sure to only include samples that are valid for the given data
				% column
				valid_eye_raw_idx = find(cur_gaze_data_table.(cur_X_col_name)(cur_calibration_set_ID_row_idx, norm_pos_X_idx) ~= out_of_bounds_marker_value);
				cur_selected_samples_idx = intersect(selected_samples_idx, valid_eye_raw_idx);

				% moving (eventIDE coordinates)
				all_gaze_selected_samples = [cur_gaze_data_table.(cur_X_col_name)(cur_calibration_set_ID_row_idx, norm_pos_X_idx) cur_gaze_data_table.(cur_Y_col_name)(cur_calibration_set_ID_row_idx, norm_pos_Y_idx)];
				current_gaze_samples = all_gaze_selected_samples(cur_selected_samples_idx, :);
				% fixed (eventIDE coordinates
				all_target_selected_samples = [fixation_target.by_sample.table(cur_calibration_set_ID_row_idx, FTBS_cn.FixationPointX) fixation_target.by_sample.table(cur_calibration_set_ID_row_idx, FTBS_cn.FixationPointY)];
				current_target_selected_samples = all_target_selected_samples(cur_selected_samples_idx, :);


				% calculate the registration

				% for pwl/lwm try to only select the selectd samples closest to the
				% respective cluster center/ the cluster median position
				cur_selected_samples_pwl_lwm_idx = [];
				for i_fix_target = 1 : length(find(unique_fixation_targets))
					unique_fixation_target_id = unique_fixation_targets(nonzero_unique_fixation_target_idx(i_fix_target));
					current_fixation_target_samples_idx = find(fixation_target.by_sample.table(:, FTBS_cn.FixationPointID) == unique_fixation_target_id);
					valid_samples_for_current_fixtargID = intersect(cur_selected_samples_idx, current_fixation_target_samples_idx);
					if ~isempty(valid_samples_for_current_fixtargID)
						% find the sample closest to the current cluster center
						[min_dist, closest_point_idx_idx] = min(euclidean_distance_array(valid_samples_for_current_fixtargID, unique_fixation_target_id));
						cur_selected_samples_pwl_lwm_idx = [cur_selected_samples_pwl_lwm_idx, valid_samples_for_current_fixtargID(closest_point_idx_idx)];
					end
				end
				n_control_points = length(cur_selected_samples_pwl_lwm_idx);

				transformationType_string = transformationType;
				output_degree_string = '';
				switch (transformationType)
					case 'polynomial'
						if (n_control_points < 15) && polynomial_degree == 4
							polynomial_degree = polynomial_degree - 1;
						end
						if (n_control_points < 10) && polynomial_degree == 3
							polynomial_degree = polynomial_degree - 1;
						end
						% for polynomial_degree we need 6 control points but simply fail
						transformationType_string = [transformationType_string, ' (degree: ', num2str(polynomial_degree),')'];
						output_degree_string = ['.', num2str(polynomial_degree)];
						current_tform = fn_fitgeotrans(current_target_selected_samples, current_gaze_samples, transformationType, polynomial_degree);
					case 'pwl'
						current_tform = fn_fitgeotrans(all_target_selected_samples(cur_selected_samples_pwl_lwm_idx, :), all_gaze_selected_samples(cur_selected_samples_pwl_lwm_idx, :), transformationType);
					case 'lwm'
						if 	polynomial_degree > n_control_points
							disp(['Selected number of lwm control points (', num2str(polynomial_degree),') larger than number of control point pairs (', num2str(n_control_points), '). Reducing to ', num2str(n_control_points)]);
							polynomial_degree = n_control_points;
						end
						output_degree_string = ['.', num2str(lwm_N)];
						transformationType_string = [transformationType_string, ' (n: ', num2str(polynomial_degree),')'];
						current_tform = fn_fitgeotrans(all_target_selected_samples(cur_selected_samples_pwl_lwm_idx, :), all_gaze_selected_samples(cur_selected_samples_pwl_lwm_idx, :), transformationType, lwm_N); % polynomial_degree is N
					otherwise
						current_tform = fn_fitgeotrans(current_target_selected_samples, current_gaze_samples, transformationType);
				end

				if ~isempty(current_tform)

					% apply the registration to the whole x y data series
					current_registered_gaze_selected_samples = transformPointsInverse(current_tform, all_gaze_selected_samples);

					% show results
					cur_data_name = current_data_col_name;
					cur_data_name = cur_nonvar_calibration_set_name;
					cur_data_fh = figure('Name', [cur_data_name, ': Re-registration, (', transformationType_string, ')']);
					fnFormatDefaultAxes(DefaultAxesType);
					[output_rect] = fnFormatPaperSize(DefaultPaperSizeType, gcf, output_rect_fraction);
					set(gcf(), 'Units', 'centimeters', 'Position', output_rect, 'PaperPosition', output_rect);

					selected_samples_ah = fn_plot_selected_and_reregistered_samples_over_targets(...
						fixation_target.by_sample.table(cur_calibration_set_ID_row_idx, FTBS_cn.FixationPointX), fn_convert_eventide2_matlab_coord(fixation_target.by_sample.table(cur_calibration_set_ID_row_idx, FTBS_cn.FixationPointY)), cur_selected_samples_idx, target_color_spec, ...
						cal_eventide_gaze_x_list(:), fn_convert_eventide2_matlab_coord(cal_eventide_gaze_y_list(:)), cur_selected_samples_idx, [1 0 0], ...
						current_registered_gaze_selected_samples(:, 1), fn_convert_eventide2_matlab_coord(current_registered_gaze_selected_samples(:, 2)), cur_selected_samples_idx, [0 1 0]);
					title([cur_nonvar_calibration_set_name, '; ', cur_data_name, ': ', transformationType_string], 'Interpreter', 'None', 'FontSize', 12);
					write_out_figure(cur_data_fh, fullfile(gaze_tracker_logfile_path, ['gazeregistration.', tracker_type, '.re-registered.', '.', cur_calibration_set_name, '.', transformationType, output_degree_string, '.', cur_data_name, '.pdf']));
					registration_struct.(transformationType).(cur_data_name).tform = current_tform;
					registration_struct.(transformationType).(cur_data_name).colnames = {cur_X_col_name, cur_Y_col_name};
					registration_struct.(transformationType).(cur_data_name).selected_samples_idx = cur_selected_samples_idx;
					registration_struct.(transformationType).info.cur_calibration_set_name = cur_calibration_set_name;


					switch transformationType
						case 'polynomial'
							registration_struct.(transformationType).(cur_data_name).polynomial_degree = polynomial_degree;
						case 'lwm'
							registration_struct.(transformationType).(cur_data_name).lwm_n_points = polynomial_degree;
							registration_struct.(transformationType).(cur_data_name).cur_selected_samples_pwl_lwm_idx = cur_selected_samples_pwl_lwm_idx;
						case 'pwl'
							registration_struct.(transformationType).(cur_data_name).cur_selected_samples_pwl_lwm_idx = cur_selected_samples_pwl_lwm_idx;
					end

					out_registration_struct.(cur_calibration_set_name).registration_struct = registration_struct;

				end
			end

		end

	end % loop over calibration_set_IDs


	% % construct the output name

	if exist('out_registration_struct', 'var') && exist('registration_struct', 'var')
		% output_mat_filename = ['GAZEREGv02.SID_', sessionID, '.SIDE_', side, '.SUBJECTID_', subject_name, '.', tracker_type, '.TRACKERELEMENTID_', tracker_elementID, '.mat'];
		% save to the current directory
		save(fullfile(gaze_tracker_logfile_path, output_mat_filename), 'registration_struct', 'out_registration_struct');
		% save to the day's directory.
		save(fullfile(gaze_tracker_logfile_path, '..', output_mat_filename), 'registration_struct', 'out_registration_struct');
	else
		disp([mfilename, ': No registration created, nothing to save...']);
	end
end

% how long did it take?
tictoc_timestamp_list.(mfilename).end = toc(tictoc_timestamp_list.(mfilename).start);
disp([mfilename, ' took: ', num2str(tictoc_timestamp_list.(mfilename).end), ' seconds.']);
disp([mfilename, ' took: ', num2str(tictoc_timestamp_list.(mfilename).end / 60), ' minutes. Done...']);

return
end




function [converted_coord_list] = fn_convert_eventide2_matlab_coord(input_coord_list, local_offset, local_scale, direction)
% matlab and eventIDE use different coordinate systems so scale
% the default values work for the Y-axis flip and a 1080 full hd screen
% resoution

% for CCF we do not need to do this, so return the for now, ulyimately
% remove this wrapper...
converted_coord_list = input_coord_list;
return

if ~exist('local_scale', 'var') ||	isempty(local_scale)
	local_scale = -1;
end

if ~exist('local_offset', 'var') ||	isempty(local_offset)
	local_offset = 1080;
end

if ~exist('direction', 'var') || isempty(direction)
	direction = 'forward';
end

% note forward and inverse are the identical operation
switch (direction)
	case 'forward'
		converted_coord_list = (input_coord_list * local_scale) + local_offset;
	case {'inverse', 'backward'}
		converted_coord_list = (input_coord_list - local_offset) ./ local_scale;
	otherwise
		error(['Unknown direction (', direction, ') encountered, only forward and inverse are defined.']);
end

return
end


function [robust_mean] = fn_robust_mean(value_list, outlier_fraction)
% get the mean of a value list after removing the outlier_fraction part of
% the smallest and largest values, as well as ignoring NaNs, in case of
% singleton inputs simply return that value

if ~exist('outlier_fraction', 'var') || isempty(outlier_fraction)
	outlier_fraction = 0.05;
end

% this is not fully ideal, but allows to use this function to clean up
% things
if (length(value_list) == 1)
	robust_mean = value_list;
	return
end

% remove any eventual NaNs
nan_lidx = isnan(value_list);
value_list = value_list(~nan_lidx);

if isempty(value_list)
	error('No non-NaN values in value_list.');
end

% sort to allow removal of the extremes
sorted_value_list = sort(value_list);
n_values = length(sorted_value_list);

low_cutoff_idx = round(outlier_fraction * n_values);
high_cutoff_idx = n_values - low_cutoff_idx;

if low_cutoff_idx < high_cutoff_idx
	robust_mean = mean(sorted_value_list(low_cutoff_idx+1:high_cutoff_idx-1));
end

if low_cutoff_idx >= high_cutoff_idx
	% return the central value
	robust_mean = sorted_value_list(round(n_values/2));
end

return
end

function [columnnames_struct, n_fields] = local_get_column_name_indices(name_list, start_val)
% return a structure with each field for each member if the name_list cell
% array, giving the position in the name_list, then the columnnames_struct
% can serve as to address the columns, so the functions assigning values
% to the columns do not have to care too much about the positions, and it
% becomes easy to add fields.
% name_list: cell array of string names for the fields to be added
% start_val: numerical value to start the field values with (if empty start
%            with 1 so the results are valid indices into name_list)

if nargin < 2
	start_val = 1;  % value of the first field
end
n_fields = length(name_list);
for i_col = 1 : length(name_list)
	cur_name = name_list{i_col};
	% skip empty names, this allows non consequtive numberings
	if ~isempty(cur_name)
		columnnames_struct.(cur_name) = i_col + (start_val - 1);
	end
end
return
end


function [ ] = fnFormatDefaultAxes( type )
%FNFORMATDEFAULTAXES Set default font and fontsize and line width for all
%axes
%FORMAT_DEFAULT format the plots for further processing...
%   type is simple a unique string to select the requested set
% 20070827sm: changed default output formatting to allow pretty paper output
switch type
	case 'PNM2019'
		set(0, 'DefaultAxesLineWidth', 0.5, 'DefaultAxesFontName', 'Arial', 'DefaultAxesFontSize', 12, 'DefaultAxesFontWeight', 'normal');
	case 'BoS_manuscript'
		set(0, 'DefaultAxesLineWidth', 0.5, 'DefaultAxesFontName', 'Arial', 'DefaultAxesFontSize', 6, 'DefaultAxesFontWeight', 'normal');
	case 'SfN2018'
		set(0, 'DefaultAxesLineWidth', 0.5, 'DefaultAxesFontName', 'Arial', 'DefaultAxesFontSize', 6, 'DefaultAxesFontWeight', 'normal');
	case 'PrimateNeurobiology2018DPZ'
		set(0, 'DefaultAxesLineWidth', 2.0, 'DefaultAxesFontName', 'Arial', 'DefaultAxesFontSize', 20, 'DefaultAxesFontWeight', 'bold');
	case 'DPZ2017Evaluation'
		set(0, 'DefaultAxesLineWidth', 2.0, 'DefaultAxesFontName', 'Arial', 'DefaultAxesFontSize', 20, 'DefaultAxesFontWeight', 'bold');
	case '16to9slides'
		set(0, 'DefaultAxesLineWidth', 1.5, 'DefaultAxesFontName', 'Helvetica', 'DefaultAxesFontSize', 24, 'DefaultAxesFontWeight', 'bold');
	case 'fp_paper'
		set(0, 'DefaultAxesLineWidth', 1.5, 'DefaultAxesFontName', 'Helvetica', 'DefaultAxesFontSize', 8, 'DefaultAxesFontWeight', 'bold');
	case 'sfn_poster'
		set(0, 'DefaultAxesLineWidth', 2.0, 'DefaultAxesFontName', 'Helvetica', 'DefaultAxesFontSize', 24, 'DefaultAxesFontWeight', 'bold');
	case {'sfn_poster_2011', 'sfn_poster_2012', 'sfn_poster_2013'}
		set(0, 'DefaultAxesLineWidth', 2.0, 'DefaultAxesFontName', 'Helvetica', 'DefaultAxesFontSize', 18, 'DefaultAxesFontWeight', 'bold');
	case '20120519'
		set(0, 'DefaultAxesLineWidth', 2.0, 'DefaultAxesFontName', 'Helvetica', 'DefaultAxesFontSize', 12, 'DefaultAxesFontWeight', 'bold');
	case 'ms13_paper'
		set(0, 'DefaultAxesLineWidth', 1.5, 'DefaultAxesFontName', 'Helvetica', 'DefaultAxesFontSize', 8, 'DefaultAxesFontWeight', 'bold');
	case 'ms13_paper_unitdata'
		set(0, 'DefaultAxesLineWidth', 1.5, 'DefaultAxesFontName', 'Helvetica', 'DefaultAxesFontSize', 8, 'DefaultAxesFontWeight', 'bold');
	otherwise
		%set(0, 'DefaultAxesLineWidth', 4, 'DefaultAxesFontName', 'Helvetica', 'DefaultAxesFontSize', 24, 'DefaultAxesFontWeight', 'bold');
end

return
end


function [ output_rect ] = fnFormatPaperSize( type, gcf_h, fraction, do_center_in_paper )
%FNFORMATPAPERSIZE Set the paper size for a plot, also return a reasonably
%tight output_rect.
% 20070827sm: changed default output formatting to allow pretty paper output
% Example usage:
%     Cur_fh = figure('Name', 'Test');
%     fnFormatDefaultAxes('16to9slides');
%     [output_rect] = fnFormatPaperSize('16to9landscape', gcf);
%     set(gcf(), 'Units', 'centimeters', 'Position', output_rect);


if nargin < 3
	fraction = 1;	% fractional columns?
end
if nargin < 4
	do_center_in_paper = 0;	% center the rectangle in the page
end


nature_single_col_width_cm = 8.9;
nature_double_col_width_cm = 18.3;
nature_full_page_width_cm = 24.7;

A4_w_cm = 21.0;
A4_h_cm = 29.7;
% defaults
left_edge_cm = 1;
bottom_edge_cm = 2;

switch type
	
	case {'BoS_manuscript.5'}
		left_edge_cm = 0.05;
		bottom_edge_cm = 0.05;
		dpz_column_width_cm = 38.6 * 0.5 * 0.8;   % the columns are 38.6271mm, but the imported pdf in illustrator are too large (0.395)
		rect_w = (dpz_column_width_cm - 2*left_edge_cm) * fraction;
		rect_h = ((dpz_column_width_cm * 610/987) - 2*bottom_edge_cm) * fraction; % 610/987 approximates the golden ratio
		% configure the format PaperPositon [left bottom width height]
		if (do_center_in_paper)
			left_edge_cm = (A4_w_cm - rect_w) * 0.5;
			bottom_edge_cm = (A4_h_cm - rect_h) * 0.5;
		end
		output_rect = [left_edge_cm bottom_edge_cm rect_w rect_h];	% left, bottom, width, height
		set(gcf_h, 'PaperSize', [rect_w+2*left_edge_cm*fraction rect_h+2*bottom_edge_cm*fraction], 'PaperOrientation', 'portrait', 'PaperUnits', 'centimeters');
		
	case {'PrimateNeurobiology2018DPZ0.5', 'SfN2018.5'}
		left_edge_cm = 0.05;
		bottom_edge_cm = 0.05;
		dpz_column_width_cm = 38.6 * 0.5 * 0.8;   % the columns are 38.6271mm, but the imported pdf in illustrator are too large (0.395)
		rect_w = (dpz_column_width_cm - 2*left_edge_cm) * fraction;
		rect_h = ((dpz_column_width_cm * 610/987) - 2*bottom_edge_cm) * fraction; % 610/987 approximates the golden ratio
		% configure the format PaperPositon [left bottom width height]
		if (do_center_in_paper)
			left_edge_cm = (A4_w_cm - rect_w) * 0.5;
			bottom_edge_cm = (A4_h_cm - rect_h) * 0.5;
		end
		output_rect = [left_edge_cm bottom_edge_cm rect_w rect_h];	% left, bottom, width, height
		set(gcf_h, 'PaperSize', [rect_w+2*left_edge_cm*fraction rect_h+2*bottom_edge_cm*fraction], 'PaperOrientation', 'portrait', 'PaperUnits', 'centimeters');
		
	case 'PrimateNeurobiology2018DPZ'
		left_edge_cm = 0.05;
		bottom_edge_cm = 0.05;
		dpz_column_width_cm = 38.6 * 0.8;   % the columns are 38.6271mm, but the imported pdf in illustrator are too large (0.395)
		rect_w = (dpz_column_width_cm - 2*left_edge_cm) * fraction;
		rect_h = ((dpz_column_width_cm * 610/987) - 2*bottom_edge_cm) * fraction; % 610/987 approximates the golden ratio
		% configure the format PaperPositon [left bottom width height]
		if (do_center_in_paper)
			left_edge_cm = (A4_w_cm - rect_w) * 0.5;
			bottom_edge_cm = (A4_h_cm - rect_h) * 0.5;
		end
		output_rect = [left_edge_cm bottom_edge_cm rect_w rect_h];	% left, bottom, width, height
		set(gcf_h, 'PaperSize', [rect_w+2*left_edge_cm*fraction rect_h+2*bottom_edge_cm*fraction], 'PaperOrientation', 'portrait', 'PaperUnits', 'centimeters');
		
	case 'DPZ2017Evaluation'
		left_edge_cm = 0.05;
		bottom_edge_cm = 0.05;
		dpz_column_width_cm = 34.7 * 0.8;   % the columns are 347, 350, 347 mm, but the imported pdf in illustrator are too large (0.395)
		rect_w = (dpz_column_width_cm - 2*left_edge_cm) * fraction;
		rect_h = ((dpz_column_width_cm * 610/987) - 2*bottom_edge_cm) * fraction; % 610/987 approximates the golden ratio
		% configure the format PaperPositon [left bottom width height]
		if (do_center_in_paper)
			left_edge_cm = (A4_w_cm - rect_w) * 0.5;
			bottom_edge_cm = (A4_h_cm - rect_h) * 0.5;
		end
		output_rect = [left_edge_cm bottom_edge_cm rect_w rect_h];	% left, bottom, width, height
		set(gcf_h, 'PaperSize', [rect_w+2*left_edge_cm*fraction rect_h+2*bottom_edge_cm*fraction], 'PaperOrientation', 'portrait', 'PaperUnits', 'centimeters');
		
	case '16to9portrait'
		left_edge_cm = 1;
		bottom_edge_cm = 1;
		rect_w = (9 - 2*left_edge_cm) * fraction;
		rect_h = (16 - 2*bottom_edge_cm) * fraction;
		% configure the format PaperPositon [left bottom width height]
		if (do_center_in_paper)
			left_edge_cm = (A4_w_cm - rect_w) * 0.5;
			bottom_edge_cm = (A4_h_cm - rect_h) * 0.5;
		end
		output_rect = [left_edge_cm bottom_edge_cm rect_w rect_h];	% left, bottom, width, height
		set(gcf_h, 'PaperSize', [rect_w+2*left_edge_cm rect_h+2*bottom_edge_cm], 'PaperOrientation', 'landscape', 'PaperUnits', 'centimeters');
		
	case '16to9landscape'
		left_edge_cm = 1;
		bottom_edge_cm = 1;
		rect_w = (16 - 2*left_edge_cm) * fraction;
		rect_h = (9 - 2*bottom_edge_cm) * fraction;
		% configure the format PaperPositon [left bottom width height]
		if (do_center_in_paper)
			left_edge_cm = (A4_w_cm - rect_w) * 0.5;
			bottom_edge_cm = (A4_h_cm - rect_h) * 0.5;
		end
		output_rect = [left_edge_cm bottom_edge_cm rect_w rect_h];	% left, bottom, width, height
		set(gcf_h, 'PaperSize', [rect_w+2*left_edge_cm rect_h+2*bottom_edge_cm], 'PaperOrientation', 'portrait', 'PaperUnits', 'centimeters');
		
	case 'ms13_paper'
		rect_w = nature_single_col_width_cm * fraction;
		rect_h = nature_single_col_width_cm * fraction;
		% configure the format PaperPositon [left bottom width height]
		if (do_center_in_paper)
			left_edge_cm = (A4_w_cm - rect_w) * 0.5;
			bottom_edge_cm = (A4_h_cm - rect_h) * 0.5;
		end
		output_rect = [left_edge_cm bottom_edge_cm rect_w rect_h];	% left, bottom, width, height
		%set(gcf_h, 'PaperType', 'A4', 'PaperOrientation', 'portrait', 'PaperUnits', 'centimeters', 'PaperPosition', output_rect);
		% try to manage plots better
		set(gcf_h, 'PaperSize', [rect_w rect_h], 'PaperOrientation', 'portrait', 'PaperUnits', 'centimeters');
		
	case 'ms13_paper_unitdata'
		rect_w = nature_single_col_width_cm * fraction;
		rect_h = nature_single_col_width_cm * fraction;
		% configure the format PaperPositon [left bottom width height]
		if (do_center_in_paper)
			left_edge_cm = (A4_w_cm - rect_w) * 0.5;
			bottom_edge_cm = (A4_h_cm - rect_h) * 0.5;
		end
		output_rect = [left_edge_cm bottom_edge_cm rect_w rect_h];	% left, bottom, width, height
		% configure the format PaperPositon [left bottom width height]
		%set(gcf_h, 'PaperType', 'A4', 'PaperOrientation', 'portrait', 'PaperUnits', 'centimeters', 'PaperPosition', output_rect);
		set(gcf_h, 'PaperSize', [rect_w rect_h], 'PaperOrientation', 'portrait', 'PaperUnits', 'centimeters');
		
	case 'ms13_paper_unitdata_halfheight'
		rect_w = nature_single_col_width_cm * fraction;
		rect_h = nature_single_col_width_cm * fraction * 0.5;
		% configure the format PaperPositon [left bottom width height]
		if (do_center_in_paper)
			left_edge_cm = (A4_w_cm - rect_w) * 0.5;
			bottom_edge_cm = (A4_h_cm - rect_h) * 0.5;
		end
		output_rect = [left_edge_cm bottom_edge_cm rect_w rect_h];	% left, bottom, width, height
		% configure the format PaperPositon [left bottom width height]
		%set(gcf_h, 'PaperType', 'A4', 'PaperOrientation', 'portrait', 'PaperUnits', 'centimeters', 'PaperPosition', output_rect);
		set(gcf_h, 'PaperSize', [rect_w rect_h], 'PaperOrientation', 'portrait', 'PaperUnits', 'centimeters');
		
		
	case 'fp_paper'
		rect_w = 4.5 * fraction;
		rect_h = 1.835 * fraction;
		% configure the format PaperPositon [left bottom width height]
		if (do_center_in_paper)
			left_edge_cm = (A4_w_cm - rect_w) * 0.5;
			bottom_edge_cm = (A4_h_cm - rect_h) * 0.5;
		end
		output_rect = [left_edge_cm bottom_edge_cm rect_w rect_h];	% left, bottom, width, height
		% configure the format PaperPositon [left bottom width height]
		set(gcf_h, 'PaperType', 'A4', 'PaperOrientation', 'portrait', 'PaperUnits', 'centimeters', 'PaperPosition', output_rect);
		
	case 'sfn_poster'
		rect_w = 27.7 * fraction;
		rect_h = 12.0 * fraction;
		% configure the format PaperPositon [left bottom width height]
		if (do_center_in_paper)
			left_edge_cm = (A4_h_cm - rect_w) * 0.5;	% landscape!
			bottom_edge_cm = (A4_w_cm - rect_h) * 0.5;	% landscape!
		end
		output_rect = [left_edge_cm bottom_edge_cm rect_w rect_h];	% left, bottom, width, height
		%output_rect = [1.0 2.0 27.7 12.0];	% full width
		% configure the format PaperPositon [left bottom width height]
		set(gcf_h, 'PaperType', 'A4', 'PaperOrientation', 'landscape', 'PaperUnits', 'centimeters', 'PaperPosition', output_rect);
		
	case 'sfn_poster_0.5'
		output_rect = [1.0 2.0 (25.9/2) 8.0];	% half width
		output_rect = [1.0 2.0 11.0 10.0];	% height was (25.9/2)
		% configure the format PaperPositon [left bottom width height]
		%set(gcf_h, 'PaperType', 'usletter', 'PaperOrientation', 'landscape', 'PaperUnits', 'centimeters', 'PaperPosition', output_rect);
		set(gcf_h, 'PaperType', 'usletter', 'PaperOrientation', 'portrait', 'PaperUnits', 'centimeters', 'PaperPosition', output_rect);
		
	case 'sfn_poster_0.5_2012'
		output_rect = [1.0 2.0 (25.9/2) 8.0];	% half width
		output_rect = [1.0 2.0 11.0 9.0];	% height was (25.9/2)
		% configure the format PaperPositon [left bottom width height]
		%set(gcf_h, 'PaperType', 'usletter', 'PaperOrientation', 'landscape', 'PaperUnits', 'centimeters', 'PaperPosition', output_rect);
		set(gcf_h, 'PaperType', 'usletter', 'PaperOrientation', 'portrait', 'PaperUnits', 'centimeters', 'PaperPosition', output_rect);
		
	case 'europe'
		output_rect = [1.0 2.0 27.7 12.0];
		set(gcf_h, 'PaperType', 'A4', 'PaperOrientation', 'landscape', 'PaperUnits', 'centimeters', 'PaperPosition', output_rect);
		
	case 'europe_portrait'
		output_rect = [1.0 2.0 20.0 27.7];
		set(gcf_h, 'PaperType', 'A4', 'PaperOrientation', 'portrait', 'PaperUnits', 'centimeters', 'PaperPosition', output_rect);
		
	case 'default'
		% letter 8.5 x 11 ", or 215.9 mm ? 279.4 mm
		output_rect = [1.0 2.0 19.59 25.94];
		set(gcf_h, 'PaperType', 'usletter', 'PaperOrientation', 'landscape', 'PaperUnits', 'centimeters', 'PaperPosition', output_rect);
		
	case 'default_portrait'
		output_rect = [1.0 2.0 25.94 19.59];
		set(gcf_h, 'PaperType', 'usletter', 'PaperOrientation', 'portrait', 'PaperUnits', 'centimeters', 'PaperPosition', output_rect);
		
	otherwise
		output_rect = [1.0 2.0 25.9 12.0];
		set(gcf_h, 'PaperType', 'usletter', 'PaperOrientation', 'landscape', 'PaperUnits', 'centimeters', 'PaperPosition', output_rect);
		
end

return
end


function [ cur_ah ] = fn_plot_selected_samples_over_targets( target_x_list, target_y_list, valid_target_idx, target_color_spec, sample_x_list, sample_y_list, valid_sample_idx, sample_color_spec )

target_ah = plot(target_x_list(valid_target_idx), target_y_list(valid_target_idx), 'Color', target_color_spec, 'LineWidth', 3, 'LineStyle', 'None', 'Marker', '+', 'MarkerSize', 10);
hold on
sample_ah = plot(sample_x_list(valid_sample_idx), sample_y_list(valid_sample_idx), 'Color', sample_color_spec, 'LineWidth', 3, 'LineStyle', 'None', 'Marker', '.', 'MarkerSize', 2);
%top_target_ah = plot(target_x_list(valid_target_idx), target_y_list(valid_target_idx), 'Color', target_color_spec, 'LineWidth', 3, 'LineStyle', 'None', 'Marker', '+', 'MarkerSize', 10);
hold off
%alpha(top_target_ah, 0.33);
cur_ah = gca();

return
end


function [ cur_ah ] = fn_plot_selected_and_reregistered_samples_over_targets( target_x_list, target_y_list, valid_target_idx, target_color_spec, sample_x_list, sample_y_list, valid_sample_idx, sample_color_spec, reg_sample_x_list, reg_sample_y_list, reg_valid_sample_idx, reg_sample_color_spec )

target_ah = plot(target_x_list(valid_target_idx), target_y_list(valid_target_idx), 'Color', target_color_spec, 'LineWidth', 1, 'LineStyle', 'None', 'Marker', '+', 'MarkerSize', 20);
hold on
sample_ah = plot(sample_x_list(valid_sample_idx), sample_y_list(valid_sample_idx), 'Color', sample_color_spec, 'LineWidth', 2, 'LineStyle', 'None', 'Marker', '.', 'MarkerSize', 2);
reg_sample_ah = plot(reg_sample_x_list(reg_valid_sample_idx), reg_sample_y_list(reg_valid_sample_idx), 'Color', reg_sample_color_spec, 'LineWidth', 3, 'LineStyle', 'None', 'Marker', '.', 'MarkerSize', 2);

%top_target_ah = plot(target_x_list(valid_target_idx), target_y_list(valid_target_idx), 'Color', target_color_spec, 'LineWidth', 3, 'LineStyle', 'None', 'Marker', '+', 'MarkerSize', 10);
hold off
%alpha(top_target_ah, 0.33);
cur_ah = gca();

return
end


function [ tform ] = fn_fitgeotrans(fixed_points, moving_points, transformationType, polynomial_degree)
tform = [];

% some transformationType require non-colinear points so try by catch
% failures gracefully, we simply ignore such transformationTypes
try
	if (nargin == 3)
		tform = fitgeotrans(fixed_points, moving_points, transformationType);
	end
	if (nargin == 4)
		tform = fitgeotrans(fixed_points, moving_points, transformationType, polynomial_degree);
	end
catch ME
	disp(ME);
	tform = [];
	disp('tform invalid, returning empty tform.');
end

return
end


function [ sessionID ] = fn_get_sessionID_from_SCP_path(gaze_tracker_logfile_FQN, session_marker_string)
sessionID = [];

% early out
if isempty(regexp(gaze_tracker_logfile_FQN, session_marker_string))
	error(['Could not extract the sessionID from: ', gaze_tracker_logfile_FQN]);
	return
end

% start
[cur_path, cur_name, cur_ext] = fileparts(gaze_tracker_logfile_FQN);

% just traverse the path from the back and return the name that contains
% the session_marker_string
while ~isempty(cur_path)
	if strcmp(cur_ext, session_marker_string)
		sessionID = cur_name;
		return
	end
	% next round
	[cur_path, cur_name, cur_ext] = fileparts(cur_path);
end

return
end


function [ side, trackerID_string ] = fn_get_side_from_tracker_logfile_name(gaze_tracker_logfile_FQN)
side = [];
trackerID_string = [];
[ ~, name, ~] = fileparts(gaze_tracker_logfile_FQN);

identifier_list = {'EyeLinkTrackerA', 'EyeLinkProxyTrackerA', 'PupilLabsTrackerA', 'PupilLabsTrackerB', 'EyeLinkProxyTrackerB'};
side_list = {'A', 'A', 'A', 'B', 'B'};

for i_identifier = 1 : length(identifier_list)
	cur_identifier = identifier_list{i_identifier};
	if ~isempty(regexp(name, cur_identifier))
		side = side_list{i_identifier};
		trackerID_string = cur_identifier;
	end
end


if isempty(side)
	error('Fix me, just add the tracker identifier to identifier_list');
end

return
end

function [ subject_name ] = fn_get_subject_name_for_side(sessionID, side)
subject_name = [];
dot_idx = find(sessionID == '.');

subject_side_prefix = ['.', side, '_'];

anchor_idx = regexp(sessionID, subject_side_prefix);

if ~isempty(anchor_idx)
	next_dot_idx = find(dot_idx > anchor_idx);
	next_dot_idx = next_dot_idx(1);
	subject_name = sessionID(anchor_idx+3:dot_idx(next_dot_idx) -1);
end

return
end


function [ cal_eventide_gaze_x_list ] = fn_calc_and_apply_gain_and_offset_adjustments_between_vectors( ref_space_vector, ref_space_range, mov_space_vector, mov_space_range, gain_off_set_calibration_FQN )
cal_eventide_gaze_x_list = [];

% this uses the regular alignment of the fixation dots to figure out the
% gain and offset refquired to translate between reference and mov(able)
% space

%TODO, find all XY fix pairs and look at the distributions of only those
%fixation samples for each pair individually, resulting in sets in which
%each histogram should only have a single peak each, then feed these
%point combinations through an affine alignment?




figure('Name', '1D alignment');
fix_ah = subplot(2, 1, 1);
% the fixation dor positions
[N_fix, fix_edges, fix_bin] = histcounts(ref_space_vector, (ref_space_range(1):1:ref_space_range(2)));
fix_bin_center_list = fix_edges(1:end-1) + diff(fix_edges)*0.5;
fix_h = plot(fix_bin_center_list, N_fix);
hold on

[fix_pks, fix_locs, fix_w, fix_p] = findpeaks(N_fix, fix_bin_center_list);
findpeaks(N_fix, fix_bin_center_list);
fix_h = plot(fix_bin_center_list, N_fix);
fix_y_lim = get(fix_ah, 'YLim');
hold off
%gain_off_set_calibration_FQN =


mov_ah = subplot(2, 1, 2);
% the gaze positions
% mov_space_range(1) = min(mov_space_vector);
% mov_space_range(2) = max(mov_space_vector);
mov_space_spacing = diff(mov_space_range) / ((ref_space_range(2) - ref_space_range(1)) / 1);
[N_mov1, mov_edges1, bin] = histcounts(mov_space_vector, (mov_space_range(1):mov_space_spacing:mov_space_range(2)));
mov_bin_center_list1 = mov_edges1(1:end-1) + diff(mov_edges1)*0.5;
mov_h1 = plot(mov_bin_center_list1, N_mov1);
mov_y_lim1 = get(mov_ah, 'YLim');

hold on


mov_space_spacing = diff(mov_space_range) / ((ref_space_range(2) - ref_space_range(1)) / 32);
[N_mov, mov_edges, bin] = histcounts(mov_space_vector, (mov_space_range(1):mov_space_spacing:mov_space_range(2)));
mov_bin_center_list = mov_edges(1:end-1) + diff(mov_edges)*0.5;
mov_h = plot(mov_bin_center_list, N_mov);
mov_y_lim = get(mov_ah, 'YLim');

[mov_pks, mov_locs, mov_w, mov_p] = findpeaks(N_mov, mov_bin_center_list);

findpeaks(N_mov, mov_bin_center_list);
mov_h = plot(mov_bin_center_list1, N_mov1 * (mov_y_lim(2)/mov_y_lim1(2)));
mov_y_lim = get(mov_ah, 'YLim');
hold off;



% get the mov_locs from the lenght(fix_pks) highest peaks from mov_pks
[sorted_mov_peak_heights, sort_idx] = sort(mov_pks);
threshold_height = sorted_mov_peak_heights(end-2);

highest_N_peak_locs_idx = find(mov_pks >= threshold_height);

sorted_mov_peak_locs = mov_locs(highest_N_peak_locs_idx);
proto_matched_mov_locs = sorted_mov_peak_locs(1:length(fix_pks));
proto_matched_fix_locs = fix_locs(1:length(fix_pks));


colors = lines;
for i_peak = 1 : length(fix_pks)
	hold(fix_ah, 'on');
	plot(fix_ah, [fix_locs(i_peak), fix_locs(i_peak)], fix_y_lim, 'Color', colors(i_peak, :));
	hold(fix_ah, 'off');
	hold(mov_ah, 'on');
	plot(mov_ah, [sorted_mov_peak_locs(i_peak), sorted_mov_peak_locs(i_peak)], mov_y_lim, 'Color', colors(i_peak, :));
	hold(mov_ah, 'off');
	
end

% now find the best offset and gain to transform


return
end



function [] = fn_select_n_points_from_axis( num_points, axis_handle, gain_off_set_calibration_FQN)
% see whether points already exist?
if exist(gain_off_set_calibration_FQN, 'file')
	load(gain_off_set_calibration_FQN);
else
	% pre allocate
	x_y_mouse_y_flipped = nan([length(nonzero_unique_fixation_target_idx), 2]);
end
% manually select all cluster centers
for i_fix_target = 1 : length(find(unique_fixation_targets))
	unique_fixation_target_id = unique_fixation_targets(nonzero_unique_fixation_target_idx(i_fix_target));
	
	title(['Select the center of the gaze sample cloud belonging to fixzation target ', num2str(unique_fixation_target_id), ', press enter after selection. (use delete to erase)'], 'FontSize', 14);
	plot(fixation_target_position_table(unique_fixation_target_id, 1), fn_convert_eventide2_matlab_coord(fixation_target_position_table(unique_fixation_target_id, 2)), 'LineWidth', 2, 'LineStyle', 'none', 'Color', 'r', 'Marker', '+', 'Markersize', 10);
	
	% if there is a stored cluster center for this fixation target, display
	% this
	if ~isnan(x_y_mouse_y_flipped(i_fix_target, 1)) || ~isnan(x_y_mouse_y_flipped(i_fix_target, 2))
		plot(x_y_mouse_y_flipped(i_fix_target, 1), x_y_mouse_y_flipped(i_fix_target, 2), 'LineWidth', 2, 'LineStyle', 'none', 'Color', [0 0 0.5], 'Marker', '+', 'Markersize', 10);
		stored_tmp_x_list = x_y_mouse_y_flipped(i_fix_target, 1);
		stored_tmp_y_list = x_y_mouse_y_flipped(i_fix_target, 2);
	else
		stored_tmp_x_list = [];
		stored_tmp_y_list = [];
	end
	% select a new cluster center
	[tmp_x_list, tmp_y_list]= getpts;
	if isempty(tmp_x_list)
		tmp_x_list = NaN;
		tmp_y_list = NaN;
		% keep the stored points if the user did not select new valid
		% points
		if ~isempty(stored_tmp_x_list)
			tmp_x_list = stored_tmp_x_list;
		end
		if ~isempty(stored_tmp_y_list)
			tmp_y_list = stored_tmp_y_list;
		end
	end
	
	% getpts returns matlab coordinates, indicate that with the _flipped
	% suffix
	x_y_mouse_y_flipped(i_fix_target, 1) = tmp_x_list(end);
	x_y_mouse_y_flipped(i_fix_target, 2) = tmp_y_list(end);
	
	if ~isnan(tmp_x_list(end)) && ~isnan(tmp_y_list(end))
		
		plot(fixation_target_position_table(unique_fixation_target_id, 1), fn_convert_eventide2_matlab_coord(fixation_target_position_table(unique_fixation_target_id, 2)), 'LineWidth', 2, 'LineStyle', 'none', 'Color', [0.8 0 0], 'Marker', '+', 'Markersize', 10);
		plot(x_y_mouse_y_flipped(i_fix_target, 1), x_y_mouse_y_flipped(i_fix_target, 2), 'LineWidth', 2, 'LineStyle', 'none', 'Color', cluster_center_color, 'Marker', 'x', 'Markersize', 10);
		% show the
		tmp_radius = acceptable_radius_pix;
		tmp_diameter = 2 * tmp_radius;
		rectangle('Position',[x_y_mouse_y_flipped(i_fix_target, 1)-tmp_radius x_y_mouse_y_flipped(i_fix_target, 2)-tmp_radius tmp_diameter tmp_diameter],'Curvature',[1,1], 'EdgeColor', cluster_center_color, 'LineWidth', 1);
		%daspect([1,1,1])
	else
		disp(['No (valid) coordinates selected for the last target position (', num2str(unique_fixation_target_id), ')']);
	end
end

save(gain_off_set_calibration_FQN, 'x_y_mouse_y_flipped');

return
end
