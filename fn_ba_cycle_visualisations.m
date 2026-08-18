function [ ] = fn_ba_cycle_visualisations( cur_CCF_runfolder_FQN_list )
%FN_BA_CYCLE_VISUALISATIONS Summary of this function goes here
%   Detailed explanation goes here


% if we run this directly for testing we want/need this to be in the
% path...
if ~exist('cur_CCF_runfolder_FQN_list', 'var') || isempty(cur_CCF_runfolder_FQN_list)
	by_host_DirectoriesStruct = GetDirectoriesByHostName('local_code');
	CCF_analysis_path = fullfile(by_host_DirectoriesStruct.SCP_CODE_BaseDir, 'CCF_analysis_matlab');
	% delete existing paths containing the calling directory
	% this is a work around for matlab's inability to detect changed files on
	% most network shares
	if ~isempty(strfind(path, [CCF_analysis_path, pathsep]))
		path_string = path;
		disp('Current directory already in the path; deleting all subdirectories from the path to work around network share issues...');
		% turn the path into cell array
		while length(path_string) > 0
			[cur_path_item, remain] = strtok(path_string, pathsep);
			path_string = remain(2:end);
			if ~isempty(strfind(cur_path_item, CCF_analysis_path))
				rmpath(cur_path_item);
			end
		end
	end
	% now add them again
	addpath(genpath(CCF_analysis_path));

	[SESSIONLOGS_dir, cur_SCP_DATA_BaseDir] = fn_get_SESSIONLOGS_dir_for_host();

	% Y:\SCP_DATA\SCP-CTRL-01\SESSIONLOGS\2025\251205\20251205T185226.A_NONE.B_NONE.SCP_01.sessiondir\TDT\SCP_DAG_v26_PZ5ms-251205-185203
	cur_CCF_runfolder_FQN_list = {...
		...fullfile(SESSIONLOGS_dir, '2025', '251205', '20251205T185226.A_NONE.B_NONE.SCP_01.sessiondir') ...
		...fullfile(SESSIONLOGS_dir, '2025', '251216', '20251216T114536.A_NONE.B_NONE.SCP_01.sessiondir') ...
		...fullfile(SESSIONLOGS_dir, '2026', '260204', '20260204T104914.A_Elmo.B_JL.SCP_01.sessiondir') ...
		...fullfile(SESSIONLOGS_dir, '2026', '260204', '20260204T112256.A_Elmo.B_JL.SCP_01.sessiondir') ...
		...fullfile(SESSIONLOGS_dir, '2026', '260204', '20260204T115759.A_Elmo.B_JL.SCP_01.sessiondir') ...
		fullfile(cur_SCP_DATA_BaseDir, 'SCP-CTRL-01', 'CCF', 'foraging_task_2_NHP', 'SESSIONLOGS', '2026', '260316', '20260316T133055.A_BA.B_NONE.SCP_01.sessiondir') ...	% test session Basak with gaze tracking
		...fullfile(SESSIONLOGS_dir, '2026', '260319', '20260319T112338.A_Elmo.B_BA.SCP_01.sessiondir') ...	% Elmo's first session with gaze tracking!!!
		};
	cur_CCF_runfolder_FQN_list = {...
		fullfile(SESSIONLOGS_dir, '2026', '260319', '20260319T112338.A_Elmo.B_BA.SCP_01.sessiondir') ...	% Elmo's first session with gaze tracking!!!
	};

	cur_CCF_runfolder_FQN_list = {fullfile(SESSIONLOGS_dir, '2026', '260319', '20260319TNNNNNNM2.A_Elmo.B_MIXED.SCP_01.sessiondir')};
end


load_saved_CCF_data = 1;
save_file_fqn = fullfile(cur_CCF_runfolder_FQN_list{1}, 'CCF_data.mat');

if ~isfile(save_file_fqn) || ~load_saved_CCF_data
	disp('Parsing CCF data, might take a while');
	[triallog_table, record_struct, record2D_table, AI_samples_struct, DI_samples_struct, json_struct, h5_struct, txt_struct, jsonl_struct, enum_struct, fixations_struct] = fn_parse_CCF_data( cur_CCF_runfolder_FQN_list );
	save(save_file_fqn, 'triallog_table', 'record_struct', 'record2D_table', 'AI_samples_struct', 'DI_samples_struct', 'json_struct', 'h5_struct', 'txt_struct', 'jsonl_struct', 'enum_struct', 'fixations_struct');
else
	disp('Loading CCF data, should be fast');
	load(save_file_fqn);
end

% nasty hack
min_confidence = 0.9;

min_right_confidence = min_confidence;
right_eye_low_confidence_ldx = record2D_table.A_right_eye_confidence < min_right_confidence;
record2D_table.orig_A_right_eye_X = record2D_table.A_right_eye_X;
record2D_table.A_right_eye_X(right_eye_low_confidence_ldx) = NaN;
record2D_table.orig_A_right_eye_Y = record2D_table.A_right_eye_Y;
record2D_table.A_right_eye_Y(right_eye_low_confidence_ldx) = NaN;

min_left_confidence = min_confidence;
left_eye_low_confidence_ldx = record2D_table.A_left_eye_confidence < min_left_confidence;
record2D_table.orig_A_left_eye_X = record2D_table.A_left_eye_X;
record2D_table.A_left_eye_X(left_eye_low_confidence_ldx) = NaN;
record2D_table.orig_A_left_eye_Y = record2D_table.A_left_eye_Y;
record2D_table.A_left_eye_Y(left_eye_low_confidence_ldx) = NaN;


% the number of targets in a run is not fixed, so detect it...
record2D_colname_list = record2D_table.Properties.VariableNames;

eye_prefix_list ={};
for i_col = 1 : length(record2D_colname_list)
	cur_col_name = record2D_colname_list{i_col};
	cur_eye_prefix_cell = regexp(cur_col_name, '^[A|B]_(right|left)_eye', 'match');
	if ~isempty(cur_eye_prefix_cell)
		eye_prefix_list = [eye_prefix_list, cur_eye_prefix_cell{1}];
	end
end
eye_prefix_list = unique(eye_prefix_list);

	

%max_dispersion_threshold = json_struct.conf_dot_json.target_radius/10; %
max_dispersion_threshold_dva = 2;
max_dispersion_threshold_pixel = (tand(max_dispersion_threshold_dva) * json_struct.conf_dot_json.screen_to_eye_distance_NHP_mm) * (json_struct.conf_dot_json.screen_width_pixel/json_struct.conf_dot_json.screen_width_mm);
% in relative CCF win pos space
max_dispersion_threshold = max_dispersion_threshold_pixel / (json_struct.conf_dot_json.field_size - 2 * json_struct.conf_dot_json.target_radius * json_struct.conf_dot_json.field_size);

min_fixation_duration_threshold_ms = 90; 

	% TODO fix max_dispersion_threshold and min_fixation_duration_threshold_ms
% for this...


load_saved_fixation_data = 1;
save_fixation_fqn = fullfile(cur_CCF_runfolder_FQN_list{1}, 'CCF_eye_fixations.mat');

if ~isfile(save_fixation_fqn) || ~load_saved_fixation_data
	disp('Detecting fixations, might take a while');

	request_list = {'detect_eye_fixations'};
	%request_list = {};
	fixations_struct = struct();
	debug = 0;
	if ismember({'detect_eye_fixations'}, request_list)
		for i_eye = 1 : length(eye_prefix_list)
			disp([mfilename, ': INFO: Processing requested detect_eye_fixations: ', eye_prefix_list{i_eye}]);
			timestamps.(mfilename).detect_eye_fixations.(eye_prefix_list{i_eye}).start = tic;
			cur_eye = eye_prefix_list{i_eye};
			cur_data_struct_of_arr.timestamp = record2D_table.timestamp * 1000;	% we want milliseconds
			cur_data_struct_of_arr.X = record2D_table.([cur_eye, '_X']);
			cur_data_struct_of_arr.Y = record2D_table.([cur_eye, '_Y']);
			% local override
			% max_dispersion_threshold = conf_struct.target_radius/2;
			% min_fixation_duration_threshold_ms = 100;
			isDraw = 0;
			cur_fixation_struct = fn_spatial_dispersion_fixation_detector_CCF(cur_data_struct_of_arr, max_dispersion_threshold, min_fixation_duration_threshold_ms, isDraw);
			record2D_table.([cur_eye, '_per_sample_fixID']) = cur_fixation_struct.per_sample_fixID;
			cur_fixation_struct = rmfield(cur_fixation_struct, 'per_sample_fixID');	% we move this into record2D already...
			fixations_struct.(cur_eye) = cur_fixation_struct;
			if (debug)
				cur_fh = figure('Name', cur_eye);
				plot(cur_fixation_struct.mean_X, cur_fixation_struct.mean_Y, 'LineWidth', 0.5, 'Marker', 'o', 'LineStyle', 'none');
				cur_ah = gca();
				axis equal
				axis square
			end
			duration_s = toc(timestamps.(mfilename).detect_eye_fixations.(eye_prefix_list{i_eye}).start);
			disp(['detect_eye_fixations (', eye_prefix_list{i_eye}, ') took: ', num2str(duration_s), ' seconds.']);
		end
		save(save_fixation_fqn, 'fixations_struct', 'record2D_table');
	end
else
	disp('Loading detected fixations,should be fast.');
	load(save_fixation_fqn);
end


cur_CCF_runfolder_FQN = cur_CCF_runfolder_FQN_list{1};
% detect target prefixes and radius (if available)
record2D_colnames = record2D_table.Properties.VariableNames;

target_prefix_list = {};
for i_col = 1:numel(record2D_colnames)
	cur_name = record2D_colnames{i_col};
	m = regexp(cur_name, '^target\d+_X$', 'once');
	if ~isempty(m)
		target_prefix_list{end+1} = regexprep(cur_name, '_X$', '');
	end
end
target_prefix_list = unique(target_prefix_list, 'stable');

if isfield(json_struct, 'conf') && isfield(json_struct.conf, 'target_radius')
	target_radius = json_struct.conf.target_radius;
else
	target_radius = 0.03;
end



%% =======================
% Pre-collection gaze proportions (last 2 s) + grouped violin plots
% ========================
% This section does NOT overwrite triallog_table or record2D_table.
% It builds new tables: target_gaze_summary, gaze_long_table.

% --- defensive checks for required columns ---
req_triallog_cols = { ...
    'collection_num', 'trial_num', 'col_targ_id', ...
    'collected_by_A', 'collected_by_B', ...
    'collection_start_tick_idx', 'collection_end_tick_idx'};
req_record2D_cols = { ...
    'A_right_eye_on_target0', 'A_right_eye_on_target1', 'A_right_eye_on_target2'};

missing_triallog = setdiff(req_triallog_cols, triallog_table.Properties.VariableNames);
missing_record2D = setdiff(req_record2D_cols, record2D_table.Properties.VariableNames);

if ~isempty(missing_triallog)
    error('Missing required triallog columns: %s', strjoin(missing_triallog, ', '));
end
if ~isempty(missing_record2D)
    error('Missing required record2D columns: %s', strjoin(missing_record2D, ', '));
end

% --- constants from task logic ---
fs_hz = 120;                    % sampling rate
win_len_samples = 2 * fs_hz;    % 2 s = 240 samples

n_rows = height(triallog_table);

% preallocate
collection_num  = triallog_table.collection_num;
trial_num       = triallog_table.trial_num;
col_targ_id     = triallog_table.col_targ_id;
collected_by_A  = triallog_table.collected_by_A;
collected_by_B  = triallog_table.collected_by_B;

window_start_idx = nan(n_rows,1);
window_end_idx   = nan(n_rows,1);

n_samples_win = nan(n_rows,1);
target0_fix   = nan(n_rows,1);
target1_fix   = nan(n_rows,1);
target2_fix   = nan(n_rows,1);

prop_target0  = nan(n_rows,1);
prop_target1  = nan(n_rows,1);
prop_target2  = nan(n_rows,1);

selected_group = repmat("unclassified", n_rows, 1);

n_record2D = height(record2D_table);

for i = 1:n_rows
    c_start = triallog_table.collection_start_tick_idx(i);
    c_end   = triallog_table.collection_end_tick_idx(i);

    % skip invalid rows safely
    if isnan(c_start) || isnan(c_end)
        selected_group(i) = "unclassified";
        continue
    end

    % --- window definition from real task logic ---
    % end = collection_end_tick_idx
    % start = max(collection_start_tick_idx, collection_end_tick_idx - 240 + 1)
    w_end = round(c_end);
    w_start = max(round(c_start), round(c_end) - win_len_samples + 1);

    % clamp to valid record2D range
    w_start = max(1, w_start);
    w_end   = min(n_record2D, w_end);

    if w_end < w_start
        selected_group(i) = "unclassified";
        continue
    end

    window_start_idx(i) = w_start;
    window_end_idx(i)   = w_end;

    idx = w_start:w_end;
    n_samples_win(i) = numel(idx);

    % ensure logical/numeric consistency
    v0 = record2D_table.A_right_eye_on_target0(idx);
    v1 = record2D_table.A_right_eye_on_target1(idx);
    v2 = record2D_table.A_right_eye_on_target2(idx);

    target0_fix(i) = sum(v0 == 1, 'omitnan');
    target1_fix(i) = sum(v1 == 1, 'omitnan');
    target2_fix(i) = sum(v2 == 1, 'omitnan');

    if n_samples_win(i) > 0
        prop_target0(i) = target0_fix(i) / n_samples_win(i);
        prop_target1(i) = target1_fix(i) / n_samples_win(i);
        prop_target2(i) = target2_fix(i) / n_samples_win(i);
    end

	% --- grouping logic (task-corrected) ---
	% target mapping:
	%   col_targ_id == 0 : orange cooperative (joint)
	%   col_targ_id == 1 : blue competitive (single winner)
	%   col_targ_id == 2 : white competitive (single winner)

	if col_targ_id(i) == 0
		selected_group(i) = "orange_joint";

	elseif col_targ_id(i) == 1 && collected_by_A(i) == 1
		selected_group(i) = "blue_selected_by_monkey";

	elseif col_targ_id(i) == 1 && collected_by_B(i) == 1
		selected_group(i) = "blue_selected_by_human";

	elseif col_targ_id(i) == 2 && collected_by_A(i) == 1
		selected_group(i) = "white_selected_by_monkey";

	elseif col_targ_id(i) == 2 && collected_by_B(i) == 1
		selected_group(i) = "white_selected_by_human";

	else
		selected_group(i) = "unclassified";
	end

% --- wide summary table ---
target_gaze_summary = table( ...
    collection_num, ...
    trial_num, ...
    col_targ_id, ...
    collected_by_A, ...
    collected_by_B, ...
    selected_group, ...
    window_start_idx, ...
    window_end_idx, ...
    n_samples_win, ...
    target0_fix, ...
    target1_fix, ...
    target2_fix, ...
    prop_target0, ...
    prop_target1, ...
    prop_target2);

% --- long-format table ---
groups_col = selected_group;
n = height(target_gaze_summary);

gaze_long_table = table( ...
    [groups_col; groups_col; groups_col], ...
    [repmat("target0_orange", n, 1); repmat("target1_blue", n, 1); repmat("target2_white", n, 1)], ...
    [target_gaze_summary.prop_target0; target_gaze_summary.prop_target1; target_gaze_summary.prop_target2], ...
    'VariableNames', {'selected_group','gaze_target','fix_prop'});

% optional: drop unclassified and NaN before plotting
plot_table = gaze_long_table(gaze_long_table.selected_group ~= "unclassified" & ~isnan(gaze_long_table.fix_prop), :);

% enforce readable order
group_order = categorical([ ...
    "orange_joint", ...
    "blue_selected_by_monkey", ...
    "blue_selected_by_human", ...
    "white_selected_by_monkey", ...
    "white_selected_by_human"]);
plot_table.selected_group = categorical(plot_table.selected_group, categories(group_order), 'Ordinal', true);
plot_table.gaze_target = categorical(plot_table.gaze_target, ...
    ["target0_orange","target1_blue","target2_white"], 'Ordinal', true);

% --- plotting: preferred violin ---
figure('Name','Monkey gaze distribution: last 2 s before collection');
hold on;

% If violinplot exists, use it; otherwise fallback to boxchart+swarmchart.
if exist('violinplot','file') == 2
    % Use combined grouping labels so each group shows 3 targets
    combo = strcat(string(plot_table.selected_group), " | ", string(plot_table.gaze_target));
    violinplot(plot_table.fix_prop, combo);
    ylabel('Monkey gaze proportion in last 2 s before collection');
    title('Pre-collection monkey gaze proportions by selected target group');
    xtickangle(35);
else
    % fallback
    boxchart(plot_table.selected_group, plot_table.fix_prop, 'GroupByColor', plot_table.gaze_target);
    swarmchart(double(plot_table.selected_group), plot_table.fix_prop, 8, double(plot_table.gaze_target), 'filled', 'MarkerFaceAlpha', 0.25);
    ylabel('Monkey gaze proportion in last 2 s before collection');
    title('Pre-collection monkey gaze proportions by selected target group');
    legend('Location','bestoutside');
end

% target-color meaning text
annotation('textbox', [0.15 0.85 0.7 0.08], ...
    'String', 'target0 = orange, target1 = blue, target2 = white', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center');

hold off;

% --- required preview ---
disp(target_gaze_summary(1:min(10,height(target_gaze_summary)), :))
openvar('target_gaze_summary')



n_cycles = size(triallog_table, 1);
for i_cycle = 1 : n_cycles
		disp(['Processing cycle ']);
		cur_start_idx = triallog_table.collection_start_tick_idx(i_cycle);
		cur_end_idx   = triallog_table.collection_end_tick_idx(i_cycle);


		A_right_eye_fixations_in_cycle_idx = unique(record2D_table.A_right_eye_per_sample_fixID(cur_start_idx:cur_end_idx));
		A_right_eye_fixations_in_cycle_idx(A_right_eye_fixations_in_cycle_idx == 0) = [];

		cur_cycle_A_right_eye_fix_X = fixations_struct.A_right_eye.mean_X(A_right_eye_fixations_in_cycle_idx);
		cur_cycle_A_right_eye_fix_Y = fixations_struct.A_right_eye.mean_Y(A_right_eye_fixations_in_cycle_idx);


		A_left_eye_fixations_in_cycle_idx = unique(record2D_table.A_left_eye_per_sample_fixID(cur_start_idx:cur_end_idx));
		A_left_eye_fixations_in_cycle_idx(A_left_eye_fixations_in_cycle_idx == 0) = [];

		cur_cycle_A_left_eye_fix_X = fixations_struct.A_left_eye.mean_X(A_left_eye_fixations_in_cycle_idx);
		cur_cycle_A_left_eye_fix_Y = fixations_struct.A_left_eye.mean_Y(A_left_eye_fixations_in_cycle_idx);



		if ~isnan(cur_start_idx) && ~isnan(cur_end_idx)
			cycle_str = ['cycle', num2str(i_cycle, '%04.0f')];  % e.g. cycle0001

			cur_fh = figure('Name', cycle_str);

			set(cur_fh, 'Units', 'pixels', 'Position', [100 100 900 450]);
			% two horizontal panels: aims (left), agents (right)
			t = tiledlayout(cur_fh, 1, 3, ...
				'TileSpacing', 'compact', ...
				'Padding', 'compact');

			% **AIMS PART**
			ax_aims = nexttile(1);
			cla(ax_aims);
			hold(ax_aims, 'on');
			
			% Targets first (background)
			end_tick = cur_end_idx;
			for i_t = 1:numel(target_prefix_list)
				prefix = target_prefix_list{i_t};
				x_t = record2D_table.([prefix, '_X'])(end_tick);
				y_t = record2D_table.([prefix, '_Y'])(end_tick);
				id_col = [prefix, '_id'];
				if ismember(id_col, record2D_table.Properties.VariableNames)
					cur_id = record2D_table.(id_col)(end_tick);
				else
					cur_id = NaN;
				end
				if isnan(x_t) || isnan(y_t) || isnan(cur_id)
					continue
				end
				switch cur_id
					case 2   % competitive_targets
						face_col = [1 1 1];
					case 0
						face_col = [250 114 44] / 255;
					case 1
						face_col = [87 117 189] / 255;
					otherwise
						face_col = [0.8 0.8 0.8];
				end
				rectangle(ax_aims, ...
					'Position', [x_t - target_radius, y_t - target_radius, 2*target_radius, 2*target_radius], ...
					'Curvature', [1 1], ...
					'FaceColor', face_col, ...
					'EdgeColor', [0 0 0], ...
					'LineWidth', 1);
			end

			% trajectory indices and time-color coding
			k = cur_start_idx:cur_end_idx;
			nS = numel(k);
			idx = (0:nS-1)';
			idx_norm = idx ./ max(1, idx(end));
			nC = 256;
			cmap_time = parula(nC);
			c_idx = max(1, min(nC, 1 + floor(idx_norm * (nC-1))));
			step_mark = 25;
			is_mark = false(nS,1);
			is_mark(1:step_mark:end) = true;
			is_mark(end) = true;

			% pre-init legend handles
			h_aims0 = plot(ax_aims, NaN, NaN, 'o', 'Color', 'k');
			h_aims1 = plot(ax_aims, NaN, NaN, 's', 'Color', 'k');

			colormap(ax_aims, cmap_time);
			for i = 1:nS
				kk = k(i);
				cur_col = cmap_time(c_idx(i), :);
				if i > 1
					kk_prev = k(i-1);
					line(ax_aims, ...
						[record2D_table.aims0_X(kk_prev), record2D_table.aims0_X(kk)], ...
						[record2D_table.aims0_Y(kk_prev), record2D_table.aims0_Y(kk)], ...
						'Color', cur_col, 'LineWidth', 1.5, 'HandleVisibility', 'off');
					line(ax_aims, ...
						[record2D_table.aims1_X(kk_prev), record2D_table.aims1_X(kk)], ...
						[record2D_table.aims1_Y(kk_prev), record2D_table.aims1_Y(kk)], ...
						'Color', cur_col, 'LineWidth', 1.5, 'HandleVisibility', 'off', 'LineStyle', '--');
				end
				if is_mark(i)
					h_aims0 = scatter(ax_aims, record2D_table.aims0_X(kk), record2D_table.aims0_Y(kk), ...
						30, ...
						'Marker', 'o', ...
						'MarkerEdgeColor', 'k', ...
						'MarkerFaceColor', 'none');
					h_aims1 = scatter(ax_aims, record2D_table.aims1_X(kk), record2D_table.aims1_Y(kk), ...
						30, ...
						'Marker', '^', ...
						'MarkerEdgeColor', 'k', ...
						'MarkerFaceColor', 'none');
				end
			end
				% if is_mark(i)
				% 	h_aims0 = scatter(ax_aims, record2D_table.aims0_X(kk), record2D_table.aims0_Y(kk), ...
					% 	30, c_idx(i), 'filled', 'Marker', 'o', 'MarkerEdgeColor', 'k');
				% 	h_aims1 = scatter(ax_aims, record2D_table.aims1_X(kk), record2D_table.aims1_Y(kk), ...
					% 	30, c_idx(i), 'filled', 'Marker', 's', 'MarkerEdgeColor', 'k');
				% end
			axis(ax_aims, [0 1 0 1]); pbaspect(ax_aims, [1 1 1]);
			xticks(ax_aims, [0 0.5 1]); yticks(ax_aims, [0 0.5 1]);
			xlabel(ax_aims, 'x'); ylabel(ax_aims, 'y');
			if i_cycle > 1
				prev_x = triallog_table.col_targ_position_XY(i_cycle - 1, 1);
				prev_y = triallog_table.col_targ_position_XY(i_cycle - 1, 2);
				if ~isnan(prev_x) && ~isnan(prev_y)
					rectangle(ax_aims, ...
						'Position', [prev_x - target_radius, prev_y - target_radius, 2*target_radius, 2*target_radius], ...
						'Curvature', [1 1], ...
						'FaceColor', 'none', ...
						'EdgeColor', [0 0 0], ...
						'LineStyle', '--', ...
						'LineWidth', 1.5);
				end
			end
			title(ax_aims, ['AIMS - ' cycle_str], 'Interpreter', 'none');
			h_target_aims = plot(ax_aims, NaN, NaN, 'o', ...
				'MarkerFaceColor', [0.8 0.8 0.8], ...
				'MarkerEdgeColor', [0 0 0], ...
				'LineStyle', 'none');
			lgd_aims = legend(ax_aims, [h_aims0, h_aims1, h_target_aims], ...
				{'Aims0', 'Aims1', 'Targets'}, ...
				'Location', 'southoutside', ...
				'Orientation', 'vertical');
			lgd_aims.Box = 'off';
			lgd_aims.FontSize = 8;
			% **AGENTS PART**
			ax_agents = nexttile(2);
			cla(ax_agents);
			hold(ax_agents, 'on');
			
			% 1) TARGETS FIRST (background, same as before)
			for i_t = 1:numel(target_prefix_list)
    			prefix = target_prefix_list{i_t};
    			x_t = record2D_table.([prefix, '_X'])(end_tick);
    			y_t = record2D_table.([prefix, '_Y'])(end_tick);
    			id_col = [prefix, '_id'];
    			if ismember(id_col, record2D_table.Properties.VariableNames)
        			cur_id = record2D_table.(id_col)(end_tick);
    			else
        			cur_id = NaN;
    			end
			
    			if isnan(x_t) || isnan(y_t) || isnan(cur_id)
        			continue
    			end
			
    			switch cur_id
        			case 2
            			face_col = [1 1 1];              % white
        			case 0
            			face_col = [250 114 44] / 255;   % orange
        			case 1
            			face_col = [87 117 189] / 255;   % blue
        			otherwise
            			face_col = [0.8 0.8 0.8];        % fallback
    			end
			
    			rectangle(ax_agents, ...
        			'Position', [x_t - target_radius, y_t - target_radius, ...
                     			2*target_radius, 2*target_radius], ...
        			'Curvature', [1 1], ...
        			'FaceColor', face_col, ...
        			'EdgeColor', [0 0 0], ...
        			'LineWidth', 1);
			end
			colormap(ax_agents, cmap_time);

			% pre-init handles
			h_agent0 = plot(ax_agents, NaN, NaN, '+', 'Color', 'k');
			h_agent1 = plot(ax_agents, NaN, NaN, 'x', 'Color', 'k');

			for i = 1:nS
				kk = k(i);
				cur_col = cmap_time(c_idx(i), :);

				if i > 1
					kk_prev = k(i-1);
					line(ax_agents, ...
						[record2D_table.agent0_X(kk_prev), record2D_table.agent0_X(kk)], ...
						[record2D_table.agent0_Y(kk_prev), record2D_table.agent0_Y(kk)], ...
						'Color', cur_col, 'LineWidth', 1.5, 'HandleVisibility', 'off');
					line(ax_agents, ...
						[record2D_table.agent1_X(kk_prev), record2D_table.agent1_X(kk)], ...
						[record2D_table.agent1_Y(kk_prev), record2D_table.agent1_Y(kk)], ...
						'Color', cur_col, 'LineWidth', 1.5, 'HandleVisibility', 'off', 'LineStyle', '--');
				end

				if is_mark(i)
					h_agent0 = scatter(ax_agents, record2D_table.agent0_X(kk), record2D_table.agent0_Y(kk), ...
						30, ...
						'Marker', 'o', ...
						'MarkerEdgeColor', 'k', ...
						'MarkerFaceColor', 'none');
					h_agent1 = scatter(ax_agents, record2D_table.agent1_X(kk), record2D_table.agent1_Y(kk), ...
						30, ...
						'Marker', '^', ...
						'MarkerEdgeColor', 'k', ...
						'MarkerFaceColor', 'none');
				end
			end
			axis(ax_agents, [0 1 0 1]); pbaspect(ax_agents, [1 1 1]);
			xticks(ax_agents, [0 0.5 1]); yticks(ax_agents, [0 0.5 1]);
			xlabel(ax_agents, 'x'); ylabel(ax_agents, 'y');

			if i_cycle > 1
				prev_x = triallog_table.col_targ_position_XY(i_cycle - 1, 1);
				prev_y = triallog_table.col_targ_position_XY(i_cycle - 1, 2);
				if ~isnan(prev_x) && ~isnan(prev_y)
					rectangle(ax_agents, ...
						'Position', [prev_x - target_radius, prev_y - target_radius, 2*target_radius, 2*target_radius], ...
						'Curvature', [1 1], ...
						'FaceColor', 'none', ...
						'EdgeColor', [0 0 0], ...
						'LineStyle', '--', ...
						'LineWidth', 1.5);
				end
			end

			title(ax_agents, ['AGENTS - ' cycle_str], 'Interpreter', 'none');
			h_target_agents = plot(ax_agents, NaN, NaN, 'o', ...
				'MarkerFaceColor', [0.8 0.8 0.8], ...
				'MarkerEdgeColor', [0 0 0], ...
				'LineStyle', 'none');
			lgd_agents = legend(ax_agents, [h_agent0, h_agent1, h_target_agents], ...
				{'Agent0', 'Agent1', 'Targets'}, ...
				'Location', 'southoutside', ...
				'Orientation', 'vertical');
			lgd_agents.Box = 'off';
			lgd_agents.FontSize = 8;
			%Eyes plot
			ax_eyes = nexttile(3);
			cla(ax_eyes);
			hold(ax_eyes, 'on');
			end_tick = cur_end_idx;
			for i_t = 1:numel(target_prefix_list)
				prefix = target_prefix_list{i_t};
				x_t = record2D_table.([prefix, '_X'])(end_tick);
				y_t = record2D_table.([prefix, '_Y'])(end_tick);
				id_col = [prefix, '_id'];
				if ismember(id_col, record2D_table.Properties.VariableNames)
					cur_id = record2D_table.(id_col)(end_tick);
				else
					cur_id = NaN;
				end
				if isnan(x_t) || isnan(y_t) || isnan(cur_id)
					continue
				end
				switch cur_id
					case 2   % competitive_targets
						face_col = [1 1 1];
					case 0
						face_col = [250 114 44] / 255;
					case 1
						face_col = [87 117 189] / 255;
					otherwise
						face_col = [0.8 0.8 0.8];
				end
				rectangle(ax_eyes, ...
					'Position', [x_t - target_radius, y_t - target_radius, 2*target_radius, 2*target_radius], ...
					'Curvature', [1 1], ...
					'FaceColor', face_col, ...
					'EdgeColor', [0 0 0], ...
					'LineWidth', 1);
			end
			colormap(ax_eyes, cmap_time);
			% pre-init handles
			h_right_eye = plot(ax_eyes, NaN, NaN, 'x', 'Color', 'k');
			h_left_eye = plot(ax_eyes, NaN, NaN, '+', 'Color', 'k');
			for i = 1:nS
				kk = k(i);
				cur_col = cmap_time(c_idx(i), :);

				if i > 1
					kk_prev = k(i-1);
					line(ax_eyes, ...
						[record2D_table.A_right_eye_X(kk_prev), record2D_table.A_right_eye_X(kk)], ...
						[record2D_table.A_right_eye_Y(kk_prev), record2D_table.A_right_eye_Y(kk)], ...
						'Color', cur_col, 'LineWidth', 1.5, 'HandleVisibility', 'off');
					line(ax_eyes, ...
						[record2D_table.A_left_eye_X(kk_prev), record2D_table.A_left_eye_X(kk)], ...
						[record2D_table.A_left_eye_Y(kk_prev), record2D_table.A_left_eye_Y(kk)], ...
						'Color', cur_col, 'LineWidth', 1.5, 'HandleVisibility', 'off', 'LineStyle', ':');
				end
				if is_mark(i)
					%h_right_eye = scatter(ax_eyes, record2D_table.A_right_eye_X(kk), record2D_table.A_right_eye_Y(kk), ...
					%	30, c_idx(i), 'filled', 'Marker', 'x', 'MarkerEdgeColor', 'k');
					%h_left_eye = scatter(ax_eyes, record2D_table.A_left_eye_X(kk), record2D_table.A_left_eye_Y(kk), ...
					%	30, c_idx(i), 'filled', 'Marker', '+', 'MarkerEdgeColor', 'k');
				end
			end

			h_right_eye = scatter(ax_eyes, ...
				cur_cycle_A_right_eye_fix_X, cur_cycle_A_right_eye_fix_Y, ...
				30, ...
				'Marker', 'd', ...
				'MarkerEdgeColor', 'k', ...
				'MarkerFaceColor', 'none');
			h_left_eye = scatter(ax_eyes, ...
				cur_cycle_A_left_eye_fix_X,cur_cycle_A_left_eye_fix_Y, ...
				30, ...
				'Marker', 's', ...
				'MarkerEdgeColor', 'k', ...
				'MarkerFaceColor', 'none');
			axis(ax_eyes, [0 1 0 1]); pbaspect(ax_eyes, [1 1 1]);
			xticks(ax_eyes, [0 0.5 1]); yticks(ax_eyes, [0 0.5 1]);
			xlabel(ax_eyes, 'x'); ylabel(ax_eyes, 'y');

			if i_cycle > 1
				prev_x = triallog_table.col_targ_position_XY(i_cycle - 1, 1);
				prev_y = triallog_table.col_targ_position_XY(i_cycle - 1, 2);
				if ~isnan(prev_x) && ~isnan(prev_y)
					rectangle(ax_eyes, ...
						'Position', [prev_x - target_radius, prev_y - target_radius, 2*target_radius, 2*target_radius], ...
						'Curvature', [1 1], ...
						'FaceColor', 'none', ...
						'EdgeColor', [0 0 0], ...
						'LineStyle', '--', ...
						'LineWidth', 1.5);
				end
			end

			title(ax_eyes, ['EYES - ' cycle_str], 'Interpreter', 'none');
			h_target_eyes = plot(ax_eyes, NaN, NaN, 'o', ...
				'MarkerFaceColor', [0.8 0.8 0.8], ...
				'MarkerEdgeColor', [0 0 0], ...
				'LineStyle', 'none');
			lgd_eyes = legend(ax_eyes, [h_right_eye, h_left_eye, h_target_eyes], ...
				{'Right', 'Left', 'Targets'}, ...
				'Location', 'southoutside', ...
				'Orientation', 'vertical', ...
				'Interpreter', 'none');
			lgd_eyes.Box = 'off';
			lgd_eyes.FontSize = 8;

			cb = colorbar(ax_eyes);
			cb.Label.String = 'time within cycle (sample order)';
			cb.Location = 'eastoutside';
			% keep both panels perfectly consistent when zooming
			linkaxes([ax_aims, ax_agents, ax_eyes], 'xy');
			% save pdf and close
			outfile_fqn = fullfile(cur_CCF_runfolder_FQN, 'figures', ...
				['cycle_', num2str(i_cycle, '%04.0f'), '.pdf']);
			if ~isfolder(fileparts(outfile_fqn))
				mkdir(fileparts(outfile_fqn));
			end

			% configure paper size/orientation and let print scale to fit
			set(cur_fh, 'PaperUnits', 'centimeters');
			set(cur_fh, 'PaperOrientation', 'landscape');
			set(cur_fh, 'PaperPosition', [0 0 28 14]);   % width x height on page
			set(cur_fh, 'PaperSize',     [28 14]);
			print(cur_fh, outfile_fqn, '-dpdf', '-painters');
			close(cur_fh);
		end
end
end





