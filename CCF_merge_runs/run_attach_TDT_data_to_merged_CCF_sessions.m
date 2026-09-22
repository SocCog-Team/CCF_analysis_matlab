function [ synthetic_tank_FQN_list, fail_sessiondir_FQN_list ] = run_attach_TDT_data_to_merged_CCF_sessions( ...
	merged_sessiondir_FQN_list, attach_request_list, gap_fill_mode)
%RUN_ATTACH_TDT_DATA_TO_MERGED_CCF_SESSIONS Batch fn_attach_TDT_data_to_merged_CCF_session.
%   Default request list is {} (headers + segment table + tbc_1 only).
%   Default session list is the 260319 pilot. Pass 'all' to walk the catalog.
%
%   run_attach_TDT_data_to_merged_CCF_sessions
%   run_attach_TDT_data_to_merged_CCF_sessions('all')
%   run_attach_TDT_data_to_merged_CCF_sessions('all', {'datafilt2','dataspikes'}, 'zero')
%   run_attach_TDT_data_to_merged_CCF_sessions({sessiondir_FQN}, {'datafilt2'}, 'zero')

timestamps.(mfilename).start = tic;
disp(['Starting: ', mfilename]);
dbstop if error

this_dir = fileparts(mfilename('fullpath'));
addpath(genpath(fileparts(this_dir)));

[SESSIONLOGS_dir, ~] = fn_get_SESSIONLOGS_dir_for_host();

% same days as fn_merge_same_session_CCF_sessiondirs TDT merge lists
catalog_sessiondir_FQN_list = { ...
...	fullfile(SESSIONLOGS_dir, '2025', '251219', '20251219TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...% attached: spike_sorted: no gaze data
...	fullfile(SESSIONLOGS_dir, '2026', '260204', '20260204TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...% attached: spike_sorted: no gaze data
...	fullfile(SESSIONLOGS_dir, '2026', '260206', '20260206TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...% attached: spike_sorted: no gaze data
	fullfile(SESSIONLOGS_dir, '2026', '260306', '20260306TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...% attached: NOT spike_sorted: no gaze data
	fullfile(SESSIONLOGS_dir, '2026', '260312', '20260312TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...% attached: NOT spike_sorted: no gaze data
	fullfile(SESSIONLOGS_dir, '2026', '260319', '20260319TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...% attached: NOT spike_sorted: gaze data
	fullfile(SESSIONLOGS_dir, '2026', '260320', '20260320TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...% attached: NOT spike_sorted: gaze data (broken calibration data, take calibration from 260319)
	fullfile(SESSIONLOGS_dir, '2026', '260325', '20260325TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...% attached: NOT spike_sorted: gaze data
	fullfile(SESSIONLOGS_dir, '2026', '260326', '20260326TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...% attached: NOT spike_sorted: gaze data
	fullfile(SESSIONLOGS_dir, '2026', '260402', '20260402TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...% attached: NOT spike_sorted: gaze data
	fullfile(SESSIONLOGS_dir, '2026', '260403', '20260403TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...% attached: NOT spike_sorted: gaze data
	fullfile(SESSIONLOGS_dir, '2026', '260409', '20260409TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...% attached: NOT spike_sorted: gaze data
	fullfile(SESSIONLOGS_dir, '2026', '260423', '20260423TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...% attached: NOT spike_sorted: gaze data
	fullfile(SESSIONLOGS_dir, '2026', '260424', '20260424TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...% attached: NOT spike_sorted: gaze data
	fullfile(SESSIONLOGS_dir, '2026', '260428', '20260428TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...% attached: NOT spike_sorted: gaze data
	fullfile(SESSIONLOGS_dir, '2026', '260429', '20260429TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...% attached: NOT spike_sorted: gaze data
	fullfile(SESSIONLOGS_dir, '2026', '260430', '20260430TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...% attached: NOT spike_sorted: gaze data
	fullfile(SESSIONLOGS_dir, '2026', '260501', '20260501TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir'), ...% attached: NOT spike_sorted: gaze data
	};

if ~exist('merged_sessiondir_FQN_list', 'var') || isempty(merged_sessiondir_FQN_list)
	merged_sessiondir_FQN_list = catalog_sessiondir_FQN_list(contains(catalog_sessiondir_FQN_list, '260319'));
elseif (ischar(merged_sessiondir_FQN_list) || isstring(merged_sessiondir_FQN_list)) ...
		&& strcmpi(strtrim(char(merged_sessiondir_FQN_list)), 'all')
	merged_sessiondir_FQN_list = catalog_sessiondir_FQN_list;
elseif ischar(merged_sessiondir_FQN_list) || isstring(merged_sessiondir_FQN_list)
	merged_sessiondir_FQN_list = {char(merged_sessiondir_FQN_list)};
end
if ~exist('attach_request_list', 'var') || isempty(attach_request_list)
	attach_request_list = {};
	attach_request_list = {'merged_TANKdirs', 'datafilt2', 'dataspikes'};	% ignore datafilt
	attach_request_list = {'merged_TANKdirs', 'datafilt2'};	% ignore datafilt and dataspikes to expedite MUA export before spike sorting
end
if ~exist('gap_fill_mode', 'var') || isempty(gap_fill_mode)
	gap_fill_mode = 'zero';
end

synthetic_tank_FQN_list = {};
fail_sessiondir_FQN_list = {};
n_ok = 0;
n_fail = 0;
n_skip = 0;

for i_sess = 1 : length(merged_sessiondir_FQN_list)
	cur_sessiondir_FQN = merged_sessiondir_FQN_list{i_sess};
	disp(' ');
	disp([mfilename, ': INFO: session ', num2str(i_sess), '/', num2str(length(merged_sessiondir_FQN_list)), ...
		': ', cur_sessiondir_FQN]);
	if ~isfolder(cur_sessiondir_FQN)
		n_skip = n_skip + 1;
		disp([mfilename, ': WARN: sessiondir missing, skip']);
		continue
	end
	try
		[cur_tank_FQN, ~] = fn_attach_TDT_data_to_merged_CCF_session( ...
			cur_sessiondir_FQN, attach_request_list, gap_fill_mode);
		synthetic_tank_FQN_list{end+1, 1} = cur_tank_FQN; %#ok<AGROW>
		n_ok = n_ok + 1;
	catch ME
		n_fail = n_fail + 1;
		fail_sessiondir_FQN_list{end+1, 1} = cur_sessiondir_FQN; %#ok<AGROW>
		disp([mfilename, ': ERROR: ', cur_sessiondir_FQN]);
		disp(ME.message);
	end
end

disp(' ');
disp([mfilename, ': SCORE  ', num2str(n_ok), ' ok / ', num2str(n_fail), ' fail / ', ...
	num2str(n_skip), ' skip / ', num2str(length(merged_sessiondir_FQN_list)), ' listed']);

timestamps.(mfilename).end = toc(timestamps.(mfilename).start);
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end), ' seconds.']);

end
