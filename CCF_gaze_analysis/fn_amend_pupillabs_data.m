function [ out_pupillabs_struct ] = fn_amend_pupillabs_data( in_pupillabs_struct, cur_CCF_runfolder_FQN, CCF_conf, sessionID_struct, request_list, GAZE_OPTS_struct)
%FN_AMEND_PUPILLABS_DATA Summary of this function goes here
%   Detailed explanation goes here

timestamps.(mfilename).start = tic;
disp(['Starting: ', mfilename]);
dbstop if error
fq_mfilename = mfilename('fullpath');


if ~exist('GAZE_OPTS_struct', 'var') || isempty(GAZE_OPTS_struct)
	%GAZE_OPTS_struct.per_session_resultdir_FQD = fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', 'per_session_data_collection', 'GAZE_TOUCH');	% where to store the per session results in addition to the local storage, keep empty to ignore
	%GAZE_OPTS_struct.GAZE_PETH_subdir_name = 'GAZE_TOUCH'; % relative to a session dir
	%GAZE_OPTS_struct.requested_processings_list = {'PETH'};	% PETH or TBD full trace
	%GAZE_OPTS_struct.GAZE_data_prefix = 'BINOCCULAR_RAW_resampled_registered_';	% which data to operate on RIGHT_EYE_RAW_resampled_registered_, LEFT_EYE_RAW_resampled_registered_
	GAZE_OPTS_struct.fixation_detection_method = 'iDT';	% % following Salvucci, Goldberg (2000), only iDT implemented yet (PETH data are already iVT processed with coarse limt of 50 DVA(second
	GAZE_OPTS_struct.show_fixation_detection = 0;		% show the detected fixations
	GAZE_OPTS_struct.iDT.max_dispersion_threshold_pixel = 20;	% how much dispersion will we accept, iin pixel
	GAZE_OPTS_struct.iDT.max_dispersion_threshold_dva = 2.0;	% how much dispersion will we accept, in DVA, diameter of a gaze permission disc

	GAZE_OPTS_struct.iDT.min_duration_threshold_ms = 80;	% how long does a proto fixation need to last to be considered a true fixation?
	GAZE_OPTS_struct.eye2screen_mm = 350;% for NHP 35cm
	GAZE_OPTS_struct.pixel_size_mm = ((1209.4/1920) + (680.4/1080)) * 0.5;% for the OLED screen the pixels are slight asymmetric
	GAZE_OPTS_struct.simple_pix2dva_factor = atand((GAZE_OPTS_struct.pixel_size_mm) / (GAZE_OPTS_struct.eye2screen_mm));

	%GAZE_OPTS_struct.last_pre_event_fix.require_straddling_event = 1;	% this is needed to clean up the pre_event window, so we require the pre_event fixation to span o/over the respective event
	%GAZE_OPTS_struct.last_pre_event_fix.min_pre_event_offset_ms = -50;	% for the pre event fixation, how close to the event the fixation needs to end
	%GAZE_OPTS_struct.first_post_event_fix.max_post_event_onset_ms = 250;	% for the post event fixation
	%GAZE_OPTS_struct.pre_event_window = [-400, 0];	% for raw averaging of fixation location, or for selectng the window for fixation to target detection
	%GAZE_OPTS_struct.post_event_window = [0, 400];	% for raw averaging of fixation location
	%GAZE_OPTS_struct.target_fixation_max_allowed_distance_dva = 4;	% how far away from a target (S or O) a fixation is acceptable
	%GAZE_OPTS_struct.target_fixation_max_allowed_distance_pixel = 40;


	GAZE_OPTS_struct.report_unit = 'pixel';% pixel or dva
	GAZE_OPTS_struct.report_unit = 'dva';% pixel or dva

	% calibration data for SCP01
	GAZE_OPTS_struct.NHP.A.eye2srceen_distance_mm = 350;
	GAZE_OPTS_struct.NHP.B.eye2srceen_distance_mm = 350;
	GAZE_OPTS_struct.HP.A.eye2srceen_distance_mm = 500;
	GAZE_OPTS_struct.HP.B.eye2srceen_distance_mm = 500;
	GAZE_OPTS_struct.NHP.A.x_screen_intereye_pix = 960;				% with ~6cm inter pupil distance for human, this would be 3cm num2str(960 + (30 * 1920/1209.4)) = 1007.6269 or 912.3731, and for monkeys ~3.5cm inter pupil distance:  num2str(960 + (35/2 * 1920/1209.4)) 987.7824 or 932.2176
	GAZE_OPTS_struct.NHP.A.y_screen_clostest2eye_pix = 341.27;		% with ~6cm inter pupil distance for human, this would be 3cm num2str(960 + (30 * 1920/1209.4)) = 1007.6269 or 912.3731, and for monkeys ~3.5cm inter pupil distance:  num2str(960 + (35/2 * 1920/1209.4)) 987.7824 or 932.2176
	GAZE_OPTS_struct.NHP.B.x_screen_intereye_pix = 960;				% the screen pixel coordinate of where the binoccular (head) gaze axis meets the screen
	GAZE_OPTS_struct.NHP.B.y_screen_clostest2eye_pix = 341.27;		% the screen pixel coordinate of the eye
	GAZE_OPTS_struct.HP.A.x_screen_intereye_pix = 960;
	GAZE_OPTS_struct.HP.A.y_screen_clostest2eye_pix = 341.27;
	GAZE_OPTS_struct.HP.B.x_screen_intereye_pix = 960;				% the screen pixel coordinate of the eye
	GAZE_OPTS_struct.HP.B.y_screen_clostest2eye_pix = 341.27;		% the screen pixel coordinate of the eye
	GAZE_OPTS_struct.NHP.inter_pupillary_distance_mm = 35;			% see https://www.sciencedirect.com/science/article/pii/S0165027019301591 other reports are 25-35mm
	GAZE_OPTS_struct.HP.inter_pupillary_distance_mm = 63;			% see https://en.wikipedia.org/wiki/Pupillary_distance
	GAZE_OPTS_struct.x_center_pix = 960;							% the virtual gaze center in X pixels
	GAZE_OPTS_struct.y_center_pix = 580;							% the virtual gaze center in Y pixels

	% which fixation types to export
	%GAZE_OPTS_struct.PETH.fixation_type_set_list = {'last_pre_event_fix', 'first_post_event_fix', 'pre_S_sacc2targ_fix', 'post_S_sacc2targ_fix', 'pre_O_sacc2targ_fix', 'post_O_sacc2targ_fix'};

end



gaze_subtable_list = fieldnames(in_pupillabs_struct);

% potentioally make this configurable as argument, but polynomial order 2
% generally seems the best solution...
registration_type = 'polynomial'; % polynomial or affine

% now run this separately for A0 and B1 instances...
A0_set_ldx = contains(gaze_subtable_list, regexpPattern('^A0_'));
B1_set_ldx = contains(gaze_subtable_list, regexpPattern('^B1_'));

set_idx_list = {find(A0_set_ldx), find(B1_set_ldx)};
set_Side_list = {'A', 'B'};
for i_set = 1 : length(set_Side_list)
	cur_side = set_Side_list{i_set};
	cur_set_idx = set_idx_list{i_set};

	if isempty(cur_set_idx)
		disp([mfilename, ': INFO: no subtables found for side ', cur_side]);
		continue
	end
	% GAZEREGv03.SESSIONID_20260316T132749.A_BA.B_NONE.SCP_01.SIDEID_A.SUBJECTID_BA.TRACKERID_pupillabs.ELEMENTID_pupillabs_data.mat
	switch cur_side
		case 'A'
			combined_subject_string = [sessionID_struct.subject_A_string, '.B_*'];
		case 'B'
			combined_subject_string = ['A_*.', sessionID_struct.subject_B_string];
	end
	cur_calibration_dirstruct = dir(fullfile(cur_CCF_runfolder_FQN, '..', ['GAZEREGv0*.SESSIONID_', sessionID_struct.YYYYMMDD_string, '*.', combined_subject_string, '.SIDEID_', cur_side, '.*.mat']));

	if ~isempty(cur_calibration_dirstruct)
		cur_reg_struct = load(fullfile(cur_calibration_dirstruct(1).folder, cur_calibration_dirstruct(1).name));
	else
		cur_reg_struct = [];
		disp([mfilename, ': INFO: could not find a compatible gaze regfistration file: ', ['GAZEREGv0*.SESSIONID_', sessionID_struct.YYYYMMDD_string, '*.', combined_subject_string, '.SIDEID_', cur_side, '.*.mat']]);
	end

	% now loop over the subtables for the current side
	for i_subtable = 1 :length(cur_set_idx)
		cur_subtable_name = gaze_subtable_list{cur_set_idx(i_subtable)};
		cur_data_table = in_pupillabs_struct.(cur_subtable_name);

		cur_eye = [];
		if contains(cur_subtable_name, 'pupil_dot_0')
			cur_eye = 'right';
		elseif contains(cur_subtable_name, 'pupil_dot_1')
			cur_eye = 'left';
		end
	

		cur_data_table_column_names = cur_data_table.Properties.VariableNames;

		% now work through the request_list
		if ismember({'fix_timestamps'}, request_list)
			disp([mfilename, ': INFO: fixing timestamps']);
			% take the best available time stamps from the tracker file
			% correct timestamps?
			[col_header, corrected_local_timestamp_list] = fn_correct_remote_network_timestamps('PupilLabs', cur_data_table.receive_timestamp_s, cur_data_table.timestamp, cur_CCF_runfolder_FQN);
			cur_data_table.(col_header) = corrected_local_timestamp_list;
		end

		if ismember({'apply_registration'}, request_list)
			if isempty(cur_reg_struct)
				disp([mfilename, ': INFO: apply_registration requestd, but no gaze registartion file exists, skipping...']);
			else
				disp([mfilename, ': INFO: applying gaze corrections']);
				cur_subtable_reg_tform = cur_reg_struct.out_registration_struct.(cur_subtable_name).registration_struct.(registration_type).(cur_subtable_name).tform;
				cur_data_table.registered_norm_pos = transformPointsInverse(cur_subtable_reg_tform, cur_data_table.norm_pos);
			end
			

			% this only makes sense with registred norm_pos
			if ismember({'convert_reg_norm_pos_to_eventide_pixel_pos'}, request_list) && ismember({'registered_norm_pos'}, cur_data_table.Properties.VariableNames)
				% to be used with fn_convert_pixels_2_DVA
				cur_data_table.registered_pixel_pos = nan(size(cur_data_table.registered_norm_pos));
				[cur_data_table.registered_pixel_pos(:, 1), cur_data_table.registered_pixel_pos(:, 2)] = fn_CCF_win_to_engine_pos(cur_data_table.registered_norm_pos(:, 1), cur_data_table.registered_norm_pos(:, 2), CCF_conf.field_size, CCF_conf.target_radius, CCF_conf.field_x_offset, CCF_conf.field_y_offset);
				% eventide convention has (0,0) be top left (CCF uses (0,0): bottom
				% left) so we adjust things accordingly so we can re-use
				% existing gaze analysis code.
				cur_data_table.registered_pixel_pos(:, 2) = CCF_conf.screen_height_pixel - cur_data_table.registered_pixel_pos(:, 2);
			end

			if ismember({'convert_to_DVA'}, request_list) && ismember({'registered_pixel_pos'}, cur_data_table.Properties.VariableNames) && ~isempty(cur_eye)
				cur_data_table.registered_dva_pos = nan(size(cur_data_table.registered_pixel_pos));
				cur_species = sessionID_struct.(['species_', cur_side]);
				cur_screen_pix2mm_x = CCF_conf.screen_width_mm/CCF_conf.screen_width_pixel;
				cur_screen_pix2mm_y = CCF_conf.screen_height_mm/CCF_conf.screen_height_pixel;
				cur_eye2srceen_distance_mm =  GAZE_OPTS_struct.(cur_species).(cur_side).eye2srceen_distance_mm;
				half_inter_pupillary_distance_pix = GAZE_OPTS_struct.(cur_species).inter_pupillary_distance_mm * 0.5 / cur_screen_pix2mm_x;

				switch (cur_side)
					case 'A'
						switch cur_eye
							case 'right'
								cur_x_screen_clostest2eye_pix = GAZE_OPTS_struct.(cur_species).(cur_side).x_screen_intereye_pix + half_inter_pupillary_distance_pix;
							case 'left'
								cur_x_screen_clostest2eye_pix = GAZE_OPTS_struct.(cur_species).(cur_side).x_screen_intereye_pix - half_inter_pupillary_distance_pix;
						end
					case 'B'
						switch cur_eye
							case 'right'
								cur_x_screen_clostest2eye_pix = GAZE_OPTS_struct.(cur_species).(cur_side).x_screen_intereye_pix - half_inter_pupillary_distance_pix;
							case 'left'
								cur_x_screen_clostest2eye_pix = GAZE_OPTS_struct.(cur_species).(cur_side).x_screen_intereye_pix + half_inter_pupillary_distance_pix;
						end
				end

				cur_y_screen_clostest2eye_pix = GAZE_OPTS_struct.(cur_species).(cur_side).y_screen_clostest2eye_pix;
				cur_origin_X_pix = GAZE_OPTS_struct.x_center_pix;
				cur_origin_Y_pix =  GAZE_OPTS_struct.y_center_pix;
				[cur_data_table.registered_dva_pos(:,1), cur_data_table.registered_dva_pos(:,2)] = fn_convert_pixels_2_DVA_CCF(cur_data_table.registered_pixel_pos(:, 1), cur_data_table.registered_pixel_pos(:, 2), cur_x_screen_clostest2eye_pix, cur_y_screen_clostest2eye_pix, cur_screen_pix2mm_x, cur_screen_pix2mm_y, cur_eye2srceen_distance_mm, cur_origin_X_pix, cur_origin_Y_pix);
			end

		end
		out_pupillabs_struct.(cur_subtable_name) = cur_data_table;
	end
end


% final end...
timestamps.(mfilename).end = toc(timestamps.(mfilename).start);
cur_duration_s = timestamps.(mfilename).end;
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end), ' seconds (', num2str(floor(cur_duration_s/(60*60))), ' hours ', num2str(floor(cur_duration_s/60)), ' minutes ', num2str(mod(cur_duration_s, 60)), ' seconds).']);

end

