function [ out_pupillabs_struct ] = fn_amend_pupillabs_data( in_pupillabs_struct, cur_CCF_runfolder_FQN, CCF_conf, sessionID_struct, request_list)
%FN_AMEND_PUPILLABS_DATA Summary of this function goes here
%   Detailed explanation goes here


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
				cur_data_table.registered_pixel_pos(:, 1:2) = CCF_conf.screen_height_pixel - cur_data_table.registered_pixel_pos(:, 1:2);
			end
		end
		out_pupillabs_struct.(cur_subtable_name) = cur_data_table;
	end
end

end

