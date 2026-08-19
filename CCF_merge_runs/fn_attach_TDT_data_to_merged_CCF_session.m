function [ synthetic_tank_FQN, tdt_ccf_segment_table ] = fn_attach_TDT_data_to_merged_CCF_session( ...
	merged_sessiondir_FQN, attach_request_list, gap_fill_mode)
%FN_ATTACH_TDT_DATA_TO_MERGED_CCF_SESSION Gap-fill ULTRASort products onto tbc_1.
%   Always-on (empty attach_request_list): synthetic tank, renamed run-1
%   headers, ULTRASort sidecars (xlsx/svg/tif/jpg), segment table, tbc_1
%   re-save, STAGE markers, GB estimate.
%   Tokens: 'merged_TANKdirs' | 'datafilt' | 'datafilt2' | 'dataspikes'
%
%   merged_sessiondir_FQN: .sessiondir, .mergedir, or a merge-list .txt
%       whose parent is one of those.
%   gap_fill_mode: 'zero' (default; aliases 'null','nulling'), 'mean',
%       'gaussian', 'nan'

timestamps.(mfilename).start = tic;
disp(['Starting: ', mfilename]);
fq_mfilename = mfilename('fullpath');
dbstop if error
debug = 0;

synthetic_tank_FQN = [];
tdt_ccf_segment_table = table();

fn_ensure_aux_and_ccf_on_path(fq_mfilename);
[SESSIONLOGS_dir, ~] = fn_get_SESSIONLOGS_dir_for_host();

if ~exist('merged_sessiondir_FQN', 'var') || isempty(merged_sessiondir_FQN)
	merged_sessiondir_FQN = fullfile(SESSIONLOGS_dir, '2026', '260319', ...
		'20260319TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir');
end
if ~exist('attach_request_list', 'var') || isempty(attach_request_list)
	attach_request_list = {};
end
if ~exist('gap_fill_mode', 'var') || isempty(gap_fill_mode)
	gap_fill_mode = 'zero';
end
gap_fill_mode = fn_normalize_gap_fill_mode(gap_fill_mode);
attach_request_list = fn_validate_attach_request_list(attach_request_list);

[merged_sessiondir_FQN, mergedir_FQN] = fn_resolve_sessiondir_and_mergedir(merged_sessiondir_FQN);
session_info = fn_parse_session_id(merged_sessiondir_FQN);
if (debug)
	disp([mfilename, ': INFO: session_id=', session_info.session_id]);
end

merge_struct_FQN = fullfile(mergedir_FQN, 'TDT_TANKdir_merge_struct.mat');
merge_list_FQN = fullfile(mergedir_FQN, 'merge_TDT_TANK_dir_list.txt');
manifest_FQN = fullfile(merged_sessiondir_FQN, 'merge_manifest.json');
if ~isfile(merge_struct_FQN)
	error([mfilename, ': missing TDT_TANKdir_merge_struct.mat: ', merge_struct_FQN]);
end
if ~isfile(merge_list_FQN)
	error([mfilename, ': missing merge_TDT_TANK_dir_list.txt: ', merge_list_FQN]);
end
if ~isfile(manifest_FQN)
	error([mfilename, ': missing merge_manifest.json: ', manifest_FQN]);
end

tmp_merge = load(merge_struct_FQN, 'merge_struct');
merge_struct = tmp_merge.merge_struct;
clear tmp_merge

source_tank_FQN_list = fn_translate_and_require_folder_list(merge_struct.TDT_TANKdir_merge_list);
n_run = length(source_tank_FQN_list);
if n_run < 1
	error([mfilename, ': merge_struct.TDT_TANKdir_merge_list is empty']);
end

sr_list = double(merge_struct.sampling_rate_Hz(:));
if (max(sr_list) - min(sr_list)) > 1e-6
	error([mfilename, ': sampling_rate_Hz not identical across tanks: ', num2str(sr_list')]);
end
sr = sr_list(1);
n_k_list = double(merge_struct.samples_per_TANK(:));
if length(n_k_list) ~= n_run
	error([mfilename, ': samples_per_TANK length does not match n_run']);
end

[source_tank_id_list, synthetic_tank_ID] = fn_synthetic_tank_id_from_sources(source_tank_FQN_list);
tdt_parent_FQN = fullfile(merged_sessiondir_FQN, 'TDT');
if ~isfolder(tdt_parent_FQN)
	mkdir(tdt_parent_FQN);
end
synthetic_tank_FQN = fullfile(tdt_parent_FQN, synthetic_tank_ID);
if ~isfolder(synthetic_tank_FQN)
	mkdir(synthetic_tank_FQN);
end
disp([mfilename, ': INFO: synthetic tank: ', synthetic_tank_FQN]);

headers_incomplete_ldx = fn_stage_is_done(synthetic_tank_FQN, 'headers') ...
	&& isempty(fn_dir_header_files(synthetic_tank_FQN, '*.tsq'));
if ~fn_stage_is_done(synthetic_tank_FQN, 'headers') || headers_incomplete_ldx
	if headers_incomplete_ldx
		disp([mfilename, ': WARN: STAGE_headers.finished but no .tsq, redoing headers']);
		delete(fullfile(synthetic_tank_FQN, 'STAGE_headers.finished'));
	end
	fn_copy_rename_first_tank_headers(source_tank_FQN_list{1}, source_tank_id_list{1}, ...
		synthetic_tank_FQN, synthetic_tank_ID);
	copyfile(merge_struct_FQN, fullfile(synthetic_tank_FQN, 'TDT_TANKdir_merge_struct.mat'));
	copyfile(merge_list_FQN, fullfile(synthetic_tank_FQN, 'merge_TDT_TANK_dir_list.txt'));
	fn_write_stage_marker(synthetic_tank_FQN, 'headers');
end

xlsx_stem = 'unit_merge_and_reject_sheet.v01.20210309.160ch.neg.pos.';
expected_xlsx_FQN = fullfile(synthetic_tank_FQN, [xlsx_stem, session_info.session_id, '.xlsx']);
sidecars_incomplete_ldx = fn_stage_is_done(synthetic_tank_FQN, 'ultrasort_sidecars') ...
	&& ismember('dataspikes', attach_request_list) && ~isfile(expected_xlsx_FQN);
if ~fn_stage_is_done(synthetic_tank_FQN, 'ultrasort_sidecars') || sidecars_incomplete_ldx
	if sidecars_incomplete_ldx
		disp([mfilename, ': WARN: STAGE_ultrasort_sidecars.finished but ephys xlsx missing, redoing sidecars']);
		delete(fullfile(synthetic_tank_FQN, 'STAGE_ultrasort_sidecars.finished'));
	end
	fn_copy_ultrasort_sidecars(mergedir_FQN, synthetic_tank_FQN, ...
		attach_request_list, session_info.session_id, xlsx_stem);
	fn_write_stage_marker(synthetic_tank_FQN, 'ultrasort_sidecars');
end

tbc_FQN_list = cell(n_run, 1);
time_conversion_struct_list = cell(n_run, 1);
tbc_1_src_struct = struct();
for i_run = 1 : n_run
	cur_tbc_FQN = fullfile(source_tank_FQN_list{i_run}, 'timebase_conversion_BEHAVIOUR_EPHYS.mat');
	if ~isfile(cur_tbc_FQN)
		error([mfilename, ': missing TBC for run ', num2str(i_run), ': ', cur_tbc_FQN]);
	end
	tbc_FQN_list{i_run} = cur_tbc_FQN;
	tmp_tbc = load(cur_tbc_FQN, 'time_conversion_struct', ...
		'ParaState_TDT_timestamps', 'ParaState_CCF_timestamps', 'REF_EPOC', ...
		'ParaState_CCF_idx', 'ParaState_TDT_idx');
	time_conversion_struct_list{i_run} = tmp_tbc.time_conversion_struct;
	if i_run == 1
		tbc_1_src_struct = tmp_tbc;
	end
	clear tmp_tbc
end

segment_table_FQN = fullfile(synthetic_tank_FQN, 'tdt_ccf_segment_table.mat');
if ~fn_stage_is_done(synthetic_tank_FQN, 'segment_table') || ~isfile(segment_table_FQN)
	tdt_ccf_segment_table = fn_build_tdt_ccf_segment_table( ...
		source_tank_FQN_list, tbc_FQN_list, time_conversion_struct_list, ...
		n_k_list, sr, gap_fill_mode, synthetic_tank_FQN);
	save(segment_table_FQN, 'tdt_ccf_segment_table', 'sr', 'gap_fill_mode', 'synthetic_tank_ID');
	fn_write_stage_marker(synthetic_tank_FQN, 'segment_table');
else
	tmp_seg = load(segment_table_FQN, 'tdt_ccf_segment_table');
	tdt_ccf_segment_table = tmp_seg.tdt_ccf_segment_table;
	clear tmp_seg
end
fn_print_gap_gb_estimate(tdt_ccf_segment_table, merge_struct, attach_request_list, gap_fill_mode);

if ~fn_stage_is_done(synthetic_tank_FQN, 'tbc')
	fn_resave_tbc_1(tbc_1_src_struct, synthetic_tank_FQN, merged_sessiondir_FQN);
	fn_write_stage_marker(synthetic_tank_FQN, 'tbc');
end

concat_start_idx_list = [1; cumsum(n_k_list(1:end-1)) + 1];
concat_end_idx_list = cumsum(n_k_list);
concat_start_ts_ms_list = (concat_start_idx_list ./ sr) * 1000;

for i_tok = 1 : length(attach_request_list)
	cur_token = attach_request_list{i_tok};
	if fn_stage_is_done(synthetic_tank_FQN, cur_token)
		disp([mfilename, ': INFO: STAGE_', cur_token, '.finished exists, skip']);
		continue
	end
	switch cur_token
		case {'merged_TANKdirs', 'datafilt', 'datafilt2'}
			fn_attach_continuous_token(mergedir_FQN, synthetic_tank_FQN, cur_token, ...
				tdt_ccf_segment_table, concat_start_idx_list, concat_end_idx_list, gap_fill_mode);
		case 'dataspikes'
			fn_attach_dataspikes_token(mergedir_FQN, synthetic_tank_FQN, ...
				tdt_ccf_segment_table, time_conversion_struct_list, ...
				concat_start_ts_ms_list);
		otherwise
			error([mfilename, ': unhandled attach token: ', cur_token]);
	end
	fn_write_stage_marker(synthetic_tank_FQN, cur_token);
end

fn_strip_data_from_scaledSEV_mats(synthetic_tank_FQN);

fn_extend_merge_manifest(manifest_FQN, synthetic_tank_FQN, synthetic_tank_ID, ...
	mergedir_FQN, attach_request_list, gap_fill_mode);
fn_write_stage_marker(synthetic_tank_FQN, 'qc');

timestamps.(mfilename).end = toc(timestamps.(mfilename).start);
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end), ' seconds.']);

end


function fn_ensure_aux_and_ccf_on_path(fq_mfilename)

merge_runs_dir = fileparts(fq_mfilename);
ccf_root = fileparts(merge_runs_dir);
scp_code_root = fileparts(ccf_root);
aux_dir = fullfile(scp_code_root, 'AuxiliaryFunctions', 'Matlab');
if exist('fn_load_stored_pathname', 'file') ~= 2
	if ~isfolder(aux_dir)
		error([mfilename, ': AuxiliaryFunctions/Matlab not found: ', aux_dir]);
	end
	addpath(aux_dir);
end
if exist('fn_convert_time_between_named_timebases_CCF', 'file') ~= 2
	addpath(genpath(ccf_root));
end

end


function [ gap_fill_mode ] = fn_normalize_gap_fill_mode(gap_fill_mode)

gap_fill_mode = lower(char(gap_fill_mode));
if ismember(gap_fill_mode, {'null', 'nulling'})
	gap_fill_mode = 'zero';
end
valid_list = {'zero', 'mean', 'gaussian', 'nan'};
if ~ismember(gap_fill_mode, valid_list)
	error([mfilename, ': unhandled gap_fill_mode: ', gap_fill_mode]);
end

end


function [ attach_request_list ] = fn_validate_attach_request_list(attach_request_list)

if ischar(attach_request_list) || isstring(attach_request_list)
	attach_request_list = {char(attach_request_list)};
end
valid_list = {'merged_TANKdirs', 'datafilt', 'datafilt2', 'dataspikes'};
for i_tok = 1 : length(attach_request_list)
	cur_token = char(attach_request_list{i_tok});
	attach_request_list{i_tok} = cur_token;
	if ~ismember(cur_token, valid_list)
		error([mfilename, ': unknown attach_request_list token: ', cur_token]);
	end
end

end


function [ merged_sessiondir_FQN, mergedir_FQN ] = fn_resolve_sessiondir_and_mergedir(in_FQN)

in_FQN = char(in_FQN);
if contains(in_FQN, 'SCP_DATA')
	[in_FQN, ~] = fn_load_stored_pathname(in_FQN);
end

if isfile(in_FQN)
	parent_FQN = fileparts(in_FQN);
	in_FQN = parent_FQN;
end
if ~isfolder(in_FQN)
	error([mfilename, ': not a folder (after resolving list parent): ', in_FQN]);
end

if endsWith(in_FQN, '.sessiondir')
	merged_sessiondir_FQN = in_FQN;
elseif endsWith(in_FQN, '.mergedir')
	merged_sessiondir_FQN = [extractBefore(in_FQN, '.mergedir'), '.sessiondir'];
else
	error([mfilename, ': expected .sessiondir or .mergedir: ', in_FQN]);
end
mergedir_FQN = [extractBefore(merged_sessiondir_FQN, '.sessiondir'), '.mergedir'];
if ~isfolder(merged_sessiondir_FQN)
	error([mfilename, ': sessiondir missing: ', merged_sessiondir_FQN]);
end
if ~isfolder(mergedir_FQN)
	error([mfilename, ': mergedir sibling missing: ', mergedir_FQN]);
end

end


function [ folder_FQN_list ] = fn_translate_and_require_folder_list(stored_list)

if isstring(stored_list)
	stored_list = cellstr(stored_list);
end
if ischar(stored_list)
	stored_list = {stored_list};
end
folder_FQN_list = {};
for i_item = 1 : length(stored_list)
	cur_stored = char(strtrim(stored_list{i_item}));
	if isempty(cur_stored)
		continue
	end
	[cur_FQN, ~] = fn_load_stored_pathname(cur_stored);
	if ~isfolder(cur_FQN)
		error([mfilename, ': translated tank folder missing: ', cur_FQN, ' (stored: ', cur_stored, ')']);
	end
	folder_FQN_list{end+1, 1} = cur_FQN; %#ok<AGROW>
end

end


function [ source_tank_id_list, synthetic_tank_ID ] = fn_synthetic_tank_id_from_sources(source_tank_FQN_list)

n_run = length(source_tank_FQN_list);
source_tank_id_list = cell(n_run, 1);
zeroed_id_list = cell(n_run, 1);
for i_run = 1 : n_run
	[~, source_tank_id_list{i_run}] = fileparts(source_tank_FQN_list{i_run});
	zeroed_id_list{i_run} = regexprep(source_tank_id_list{i_run}, '-\d{6}$', '-000000');
	if strcmp(zeroed_id_list{i_run}, source_tank_id_list{i_run}) ...
			&& isempty(regexp(source_tank_id_list{i_run}, '-\d{6}$', 'once'))
		error([mfilename, ': tank id does not end in -HHMMSS: ', source_tank_id_list{i_run}]);
	end
end
if numel(unique(zeroed_id_list)) ~= 1
	error([mfilename, ': source tanks do not share prefix+date for synthetic TANKDIR']);
end
synthetic_tank_ID = zeroed_id_list{1};

end


function [ is_done_ldx ] = fn_stage_is_done(synthetic_tank_FQN, stage_name)

is_done_ldx = isfile(fullfile(synthetic_tank_FQN, ['STAGE_', stage_name, '.finished']));

end


function fn_write_stage_marker(synthetic_tank_FQN, stage_name)

stage_FQN = fullfile(synthetic_tank_FQN, ['STAGE_', stage_name, '.finished']);
fid = fopen(stage_FQN, 'w');
if fid == -1
	error([mfilename, ': could not write STAGE marker: ', stage_FQN]);
end
fprintf(fid, '%s\n', datestr(now, 'yyyy-mm-ddTHH:MM:SS'));
fclose(fid);
disp([mfilename, ': INFO: wrote ', stage_FQN]);

end


function [ tsq_dirstruct ] = fn_dir_header_files(tank_FQN, wildcard_string)

tsq_dirstruct = dir(fullfile(tank_FQN, wildcard_string));
keep_ldx = true(length(tsq_dirstruct), 1);
for i_file = 1 : length(tsq_dirstruct)
	if strncmp(tsq_dirstruct(i_file).name, '._', 2)
		keep_ldx(i_file) = false;
	end
end
tsq_dirstruct = tsq_dirstruct(keep_ldx);

end


function fn_copy_rename_first_tank_headers(src_tank_FQN, src_tank_ID, dest_tank_FQN, dest_tank_ID)

% Synapse stems are often '{Subject}-{YYMMDD}_{TANKDIR}.tsq', not '{TANKDIR}.tsq'.
% TDTbin2mat globs *.tsq in the block dir — match that, then rename by tank-id swap.
tsq_dirstruct = fn_dir_header_files(src_tank_FQN, '*.tsq');
if isempty(tsq_dirstruct)
	error([mfilename, ': no .tsq in first tank: ', src_tank_FQN]);
end
if length(tsq_dirstruct) > 1
	error([mfilename, ': multiple .tsq in first tank: ', src_tank_FQN]);
end
[~, src_header_stem] = fileparts(tsq_dirstruct(1).name);
if ~contains(src_header_stem, src_tank_ID)
	error([mfilename, ': .tsq stem does not contain tank ID ', src_tank_ID, ': ', src_header_stem]);
end
dest_header_stem = strrep(src_header_stem, src_tank_ID, dest_tank_ID);
disp([mfilename, ': INFO: header stem ', src_header_stem, ' -> ', dest_header_stem]);

stem_ext_list = {'.Tbk', '.Tdx', '.tev', '.tin', '.tnt', '.tsq'};
have_tsq_ldx = false;
have_tev_ldx = false;
for i_ext = 1 : length(stem_ext_list)
	cur_ext = stem_ext_list{i_ext};
	cur_src = fullfile(src_tank_FQN, [src_header_stem, cur_ext]);
	cur_dest = fullfile(dest_tank_FQN, [dest_header_stem, cur_ext]);
	if ~isfile(cur_src)
		disp([mfilename, ': WARN: header file missing, skip: ', cur_src]);
		continue
	end
	disp([mfilename, ': INFO: copy ', cur_src, ' -> ', cur_dest]);
	copyfile(cur_src, cur_dest);
	if strcmpi(cur_ext, '.tsq')
		have_tsq_ldx = true;
	end
	if strcmpi(cur_ext, '.tev')
		have_tev_ldx = true;
	end
end
if ~have_tsq_ldx || ~have_tev_ldx
	error([mfilename, ': first tank must have both .tsq and .tev (parse/TDTbin2mat)']);
end

src_rz2 = fullfile(src_tank_FQN, [src_tank_ID, '.TDT_RZ2_streams.mat']);
if ~isfile(src_rz2)
	src_rz2 = fullfile(src_tank_FQN, [src_header_stem, '.TDT_RZ2_streams.mat']);
end
if isfile(src_rz2)
	copyfile(src_rz2, fullfile(dest_tank_FQN, [dest_tank_ID, '.TDT_RZ2_streams.mat']));
else
	disp([mfilename, ': WARN: no TDT_RZ2_streams.mat in first tank']);
end

loose_name_list = {'Notes.txt', 'StoresListing.txt', 'bad_channel_list.txt'};
for i_loose = 1 : length(loose_name_list)
	cur_src = fullfile(src_tank_FQN, loose_name_list{i_loose});
	if isfile(cur_src)
		copyfile(cur_src, fullfile(dest_tank_FQN, loose_name_list{i_loose}));
	end
end

end


function fn_copy_ultrasort_sidecars(mergedir_FQN, synthetic_tank_FQN, ...
	attach_request_list, session_id, xlsx_stem)

xlsx_dirstruct = dir(fullfile(mergedir_FQN, [xlsx_stem, '*.xlsx']));
keep_ldx = true(length(xlsx_dirstruct), 1);
for i_xlsx = 1 : length(xlsx_dirstruct)
	if contains(xlsx_dirstruct(i_xlsx).name, 'template', 'IgnoreCase', true) ...
			|| strncmp(xlsx_dirstruct(i_xlsx).name, '._', 2)
		keep_ldx(i_xlsx) = false;
	end
end
xlsx_dirstruct = xlsx_dirstruct(keep_ldx);
if length(xlsx_dirstruct) > 1
	error([mfilename, ': multiple unit_merge_and_reject_sheet xlsx in ', mergedir_FQN]);
end
if isempty(xlsx_dirstruct)
	if ismember('dataspikes', attach_request_list)
		error([mfilename, ': dataspikes requested but no unit_merge_and_reject_sheet xlsx in ', mergedir_FQN]);
	end
	disp([mfilename, ': WARN: no unit_merge_and_reject_sheet xlsx in mergedir']);
else
	if ~contains(xlsx_dirstruct(1).name, session_id)
		disp([mfilename, ': WARN: xlsx name does not contain session_id ', session_id, ...
			': ', xlsx_dirstruct(1).name]);
	end
	fn_copy_file_skip_existing(fullfile(xlsx_dirstruct(1).folder, xlsx_dirstruct(1).name), ...
		fullfile(synthetic_tank_FQN, xlsx_dirstruct(1).name));
end

plot_wildcard_list = { ...
	'*.svg', '*.tif', '*.tiff', '*.jpg', '*.jpeg', ...
	'PreWhitenRotMat_Array*.*', 'ChanCovarianceTime_Array*.*', 'ChannelCorr_Array*.*', ...
	'ch*_SpikeDetectionStats.*'};
n_copied = 0;
for i_wild = 1 : length(plot_wildcard_list)
	n_copied = n_copied + fn_copy_wildcard_skip_existing( ...
		mergedir_FQN, plot_wildcard_list{i_wild}, synthetic_tank_FQN);
end
disp([mfilename, ': INFO: ultrasort sidecar plots copied or already present, this pass n_new=', num2str(n_copied)]);

end


function [ n_copied ] = fn_copy_wildcard_skip_existing(src_dir_FQN, wildcard_string, dest_dir_FQN)

n_copied = 0;
src_dirstruct = dir(fullfile(src_dir_FQN, wildcard_string));
for i_file = 1 : length(src_dirstruct)
	if src_dirstruct(i_file).isdir || strncmp(src_dirstruct(i_file).name, '._', 2)
		continue
	end
	if fn_copy_file_skip_existing( ...
			fullfile(src_dirstruct(i_file).folder, src_dirstruct(i_file).name), ...
			fullfile(dest_dir_FQN, src_dirstruct(i_file).name))
		n_copied = n_copied + 1;
	end
end

end


function [ did_copy_ldx ] = fn_copy_file_skip_existing(src_FQN, dest_FQN)

did_copy_ldx = false;
if ~isfile(src_FQN)
	return
end
if isfile(dest_FQN)
	return
end
copyfile(src_FQN, dest_FQN);
did_copy_ldx = true;

end


function [ tdt_ccf_segment_table ] = fn_build_tdt_ccf_segment_table( ...
	source_tank_FQN_list, tbc_FQN_list, time_conversion_struct_list, ...
	n_k_list, sr, gap_fill_mode, synthetic_tank_FQN)

n_run = length(source_tank_FQN_list);
tbc_1 = time_conversion_struct_list{1};
i0_list = nan(n_run, 1);
i1_list = nan(n_run, 1);
t_start_ccf_list = nan(n_run, 1);
t_end_ccf_list = nan(n_run, 1);
t_start_tdt1_list = nan(n_run, 1);
t_end_tdt1_list = nan(n_run, 1);
residual_list = nan(n_run, 1);

for i_run = 1 : n_run
	n_k = n_k_list(i_run);
	tbc_k = time_conversion_struct_list{i_run};
	t_start_ccf_list(i_run) = fn_convert_named(0, tbc_k, 'TDT', 'CCF');
	t_end_ccf_list(i_run) = fn_convert_named((n_k - 1) / sr, tbc_k, 'TDT', 'CCF');
	t_start_tdt1_list(i_run) = fn_convert_named(t_start_ccf_list(i_run), tbc_1, 'CCF', 'TDT');
	t_end_tdt1_list(i_run) = fn_convert_named(t_end_ccf_list(i_run), tbc_1, 'CCF', 'TDT');
	raw_i0 = round(t_start_tdt1_list(i_run) * sr);
	if i_run > 1 && raw_i0 < 1
		error([mfilename, ': run ', num2str(i_run), ' would land before sample 1 on tbc_1']);
	end
	i0_list(i_run) = max(1, raw_i0);
	i1_list(i_run) = i0_list(i_run) + n_k - 1;
	if i_run > 1 && i0_list(i_run) <= i1_list(i_run - 1)
		error([mfilename, ': overlap run ', num2str(i_run), ...
			' i0=', num2str(i0_list(i_run)), ' vs prev i1=', num2str(i1_list(i_run - 1))]);
	end
	residual_list(i_run) = i1_list(i_run) - round(t_end_tdt1_list(i_run) * sr);
end

N = max(i1_list);
gap_samples = N - sum(n_k_list);

run_idx = (0 : n_run - 1)';
tdt_ccf_segment_table = table(run_idx, i0_list, i1_list, n_k_list, ...
	t_start_ccf_list, t_end_ccf_list, t_start_tdt1_list, t_end_tdt1_list, residual_list, ...
	source_tank_FQN_list, tbc_FQN_list, ...
	'VariableNames', {'run_idx', 'i0', 'i1', 'n_k', ...
	't_start_ccf', 't_end_ccf', 't_start_tdt1', 't_end_tdt1', 'residual_idx', ...
	'source_tank_FQN', 'tbc_FQN'});
tdt_ccf_segment_table.N = repmat(N, n_run, 1);
tdt_ccf_segment_table.sr = repmat(sr, n_run, 1);
tdt_ccf_segment_table.gap_fill_mode = repmat({gap_fill_mode}, n_run, 1);
tdt_ccf_segment_table.synthetic_tank_FQN = repmat({synthetic_tank_FQN}, n_run, 1);
tdt_ccf_segment_table.gap_samples = repmat(gap_samples, n_run, 1);

disp([mfilename, ': INFO: N=', num2str(N), ' gap_samples=', num2str(gap_samples), ...
	' gap_s=', num2str(gap_samples / sr)]);
for i_run = 1 : n_run
	disp([mfilename, ': INFO: run ', num2str(i_run), ...
		' CCF ', num2str(t_start_ccf_list(i_run), '%.6f'), ' .. ', num2str(t_end_ccf_list(i_run), '%.6f'), ...
		' i0=', num2str(i0_list(i_run)), ' i1=', num2str(i1_list(i_run)), ...
		' residual_idx=', num2str(residual_list(i_run))]);
end

end


function [ converted_s ] = fn_convert_named(ts_list, time_conversion_struct, from_name, to_name)

converted_s = fn_convert_time_between_named_timebases_CCF(ts_list, time_conversion_struct, from_name, to_name);
if isempty(converted_s) && ~isempty(ts_list)
	error([mfilename, ': convert ', from_name, ' -> ', to_name, ' returned empty']);
end
converted_s = converted_s(:);

end


function fn_print_gap_gb_estimate(tdt_ccf_segment_table, merge_struct, attach_request_list, gap_fill_mode)

N = tdt_ccf_segment_table.N(1);
sr = tdt_ccf_segment_table.sr(1);
ch_list = merge_struct.channel_num_string_list{1};
if iscell(ch_list)
	n_ch = numel(ch_list);
else
	n_ch = numel(merge_struct.channel_num_string_list);
end
continuous_token_list = {'merged_TANKdirs', 'datafilt', 'datafilt2'};
n_continuous = sum(ismember(attach_request_list, continuous_token_list));
gb_int16_per_type = (N * n_ch * 2) / (1024^3);
gb_single_per_type = (N * n_ch * 4) / (1024^3);
disp([mfilename, ': INFO: n_ch=', num2str(n_ch), ' N=', num2str(N), ...
	' sr=', num2str(sr), ' gap_fill_mode=', gap_fill_mode]);
if isempty(attach_request_list)
	disp([mfilename, ': INFO: empty request: metadata only, no channel I/O; ~', ...
		num2str(gb_int16_per_type, '%.2f'), ' GB/type (int16) if a continuous token is added later']);
else
	disp([mfilename, ': INFO: request {', strjoin(attach_request_list, ','), '}; ~', ...
		num2str(gb_int16_per_type, '%.2f'), ' GB/type (int16), ~', num2str(gb_single_per_type, '%.2f'), ...
		' GB/type (single); n_continuous=', num2str(n_continuous), ...
		' (~', num2str(n_continuous * gb_int16_per_type, '%.2f'), ' GB int16)']);
end

end


function fn_resave_tbc_1(tbc_1_src_struct, synthetic_tank_FQN, merged_sessiondir_FQN)

REF_EPOC = 'DigitalInMessage';
if isfield(tbc_1_src_struct, 'REF_EPOC') && ~isempty(tbc_1_src_struct.REF_EPOC)
	REF_EPOC = tbc_1_src_struct.REF_EPOC;
end
ParaState_TDT_timestamps = tbc_1_src_struct.ParaState_TDT_timestamps(:);
ParaState_CCF_timestamps = tbc_1_src_struct.ParaState_CCF_timestamps(:);
ParaState_CCF_idx = tbc_1_src_struct.ParaState_CCF_idx;
ParaState_TDT_idx = tbc_1_src_struct.ParaState_TDT_idx;
if numel(ParaState_TDT_timestamps) ~= numel(ParaState_CCF_timestamps)
	error([mfilename, ': tbc_1 ParaState TDT/CCF lengths differ']);
end
if numel(ParaState_TDT_timestamps) < 2
	error([mfilename, ': tbc_1 has fewer than 2 matched events']);
end
if numel(ParaState_TDT_timestamps) > 10
	fit_tdt_list = ParaState_TDT_timestamps(2:end-1);
	fit_ccf_list = ParaState_CCF_timestamps(2:end-1);
else
	disp([mfilename, ': INFO: less than 10 events, using all for tbc_1 re-save']);
	fit_tdt_list = ParaState_TDT_timestamps;
	fit_ccf_list = ParaState_CCF_timestamps;
end

[first2second_time_conversion_struct, second2first_time_conversion_struct, time_conversion_struct] = ...
	fn_translate_between_named_timebases_CCF(REF_EPOC, 'TDT', fit_tdt_list, 'CCF', fit_ccf_list, synthetic_tank_FQN);
time_conversion_struct.(['CCF', '_AND_', 'TDT']).CCF_session_FQN = merged_sessiondir_FQN;
time_conversion_struct.(['CCF', '_AND_', 'TDT']).TDT_tank_FQN = synthetic_tank_FQN;
cur_session_dir = merged_sessiondir_FQN;
cur_TDT_tank_FQN = synthetic_tank_FQN;
cur_time_conversion_information_FQN = fullfile(synthetic_tank_FQN, 'timebase_conversion_BEHAVIOUR_EPHYS.mat');
disp([mfilename, ': INFO: saving tbc_1 to ', cur_time_conversion_information_FQN]);
save(cur_time_conversion_information_FQN, 'first2second_time_conversion_struct', ...
	'second2first_time_conversion_struct', 'time_conversion_struct', 'REF_EPOC', ...
	'ParaState_CCF_idx', 'ParaState_CCF_timestamps', 'ParaState_TDT_idx', 'ParaState_TDT_timestamps', ...
	'cur_session_dir', 'cur_TDT_tank_FQN');

end


function fn_attach_continuous_token(mergedir_FQN, synthetic_tank_FQN, cur_token, ...
	tdt_ccf_segment_table, concat_start_idx_list, concat_end_idx_list, gap_fill_mode)

N = tdt_ccf_segment_table.N(1);
i0_list = tdt_ccf_segment_table.i0;
i1_list = tdt_ccf_segment_table.i1;
n_run = height(tdt_ccf_segment_table);

switch cur_token
	case 'merged_TANKdirs'
		src_wildcard = 'merged_TANKdirs_ch*.mat';
		dest_is_scaledSEV_ldx = true;
	case 'datafilt'
		src_wildcard = 'datafilt_ch*.mat';
		dest_is_scaledSEV_ldx = false;
	case 'datafilt2'
		src_wildcard = 'datafilt2_ch*.mat';
		dest_is_scaledSEV_ldx = false;
	otherwise
		error([mfilename, ': unhandled continuous token: ', cur_token]);
end

src_dirstruct = dir(fullfile(mergedir_FQN, src_wildcard));
src_FQN_list = {};
for i_src = 1 : length(src_dirstruct)
	cur_name = src_dirstruct(i_src).name;
	if strcmp(cur_token, 'datafilt') && contains(cur_name, 'datafilt2')
		continue
	end
	if strcmp(cur_token, 'merged_TANKdirs') && contains(cur_name, 'scaledSEV')
		continue
	end
	src_FQN_list{end+1, 1} = fullfile(src_dirstruct(i_src).folder, cur_name); %#ok<AGROW>
end
if isempty(src_FQN_list)
	error([mfilename, ': no source files for token ', cur_token, ' in ', mergedir_FQN]);
end

for i_file = 1 : length(src_FQN_list)
	cur_src_FQN = src_FQN_list{i_file};
	[~, cur_src_name, cur_src_ext] = fileparts(cur_src_FQN);
	if dest_is_scaledSEV_ldx
		cur_dest_FQN = fullfile(synthetic_tank_FQN, [cur_src_name, '.scaledSEV.mat']);
	else
		cur_dest_FQN = fullfile(synthetic_tank_FQN, [cur_src_name, cur_src_ext]);
	end
	if isfile(cur_dest_FQN)
		if dest_is_scaledSEV_ldx
			fn_strip_data_from_one_scaledSEV(cur_dest_FQN);
		end
		disp([mfilename, ': INFO: dest exists, skip channel: ', cur_dest_FQN]);
		continue
	end
	disp([mfilename, ': INFO: ', cur_token, ' ', num2str(i_file), '/', num2str(length(src_FQN_list)), ...
		': ', cur_src_name]);
	cur_file_struct = load(cur_src_FQN);
	if isfield(cur_file_struct, 'data')
		concat_vec = cur_file_struct.data;
	elseif isfield(cur_file_struct, 'cur_channel_data')
		concat_vec = cur_file_struct.cur_channel_data;
	else
		error([mfilename, ': no data/cur_channel_data in ', cur_src_FQN]);
	end
	was_row_ldx = isrow(concat_vec);
	concat_vec = concat_vec(:);
	n_concat = numel(concat_vec);
	if n_concat ~= sum(tdt_ccf_segment_table.n_k)
		error([mfilename, ': concat length ', num2str(n_concat), ...
			' ~= sum(n_k) ', num2str(sum(tdt_ccf_segment_table.n_k)), ' in ', cur_src_FQN]);
	end
	out_vec = fn_allocate_gap_fill(N, gap_fill_mode, concat_vec);
	for i_run = 1 : n_run
		out_vec(i0_list(i_run):i1_list(i_run)) = ...
			concat_vec(concat_start_idx_list(i_run):concat_end_idx_list(i_run));
	end
	if was_row_ldx
		out_vec = out_vec.';
	end
	save_struct = struct();
	if dest_is_scaledSEV_ldx
		save_struct.cur_channel_data = out_vec;
	else
		save_struct.data = out_vec;
	end
	if isfield(cur_file_struct, 'par')
		save_struct.par = cur_file_struct.par;
	end
	fn_adaptive_save(cur_dest_FQN, save_struct);
	clear cur_file_struct concat_vec out_vec save_struct
end

end


function [ out_vec ] = fn_allocate_gap_fill(N, gap_fill_mode, proto_vec)

cls = class(proto_vec);
mu = mean(double(proto_vec));
sg = std(double(proto_vec));
switch gap_fill_mode
	case 'zero'
		out_vec = zeros(N, 1, cls);
	case 'mean'
		out_vec = zeros(N, 1, cls);
		out_vec(:) = cast(mu, cls);
	case 'gaussian'
		tmp_vec = mu + sg * randn(N, 1);
		if strcmp(cls, 'int16')
			tmp_vec = round(tmp_vec);
			tmp_vec = max(double(intmin('int16')), min(double(intmax('int16')), tmp_vec));
			out_vec = int16(tmp_vec);
		else
			out_vec = cast(tmp_vec, cls);
		end
	case 'nan'
		if isinteger(proto_vec)
			error([mfilename, ': gap_fill_mode nan cannot be written into integer class ', cls]);
		end
		out_vec = nan(N, 1, cls);
	otherwise
		error([mfilename, ': unhandled gap_fill_mode: ', gap_fill_mode]);
end

end


function fn_attach_dataspikes_token(mergedir_FQN, synthetic_tank_FQN, ...
	tdt_ccf_segment_table, time_conversion_struct_list, ...
	concat_start_ts_ms_list)

known_field_list = {'index', 'spikes', 'features', 'feature_names', 'tree', 'classtemp', 'par', 'cluster_class'};
src_dirstruct = dir(fullfile(mergedir_FQN, 'dataspikes_ch*_*.mat'));
if isempty(src_dirstruct)
	error([mfilename, ': no dataspikes_ch*_*.mat in ', mergedir_FQN]);
end
n_run = height(tdt_ccf_segment_table);
tbc_1 = time_conversion_struct_list{1};
edges_ms_list = [concat_start_ts_ms_list; Inf];

for i_file = 1 : length(src_dirstruct)
	cur_src_FQN = fullfile(src_dirstruct(i_file).folder, src_dirstruct(i_file).name);
	cur_dest_FQN = fullfile(synthetic_tank_FQN, src_dirstruct(i_file).name);
	if isfile(cur_dest_FQN)
		disp([mfilename, ': INFO: dest exists, skip: ', cur_dest_FQN]);
		continue
	end
	disp([mfilename, ': INFO: dataspikes ', num2str(i_file), '/', num2str(length(src_dirstruct)), ...
		': ', src_dirstruct(i_file).name]);
	cur_file_struct = load(cur_src_FQN);
	loaded_field_list = fieldnames(cur_file_struct);
	unknown_ldx = ~ismember(loaded_field_list, known_field_list);
	if any(unknown_ldx)
		error([mfilename, ': unknown dataspikes fields: ', strjoin(loaded_field_list(unknown_ldx), ', ')]);
	end
	if ~isfield(cur_file_struct, 'index')
		error([mfilename, ': dataspikes missing index: ', cur_src_FQN]);
	end
	old_index_ms_list = cur_file_struct.index(:);
	k_list = discretize(old_index_ms_list, edges_ms_list);
	if any(isnan(k_list))
		error([mfilename, ': spike index outside concat segments in ', cur_src_FQN]);
	end
	ccf_s_list = nan(size(old_index_ms_list));
	merged_tdt_s_list = nan(size(old_index_ms_list));
	for i_run = 1 : n_run
		cur_ldx = (k_list == i_run);
		if ~any(cur_ldx)
			continue
		end
		local_tdt_s_list = (old_index_ms_list(cur_ldx) - concat_start_ts_ms_list(i_run)) / 1000;
		ccf_s_list(cur_ldx) = fn_convert_named(local_tdt_s_list, time_conversion_struct_list{i_run}, 'TDT', 'CCF');
		merged_tdt_s_list(cur_ldx) = fn_convert_named(ccf_s_list(cur_ldx), tbc_1, 'CCF', 'TDT');
	end
	new_index_ms_list = merged_tdt_s_list * 1000;
	if isrow(cur_file_struct.index)
		cur_file_struct.index = new_index_ms_list.';
	else
		cur_file_struct.index = new_index_ms_list;
	end
	if isfield(cur_file_struct, 'cluster_class') && ~isempty(cur_file_struct.cluster_class)
		cur_file_struct.cluster_class(:, 2) = new_index_ms_list;
	end
	cur_file_struct.ccf_timestamp_s = ccf_s_list;
	cur_file_struct.src_run_idx = int32(k_list - 1);
	fn_adaptive_save(cur_dest_FQN, cur_file_struct);
	clear cur_file_struct
end

end


function fn_strip_data_from_scaledSEV_mats(synthetic_tank_FQN)

scaledSEV_dirstruct = dir(fullfile(synthetic_tank_FQN, '*.scaledSEV.mat'));
n_stripped = 0;
for i_file = 1 : length(scaledSEV_dirstruct)
	cur_FQN = fullfile(scaledSEV_dirstruct(i_file).folder, scaledSEV_dirstruct(i_file).name);
	if fn_strip_data_from_one_scaledSEV(cur_FQN)
		n_stripped = n_stripped + 1;
	end
end
if n_stripped > 0
	disp([mfilename, ': INFO: stripped data from ', num2str(n_stripped), ' scaledSEV mats']);
end

end


function [ did_strip_ldx ] = fn_strip_data_from_one_scaledSEV(dest_FQN)

did_strip_ldx = false;
if ~isfile(dest_FQN)
	return
end
mat_whos_struct = whos('-file', dest_FQN);
mat_var_name_list = {mat_whos_struct.name};
if ~ismember('data', mat_var_name_list)
	return
end
if ismember('cur_channel_data', mat_var_name_list)
	keep_name_list = setdiff(mat_var_name_list, {'data'}, 'stable');
	save_struct = load(dest_FQN, keep_name_list{:});
else
	disp([mfilename, ': WARN: scaledSEV has data but no cur_channel_data, renaming: ', dest_FQN]);
	tmp_load_struct = load(dest_FQN, 'data');
	save_struct = struct();
	save_struct.cur_channel_data = tmp_load_struct.data;
	keep_name_list = setdiff(mat_var_name_list, {'data'}, 'stable');
	if ~isempty(keep_name_list)
		tmp_rest_struct = load(dest_FQN, keep_name_list{:});
		rest_name_list = fieldnames(tmp_rest_struct);
		for i_field = 1 : length(rest_name_list)
			save_struct.(rest_name_list{i_field}) = tmp_rest_struct.(rest_name_list{i_field});
		end
	end
end
disp([mfilename, ': INFO: rewrite without data: ', dest_FQN]);
fn_adaptive_save(dest_FQN, save_struct);
did_strip_ldx = true;

end


function fn_adaptive_save(dest_FQN, var_struct)

try
	save(dest_FQN, '-struct', 'var_struct');
catch ME
	if strcmp(ME.identifier, 'MATLAB:save:sizeTooBigForMATFile') ...
			|| contains(ME.message, 'v7.3')
		disp([mfilename, ': INFO: retry save -v7.3: ', dest_FQN]);
		if isfile(dest_FQN)
			delete(dest_FQN);
		end
		save(dest_FQN, '-struct', 'var_struct', '-v7.3');
	else
		rethrow(ME);
	end
end

end


function fn_extend_merge_manifest(manifest_FQN, synthetic_tank_FQN, synthetic_tank_ID, ...
	mergedir_FQN, attach_request_list, gap_fill_mode)

try
	manifest = jsondecode(fileread(manifest_FQN));
catch ME
	disp([mfilename, ': WARN: could not jsondecode merge_manifest.json, skip extend: ', ME.message]);
	return
end
manifest.tdt_attach = struct();
manifest.tdt_attach.synthetic_tank_FQN = synthetic_tank_FQN;
manifest.tdt_attach.synthetic_tank_ID = synthetic_tank_ID;
manifest.tdt_attach.mergedir_FQN = mergedir_FQN;
manifest.tdt_attach.attach_request_list = attach_request_list;
manifest.tdt_attach.gap_fill_mode = gap_fill_mode;
manifest.tdt_attach.created = datestr(now, 'yyyy-mm-ddTHH:MM:SS');
json_text = jsonencode(manifest);
json_text = strrep(json_text, ',"', sprintf(',\n"'));
fid = fopen(manifest_FQN, 'w');
if fid == -1
	error([mfilename, ': could not write merge_manifest.json: ', manifest_FQN]);
end
fwrite(fid, json_text);
fclose(fid);
disp([mfilename, ': INFO: extended ', manifest_FQN]);

end
