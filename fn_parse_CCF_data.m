function [ triallog_table, record_struct, record2D_struct, sorted_target_state_transition_table, AI_samples_struct, DI_samples_struct, json_struct, h5_struct, txt_struct, jsonl_struct, enum_struct, fixations_struct, GAZE_OPTS_struct] = fn_parse_CCF_data( cur_CCF_runfolder_FQN_list, GAZE_OPTS_struct )
%FN_PARSE_CCF_DATA Summary of this function goes here
%   Detailed explanation goes here
%
% TODO 
%	merge runs of a session, this likely requires special casing for
%	targets (if different runs use different sets of target), spcial-casing
%	collection and trial numbers, as well as modifying TDT data (re merging .SEV, datafilt, datafilt2, and dataspikes files according to the CCF timestamps)
%	allow gz versions of all files and transparently unpack and repack them
%	for each file check whether a .mat variant already exists and load that
%	unless a full reprocessing was requested (this should speed up things like jsonl parsing and fixation detection...)
%	GAZE: convert to pixel space (and from there to DVA space on request)
%	if DO_messages.jsonl exists and a TDT tank calculate the time
%		conversion data and store the struct (desired for session merging)
%		add a CCF timestamp vecor for the full rate data as well as a
%		vector of converted timestamps for into the dataspikes files
%		this is intended to help merging sessions...
% DONE:
%	implement looping over a base folder and pick the runfolders
%	automatically, changed by moving to better named "run folders"
%	merging of the individual runs per session still desired
%
%	create a per collection table that lists relevant events per collection
%	(aka "trial") for visual events as well as touch events and reward
%	events...



% if we run this directly for testing we want/need this to be in the
% path...
if ~exist('cur_CCF_runfolder_FQN_list', 'var')
	CCF_analysis_path = fullfile('C:', 'SCP_CODE', 'CCF_analysis_matlab');
	% delete existing paths containing the calling directory
	% this is a work around for matlab's inability to detect changed files on
	% most network shares
	if ~isempty(strfind(path, [CCF_analysis_path, pathsep]))
		path_string = path;
		disp('Current directory already in the path; deleting all subdirectories from the path to work around network share issues...');
		% turn the path into cell array
		while length(path_string) > 0
			[cur_path_item, remain] = strtok(path_string, ';:');
			path_string = remain(2:end);
			if ~isempty(strfind(cur_path_item, CCF_analysis_path))
				rmpath(cur_path_item);
			end
		end
	end
	% now add them again
	addpath(genpath(CCF_analysis_path));
end


data_struct_list = struct();
json_struct_list = struct();
h5_struct_list = struct();
txt_struct_list = struct();
jsonl_struct_list = struct();

%data_struct = [];

record_struct = [];
record2D_struct = [];
AI_samples_struct = [];
DI_samples_struct = [];

json_struct = [];
h5_struct = [];
txt_struct = [];
jsonl_struct = [];
enum_struct = [];

sorted_target_state_transition_table = [];


timestamps.(mfilename).start = tic;
disp(['Starting: ', mfilename]);
dbstop if error
fq_mfilename = mfilename('fullpath');
debug = 0;

redo_gaze_calibration = 0;
add_gaze_to_record2D_table = 1;
redo_record2D_amendments = 0;
redo_triallog_table = 0;
redo_DI_samples = 0;
redo_AI_samples = 0;

fn_parse_CCF_version_string = 'v.005';	% this is fed into the hashes for the caches, so the easiest way to force a single shot redo of all sessions is to change that string.


create_timebase_conversion_between_CCF_and_EPHYS = 1; % 0: do nothing, 1: do once, >1 force
load_TDT_analog_in_data = 1; % try to load the analog IN data recoded on the TDT system, for reward pulses...
REF_EPOC = 'DigitalInMessage';	% what information/method to use to find matching CCF and TDT events...


% what threshold to use to detect up from down, with Mike Walsh's caltech
% detector and the level output mac is ~3.3 Volts, while low is at 0 if the
% gain set correctly
photodiode_AI_analog_threshold_V = 2.5;	% give it some slack

use_cached_parsed_jsonl = 1;	% set to zero if you want to force reparsing



if ~exist('GAZE_OPTS_struct', 'var') || isempty(GAZE_OPTS_struct)
	%GAZE_OPTS_struct.per_session_resultdir_FQD = fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', 'per_session_data_collection', 'GAZE_TOUCH');	% where to store the per session results in addition to the local storage, keep empty to ignore
	%GAZE_OPTS_struct.GAZE_PETH_subdir_name = 'GAZE_TOUCH'; % relative to a session dir
	%GAZE_OPTS_struct.requested_processings_list = {'PETH'};	% PETH or TBD full trace
	%GAZE_OPTS_struct.GAZE_data_prefix = 'BINOCCULAR_RAW_resampled_registered_';	% which data to operate on RIGHT_EYE_RAW_resampled_registered_, LEFT_EYE_RAW_resampled_registered_
	GAZE_OPTS_struct.SCP_01.fixation_detection_method = 'iDT';	% % following Salvucci, Goldberg (2000), only iDT implemented yet (PETH data are already iVT processed with coarse limt of 50 DVA(second
	GAZE_OPTS_struct.SCP_01.show_fixation_detection = 0;		% show the detected fixations
	GAZE_OPTS_struct.SCP_01.iDT.max_dispersion_threshold_dva = 1.5;		% how much dispersion will we accept, in DVA, diameter of a gaze permission disc, this has priority over pixel and CCF
	GAZE_OPTS_struct.SCP_01.iDT.max_dispersion_threshold_pixel = 20;	% how much dispersion will we accept, iin pixel, this has priority over CCF
	GAZE_OPTS_struct.SCP_01.iDT.max_dispersion_threshold_CCF = 0.05;	% how much dispersion will we accept, in relative CCF space

	GAZE_OPTS_struct.SCP_01.iDT.min_duration_threshold_ms = 90;	% how long does a proto fixation need to last to be considered a true fixation?
	GAZE_OPTS_struct.SCP_01.eye2screen_mm = 350;% for NHP 35cm
	GAZE_OPTS_struct.SCP_01.pixel_size_mm = ((1209.4/1920) + (680.4/1080)) * 0.5;% for the OLED screen the pixels are slight asymmetric
	GAZE_OPTS_struct.SCP_01.simple_pix2dva_factor = atand((GAZE_OPTS_struct.SCP_01.pixel_size_mm) / (GAZE_OPTS_struct.SCP_01.eye2screen_mm));
	GAZE_OPTS_struct.SCP_01.gaze_unit_suffix_string = '_dva'; % what gaze source to use for fixation detection, CCF relative space: ''; EventIDE pixel space: '_pixel'; calibrated degree visual angle space: '_dva';	% will fall back to CCF space
	GAZE_OPTS_struct.SCP_01.gaze_selection_col_suffix_string = '_confidence';
	GAZE_OPTS_struct.SCP_01.gaze_selection_min_threshold_value = 0.85;
	GAZE_OPTS_struct.SCP_01.gaze_selection_max_threshold_value = [];

	%GAZE_OPTS_struct.last_pre_event_fix.require_straddling_event = 1;	% this is needed to clean up the pre_event window, so we require the pre_event fixation to span o/over the respective event
	%GAZE_OPTS_struct.last_pre_event_fix.min_pre_event_offset_ms = -50;	% for the pre event fixation, how close to the event the fixation needs to end
	%GAZE_OPTS_struct.first_post_event_fix.max_post_event_onset_ms = 250;	% for the post event fixation
	%GAZE_OPTS_struct.pre_event_window = [-400, 0];	% for raw averaging of fixation location, or for selectng the window for fixation to target detection
	%GAZE_OPTS_struct.post_event_window = [0, 400];	% for raw averaging of fixation location
	%GAZE_OPTS_struct.target_fixation_max_allowed_distance_dva = 4;	% how far away from a target (S or O) a fixation is acceptable
	%GAZE_OPTS_struct.target_fixation_max_allowed_distance_pixel = 40;


	GAZE_OPTS_struct.SCP_01.report_unit = 'pixel';% pixel or dva
	GAZE_OPTS_struct.SCP_01.report_unit = 'dva';% pixel or dva

	% calibration data for SCP01
	GAZE_OPTS_struct.SCP_01.NHP.A.eye2srceen_distance_mm = 350;
	GAZE_OPTS_struct.SCP_01.NHP.B.eye2srceen_distance_mm = 350;
	GAZE_OPTS_struct.SCP_01.HP.A.eye2srceen_distance_mm = 500;
	GAZE_OPTS_struct.SCP_01.HP.B.eye2srceen_distance_mm = 500;
	GAZE_OPTS_struct.SCP_01.NHP.A.x_screen_intereye_pix = 960;				% with ~6cm inter pupil distance for human, this would be 3cm num2str(960 + (30 * 1920/1209.4)) = 1007.6269 or 912.3731, and for monkeys ~3.5cm inter pupil distance:  num2str(960 + (35/2 * 1920/1209.4)) 987.7824 or 932.2176
	GAZE_OPTS_struct.SCP_01.NHP.A.y_screen_clostest2eye_pix = 341.27;		% with ~6cm inter pupil distance for human, this would be 3cm num2str(960 + (30 * 1920/1209.4)) = 1007.6269 or 912.3731, and for monkeys ~3.5cm inter pupil distance:  num2str(960 + (35/2 * 1920/1209.4)) 987.7824 or 932.2176
	GAZE_OPTS_struct.SCP_01.NHP.B.x_screen_intereye_pix = 960;				% the screen pixel coordinate of where the binoccular (head) gaze axis meets the screen
	GAZE_OPTS_struct.SCP_01.NHP.B.y_screen_clostest2eye_pix = 341.27;		% the screen pixel coordinate of the eye
	GAZE_OPTS_struct.SCP_01.HP.A.x_screen_intereye_pix = 960;
	GAZE_OPTS_struct.SCP_01.HP.A.y_screen_clostest2eye_pix = 341.27;
	GAZE_OPTS_struct.SCP_01.HP.B.x_screen_intereye_pix = 960;				% the screen pixel coordinate of the eye
	GAZE_OPTS_struct.SCP_01.HP.B.y_screen_clostest2eye_pix = 341.27;		% the screen pixel coordinate of the eye
	GAZE_OPTS_struct.SCP_01.NHP.inter_pupillary_distance_mm = 40;			% see https://www.sciencedirect.com/science/article/pii/S0165027019301591 other reports are 25-35mm, Elmo measured 40 mm
	GAZE_OPTS_struct.SCP_01.HP.inter_pupillary_distance_mm = 63;			% see https://en.wikipedia.org/wiki/Pupillary_distance
	GAZE_OPTS_struct.SCP_01.x_center_pix = 960;							% the virtual gaze center in X pixels
	GAZE_OPTS_struct.SCP_01.y_center_pix = 580;							% the virtual gaze center in Y pixels

	% which fixation types to export
	%GAZE_OPTS_struct.PETH.fixation_type_set_list = {'last_pre_event_fix', 'first_post_event_fix', 'pre_S_sacc2targ_fix', 'post_S_sacc2targ_fix', 'pre_O_sacc2targ_fix', 'post_O_sacc2targ_fix'};

end


if ~exist('cur_CCF_runfolder_FQN_list', 'var') || isempty(cur_CCF_runfolder_FQN_list)
	% (venv_py3.10) root@LC38836:/home/smoeller@dpz.lokal/SCP_CODE/TASKS/foraging_task_2_NHP/src#
	CCF_recordings_folder_FQN = fullfile('~', 'SCP_CODE', 'TASKS', 'foraging_task_2_NHP', 'recordings');
	cur_CCF_runfolder_FQN_list = fullfile(CCF_recordings_folder_FQN, '101_000', '0');
	%cur_CCF_runfolder_FQN_list = fullfile(CCF_recordings_folder_FQN, '101_000', '0');
	cur_CCF_runfolder_FQN_list = fullfile(CCF_recordings_folder_FQN, '102_000', '4');
	cur_CCF_runfolder_FQN_list = fullfile(CCF_recordings_folder_FQN, '109_002', '0');
	cur_CCF_runfolder_FQN_list = fullfile(CCF_recordings_folder_FQN, '000_000', '19');

	% CCF_data_base_path = fullfile('/', 'Users', 'smoeller', 'DPZ', 'taskcontroller', 'CODE', 'CCF', 'CCF_RECORDINGS', 'recordings');
	% CCF_data_base_path = fullfile('/', 'Volumes', 'snd', 'taskcontroller', 'SCP_DATA', 'SCP-CTRL-01', 'CCF', 'recordings');
	% cur_CCF_runfolder_FQN_list = fullfile(CCF_data_base_path, '001_101', '28');
	% cur_CCF_runfolder_FQN_list = fullfile(CCF_data_base_path, '100_101', '3');
	% 
	% cur_CCF_runfolder_FQN_list = fullfile('/', 'Volumes', 'snd', 'taskcontroller', 'SCP_DATA', 'SCP-CTRL-01', 'CCF', 'recordings', '001_100', '7');

	% Y:\SCP_DATA\SCP-CTRL-01\SESSIONLOGS\2025\251205\20251205T185226.A_NONE.B_NONE.SCP_01.sessiondir\TDT\SCP_DAG_v26_PZ5ms-251205-185203
	cur_CCF_runfolder_FQN_list = {...
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2025', '251205', '20251205T185226.A_NONE.B_NONE.SCP_01.sessiondir') ...
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2025', '251216', '20251216T114536.A_NONE.B_NONE.SCP_01.sessiondir') ...
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260204', '20260204T104914.A_Elmo.B_JL.SCP_01.sessiondir') ...
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260204', '20260204T112256.A_Elmo.B_JL.SCP_01.sessiondir') ...		
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260204', '20260204T115759.A_Elmo.B_JL.SCP_01.sessiondir') ...
		};


	% test 9-dot-calibration (with new jsonl format where the type is indicative of different record types that should be steered into individual subtables)
	%Y:\SCP_DATA\SCP-CTRL-01\CCF\foraging_task_2_NHP\SESSIONLOGS\2026\260316\20260316T132749.A_BA.B_NONE.SCP_01.sessiondir
%	cur_CCF_runfolder_FQN_list = {fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'CCF', 'foraging_task_2_NHP', 'SESSIONLOGS', '2026', '260316', '20260316T132749.A_BA.B_NONE.SCP_01.sessiondir')};
	% session recorded after the 9-dot-should use the same registration
	% file, note this has broken target_state columns, but should serve for
	% the gaze processing... this needs fixing by running the record2D
	% files through the state machine again...
%	cur_CCF_runfolder_FQN_list = {fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'CCF', 'foraging_task_2_NHP', 'SESSIONLOGS', '2026', '260316', '20260316T133055.A_BA.B_NONE.SCP_01.sessiondir')};

% Basak 2nd calibration and test session
%Y:\SCP_DATA\SCP-CTRL-01\CCF\foraging_task_2_NHP\SESSIONLOGS\2026\260324\20260324T133634.A_BA.B_NONE.SCP_01.sessiondir
%	cur_CCF_runfolder_FQN_list = {fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'CCF', 'foraging_task_2_NHP', 'SESSIONLOGS', '2026', '260324', '20260324T133634.A_BA.B_NONE.SCP_01.sessiondir')};

	%% first Elmo pupillabs calibration session
	%% Y:\SCP_DATA\SCP-CTRL-01\CCF\foraging_task_2_NHP\SESSIONLOGS\2026\260319\20260319T110006.A_Elmo.B_NONE.SCP_01.sessiondir
	%cur_CCF_runfolder_FQN_list = {fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'CCF', 'foraging_task_2_NHP', 'SESSIONLOGS', '2026', '260319', '20260319T110006.A_Elmo.B_NONE.SCP_01.sessiondir')};
	% first dyadic run with gaze tracking, use for gaze processing development 
%	cur_CCF_runfolder_FQN_list = {fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'CCF', 'foraging_task_2_NHP', 'SESSIONLOGS', '2026', '260319', '20260319T112338.A_Elmo.B_BA.SCP_01.sessiondir')};

%	% fixed state columns, looks good
%	cur_CCF_runfolder_FQN_list = {fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'CCF', 'foraging_task_2_NHP', 'SESSIONLOGS', '2026', '260318', '20260318T164215.A_NONE.B_NONE.SCP_01.sessiondir')};
	%cur_CCF_runfolder_FQN_list = fullfile(CCF_recordings_folder_FQN, '000_000', '19');

	%% second Elmo pupillabs calibration session: NOTE no manual_calibration_state.jsonl log was recorded (the session was never started with SPACE)
	%% Y:\SCP_DATA\SCP-CTRL-01\SESSIONLOGS\2026\260320\20260320T101256.A_Elmo.B_NONE.SCP_01.sessiondir
	%cur_CCF_runfolder_FQN_list = {fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'CCF', 'foraging_task_2_NHP', 'SESSIONLOGS', '2026', '260320', '20260320T101256.A_Elmo.B_NONE.SCP_01.sessiondir')};

	% elmo calibration
	cur_CCF_runfolder_FQN_list = {fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'CCF', 'foraging_task_2_NHP', 'SESSIONLOGS', '2026', '260325', '20260325T094322.A_Elmo.B_NONE.SCP_01.sessiondir')};


	% test file for merged session parsing...without pupillabs_data.jsonl
	cur_CCF_runfolder_FQN_list = {fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2025', '251219', '20251219TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir')};

	% test file for merged session parsing... with pupillabs_data.jsonl
	cur_CCF_runfolder_FQN_list = {fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260319', '20260319TNNNNNNM2.A_Elmo.B_MIXED.SCP_01.sessiondir')};

	cur_CCF_runfolder_FQN_list = { ...
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2025', '251219', '20251219TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 1, re-run with correct scaling
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260204', '20260204TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 2, correct scaling
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260206', '20260206TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 3, correct scaling
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260306', '20260306TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 4, 
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260312', '20260312TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 5, 
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260319', '20260319TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 6, first session with monkey gaze data..., 4 runs (last solo)
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260320', '20260320TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 7, session with gaze data, but with broken calibration data, take calibration from 260319
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260325', '20260325TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 8, 
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260326', '20260326TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 9, 
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260402', '20260402TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 10, 
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260403', '20260403TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 11, 
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260409', '20260409TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 12,
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260423', '20260423TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 13, PAPER BLOCK, face-center
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260424', '20260424TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 14, PAPER BLOCK, face-center
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260428', '20260428TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 15, confederate right (from A's perspectiive) face-right (src_run 1-3)
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260429', '20260429TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 16, confederate right (from A's perspectiive) face-right (src_run 1-3)
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260430', '20260430TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 17, confederate right (from A's perspectiive) face-right (src_run 1), confederate face center (src_run 2)
		fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260501', '20260501TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% 18, confederate right (from A's perspectiive) face-right (src_run 1), confederate left (src_run 2)
		};

	%cur_CCF_runfolder_FQN_list = cur_CCF_runfolder_FQN_list(end); % clear up to 7
	%cur_CCF_runfolder_FQN_list = cur_CCF_runfolder_FQN_list(1:5); % clear up to 7
	cur_CCF_runfolder_FQN_list = cur_CCF_runfolder_FQN_list(6:end); % clear up to 7
	cur_CCF_runfolder_FQN_list = cur_CCF_runfolder_FQN_list(end); % clear up to 7

	only_process_gaze_calibration = 0;
	if (only_process_gaze_calibration)
	% the gaze calibration sessions...
	cur_CCF_runfolder_FQN_list = { ...
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260319', '20260319T110006.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% first session with monkey gaze data...
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260320', '20260320TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...	% the calibration routine was broken, this session uses the calibration from 260319 instead
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260326', '20260326T103026.A_Elmo.B_NONE.SCP_01.sessiondir'), ...
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260326', '20260326T103026.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 12
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260402', '20260402T100142.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 12
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260403', '20260403T093508.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 12
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260409', '20260409T100642.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 12
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260423', '20260423T102851.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 13
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260424', '20260424T101945.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 13
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260428', '20260428T102602.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 13
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260429', '20260429T100042.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 13	
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260430', '20260430T090028.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 13	
		...fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2026', '260501', '20260501T085455.A_Elmo.B_NONE.SCP_01.sessiondir'), ...	% 13	
		};
	end

% use a file picker to select the desired folder
end


if ~iscell(cur_CCF_runfolder_FQN_list)
	cur_CCF_runfolder_FQN_list = {cur_CCF_runfolder_FQN_list};
end

for i_runfolder = 1 : length(cur_CCF_runfolder_FQN_list)
	cur_CCF_runfolder_FQN = cur_CCF_runfolder_FQN_list{i_runfolder};
	disp(['Processing: ', cur_CCF_runfolder_FQN]);

	[~, proto_varname_session_id, tmp_ext] = fileparts(cur_CCF_runfolder_FQN);
	if ~strcmp(tmp_ext, '.sessiondir')
		error([mfilename, ': WARN: session folder dies not end in .sessiondir...']);
	end
	varname_session_id = fn_sanitize_value_as_matlab_variable_name(proto_varname_session_id, 1 ,1);
	timestamps.(mfilename).(varname_session_id).start = tic;


	if ~isfolder(cur_CCF_runfolder_FQN)
		error([mfilename, ': ERROR: could not find/open directory: ', cur_CCF_runfolder_FQN]);
	end

	% what files do we have here
	json_dir_struct = dir(fullfile(cur_CCF_runfolder_FQN, '*.json'));
	h5_dir_struct = dir(fullfile(cur_CCF_runfolder_FQN, '*.h5'));
	txt_dir_struct = dir(fullfile(cur_CCF_runfolder_FQN, '*.txt'));
	sessionID_dir_struct = dir(fullfile(cur_CCF_runfolder_FQN, '*.sessionID'));
	jsonl_dir_struct = dir(fullfile(cur_CCF_runfolder_FQN, '*.jsonl'));

	session_id = extractBefore(sessionID_dir_struct.name, '.sessionID');
	sessionID_struct = fn_parse_session_id(session_id);


	% check a potential TDT tank dir
	[TDT_tank_ID, TDT_tank_FQN, TDT_sess_base_dir] = fn_get_TDT_tank_ID_and_FQN_CCF(cur_CCF_runfolder_FQN, session_id , 'TDT');


	% the python enums:
	enum_struct = fn_extract_python_enums(fullfile(cur_CCF_runfolder_FQN, 'enums.py'));

	% find additional information per cycle
	addition_triallog_per_cycle_info_filename_list = {'movement_to_target.csv'};
	additional_triallog_column_table = [];
	cur_additional_per_cycle_info_FQN_list = {};
	for i_additinal_per_cycle_info_FQN = 1 : length(addition_triallog_per_cycle_info_filename_list)
		cur_additional_per_cycle_info_FQN = fullfile(cur_CCF_runfolder_FQN, addition_triallog_per_cycle_info_filename_list{i_additinal_per_cycle_info_FQN});
		cur_additional_per_cycle_info_FQN_list(end+1) = {cur_additional_per_cycle_info_FQN};
		if isfile(cur_additional_per_cycle_info_FQN)
			[cur_dir, cur_name, cur_ext] = fileparts(cur_additional_per_cycle_info_FQN);
			switch cur_ext
				case {'.csv'}
					cur_additional_triallog_column_table = readtable(cur_additional_per_cycle_info_FQN);
				otherwise
					error([mfilename, ': unhandled extension: ', cur_ext]);
			end

			switch addition_triallog_per_cycle_info_filename_list{i_additinal_per_cycle_info_FQN}
				case 'movement_to_target.csv'
					% rename columns
					existing_names = cur_additional_triallog_column_table.Properties.VariableNames;
					changed_names = regexprep(existing_names, '^p0_', 'A_');
					changed_names = regexprep(changed_names, '^p1_', 'B_');
					changed_names = regexprep(changed_names, '_frame$', '_tick_idx');
					cur_additional_triallog_column_table = renamevars(cur_additional_triallog_column_table, existing_names, changed_names);

			end

			if isempty(additional_triallog_column_table)
				additional_triallog_column_table = cur_additional_triallog_column_table;
			else
				additional_triallog_column_table = [additional_triallog_column_table, cur_additional_triallog_column_table];	% UNTESTED
			end
			disp([mfilename, ': INFO: added additional per cycle information from: ', cur_additional_per_cycle_info_FQN]);
		else
			disp([mfilename, ': did not find data file with additional per_cycle information: ', cur_additional_per_cycle_info_FQN]);
		end
	end


	% the json files
	for i_json_FQN = 1 : length(json_dir_struct)
		cur_json_name = json_dir_struct(i_json_FQN).name;
		cur_json_name_sanitized = fn_sanitize_string_as_matlab_variable_name(cur_json_name);
		if (debug)
			disp(['Processing: ', cur_json_name]);
		end
		cur_json_FQN = [json_dir_struct(i_json_FQN).folder, filesep, json_dir_struct(i_json_FQN).name];
		[~, cur_json_name] = fileparts(json_dir_struct(i_json_FQN).name);
		% this will likely fail for complex or (too) large json files...
		tmp_string_data = fileread(cur_json_FQN);
		if ~isempty(tmp_string_data)
			json_struct.(cur_json_name_sanitized) = jsondecode(tmp_string_data);
		else
			disp([cur_json_name, ' contained no data, skipping...']);
		end
	end

	% is this a merged session
	session_is_merged = 0;
	source_session_FQN_list = [];
	if isfield(json_struct, 'merge_manifest_dot_json') && ~isempty(json_struct.merge_manifest_dot_json)
		session_is_merged = 1;
		source_session_FQN_list = {json_struct.merge_manifest_dot_json.source_sessions.sessiondir_FQN};
	end


	% this comes from conf.py, and should autoadapt
	if isfield(json_struct, 'conf_dot_json')
		if isfield(GAZE_OPTS_struct, json_struct.conf_dot_json.setup_id)
			GAZE_OPTS_struct = GAZE_OPTS_struct.(json_struct.conf_dot_json.setup_id);
		end
		if isfield(json_struct.conf_dot_json, 'screen_height_mn') && ~isfield(json_struct.conf_dot_json, 'screen_height_mm')
			json_struct.conf_dot_json.screen_height_mm = json_struct.conf_dot_json.screen_height_mn;
		end
		GAZE_OPTS_struct.pixel_size_mm = ((json_struct.conf_dot_json.screen_width_mm/json_struct.conf_dot_json.screen_width_pixel) + (json_struct.conf_dot_json.screen_height_mm/json_struct.conf_dot_json.screen_height_pixel)) * 0.5;% for the OLED screen the pixels are slight asymmetric
		GAZE_OPTS_struct.simple_pix2dva_factor = atand((GAZE_OPTS_struct.pixel_size_mm) / (GAZE_OPTS_struct.eye2screen_mm));
		[GAZE_OPTS_struct.x_center_pix, GAZE_OPTS_struct.y_center_pix] = fn_CCF_win_to_engine_pos( 0.5, 0.5, json_struct.conf_dot_json.field_size, json_struct.conf_dot_json.target_radius, json_struct.conf_dot_json.field_x_offset, json_struct.conf_dot_json.field_y_offset);
	end

	% the jsonl files
	for i_jsonl_FQN = 1 : length(jsonl_dir_struct)
		cur_jsonl_name = jsonl_dir_struct(i_jsonl_FQN).name;
		cur_jsonl_name_sanitized = fn_sanitize_string_as_matlab_variable_name(cur_jsonl_name);

		if (debug)
			disp(['Processing: ', cur_jsonl_name]);
		end
		cur_jsonl_FQN = [jsonl_dir_struct(i_jsonl_FQN).folder, filesep, jsonl_dir_struct(i_jsonl_FQN).name];
		[~, cur_jsonl_name] = fileparts(jsonl_dir_struct(i_jsonl_FQN).name);
		% this will likely fail for complex or (too) large json files...
		tmp_string_data = fileread(cur_jsonl_FQN);
		if ~isempty(tmp_string_data)
			cur_jsonl_mat_fqn = [cur_jsonl_FQN, '.mat'];
			cur_jsonl_mat_fqn_dirstruct = dir(cur_jsonl_mat_fqn);
			%use_cached_parsed_jsonl = 1;	% does not work right now
			if (~use_cached_parsed_jsonl || ~isfile(cur_jsonl_mat_fqn) || cur_jsonl_mat_fqn_dirstruct.bytes < 10)
				%parsed_jsonl = fn_parse_jsonl_file(cur_jsonl_FQN);
				disp([mfilename, ': INFO: parsing: ', cur_jsonl_FQN]);
				timestamps.(mfilename).start_cur_jsonl_name_sanitized = tic;
				cur_parsed_jsonl = fn_parse_jsonl_file(cur_jsonl_FQN); %TODO: save these out as parsed .mat files and simply reload these unless a re-parsing is requested (also pack the raw jsonl files with gzip to save some space...)
				jsonl_struct.(cur_jsonl_name_sanitized) = cur_parsed_jsonl;
				timestamps.(mfilename).end_cur_jsonl_name_sanitized = toc(timestamps.(mfilename).start_cur_jsonl_name_sanitized);
				disp([mfilename, ' parsing ', cur_jsonl_name_sanitized, ' took: ', num2str(timestamps.(mfilename).end_cur_jsonl_name_sanitized), ' seconds.']);

				% this will fail currently as the struct of tables does not
				% seem to allow getByteStreamFromArray
				if (use_cached_parsed_jsonl)
					s = warning('error', 'MATLAB:save:sizeTooBigForMATFile');
					try
						save(cur_jsonl_mat_fqn, 'cur_parsed_jsonl');
					catch ME
						disp(ME.identifier);
						% delete the partially written file
						disp(['Save aborted halfway through, deleting partially written: ', cur_jsonl_mat_fqn]);
						delete(cur_jsonl_mat_fqn);
						
						% type specific clean up (to make this fit into normal matlab files)
						switch cur_jsonl_name_sanitized
							case 'pupillabs_data_dot_jsonl'
								% add those columns we really need and
								% leave out the nested structures
								columns_to_keep_list = {'type', 'receive_timestamp_s', 'collection_number', 'norm_pos', 'diameter', 'confidence', 'timestamp', 'run_idx', 'diameter_3d', 'model_confidence'};
								cur_subtable_name_list = fieldnames(cur_parsed_jsonl);
								for i_subtable = 1 : length(cur_subtable_name_list)
									cur_subtable_col_names = cur_parsed_jsonl.(cur_subtable_name_list{i_subtable}).Properties.VariableNames;
									colums_to_drop_ldx = ~ismember(cur_subtable_col_names, columns_to_keep_list);
									cur_parsed_jsonl.(cur_subtable_name_list{i_subtable})(:, colums_to_drop_ldx) = [];
								end
								disp('Saving with reduced set of columns...');
								save(cur_jsonl_mat_fqn, 'cur_parsed_jsonl');

							otherwise
								disp([mfilename, ': WARN: could not save cur_jsonl_mat_fqn']);
						end

						% restore warnings
						clear cur_parsed_jsonl
					end
					warning(s);
				end
			else
				disp([mfilename, ': INFO: loading: ', cur_jsonl_mat_fqn]);
				tmp = load(cur_jsonl_mat_fqn, 'cur_parsed_jsonl');
				if isfield(tmp, 'byteStreamed_cur_parsed_jsonl')
					cur_parsed_jsonl = getArrayFromByteStream(tmp.byteStreamed_cur_parsed_jsonl);
				else
					cur_parsed_jsonl = tmp.cur_parsed_jsonl;
					clear tmp
				end
				jsonl_struct.(cur_jsonl_name_sanitized) = cur_parsed_jsonl;
				clear cur_parsed_jsonl

			end
			% fix timestamps for gaze data
			switch cur_jsonl_name_sanitized
				case 'pupillabs_data_dot_jsonl'
					% fix up the timestamps for all subtables
					request_list = {'fix_timestamps', 'apply_registration', 'convert_reg_norm_pos_to_eventide_pixel_pos', 'convert_to_DVA', 'calculate_binocular_gaze_data'};
					jsonl_struct.(cur_jsonl_name_sanitized) = fn_amend_pupillabs_data(jsonl_struct.(cur_jsonl_name_sanitized), cur_CCF_runfolder_FQN, json_struct.conf_dot_json, sessionID_struct, request_list, GAZE_OPTS_struct);
			end

		else
			disp([cur_jsonl_name, ' contained no data, skipping...']);
		end
	end


	% for this we need both a TDT tank dir,as well as DO_messages.jsonl
	if (create_timebase_conversion_between_CCF_and_EPHYS > 0) 
		% we either need an existing tank dir or are on a merged session,
		% in which case we need to dive into the source run folders
		if isempty(TDT_tank_FQN) && ~session_is_merged
			% NOTHING TO DO
			time_conversion_session_FQN_list = {};
		elseif (isempty(TDT_tank_FQN) && session_is_merged)
			% need to dive into the source sessions
			time_conversion_session_FQN_list = source_session_FQN_list;
		elseif (~isempty(TDT_tank_FQN) && session_is_merged)
			% all 
			time_conversion_session_FQN_list = [source_session_FQN_list, cur_CCF_runfolder_FQN];
		elseif (~isempty(TDT_tank_FQN) && ~session_is_merged) 
			time_conversion_session_FQN_list = {cur_CCF_runfolder_FQN};
		end

		for i_tbc_session = 1 : length(time_conversion_session_FQN_list)
			cur_tbc_session_dir = time_conversion_session_FQN_list{i_tbc_session};
			cur_tbc_session_struct = fn_parse_session_id(cur_tbc_session_dir);
			[cur_TDT_tank_ID, cur_TDT_tank_FQN, cur_TDT_sess_base_dir] = fn_get_TDT_tank_ID_and_FQN_CCF(cur_tbc_session_dir, cur_tbc_session_struct.session_id , 'TDT');
			cur_session_dir = [extractBefore(cur_TDT_sess_base_dir, '.sessiondir'), '.sessiondir'];

			cur_DO_messages_dot_jsonl_FQN = fullfile(cur_session_dir, 'DO_messages.jsonl');
			if ~isfile(cur_DO_messages_dot_jsonl_FQN)
				disp([mfilename, ': WARN: expected DO_messages.jsonl not found: ',cur_DO_messages_dot_jsonl_FQN ]);
				continue
			end


			% now check whethre the timebase conversion file already exists
			cur_time_conversion_information_FQN = fullfile(cur_TDT_tank_FQN, 'timebase_conversion_BEHAVIOUR_EPHYS.mat');
			if (create_timebase_conversion_between_CCF_and_EPHYS > 1) || ~isfile(cur_time_conversion_information_FQN)
				% even just loading costs time so only handle
				% cur_DO_messages_dot_jsonl_FQN if we actually want/need to
				% create timebase_conversion_BEHAVIOUR_EPHYS
				if isfile([cur_DO_messages_dot_jsonl_FQN, '.mat'])
					cur_DO_messages_dot_jsonl = load([cur_DO_messages_dot_jsonl_FQN, '.mat'], 'cur_parsed_jsonl');
					cur_DO_messages_dot_jsonl = cur_DO_messages_dot_jsonl.cur_parsed_jsonl;
				else
					cur_DO_messages_dot_jsonl = fn_parse_jsonl_file(cur_DO_messages_dot_jsonl_FQN);
				end

				% load the TDT information (headers, epocs, and non-broadband streams)
				narrowband_streams_mat_suffix = '.TDT_RZ2_streams.mat';
				[TDT_header, TDT_epocs, TDT_streams] = fn_load_TDT_header_epocs_narrowband_streams_CCF(cur_TDT_tank_FQN, cur_TDT_tank_ID, narrowband_streams_mat_suffix, load_TDT_analog_in_data);
				%TDT_recording_duration_sec = size(TDT_streams.epocs.Tick.data, 1);
				% get all state transitions as TDT epocs, this is required for fn_match_EventIDE_and_TDT_reference_events with REF_EPOCH = DigitalInMessage
				epocized_TDT_stat = fn_compress_TDT_stream_to_epoc_by_change_detection_CCF(TDT_streams.streams.stat);
				TDT_epocs.epocs.DigitalInMessage = epocized_TDT_stat;

				% to convert between different time bases we need events that we kno
				% whappened at the same wall-clock time so we can automatically calculate
				% conversion factors between the two time bases
				[ParaState_CCF_idx, ParaState_CCF_timestamps, ParaState_TDT_idx, ParaState_TDT_timestamps] = fn_match_pythonCCF_and_TDT_reference_events_CCF(REF_EPOC, cur_DO_messages_dot_jsonl, TDT_epocs);
				if (length(ParaState_CCF_idx) > 1)
					% % calculate time conversions, avoid the first and last event...
					if (length(ParaState_CCF_idx) > 10) && (length(ParaState_TDT_idx) > 10)
						[first2second_time_conversion_struct, second2first_time_conversion_struct, time_conversion_struct] = fn_translate_between_named_timebases_CCF(REF_EPOC, 'TDT', ParaState_TDT_timestamps(2:end-1), 'CCF', ParaState_CCF_timestamps(2:end-1), cur_TDT_tank_FQN);
					else
						% if less than 10 events, use all
						disp([mfilename, ': INFO: less than 10 events, using all for matching...']);
						[first2second_time_conversion_struct, second2first_time_conversion_struct, time_conversion_struct] = fn_translate_between_named_timebases_CCF(REF_EPOC, 'TDT', ParaState_TDT_timestamps(1:end), 'CCF', ParaState_CCF_timestamps(1:end), cur_TDT_tank_FQN);
					end
					time_conversion_struct.(['CCF', '_AND_', 'TDT']).CCF_session_FQN = cur_session_dir;
					time_conversion_struct.(['CCF', '_AND_', 'TDT']).TDT_tank_FQN = cur_TDT_tank_FQN;
					disp([mfilename, ': Saving time conversion information to: ', cur_time_conversion_information_FQN]);
					save(cur_time_conversion_information_FQN, 'first2second_time_conversion_struct', 'second2first_time_conversion_struct', 'time_conversion_struct', 'REF_EPOC', 'ParaState_CCF_idx', 'ParaState_CCF_timestamps', 'ParaState_TDT_idx', 'ParaState_TDT_timestamps', 'cur_session_dir', 'cur_TDT_tank_FQN');
					% to use this:
					% spike_TDT_ts_list = fn_convert_time_between_named_timebases_CCF((spike_TDT_ts_list), time_conversion_struct, 'TDT', 'CCF');
				else
					disp([mfilename, ': WARN: less than two common events, timebase conversion impossible, skipping...']);
				end
			else
				disp('Timebase conversion mat file already exists and re-calculation not forced, skipping (set create_timebase_conversion_between_CCF_and_EPHYS = 2 to force re-calculation)');
			end
		end
	end

	% load the sessionID
	session_id = [];
	if ~isempty(sessionID_dir_struct)
		session_id = extractBefore(sessionID_dir_struct.name, '.sessionID');
		CCF_session_dir_FQN = fileread(fullfile(sessionID_dir_struct.folder, sessionID_dir_struct.name));
		CCF_session_dir_FQN_elements = split(strtrim(CCF_session_dir_FQN), '/');	% this is coming from Linux so forward slash
		CCF_run = CCF_session_dir_FQN_elements{end};
		CCF_pair = CCF_session_dir_FQN_elements{end-1};
	end

	% try to detect a 9-dot-calibration session, so we can start the
	% calibration routine (but only do so if a calibration does not exist already in the parent directory... (the session day directory))
	if isfield(jsonl_struct, 'manual_calibration_state_dot_jsonl') && isfield(jsonl_struct, 'pupillabs_data_dot_jsonl')

		% TODO only run this if no registration exists in the parent
		% directory... (this is interactive but only needs to be run once)
		calibration_dirstruct = dir(fullfile(cur_CCF_runfolder_FQN, ['GAZEREGv0*.SESSIONID_', session_id, '.*.mat']));

		if (redo_gaze_calibration) || isempty(calibration_dirstruct)
			reg_struct = fn_gaze_recalibrator_v02_CCF(cur_CCF_runfolder_FQN, jsonl_struct.pupillabs_data_dot_jsonl, jsonl_struct.manual_calibration_state_dot_jsonl, ...
				fullfile(cur_CCF_runfolder_FQN, 'pupillabs_data.jsonl'), json_struct.conf_dot_json, 'pupillabs');
		else
			disp([mfilename, ': INFO: gaze registration file exists, skipping interactive 9-dot-calibration procedure, set redo_gaze_calibration = 1 to force a re-run.']);
		end
	end


	for i_h5_FQN = 1 : length(h5_dir_struct)
		cur_h5_name = h5_dir_struct(i_h5_FQN).name;
		if (debug)
			disp(['Processing: ', cur_h5_name]);
		end
		cur_h5_FQN = [json_dir_struct(i_h5_FQN).folder, filesep, h5_dir_struct(i_h5_FQN).name];
		[~, cur_h5_name] = fileparts(h5_dir_struct(i_h5_FQN).name);

		cur_file_info = dir(cur_h5_FQN);
		if cur_file_info.bytes < 97
			disp([mfilename, ': H5 file too small, probably corrupted, skipping: ', cur_h5_FQN])
			continue
		end

		try 
			cur_h5info = h5info(cur_h5_FQN);
		catch ME
			ME
			disp([mfilename, ': H5 file probably corrupted, skipping: ', cur_h5_FQN])
			continue
		end

		for i_h5_dataset = 1 : length(cur_h5info.Datasets)
			cur_h5_dataset_name =  cur_h5info.Datasets.Name;
			cur_data = h5read(cur_h5_FQN, ['/', cur_h5_dataset_name]);	% hdf5 datasets start with / apparently

			if contains(cur_h5_FQN, 'record2D.h5')
				% this has a leading dimension of size 1
				cur_data = squeeze(cur_data);
			end

			if ~isempty(cur_data)
				% python arrays have flipped dimensionality, but we want
				% named columns
				h5_struct.([cur_h5_name, '_', cur_h5_dataset_name]) = cur_data;
			else
				disp([cur_h5_name, ' (' , cur_h5_dataset_name, ') contained no data, skipping...']);
			end
		end
	end



%figure; plot(h5_struct.AI_samples_data(1,:)');

%tmp = h5_struct.DI_samples_data(1,:)';
%figure; plot(h5_struct.DI_samples_data(1,:)');
%tmp_1 = bitget(tmp, 1);
%figure; plot(tmp_1);

%tmp_2 = bitget(tmp, 2);
%figure; plot(tmp_2);




	if ~isempty(h5_struct) && ismember({'record_data'}, fieldnames(h5_struct))
		% create a proper header for the data and reshape to 2D table...
		record_struct.header = {};
		[dim1, dim2, dim3] = size(h5_struct.record_data);	% dim1 X, Y, additional data, dim2; entries: 
		n_cols = dim1 * dim2;
		n_rows = dim3;

		record_struct.table = reshape(h5_struct.record_data, n_cols, n_rows)';
		record_struct.header = {'aim_0_X_rel', 'aim_0_Y_rel', 'tick_timestamp_sec', 'aim_1_X_rel', 'aim_1_Y_rel', '', 'agent_0_X', 'agent_0_Y', 'cumulative_score_0', 'agent_1_X', 'agent_1_Y', ''};
		n_agent_cols = 12;
		n_cols_per_entity = 3;
		n_targets = (n_cols - n_agent_cols)/3;
		for i_targets = 1 : n_targets
			cur_target_id_col_idx = (n_agent_cols + ((i_targets - 1) * n_cols_per_entity) + n_cols_per_entity);
			cur_target_id = unique(record_struct.table(:, cur_target_id_col_idx));
			if length(cur_target_id) ~= 1
				error('flattening 3D table failed, please investigate why');
			end
			record_struct.header(end+1) = {['target_', num2str(cur_target_id), '_X_rel']};
			record_struct.header(end+1) = {['target_', num2str(cur_target_id), '_Y_rel']};
			record_struct.header(end+1) = {['target_', num2str(cur_target_id), '_ID']};
		end
		
	else
		disp(['No data record_data found in ', cur_CCF_runfolder_FQN]);
	end
	
	% record2D
	if ~isempty(h5_struct) && ismember({'record2D_data'}, fieldnames(h5_struct))
		% TODO: cache this as mat file as processing is quite costly...


		gaze_data_source_regexp_list = {'^A0_pupillabs_pupil_dot_[0|1]_dot_2d'};
		fn_add_gaze_data_to_record2D_request_list = {'synthesize_binocular_gaze_data'};


		fn_amend_record2D_table_request_list = {'nan_out_invalid_aims_pos', 'nan_out_invalid_agent_pos', ...
		'calc_and_store_distances_to_targets', ...
		'add_per_target_changed_pos_col', ...
		...'detect_agent_fixations', 'detect_aim_fixations', ...
		'detect_eye_fixations', ...	% needs fixing
		'calc_and_store_gaze_distance_to_face_region', ...
		'calc_and_store_gaze_distance_to_agents', ...
		'calc_and_store_gaze_distance_to_aims', ...
		};
		max_dispersion_threshold = json_struct.conf_dot_json.target_radius/2; % potentially define this in millimeter?
		min_fixation_duration_threshold_ms = 100; 


		record2D_subhash_list = { ...
			DataHash(fn_parse_CCF_version_string), ...
			DataHash(h5_struct.record2D_data), ...						% if the record2D data changed, play it save and recompute things
			DataHash(gaze_data_source_regexp_list), ...					
			DataHash(fn_add_gaze_data_to_record2D_request_list), ...
			DataHash(fn_amend_record2D_table_request_list), ...
			DataHash(max_dispersion_threshold), ...
			DataHash(min_fixation_duration_threshold_ms), ...
			DataHash(GAZE_OPTS_struct), ...
		};
		% hash of hashes...
		record2D_hash = DataHash(record2D_subhash_list);
		record2D_cache_FQN = fullfile(h5_dir_struct(1).folder, ['record2D_cache_', record2D_hash, '.mat']);

		if isfile(record2D_cache_FQN) && ~(redo_record2D_amendments)
			% load this
			disp([mfilename, ': INFO: loading record2D_table and fixations_struct from cache: ', record2D_cache_FQN]);
			load(record2D_cache_FQN);
		else

			% create a proper header for the data and reshape to 2D table...
			record2D_struct.header = json_struct.record2D_header_dot_json.record2D_column_names';
			record2D_struct.table = squeeze(h5_struct.record2D_data)';
			record2D_table = array2table(record2D_struct.table, 'VariableNames', record2D_struct.header);

			%% seem to match...
			%corrected_record2D_struct.header = json_struct.corrected_record2D_header_dot_json.record2D_column_names';
			%corrected_record2D_struct.table = squeeze(h5_struct.corrected_record2D_data)';
			%corrected_record2D_table = array2table(corrected_record2D_struct.table, 'VariableNames', corrected_record2D_struct.header);


			if (add_gaze_to_record2D_table)
				disp([mfilename, ': INFO: requested adding gaze data to record2D_table (tick aligned calibrated gaze data)']);
				if isfield(jsonl_struct, 'pupillabs_data_dot_jsonl')
					record2D_table = fn_add_gaze_data_to_record2D(record2D_table, jsonl_struct.pupillabs_data_dot_jsonl, 'pupillabs',  json_struct.conf_dot_json, gaze_data_source_regexp_list, fn_add_gaze_data_to_record2D_request_list);
				else
					disp([mfilename, ': INFO: jsonl_struct does not contain pupillabs_data_dot_jsonl, skipping...']);
				end
			end
			[record2D_table, fixations_struct] = fn_amend_record2D_table(record2D_table, json_struct.conf_dot_json, fn_amend_record2D_table_request_list, max_dispersion_threshold, min_fixation_duration_threshold_ms, GAZE_OPTS_struct);

			% add the sessionID column to record2D (for merged sessions maybe consider adding the src_sessionIDs as well)
			if ~ismember({'sessionID'}, record2D_table.Properties.VariableNames)
				record2D_table.sessionID = repmat({session_id}, size(record2D_table, 1), 1);
			end
			if ~ismember({'cycle'}, record2D_table.Properties.VariableNames)
				record2D_table.cycle = zeros(size(record2D_table, 1), 1);
			end


			% delete existing cache files to avoid these lingering around
			cache_wildcard_dir_string = regexprep(record2D_cache_FQN, record2D_hash, '*');	% construct the dir wildcard string
			existing_record2D_cache_FQN_dirstruct = dir(cache_wildcard_dir_string);
			for i_tmp_cache_FQN = 1 : length(existing_record2D_cache_FQN_dirstruct)
				delete(fullfile(existing_record2D_cache_FQN_dirstruct(i_tmp_cache_FQN).folder, existing_record2D_cache_FQN_dirstruct(i_tmp_cache_FQN).name));
			end
			%  save record2D_table and fixations_struct
			disp([mfilename, ': INFO: saving record2D_table and fixations_struct as cache: ', record2D_cache_FQN]);
			save(record2D_cache_FQN, 'record2D_table', 'fixations_struct');
		end


		% the number of targets in a run is not fixed, so detect it...
		record2D_colname_list = record2D_table.Properties.VariableNames;
		target_prefix_list ={};
		for i_col = 1 : length(record2D_colname_list)
			cur_col_name = record2D_colname_list{i_col};
			cur_target_prefix_cell = regexp(cur_col_name, '^target\d*', 'match');
			if ~isempty(cur_target_prefix_cell)
				target_prefix_list = [target_prefix_list, cur_target_prefix_cell{1}];
			end
		end
		target_prefix_list = unique(target_prefix_list);


	else
		target_prefix_list = {};
		disp(['No record2D data found in ', cur_CCF_runfolder_FQN]);
		return
	end

	% extract collection/trial start/stop timestamps from record2D

	
	% process record2D to create a triallog table (as matlab table)
	if ~isempty(record2D_table)
		if isfield(json_struct, 'conf_dot_json')
			target_radius = json_struct.conf_dot_json.target_radius;
		else
			target_radius = [];
		end

		triallog_table_subhash_list = {...
			DataHash(fn_parse_CCF_version_string), ...
			DataHash(record2D_table), ...
			DataHash(enum_struct), ...
			DataHash(target_radius)...
			};
		triallog_table_hash = DataHash(triallog_table_subhash_list);

		triallog_table_cache_FQN = fullfile(h5_dir_struct(1).folder, ['triallog_table_cache_', triallog_table_hash, '.mat']);
		if isfile(triallog_table_cache_FQN) && ~(redo_triallog_table)
			% load this
			disp([mfilename, ': INFO: loading triallog_table from cache: ', triallog_table_cache_FQN]);
			load(triallog_table_cache_FQN, 'triallog_table', 'record2D_table', 'sorted_target_state_transition_table');
		else

			[triallog_table, record2D_table, sorted_target_state_transition_table] = fn_create_triallog_from_record2D(session_id, record2D_table, enum_struct, target_radius);
			% We need this later... NOTE: will not work well for merged
			% sessions, as the tick timing changes for each run, and with a
			% 1/120 second (~8ms) granularity, which is bad...
			%[first2second_time_conversion_struct, second2first_time_conversion_struct, time_conversion_struct] = fn_create_timing_conversion_struct('CCF_timestamps', triallog_table.collection_start_s, 'CCF_ticks', triallog_table.collection_start_tick_idx);

			if ismember({'src_run_idx'}, triallog_table.Properties.VariableNames) && isfield(json_struct, 'merge_manifest') && isfield(json_struct.merge_manifest, 'source_sessions') && isfield(json_struct.merge_manifest.source_sessions, 'session_id')
				unassigned_src_run_idx = find(triallog_table.src_run_idx == 0);
				triallog_table.src_run_idx(unassigned_src_run_idx) = triallog_table.src_run_idx(unassigned_src_run_idx - 1);	% since we have unassigned src_run_idx at the end of a run, just force these to refer to the correct session
				merged_session_id_list = {json_struct.merge_manifest.source_sessions.session_id}';
				triallog_table.src_session_id = merged_session_id_list(triallog_table.src_run_idx);
			end
			% delete existing cache files to avoid these lingering around
			cache_wildcard_dir_string = regexprep(triallog_table_cache_FQN, triallog_table_hash, '*');	% construct the dir wildcard string
			existing_triallog_table_cache_FQN_dirstruct = dir(cache_wildcard_dir_string);
			for i_tmp_cache_FQN = 1 : length(existing_triallog_table_cache_FQN_dirstruct)
				delete(fullfile(existing_triallog_table_cache_FQN_dirstruct(i_tmp_cache_FQN).folder, existing_triallog_table_cache_FQN_dirstruct(i_tmp_cache_FQN).name));
			end
			%  save DI_samples and fixations_struct
			disp([mfilename, ': INFO: saving triallog_table as cache: ', triallog_table_cache_FQN]);
			save(triallog_table_cache_FQN, 'triallog_table', 'record2D_table', 'sorted_target_state_transition_table');
		end
		


	end

	% add the reward information per collection
	if ~isempty(jsonl_struct) && isfield(jsonl_struct, 'reward_trains')
		% attention collection number is increased just before reward is
		% dispensed, so the reward collection number is offset by +1 for
		% reason TASK, while offset by +0 for reason MANUAL
		triallog_table = fn_add_reward_information_to_triallog(triallog_table, jsonl_struct.reward_trains);
	end


	if isfield(h5_struct, 'DI_samples_data') && ~isempty(h5_struct.DI_samples_data)
		%TODO switch to cached data if it exists
		DI_samples_subhash_list = {...
			DataHash(fn_parse_CCF_version_string), ...
			DataHash(h5_struct), ...
			DataHash(json_struct), ...
			DataHash(triallog_table)...
			};
		DI_samples_hash = DataHash(DI_samples_subhash_list);

		DI_samples_cache_FQN = fullfile(h5_dir_struct(1).folder, ['DI_samples_cache_', DI_samples_hash, '.mat']);
		if isfile(DI_samples_cache_FQN) && ~(redo_DI_samples)
			% load this
			disp([mfilename, ': INFO: loading DI_sample data from cache: ', DI_samples_cache_FQN]);
			load(DI_samples_cache_FQN);
		else

			% DI_samples
			[DI_samples_timestamp_list, DI_samples_struct, DI_timing_fh] = fn_estimate_per_sample_timestamps_for_h5table('DI_samples', h5_struct, json_struct);
			fn_save_figure(DI_timing_fh, cur_CCF_runfolder_FQN, 'DI_sampling_timestamp_control_plot.pdf');
			% convert the bit lines into individual columns in addition to the
			% full DI word
			DI_word = DI_samples_struct.table;
			for i_bitline = 1 : length(DI_samples_struct.header)
				DI_samples_struct.table(:, 1+i_bitline) = bitget(DI_word, i_bitline);
			end
			DI_samples_struct.header = ['DI_word', DI_samples_struct.header];

			mean_DI_sampling_interval_s =  mean(diff(DI_samples_timestamp_list));
			DI_samples_table = fn_convert_header_table_timestamp_list_struct_to_table(DI_samples_struct);
			DI_samples_collection_num_list = fn_create_feature_list_from_id_start_end_ts_lists(DI_samples_timestamp_list, triallog_table.collection_num, triallog_table.collection_start_s, [triallog_table.collection_start_s(2:end) - (0.1 * mean_DI_sampling_interval_s); triallog_table.collection_end_s(end)]);
			DI_samples_table = addvars(DI_samples_table, DI_samples_collection_num_list, 'NewVariableNames', 'collection_num');

			% delete existing cache files to avoid these lingering around
			cache_wildcard_dir_string = regexprep(DI_samples_cache_FQN, DI_samples_hash, '*');	% construct the dir wildcard string
			existing_DI_samples_cache_FQN_dirstruct = dir(cache_wildcard_dir_string);
			for i_tmp_cache_FQN = 1 : length(existing_DI_samples_cache_FQN_dirstruct)
				delete(fullfile(existing_DI_samples_cache_FQN_dirstruct(i_tmp_cache_FQN).folder, existing_DI_samples_cache_FQN_dirstruct(i_tmp_cache_FQN).name));
			end
			%  save DI_samples and fixations_struct
			disp([mfilename, ': INFO: saving DI_samples as cache: ', DI_samples_cache_FQN]);
			save(DI_samples_cache_FQN, 'DI_samples_table', 'DI_samples_timestamp_list', 'DI_samples_struct');
		end
	end


	if isfield(h5_struct, 'AI_samples_data') && ~isempty(h5_struct.AI_samples_data)
		% switch to cached data if exists

		AI_samples_subhash_list = {...
			DataHash(fn_parse_CCF_version_string), ...
			DataHash(h5_struct), ...
			DataHash(json_struct), ...
			DataHash(triallog_table), ...
			DataHash(photodiode_AI_analog_threshold_V)...
			};
		AI_samples_hash = DataHash(AI_samples_subhash_list);

		AI_samples_cache_FQN = fullfile(h5_dir_struct(1).folder, ['AI_samples_cache_', AI_samples_hash, '.mat']);
		if isfile(AI_samples_cache_FQN) && ~(redo_AI_samples)
			% load this
			disp([mfilename, ': INFO: loading AI_sample data from cache: ', AI_samples_cache_FQN]);
			load(AI_samples_cache_FQN);
		else

			% add session timestamps to sampled data
			% AI_samples
			[AI_samples_timestamp_list, AI_samples_struct, AI_timing_fh] = fn_estimate_per_sample_timestamps_for_h5table('AI_samples', h5_struct, json_struct);
			fn_save_figure(AI_timing_fh, cur_CCF_runfolder_FQN, 'AI_sampling_timestamp_control_plot.pdf');
			mean_AI_sampling_interval_s =  mean(diff(AI_samples_timestamp_list));
			AI_samples_table = fn_convert_header_table_timestamp_list_struct_to_table(AI_samples_struct);
			AI_samples_collection_num_list = fn_create_feature_list_from_id_start_end_ts_lists(AI_samples_timestamp_list, triallog_table.collection_num, triallog_table.collection_start_s, [triallog_table.collection_start_s(2:end) - (0.1 * mean_AI_sampling_interval_s); triallog_table.collection_end_s(end)]);
			AI_samples_table = addvars(AI_samples_table, AI_samples_collection_num_list, 'NewVariableNames', 'collection_num');

			% process the photodiode information and correct the timing in the
			% jsonl table
			% extract the photodiode onset/offset timestamps and add to
			% per_collection_table
			onset_offset_events_struct = fn_extract_event_ts_from_photodiode_AI_samples( AI_samples_timestamp_list, AI_samples_table.MSD_LCD_level, AI_samples_collection_num_list, photodiode_AI_analog_threshold_V);

			% add columns to the for PDD_onset_timestamp_s and
			% PDD_offset_timestamp_s for the matching collection
			% numbers

			triallog_table = addvars(triallog_table, nan(size(triallog_table.collection_start_s)), nan(size(triallog_table.collection_start_s)), 'NewVariableNames', {'PDD_onset_s', 'PDD_offset_s'});
			if any(isnan(onset_offset_events_struct.pd_block_onset_collection_num_list))
				disp([mfilename, ': WARN: found NaNs in photo diode lists, removing them...']);
				nan_ldx = isnan(onset_offset_events_struct.pd_block_onset_collection_num_list);
				onset_offset_events_struct.pd_block_onset_collection_num_list(nan_ldx) = [];
				onset_offset_events_struct.pd_block_offset_collection_num_list(nan_ldx) = [];
				onset_offset_events_struct.pd_block_onset_s_list(nan_ldx) = [];
				onset_offset_events_struct.pd_block_offset_s_list(nan_ldx) = [];
			end
			triallog_table.PDD_onset_s(onset_offset_events_struct.pd_block_onset_collection_num_list + 1) = onset_offset_events_struct.pd_block_onset_s_list;
			% for merged sessions search for the record2D_table row with the
			% closest timestamp and take that row"s tick_idx

			%triallog_table.PDD_onset_tick_idx = fn_convert_time_between_named_timebases(triallog_table.PDD_onset_s, time_conversion_struct, 'CCF_timestamps', 'CCF_ticks');	% NEEDS FIXING FOR MERGED_SESSIONS
			%triallog_table.PDD_onset_tick_idx = round(triallog_table.PDD_onset_tick_idx);
			triallog_table.PDD_onset_tick_idx = fn_find_closest_tick_idx_for_timestamp_list(record2D_table.timestamp, triallog_table.PDD_onset_s);

			% the times when CCF thought the stiumuls changed.. that is the tick_idx when the backend/target repositioned itself.
			%	 fromn then it takes time to percolate to the ui/target state
			%	 change, rendering and transmission to the OLED and final
			%	 display on the screen

			% % allow for variable numbers of targets...
			% any_target_changed_pos_ldx = false(size(record2D_table.timestamp));
			% for i_target = 1 : length(target_prefix_list)
			% 	cur_target_changed_name = [target_prefix_list{i_target}, '_changed_pos'];
			% 	if isfield(record2D_table, cur_target_changed_name)
			% 	any_target_changed_pos_ldx = any_target_changed_pos_ldx | record2D_table.(cur_target_changed_name);
			% 	end
			% end
			% %any_target_changed_pos_ldx = record2D_table.target0_changed_pos | record2D_table.target1_changed_pos | record2D_table.target2_changed_pos;
			% any_target_changed_pos_idx = find(any_target_changed_pos_ldx);

			% the next is correct, but these are lagging behind by a number of
			% samples as we first increase the collection counter before we
			% change the stimulus...
			%triallog_table.PDD_offset_timestamp_s(onset_offset_events_struct.pd_block_offset_collection_num_list + 1) = onset_offset_events_struct.pd_block_offset_s_list;
			% so we account that for the pd_block_onset_collection_num_list as
			% otherwise in each collection the offset preceds the onset (which is technically correct, but undesired here for the per collection table)
			triallog_table.PDD_offset_s(onset_offset_events_struct.pd_block_onset_collection_num_list + 1) = onset_offset_events_struct.pd_block_offset_s_list;
			%triallog_table.PDD_offset_tick_idx = fn_convert_time_between_named_timebases(triallog_table.PDD_offset_s, time_conversion_struct, 'CCF_timestamps', 'CCF_ticks');
			%triallog_table.PDD_offset_tick_idx = round(triallog_table.PDD_offset_tick_idx);
			triallog_table.PDD_offset_tick_idx = fn_find_closest_tick_idx_for_timestamp_list(record2D_table.timestamp, triallog_table.PDD_offset_s);

			% delete existing cache files to avoid these lingering around
			cache_wildcard_dir_string = regexprep(AI_samples_cache_FQN, AI_samples_hash, '*');	% construct the dir wildcard string
			existing_AI_samples_cache_FQN_dirstruct = dir(cache_wildcard_dir_string);
			for i_tmp_cache_FQN = 1 : length(existing_AI_samples_cache_FQN_dirstruct)
				delete(fullfile(existing_AI_samples_cache_FQN_dirstruct(i_tmp_cache_FQN).folder, existing_AI_samples_cache_FQN_dirstruct(i_tmp_cache_FQN).name));
			end
			%  save  AI_samples and fixations_struct
			disp([mfilename, ': INFO: saving AI_samples as cache: ', AI_samples_cache_FQN]);
			save(AI_samples_cache_FQN, 'AI_samples_table', 'AI_samples_timestamp_list', 'AI_samples_struct', 'triallog_table');
		end
	end


	if exist('sorted_target_state_transition_table', 'var')
		% add reach/gaze position data to the triallog_table
		tmp_state_name_list = [enum_struct.target_state.name_list'; sorted_target_state_transition_table.new_state_ENUM_name];
		[unique_target_state_name_list, ~, proto_unique_target_state_name_list_row_idx] = unique(tmp_state_name_list, 'stable');
		tick_idx_list_list = cell(size(unique_target_state_name_list));
		for i_target_states = 2 : length(unique_target_state_name_list)
			cur_target_state_name = unique_target_state_name_list{i_target_states};
			cur_target_state_col_name = ['col_targ_', cur_target_state_name, '_tick_idx'];
			tick_idx_list_list(i_target_states) = {cur_target_state_col_name};
		end
		tick_idx_list_list(1) = [];	% we started from entry 2 to skip NONE
		tick_idx_list_list = [tick_idx_list_list; 'PDD_onset_tick_idx'];
		tick_idx_ext = '_tick_idx';

		fixation_subtables_include_list = {'aims0', 'aims1', 'agent0', 'agent1'}; % 'aims0', 'aims1', 'agent0', 'agent1', 'A_binocular_eye', 'A_left_eye', 'A_right_eye', 'B_binocular_eye', 'B_left_eye', 'B_right_eye'
		[ triallog_table ] = fn_collect_fixations_around_tick_idx_lists( triallog_table, fixations_struct, fixation_subtables_include_list, record2D_table, tick_idx_list_list, tick_idx_ext);
	end

	% potentially add additional per cycle columns
	if ~isempty(additional_triallog_column_table)
		% special casing....
		if (any(contains(cur_additional_per_cycle_info_FQN_list, 'movement_to_target.csv')))
			% here the _s timestamp columns are all based on experiement
			% start and not an absolute timestamps, but we expect/need
			% absolute timestamps, so recreate them from the matching
			% _tick_idx columns
			additional_table_col_names = additional_triallog_column_table.Properties.VariableNames;
			timestamp_column_ldx = contains(additional_table_col_names, regexpPattern('_s$'));
			timestamp_column_idx = find(timestamp_column_ldx);
			for i_proto_ts_col = 1 : length(timestamp_column_idx)
				cur_col_timestamp_name = additional_table_col_names{timestamp_column_idx(i_proto_ts_col)};
				cur_col_tick_idx_name = regexprep(cur_col_timestamp_name, '_s$', '_tick_idx');
				if ismember({cur_col_tick_idx_name}, additional_table_col_names) %&& additional_triallog_column_table.(cur_col_timestamp_name)(1) < record2D_table.timestamp(1)
					cur_nan_ldx = isnan(additional_triallog_column_table.(cur_col_tick_idx_name));
					additional_triallog_column_table.(cur_col_timestamp_name)(cur_nan_ldx) = NaN;
					additional_triallog_column_table.(cur_col_timestamp_name)(~cur_nan_ldx) = record2D_table.timestamp(additional_triallog_column_table.(cur_col_tick_idx_name)(~cur_nan_ldx));

				end
			end
		end

		existing_table_col_names = triallog_table.Properties.VariableNames;
		additional_table_col_names = additional_triallog_column_table.Properties.VariableNames;
		if any(ismember(existing_table_col_names, additional_table_col_names))
			disp('WARN: Trying to add columns of the same name');
		end
		n_existing_rows = size(triallog_table, 1);
		n_additional_rows = size(additional_triallog_column_table, 1);
		% if these are equal just add the columns at the end
		if (n_existing_rows == n_additional_rows)
			triallog_table = [triallog_table, additional_triallog_column_table];
		else
			% now we need to match rows via known matching columns
			if ismember({'trial_num'}, existing_table_col_names) && ismember({'cycle'}, additional_table_col_names)
				existing_match_column_name = 'trial_num';	% special case trial_num equals row_idx in triallog_table so no additional search necessary
				additional_match_column_name = 'cycle';
				for i_additional_column = 1 : length(additional_table_col_names)
					cur_additonal_column_name = additional_table_col_names{i_additional_column};
					cur_additonal_column_class = class(additional_triallog_column_table.(cur_additonal_column_name)(1));

					example_value = additional_triallog_column_table.(cur_additonal_column_name)(1);

					if isnumeric(example_value)
						triallog_table.(cur_additonal_column_name) = nan(size(triallog_table.collection_num));
					elseif iscell(example_value)
						triallog_table.(cur_additonal_column_name) = cell(size(triallog_table.col_targ_id_name));
						% are empty values marked as NaN strungs?
						if ismember({'NaN'}, additional_triallog_column_table.(cur_additonal_column_name))
							% potentially set all these to 'NaN'...
						end
					else
						disp('Doh...');
						keyboard
					end

					%cur_additional_data = additional_triallog_column_table.(cur_additonal_column_name);
					% now loop over all cycles
					for i_additional_row_idx = 1 : n_additional_rows
						cur_additional_row_idx = additional_triallog_column_table.(additional_match_column_name)(i_additional_row_idx);
						%cur_existing_row_idx = cur_additional_row_idx;
						% her we would need something like, if trail_num
						% would not already be the row_idx for
						% triallog_table
						cur_existing_row_idx = find(ismember(triallog_table.(existing_match_column_name), cur_additional_row_idx));	% this is generic but costly....
						%if ~iscell(additional_triallog_column_table.(cur_additonal_column_name)(cur_additional_row_idx))
							triallog_table.(cur_additonal_column_name)(cur_existing_row_idx) = additional_triallog_column_table.(cur_additonal_column_name)(i_additional_row_idx);
						%else
						%	disp('Doh...');
						%	triallog_table.(cur_additonal_column_name)(cur_additional_row_idx+1) = additional_triallog_column_table.(cur_additonal_column_name)(cur_additional_row_idx);
						%end
					end
				end
			else
				error([mfilename, ': no matching column names found...']);
			end

		end
	end

	% now check the triallog table for sanity
	existing_table_col_names = triallog_table.Properties.VariableNames;
	for i_triallog_col = 1 : length(existing_table_col_names)
		cur_col_data = triallog_table.(existing_table_col_names{i_triallog_col});
		if iscell(cur_col_data(1))
			isempty_ldx = cellfun(@isempty,cur_col_data);
			cur_col_data(isempty_ldx) = {'None'};
			nan_string_ldx = contains(cur_col_data, regexpPattern('^NaN$'));
			cur_col_data(nan_string_ldx) = {'None'};
		end
		triallog_table.(existing_table_col_names{i_triallog_col}) = cur_col_data;
	end



	% now calculate the distances between the entities and add to table or
	% add as new table

	if ~isempty(h5_struct)
		% quick and dirty reward and collection estimation
		% these are co9rrected for the offset if diff()
		A0.collection_magnitude_tick_ldx = [false; diff(record2D_table.agent0_cumulative_score)];
		B1.collection_magnitude_tick_ldx = [false; diff(record2D_table.agent1_cumulative_score)];
		A0.collection_ldx = A0.collection_magnitude_tick_ldx > 0;
		B1.collection_ldx = B1.collection_magnitude_tick_ldx > 0;
		A0.n_collections = sum(A0.collection_ldx);
		B1.n_collections = sum(B1.collection_ldx);
		A0.n_pulses = sum(A0.collection_magnitude_tick_ldx);
		B1.n_pulses = sum(B1.collection_magnitude_tick_ldx);
		
		% THIS is WRONG, as it only reports for agent0, needs a proper per
		% target report
		[unique_reward_magnitudes_A, ~, unique_reward_magnitudes_A_row_idx] = unique(A0.collection_magnitude_tick_ldx);
		[unique_reward_magnitudes_B, ~, unique_reward_magnitudes_B_row_idx] = unique(B1.collection_magnitude_tick_ldx);
		% count the occurrances
		total_collections = record2D_table.n_finished_collections(end);
		total_duration_s = record2D_table.timestamp(end) - record2D_table.timestamp(1);

		disp(['sessionID: ', session_id, '; CCF pair code: ', CCF_pair, '; CCF run number: ', CCF_run]);
		disp(['duration [sec]: ', num2str(total_duration_s, '%0.0f'), '; total collections: ', num2str(total_collections), '; CA: ', num2str(A0.n_collections), '; CB: ', num2str(B1.n_collections), '; pulses: RA: ', num2str(A0.n_pulses), '; RB: ', num2str(B1.n_pulses)]);



		% add a per target report: target ID target type, n collections (A:,
		% B), n_rewards (A, B)


		% Note, this will fail for different targets with equal reward
		% magnitude...
		% for this we need to calculate distances between agents and targets

		% TODO replace by iterating over targets
		for i_unique_rewards_A = 1 : length(unique_reward_magnitudes_A)
			cur_reward_magnitude_A = unique_reward_magnitudes_A(i_unique_rewards_A);
			%disp(['Reward magnitude ', num2str(cur_reward_magnitude)]);
			if cur_reward_magnitude_A == 0
				%disp('Reward magnitude 0, skipping');
				continue
			end
			cur_reward_magnitude_A_n_collections = sum(unique_reward_magnitudes_A_row_idx == i_unique_rewards_A);
			cur_reward_magnitude_A_n_collections_ratio = cur_reward_magnitude_A_n_collections / total_collections;
			disp(['A0: Reward magnitude ', num2str(cur_reward_magnitude_A), '; n_colllections: ', num2str(cur_reward_magnitude_A_n_collections), ' of ', num2str(total_collections), ': ', num2str(100*cur_reward_magnitude_A_n_collections_ratio, '%0.1f'), '%']);
		end
		for i_unique_rewards_B = 1 : length(unique_reward_magnitudes_B)
			cur_reward_magnitude_B = unique_reward_magnitudes_B(i_unique_rewards_B);
			%disp(['Reward magnitude ', num2str(cur_reward_magnitude)]);
			if cur_reward_magnitude_B == 0
				%disp('Reward magnitude 0, skipping');
				continue
			end
			cur_reward_magnitude_B_n_collections = sum(unique_reward_magnitudes_B_row_idx == i_unique_rewards_B);
			cur_reward_magnitude_B_n_collections_ratio = cur_reward_magnitude_B_n_collections / total_collections;
			disp(['B1: Reward magnitude ', num2str(cur_reward_magnitude_B), '; n_colllections: ', num2str(cur_reward_magnitude_B_n_collections), ' of ', num2str(total_collections), ': ', num2str(100*cur_reward_magnitude_B_n_collections_ratio, '%0.1f'), '%']);
		end
	end

	if i_runfolder == 1
		%data_struct_list = data_struct;
		json_struct_list = {json_struct};
		h5_struct_list = {h5_struct};
		txt_struct_list = {txt_struct};
	else
		%data_struct_list(end+1) = data_struct;
		json_struct_list(end+1) = {json_struct};
		h5_struct_list(end+1) = {h5_struct};
		txt_struct_list(end+1) = {txt_struct};
	end

	plot_face_gaze_histograms = 0;
	if ismember({'A_binocular_eye_dX_pixel'}, record2D_table.Properties.VariableNames) && plot_face_gaze_histograms
		% quick and dirty testing, whether vergence differs
		%figure('Name', 'All gaze dX pixel') ; histogram(record2D_table.A_binocular_eye_dX_pixel(record2D_table.A_binocular_eye_confidence >= 0.9), (-40:0.1:60));
		%figure('Name', 'All gaze dX CCF') ; histogram(record2D_table.A_binocular_eye_dX(record2D_table.A_binocular_eye_confidence >= 0.9)*json_struct.conf_dot_json.screen_height_mm/json_struct.conf_dot_json.screen_height_pixel, (-1:0.001:1));

		figure('Name', 'All gaze dX mm') ; histogram(record2D_table.A_binocular_eye_dX_pixel(record2D_table.A_binocular_eye_confidence >= 0.9)*json_struct.conf_dot_json.screen_height_mm/json_struct.conf_dot_json.screen_height_pixel, (-40:0.1:60))
		figure('Name', 'Gaze on facecenter dX mm') ; histogram(record2D_table.A_binocular_eye_dX_pixel(record2D_table.A_binocular_eye_confidence >= 0.9 & record2D_table.distance_A_binocular_eye_to_facecenter <= 1/6)*json_struct.conf_dot_json.screen_height_mm/json_struct.conf_dot_json.screen_height_pixel, (-40:0.1:60))
		figure('Name', 'Gaze on face_left dX mm') ; histogram(record2D_table.A_binocular_eye_dX_pixel(record2D_table.A_binocular_eye_confidence >= 0.9 & record2D_table.distance_A_binocular_eye_to_face_left <= 1/6)*json_struct.conf_dot_json.screen_height_mm/json_struct.conf_dot_json.screen_height_pixel, (-40:0.1:60))
		figure('Name', 'Gaze on face_right dX mm') ; histogram(record2D_table.A_binocular_eye_dX_pixel(record2D_table.A_binocular_eye_confidence >= 0.9 & record2D_table.distance_A_binocular_eye_to_face_right <= 1/6)*json_struct.conf_dot_json.screen_height_mm/json_struct.conf_dot_json.screen_height_pixel, (-40:0.1:60))
		%figure('Name', 'Gaze not on face dX mm') ; histogram(record2D_table.A_binocular_eye_dX_pixel(record2D_table.A_binocular_eye_confidence >= 0.9 & ~(record2D_table.distance_A_binocular_eye_to_facecenter <= 1/6))*json_struct.conf_dot_json.screen_height_mm/json_struct.conf_dot_json.screen_height_pixel, (-40:0.1:60))
		all_faceROI_ldx = ((record2D_table.distance_A_binocular_eye_to_facecenter <= 1/6) | (record2D_table.distance_A_binocular_eye_to_face_left <= 1/6) | (record2D_table.distance_A_binocular_eye_to_face_right <= 1/6));
		figure('Name', 'Gaze not on face dX mm') ; histogram(record2D_table.A_binocular_eye_dX_pixel(record2D_table.A_binocular_eye_confidence >= 0.9 & ~(all_faceROI_ldx))*json_struct.conf_dot_json.screen_height_mm/json_struct.conf_dot_json.screen_height_pixel, (-40:0.1:60))
	end

	timestamps.(mfilename).(varname_session_id).end = toc(timestamps.(mfilename).(varname_session_id).start);
	cur_duration_s = timestamps.(mfilename).(varname_session_id).end;
	disp([mfilename, ': ', session_id, ' took: ', num2str(timestamps.(mfilename).(varname_session_id).end), ' seconds (', num2str(floor(cur_duration_s/(60*60))), ' hours ', num2str(floor(mod(cur_duration_s, 3600)/60)), ' minutes ', num2str(mod(cur_duration_s, 60)), ' seconds).']);

end

% let' export the most complete record2D we generated
record2D_struct = record2D_table;



timestamps.(mfilename).end = toc(timestamps.(mfilename).start);
cur_duration_s = timestamps.(mfilename).end;
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end), ' seconds (', num2str(floor(cur_duration_s/(60*60))), ' hours ', num2str(floor(cur_duration_s/60)), ' minutes ', num2str(mod(cur_duration_s, 60)), ' seconds).']);

end


function [] = fn_save_figure(figure_handle, data_path, name_string)

if ~isempty(figure_handle)
	if ismember(exist('write_out_figure'), [2,4])
		write_out_figure(figure_handle, fullfile(data_path, name_string));
	else
		exportgraphics(figure_handle, fullfile(cur_path, fullfile(data_path, name_string)), 'BackgroundColor', 'none', 'ContentType', 'vector');
	end
	close(figure_handle);
end

return
end



function  out_table = fn_convert_header_table_timestamp_list_struct_to_table( in_struct )
out_table = [];

if length(in_struct.header) ~= size(in_struct.table, 2)
	error([mfilename, ': data array has more columns than the column name list, investigate...']);
end

out_table = array2table(in_struct.table, 'VariableNames', in_struct.header);

% now add the timestamp_list
%out_table.timestamp_s = in_struct.timestamp_list;
out_table = addvars(out_table, in_struct.timestamp_list, 'Before', 1, 'NewVariableNames', 'timestamp_s');

end



