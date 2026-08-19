function [ n_pass, n_fail ] = run_test_fn_attach_TDT_data_to_merged_CCF_session()
%RUN_TEST_FN_ATTACH_TDT_DATA_TO_MERGED_CCF_SESSION Always-on attach smoke on 260319.
%   attach_request_list = {} — no channel I/O. Checks synthetic tank, STAGE
%   markers, segment table, tbc mat, renamed .tsq/.tev.

timestamps.(mfilename).start = tic;
disp(['Starting: ', mfilename]);
dbstop if error

this_dir = fileparts(mfilename('fullpath'));
addpath(genpath(fileparts(this_dir)));

[SESSIONLOGS_dir, ~] = fn_get_SESSIONLOGS_dir_for_host();
pilot_sessiondir_FQN = fullfile(SESSIONLOGS_dir, '2026', '260319', ...
	'20260319TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir');

n_pass = 0;
n_fail = 0;

[synthetic_tank_FQN, tdt_ccf_segment_table] = fn_attach_TDT_data_to_merged_CCF_session( ...
	pilot_sessiondir_FQN, {}, 'zero');

check_list = { ...
	struct('name', 'synthetic tank is a folder', 'ok', isfolder(synthetic_tank_FQN)), ...
	struct('name', 'STAGE_headers.finished', 'ok', isfile(fullfile(synthetic_tank_FQN, 'STAGE_headers.finished'))), ...
	struct('name', 'STAGE_segment_table.finished', 'ok', isfile(fullfile(synthetic_tank_FQN, 'STAGE_segment_table.finished'))), ...
	struct('name', 'STAGE_tbc.finished', 'ok', isfile(fullfile(synthetic_tank_FQN, 'STAGE_tbc.finished'))), ...
	struct('name', 'STAGE_qc.finished', 'ok', isfile(fullfile(synthetic_tank_FQN, 'STAGE_qc.finished'))), ...
	struct('name', 'tdt_ccf_segment_table.mat', 'ok', isfile(fullfile(synthetic_tank_FQN, 'tdt_ccf_segment_table.mat'))), ...
	struct('name', 'timebase_conversion_BEHAVIOUR_EPHYS.mat', 'ok', isfile(fullfile(synthetic_tank_FQN, 'timebase_conversion_BEHAVIOUR_EPHYS.mat'))), ...
	struct('name', 'TDT_TANKdir_merge_struct.mat copied', 'ok', isfile(fullfile(synthetic_tank_FQN, 'TDT_TANKdir_merge_struct.mat'))), ...
	struct('name', 'merge_TDT_TANK_dir_list.txt copied', 'ok', isfile(fullfile(synthetic_tank_FQN, 'merge_TDT_TANK_dir_list.txt'))), ...
	struct('name', 'segment table nonempty', 'ok', height(tdt_ccf_segment_table) >= 1), ...
	struct('name', 'i0 strictly increasing', 'ok', isempty(tdt_ccf_segment_table) || all(diff(tdt_ccf_segment_table.i0) > 0)), ...
	struct('name', 'tank id ends -000000', 'ok', endsWith(synthetic_tank_FQN, '-000000')), ...
	};

[~, synthetic_tank_ID] = fileparts(synthetic_tank_FQN);
tbc_pdf_FQN = fullfile(synthetic_tank_FQN, 'Timing_conversion_differences_TDT-CCF.DigitalInMessage.pdf');
check_list{end+1} = struct('name', 'tbc QC PDF', 'ok', isfile(tbc_pdf_FQN));
check_list{end+1} = struct('name', 'synthetic tank_ID matches folder', 'ok', endsWith(synthetic_tank_ID, '-000000'));

tsq_dirstruct = dir(fullfile(synthetic_tank_FQN, '*.tsq'));
tev_dirstruct = dir(fullfile(synthetic_tank_FQN, '*.tev'));
if ~isempty(tsq_dirstruct) && strncmp(tsq_dirstruct(1).name, '._', 2)
	tsq_dirstruct = tsq_dirstruct(2:end);
end
check_list{end+1} = struct('name', 'copied .tsq', 'ok', ~isempty(tsq_dirstruct));
check_list{end+1} = struct('name', 'copied .tev', 'ok', ~isempty(tev_dirstruct));
if ~isempty(tsq_dirstruct)
	check_list{end+1} = struct('name', '.tsq stem contains -000000', 'ok', contains(tsq_dirstruct(1).name, '-000000'));
end

rz2_dirstruct = dir(fullfile(synthetic_tank_FQN, '*-000000.TDT_RZ2_streams.mat'));
check_list{end+1} = struct('name', 'renamed RZ2 streams mat (optional)', 'ok', true);	% warn-only below
if isempty(rz2_dirstruct)
	disp([mfilename, ': WARN: no *-000000.TDT_RZ2_streams.mat (first tank may lack it)']);
end

for i_check = 1 : length(check_list)
	if check_list{i_check}.ok
		n_pass = n_pass + 1;
		disp(['[PASS] ', check_list{i_check}.name]);
	else
		n_fail = n_fail + 1;
		disp(['[FAIL] ', check_list{i_check}.name]);
	end
end

disp(' ');
disp(tdt_ccf_segment_table(:, {'run_idx', 'i0', 'i1', 'n_k', 'residual_idx'}));
disp([mfilename, ': SCORE  ', num2str(n_pass), ' pass / ', num2str(n_fail), ' fail']);
disp([mfilename, ': tank ', synthetic_tank_FQN]);

timestamps.(mfilename).end = toc(timestamps.(mfilename).start);
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end), ' seconds.']);

end
