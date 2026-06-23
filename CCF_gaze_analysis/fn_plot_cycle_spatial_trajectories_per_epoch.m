function [plot_fh_list] = fn_plot_cycle_spatial_trajectories_per_epoch( ...
	record2D_table, ...
	triallog_table, ...
	per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray, ...
	short_all_epoch_name_list, ...
	valid_gaze_sample_ldx, ...
	face_ROI, ...
	target_prefix_list, ...
	target_radius, ...
	source_stem_regexp_list, ...
	plotting_options_struct, ...
	sorted_epoch_list, ...
	field_X_lim, ...
	field_Y_lim, ...
	aggregation_type_string, ...
	out_dir, ...
	sessionID_cycle_plot_ldx, ...
	source_row_name_list, ...
	gaze_on_object_prop_count_table, ...
	goopc_table_cycle_key_list, ...
	goopc_pct_col_regexp_list, ...
	goopc_bar_vergence_list)
%FN_PLOT_CYCLE_SPATIAL_TRAJECTORIES_PER_EPOCH
% One tiled figure per sessionID x cycle with epoch columns and source rows.
%
% source_stem_regexp_list defines one row per cell element. Each regexp is
% matched against record2D_table.Properties.VariableNames for _X columns;
% the paired _Y column is selected by replacing the trailing _X with _Y.
% Example:
%   {'^aims[01]_X$', '^agent[01]_X$', '^[AB]_binocular_eye_X$'}
% resolves to rows with stems {aims0, aims1}, {agent0, agent1},
% {A_binocular_eye, B_binocular_eye} when present.
%
% Rows with no matching stems in record2D are omitted for that call.
% Gaze-like rows (all matched stems contain '_eye') use valid_gaze_sample_ldx;
% other rows plot all epoch ticks (shown == valid).
%
% Optional goopc bar row (bottom): goopc_pct_col_regexp_list matches
% gaze_on_object_prop_count_table.Properties.VariableNames (_PCT columns).
% Row lookup uses goopc_table_cycle_key_list + epoch + goopc_bar_vergence_list
% (one grouped bar per vergence when numel > 1).

plot_fh_list = [];

if isempty(per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray)
	return
end

if ~exist('sorted_epoch_list', 'var') || isempty(sorted_epoch_list)
	sorted_epoch_list = short_all_epoch_name_list;
end
if ~exist('field_X_lim', 'var') || isempty(field_X_lim)
	field_X_lim = [-0.1, 1.1];
end
if ~exist('field_Y_lim', 'var') || isempty(field_Y_lim)
	field_Y_lim = [-0.1, 1.1];
end
if ~exist('aggregation_type_string', 'var') || isempty(aggregation_type_string)
	aggregation_type_string = 'unspecified_aggregation';
end
if ~exist('sessionID_cycle_plot_ldx', 'var')
	sessionID_cycle_plot_ldx = [];
end
if ~exist('source_row_name_list', 'var')
	source_row_name_list = {};
end
if ~exist('source_stem_regexp_list', 'var') || isempty(source_stem_regexp_list)
	source_stem_regexp_list = {'^aims[01]_X$', '^agent[01]_X$', '^[AB]_binocular_eye_X$'};
end
if ~exist('gaze_on_object_prop_count_table', 'var')
	gaze_on_object_prop_count_table = [];
end
if ~exist('goopc_table_cycle_key_list', 'var')
	goopc_table_cycle_key_list = [];
end
if ~exist('goopc_pct_col_regexp_list', 'var')
	goopc_pct_col_regexp_list = {};
end
if ~exist('goopc_bar_vergence_list', 'var') || isempty(goopc_bar_vergence_list)
	goopc_bar_vergence_list = {'nearFixations', 'farFixations'};
end
if ischar(goopc_bar_vergence_list) || isstring(goopc_bar_vergence_list)
	goopc_bar_vergence_list = cellstr(goopc_bar_vergence_list);
end
goopc_bar_vergence_list = goopc_bar_vergence_list(:)';

active_source_row_struct_arr = fn_local_resolve_source_rows( ...
	record2D_table, source_stem_regexp_list, source_row_name_list);
if isempty(active_source_row_struct_arr)
	disp([mfilename, ': WARN: no source rows resolved from source_stem_regexp_list; skipping spatial cycle plots.']);
	return
end


n_requested_cycles = sum(sessionID_cycle_plot_ldx);


resolved_goopc_pct_col_list = {};
if ~isempty(gaze_on_object_prop_count_table) && ~isempty(goopc_pct_col_regexp_list)
	resolved_goopc_pct_col_list = fn_local_resolve_goopc_pct_cols( ...
		gaze_on_object_prop_count_table, goopc_pct_col_regexp_list);
end

add_gaze_prop_bar_row = ~isempty(resolved_goopc_pct_col_list) && ~isempty(goopc_table_cycle_key_list);
if add_gaze_prop_bar_row && numel(goopc_table_cycle_key_list) ~= height(gaze_on_object_prop_count_table)
	disp([mfilename, ': WARN: goopc_table_cycle_key_list length does not match gaze_on_object_prop_count_table rows; disabling goopc bar row.']);
	add_gaze_prop_bar_row = false;
end

sessionID_cycle_key_list = fn_local_collect_sessionID_cycle_keys(per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray);
if isempty(sessionID_cycle_key_list)
	return
end

% we can only select existing key indices...
sessionID_cycle_plot_ldx(find(sessionID_cycle_plot_ldx > numel(sessionID_cycle_key_list))) = [];


sessionID_cycle_key_list = fn_local_select_sessionID_cycle_keys(sessionID_cycle_key_list, sessionID_cycle_plot_ldx);
if isempty(sessionID_cycle_key_list)
	return
end

n_requested_cycles = length(sessionID_cycle_key_list);


trace_colormap_name_list = {'autumn', 'winter'};

n_source_rows = numel(active_source_row_struct_arr);
n_tile_rows = n_source_rows + add_gaze_prop_bar_row;
n_epoch_cols = numel(sorted_epoch_list);

% spatial_out_dir = fullfile(out_dir, aggregation_type_string, 'per_cycle_spatial');
% if ~isfolder(spatial_out_dir)
% 	mkdir(spatial_out_dir);
% end
% the caller needs to make sure this is where the figures should be saved
% to
spatial_out_dir = out_dir;

autoclose_message_counter = 0;

for i_sessionID_cycle = 1 : numel(sessionID_cycle_key_list)
	cur_sessionID_cycle_key = sessionID_cycle_key_list{i_sessionID_cycle};
	cur_cycle_ref_tick_idx = fn_local_get_cycle_ref_tick_idx( ...
		per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray, cur_sessionID_cycle_key);
	if isempty(cur_cycle_ref_tick_idx)
		continue
	end

	cur_goopc_pct_x_label_list = fn_local_resolve_goopc_pct_col_labels( ...
		resolved_goopc_pct_col_list, record2D_table, cur_cycle_ref_tick_idx);

	cur_fh = figure( ...
		'Name', ['cycle_spatial_', aggregation_type_string, '_', cur_sessionID_cycle_key], ...
		'visible', plotting_options_struct.figure_visibility_string);
	plot_fh_list(end+1) = cur_fh; %#ok<AGROW>

	plot_width_cm = plotting_options_struct.panel_width_cm * n_epoch_cols;
	plot_height_cm = plotting_options_struct.panel_height_cm * n_tile_rows;
	fn_set_figure_outputpos_and_size(cur_fh, plotting_options_struct.margin_cm, plotting_options_struct.margin_cm, plot_width_cm, plot_height_cm, 1.0, 'portrait', 'inch');

	cur_tl = tiledlayout(cur_fh, n_tile_rows, n_epoch_cols, 'TileSpacing', 'Compact', 'Padding', 'Compact');

	for i_col = 1 : n_epoch_cols
		cur_epoch_name = sorted_epoch_list{i_col};
		cur_epoch_idx = find(ismember(short_all_epoch_name_list, {cur_epoch_name}), 1, 'first');
		if isempty(cur_epoch_idx)
			continue
		end

		cur_epoch_tick_ldx = strcmp( ...
			per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray(:, cur_epoch_idx), ...
			cur_sessionID_cycle_key);
		cur_tick_idx_list = find(cur_epoch_tick_ldx);
		n_valid_epoch_samples = numel(cur_tick_idx_list);

		for i_row = 1 : n_source_rows
			cur_source_row = active_source_row_struct_arr(i_row);
			cur_tile_idx = ((i_row - 1) * n_epoch_cols) + i_col;
			cur_ah = nexttile(cur_tl, cur_tile_idx);

			if isempty(cur_tick_idx_list)
				axis(cur_ah, 'off');
				continue
			end

			fn_local_draw_playing_field_and_overlays( ...
				cur_ah, record2D_table, triallog_table, cur_sessionID_cycle_key, ...
				cur_cycle_ref_tick_idx, target_prefix_list, target_radius, ...
				face_ROI, plotting_options_struct, field_X_lim, field_Y_lim);

			if cur_source_row.use_gaze_valid_ldx
				cur_valid_sample_ldx = valid_gaze_sample_ldx;
			else
				cur_valid_sample_ldx = [];
			end

			fn_local_plot_source_row_traces( ...
				cur_ah, record2D_table, cur_tick_idx_list, ...
				cur_source_row.stem_list, trace_colormap_name_list, cur_valid_sample_ldx);

			cur_subtitle_string = fn_local_format_panel_sample_subtitle( ...
				cur_source_row.stem_list, record2D_table, cur_tick_idx_list, ...
				cur_valid_sample_ldx, n_valid_epoch_samples);

			if i_row == 1
				title(cur_ah, cur_epoch_name, 'Interpreter', 'none', 'FontSize', plotting_options_struct.titlefontsize);
			end
			subtitle(cur_ah, cur_subtitle_string, ...
				'Interpreter', 'none', 'FontSize', plotting_options_struct.subtitlefontsize);

			if i_col == 1
				ylabel(cur_ah, cur_source_row.row_name, 'Interpreter', 'none', 'FontSize', plotting_options_struct.labelfontsize);
			end
		end
	end

	if add_gaze_prop_bar_row
		cur_gaze_prop_bar_row = n_source_rows + 1;
		for i_col = 1 : n_epoch_cols
			cur_epoch_name = sorted_epoch_list{i_col};
			cur_tile_idx = ((cur_gaze_prop_bar_row - 1) * n_epoch_cols) + i_col;
			cur_ah = nexttile(cur_tl, cur_tile_idx);

			cur_show_vergence_legend = (i_col == 1) && (numel(goopc_bar_vergence_list) > 1);

			[cur_has_bar_data, cur_bar_subtitle_string] = fn_local_plot_gaze_prop_bar_panel( ...
				cur_ah, gaze_on_object_prop_count_table, goopc_table_cycle_key_list, ...
				resolved_goopc_pct_col_list, cur_goopc_pct_x_label_list, ...
				triallog_table, cur_sessionID_cycle_key, cur_epoch_name, ...
				goopc_bar_vergence_list, plotting_options_struct, cur_show_vergence_legend);

			if ~cur_has_bar_data
				axis(cur_ah, 'off');
				continue
			end

			if i_col == 1
				ylabel(cur_ah, 'gaze_% goopc', 'Interpreter', 'none', 'FontSize', plotting_options_struct.labelfontsize);
			end
			subtitle(cur_ah, cur_bar_subtitle_string, ...
				'Interpreter', 'none', 'FontSize', plotting_options_struct.subtitlefontsize);
		end
	end

	if ~add_gaze_prop_bar_row
		xlabel(cur_tl, 'X [rel.]', 'Interpreter', 'none', 'FontSize', plotting_options_struct.labelfontsize);
	end
	ylabel(cur_tl, 'Y [rel.]', 'Interpreter', 'none', 'FontSize', plotting_options_struct.labelfontsize);
	title(cur_tl, ['Spatial trajectories (', aggregation_type_string, '): ', strrep(cur_sessionID_cycle_key, '_', ' cycle ')], ...
		'Interpreter', 'none', 'FontSize', plotting_options_struct.titlefontsize + 2);

	cur_out_FQN = fullfile(spatial_out_dir, ['cycle_spatial.', cur_sessionID_cycle_key, '.tiled.pdf']);
	write_out_figure(cur_fh, cur_out_FQN, [], [], plotting_options_struct.format_string_list);

	% otherwise these accumulate in memory and clog up everything, maybe consider doing this if the number of requested cycles exceeds, say 20?
	max_open_figures = 20;
	if strcmp(plotting_options_struct.figure_visibility_string, 'off') || n_requested_cycles > (max_open_figures)
		if n_requested_cycles > (max_open_figures) & autoclose_message_counter == 0
			disp([mfilename, ': INFO: automatically closing as we requested more than ', num2str(max_open_figures), ' figures.']);
		end
		close(cur_fh);
		autoclose_message_counter = autoclose_message_counter + 1;
	end

end

end


function active_source_row_struct_arr = fn_local_resolve_source_rows(record2D_table, source_stem_regexp_list, source_row_name_list)
active_source_row_struct_arr = struct('regexp_string', {}, 'row_name', {}, 'stem_list', {}, 'use_gaze_valid_ldx', {});

for i_row = 1 : numel(source_stem_regexp_list)
	cur_regexp = source_stem_regexp_list{i_row};
	cur_stem_list = fn_local_match_position_stems(record2D_table, cur_regexp);
	if isempty(cur_stem_list)
		continue
	end

	cur_row_name = fn_local_get_source_row_name(source_row_name_list, i_row, cur_regexp, cur_stem_list);
	cur_use_gaze_valid_ldx = fn_local_row_uses_gaze_valid(cur_stem_list);

	active_source_row_struct_arr(end+1) = struct( ... %#ok<AGROW>
		'regexp_string', cur_regexp, ...
		'row_name', cur_row_name, ...
		'stem_list', {cur_stem_list}, ...
		'use_gaze_valid_ldx', cur_use_gaze_valid_ldx);
end
end


function stem_list = fn_local_match_position_stems(record2D_table, x_col_regexp)
col_name_list = record2D_table.Properties.VariableNames;
x_col_match_ldx = ~cellfun(@isempty, regexp(col_name_list, x_col_regexp, 'once'));
matched_x_col_list = col_name_list(x_col_match_ldx);

stem_list = {};
for i_x_col = 1 : numel(matched_x_col_list)
	cur_x_col = matched_x_col_list{i_x_col};
	cur_y_col = regexprep(cur_x_col, '_X$', '_Y');
	if ~ismember(cur_y_col, col_name_list)
		continue
	end
	cur_stem = regexprep(cur_x_col, '_X$', '');
	stem_list{end+1} = cur_stem; %#ok<AGROW>
end

stem_list = unique(stem_list, 'stable');
end


function row_name = fn_local_get_source_row_name(source_row_name_list, row_idx, stem_regexp, stem_list)
if ~isempty(source_row_name_list) && numel(source_row_name_list) >= row_idx && ~isempty(source_row_name_list{row_idx})
	row_name = source_row_name_list{row_idx};
else
	row_name = strjoin(stem_list, ', ');
	if isempty(row_name)
		row_name = stem_regexp;
	end
end
end


function use_gaze_valid_ldx = fn_local_row_uses_gaze_valid(stem_list)
use_gaze_valid_ldx = ~isempty(stem_list) ...
	&& all(~cellfun(@isempty, regexp(stem_list, '_eye', 'once')));
end


function sessionID_cycle_key_list = fn_local_collect_sessionID_cycle_keys(per_state_cellarray)
all_keys = per_state_cellarray(:);
valid_key_ldx = ~strcmp(all_keys, 'EXCLUDE') & ~cellfun(@isempty, all_keys);
sessionID_cycle_key_list = unique(all_keys(valid_key_ldx), 'stable');
end


function selected_key_list = fn_local_select_sessionID_cycle_keys(sessionID_cycle_key_list, sessionID_cycle_plot_ldx)
if isempty(sessionID_cycle_plot_ldx)
	selected_key_list = sessionID_cycle_key_list;
	return
end

n_keys = numel(sessionID_cycle_key_list);
if islogical(sessionID_cycle_plot_ldx)
	if numel(sessionID_cycle_plot_ldx) ~= n_keys
		error([mfilename, ': ERROR: logical sessionID_cycle_plot_ldx must match number of unique sessionID_cycle keys (', num2str(n_keys), ').']);
	end
	selected_key_list = sessionID_cycle_key_list(sessionID_cycle_plot_ldx);
elseif isnumeric(sessionID_cycle_plot_ldx)
	cur_idx_list = sessionID_cycle_plot_ldx(:)';
	if any(cur_idx_list < 1) || any(cur_idx_list > n_keys)
		error([mfilename, ': ERROR: numeric sessionID_cycle_plot_ldx out of range for ', num2str(n_keys), ' unique sessionID_cycle keys.']);
	end
	selected_key_list = sessionID_cycle_key_list(cur_idx_list);
else
	error([mfilename, ': ERROR: sessionID_cycle_plot_ldx must be logical or numeric.']);
end
end


function ref_tick_idx = fn_local_get_cycle_ref_tick_idx(per_state_cellarray, sessionID_cycle_key)
cycle_tick_ldx = false(size(per_state_cellarray, 1), 1);
for i_col = 1 : size(per_state_cellarray, 2)
	cycle_tick_ldx = cycle_tick_ldx | strcmp(per_state_cellarray(:, i_col), sessionID_cycle_key);
end
cur_tick_idx_list = find(cycle_tick_ldx);
if isempty(cur_tick_idx_list)
	ref_tick_idx = [];
else
	ref_tick_idx = cur_tick_idx_list(1);
end
end


function fn_local_draw_playing_field_and_overlays(cur_ah, record2D_table, triallog_table, sessionID_cycle_key, ref_tick_idx, target_prefix_list, target_radius, face_ROI, plotting_options_struct, field_X_lim, field_Y_lim)
hold(cur_ah, 'on');

plot(cur_ah, [0 1 1 0 0], [0 0 1 1 0], 'Color', [0 0 0], 'LineWidth', 1, 'HandleVisibility', 'off');

fn_local_draw_previous_cycle_selected_target( ...
	cur_ah, triallog_table, sessionID_cycle_key, target_radius, plotting_options_struct);

for i_target = 1 : numel(target_prefix_list)
	cur_prefix = target_prefix_list{i_target};
	cur_x_col = [cur_prefix, '_X'];
	cur_y_col = [cur_prefix, '_Y'];
	cur_id_col = [cur_prefix, '_id'];
	if ~all(ismember({cur_x_col, cur_y_col, cur_id_col}, record2D_table.Properties.VariableNames))
		continue
	end

	cur_x = record2D_table.(cur_x_col)(ref_tick_idx);
	cur_y = record2D_table.(cur_y_col)(ref_tick_idx);
	cur_target_id = record2D_table.(cur_id_col)(ref_tick_idx);
	if ~isfinite(cur_x) || ~isfinite(cur_y) || ~isfinite(cur_target_id)
		continue
	end

	cur_color_name = fn_local_target_id_to_color_name(cur_target_id);
	cur_face_color = fn_local_get_color_from_struct(plotting_options_struct.color_struct, cur_color_name, [0.8, 0.8, 0.8]);

	rectangle(cur_ah, ...
		'Position', [cur_x - target_radius, cur_y - target_radius, 2 * target_radius, 2 * target_radius], ...
		'Curvature', [1, 1], ...
		'FaceColor', cur_face_color, ...
		'EdgeColor', [0, 0, 0], ...
		'LineWidth', 1, ...
		'HandleVisibility', 'off');
end

if ismember('B_facecenter_X', record2D_table.Properties.VariableNames) ...
		&& ismember('B_facecenter_Y', record2D_table.Properties.VariableNames)
	cur_face_x = record2D_table.B_facecenter_X(ref_tick_idx);
	cur_face_y = record2D_table.B_facecenter_Y(ref_tick_idx);
	if isfinite(cur_face_x) && isfinite(cur_face_y)
		cur_vh = viscircles(cur_ah, [cur_face_x, cur_face_y], face_ROI.radius, ...
			'Color', [0.7, 0.7, 0.7], 'LineWidth', 1);
		set(cur_vh, 'HandleVisibility', 'off');
	end
end

axis(cur_ah, 'equal');
set(cur_ah, 'XLim', field_X_lim, 'YLim', field_Y_lim);
box(cur_ah, 'off');
hold(cur_ah, 'off');
end


function fn_local_draw_previous_cycle_selected_target(cur_ah, triallog_table, sessionID_cycle_key, target_radius, plotting_options_struct)
[prev_x, prev_y, prev_target_id] = fn_local_lookup_previous_cycle_selected_target(triallog_table, sessionID_cycle_key);
if ~isfinite(prev_x) || ~isfinite(prev_y) || ~isfinite(prev_target_id)
	return
end

cur_color_name = fn_local_target_id_to_color_name(prev_target_id);
cur_face_color = fn_local_get_color_from_struct(plotting_options_struct.color_struct, cur_color_name, [0.8, 0.8, 0.8]);
blended_face_color = (0.5 * cur_face_color) + (0.5 * [1, 1, 1]);

theta = linspace(0, 2 * pi, 64);
x_circ = prev_x + (target_radius * cos(theta));
y_circ = prev_y + (target_radius * sin(theta));
patch(cur_ah, x_circ, y_circ, blended_face_color, ...
	'EdgeColor', cur_face_color, ...
	'LineStyle', '--', ...	% : ends up having too small line segments
	'LineWidth', 1, ...
	'HandleVisibility', 'off');
end


function [prev_x, prev_y, prev_target_id] = fn_local_lookup_previous_cycle_selected_target(triallog_table, sessionID_cycle_key)
prev_x = nan;
prev_y = nan;
prev_target_id = nan;

if isempty(triallog_table) || ~ismember('col_targ_position_XY', triallog_table.Properties.VariableNames)
	return
end

[triallog_cycle_key_list, ~, ~, ~, ~] = fn_generate_key_from_selected_table_columns_CCF( ...
	{'sessionID', 'trial_num'}, triallog_table, '_');
cur_row_idx = find(strcmp(triallog_cycle_key_list, sessionID_cycle_key), 1, 'first');
if isempty(cur_row_idx)
	return
end

cur_sessionID = triallog_table.sessionID(cur_row_idx);
cur_cycle = triallog_table.trial_num(cur_row_idx);
prev_row_idx = find(strcmp(triallog_table.sessionID, cur_sessionID) & triallog_table.trial_num == (cur_cycle - 1), 1, 'first');
if isempty(prev_row_idx)
	return
end

prev_x = triallog_table.col_targ_position_XY(prev_row_idx, 1);
prev_y = triallog_table.col_targ_position_XY(prev_row_idx, 2);
if ismember('col_targ_id', triallog_table.Properties.VariableNames)
	prev_target_id = triallog_table.col_targ_id(prev_row_idx);
end
end


function [has_data, subtitle_string] = fn_local_plot_gaze_prop_bar_panel( ...
	cur_ah, gaze_on_object_prop_count_table, goopc_table_cycle_key_list, ...
	pct_col_list, x_tick_label_list, triallog_table, sessionID_cycle_key, epoch_name, ...
	vergence_list, plotting_options_struct, show_vergence_legend)
has_data = false;
subtitle_string = '';

if ~exist('show_vergence_legend', 'var')
	show_vergence_legend = false;
end

if isempty(pct_col_list) || isempty(vergence_list)
	return
end

n_vergence = numel(vergence_list);
bar_mat = nan(numel(pct_col_list), n_vergence);
total_N_vec = nan(1, n_vergence);

for i_v = 1 : n_vergence
	goopc_row_idx = fn_local_lookup_goopc_row_idx( ...
		gaze_on_object_prop_count_table, goopc_table_cycle_key_list, ...
		sessionID_cycle_key, epoch_name, vergence_list{i_v});
	if isempty(goopc_row_idx)
		continue
	end

	if ismember('total_N', gaze_on_object_prop_count_table.Properties.VariableNames)
		total_N_vec(i_v) = gaze_on_object_prop_count_table.total_N(goopc_row_idx);
	end

	for i_col = 1 : numel(pct_col_list)
		if ismember(pct_col_list{i_col}, gaze_on_object_prop_count_table.Properties.VariableNames)
			bar_mat(i_col, i_v) = gaze_on_object_prop_count_table.(pct_col_list{i_col})(goopc_row_idx);
		end
	end
end

if ~any(isfinite(bar_mat(:)))
	return
end

has_data = true;
hold(cur_ah, 'on');

cur_color_struct = [];
if isfield(plotting_options_struct, 'color_struct') && ~isempty(plotting_options_struct.color_struct)
	cur_color_struct = plotting_options_struct.color_struct;
end
object_colors = fn_local_get_goopc_bar_object_colors( ...
	pct_col_list, triallog_table, sessionID_cycle_key, cur_color_struct);

if n_vergence == 1
	cur_bh = bar(cur_ah, bar_mat(:, 1), 0.8);
	fn_local_apply_goopc_bar_vergence_style(cur_bh, vergence_list{1}, object_colors);
else
	cur_bh = bar(cur_ah, bar_mat, 'grouped');
	for i_v = 1 : n_vergence
		fn_local_apply_goopc_bar_vergence_style(cur_bh(i_v), vergence_list{i_v}, object_colors);
	end
	if show_vergence_legend && (n_vergence > 1)
		cur_legend_labels = cellfun(@fn_local_vergence_to_legend_label, vergence_list, 'UniformOutput', false);
		cur_lh = legend(cur_ah, cur_legend_labels, 'Location', 'northeast', 'Box', 'off', ...
			'Interpreter', 'none', 'FontSize', plotting_options_struct.labelfontsize, ...
			'TextColor', [0.2, 0.2, 0.2]);
		if ~isempty(cur_lh)
			cur_lh.Color = 'none';
		end
	end
end

set(cur_ah, ...
	'XTick', 1 : numel(x_tick_label_list), ...
	'XTickLabel', x_tick_label_list, ...
	'XTickLabelRotation', 60, ...
	'TickLabelInterpreter', 'none', ...
	'YLim', [0, 100], ...
	'Box', 'off');
hold(cur_ah, 'off');

subtitle_parts = cell(1, n_vergence);
for i_v = 1 : n_vergence
	cur_leg = fn_local_vergence_to_legend_label(vergence_list{i_v});
	if isfinite(total_N_vec(i_v))
		subtitle_parts{i_v} = sprintf('%s N=%g', cur_leg, total_N_vec(i_v));
	else
		subtitle_parts{i_v} = sprintf('%s N=na', cur_leg);
	end
end
subtitle_string = ['goopc ', strjoin(subtitle_parts, ', ')];
end


function goopc_row_idx = fn_local_lookup_goopc_row_idx( ...
	gaze_on_object_prop_count_table, goopc_table_cycle_key_list, sessionID_cycle_key, epoch_name, vergence_string)
goopc_row_idx = [];

if isempty(gaze_on_object_prop_count_table) || isempty(goopc_table_cycle_key_list)
	return
end

row_ldx = strcmp(goopc_table_cycle_key_list, sessionID_cycle_key) ...
	& strcmp(gaze_on_object_prop_count_table.epoch, epoch_name);

if ismember('vergence', gaze_on_object_prop_count_table.Properties.VariableNames) ...
		&& ~isempty(vergence_string)
	row_ldx = row_ldx & strcmp(gaze_on_object_prop_count_table.vergence, vergence_string);
end

goopc_row_idx = find(row_ldx, 1, 'first');
end


function [pct_col_list] = fn_local_resolve_goopc_pct_cols(gaze_on_object_prop_count_table, goopc_pct_col_regexp_list)
pct_col_list = {};

if isempty(gaze_on_object_prop_count_table) || isempty(goopc_pct_col_regexp_list)
	return
end

all_col_name_list = gaze_on_object_prop_count_table.Properties.VariableNames;
candidate_pct_col_ldx = ~cellfun(@isempty, regexp(all_col_name_list, '_PCT$', 'once'));
candidate_pct_col_list = all_col_name_list(candidate_pct_col_ldx);

for i_regexp = 1 : numel(goopc_pct_col_regexp_list)
	cur_regexp = goopc_pct_col_regexp_list{i_regexp};
	cur_match_ldx = ~cellfun(@isempty, regexp(candidate_pct_col_list, cur_regexp, 'once'));
	cur_matched_cols = candidate_pct_col_list(cur_match_ldx);
	for i_col = 1 : numel(cur_matched_cols)
		if ~ismember(cur_matched_cols{i_col}, pct_col_list)
			pct_col_list{end+1} = cur_matched_cols{i_col}; %#ok<AGROW>
		end
	end
end
end


function x_tick_label_list = fn_local_resolve_goopc_pct_col_labels(pct_col_list, record2D_table, ref_tick_idx)
x_tick_label_list = cell(size(pct_col_list));

for i_col = 1 : numel(pct_col_list)
	x_tick_label_list{i_col} = fn_local_goopc_pct_col_to_short_label( ...
		pct_col_list{i_col}, record2D_table, ref_tick_idx);
end
end


function short_label = fn_local_goopc_pct_col_to_short_label(pct_col_name, record2D_table, ref_tick_idx)
short_label = pct_col_name;
short_label = regexprep(short_label, '_PCT$', '');
tok = regexp(short_label, '_on_(.+)$', 'tokens', 'once');
if isempty(tok)
	return
end

if iscell(tok{1})
	cur_object_stem = tok{1}{1};
else
	cur_object_stem = tok{1};
end

target_digit_match = regexp(cur_object_stem, '^target(\d+)$', 'tokens', 'once');
if ~isempty(target_digit_match)
	cur_id_col = [cur_object_stem, '_id'];
	if ismember(cur_id_col, record2D_table.Properties.VariableNames) ...
			&& ref_tick_idx >= 1 && ref_tick_idx <= height(record2D_table)
		cur_target_id = record2D_table.(cur_id_col)(ref_tick_idx);
		if isfinite(cur_target_id)
			short_label = fn_local_target_id_to_goopc_short_label(cur_target_id);
		else
			short_label = ['t', target_digit_match{1}, '?'];
		end
	else
		short_label = ['t', target_digit_match{1}, '?'];
	end
	return
end

short_label = fn_local_goopc_object_stem_to_short_label(cur_object_stem);
end


function short_label = fn_local_goopc_object_stem_to_short_label(object_stem)
switch object_stem
	case 'B_facecenter'
		short_label = 'face';
	case 'aims0'
		short_label = 'handA';
	case 'aims1'
		short_label = 'handB';
	otherwise
		short_label = object_stem;
end
end


function short_label = fn_local_target_id_to_goopc_short_label(target_id)
switch target_id
	case 0
		short_label = 'coopA';
	case 1
		short_label = 'coopB';
	case 2
		short_label = 'comp';
	case 3
		short_label = 'pun';
	case 4
		short_label = 'soloA1';
	case 5
		short_label = 'soloA2';
	otherwise
		short_label = sprintf('id%d', target_id);
end
end


function leg_label = fn_local_vergence_to_legend_label(vergence_string)
leg_label = regexprep(vergence_string, 'Fixations$', '');
end


function fn_local_apply_goopc_bar_vergence_style(cur_bh, vergence_string, object_colors)
% Per-object colors from color_struct; face/edge pattern by vergence stratum.
%   nearFixations : white fill, colored edge
%   farFixations  : colored fill, white edge
%   allFixations  : colored fill and edge
%   (other)       : colored fill, no edge

cur_white = [1, 1, 1];
cur_bar_line_width = 1;

switch vergence_string
	case 'nearFixations'
		cur_bh.FaceColor = cur_white;
		cur_bh.EdgeColor = 'flat';
		cur_bh.CData = object_colors;
		cur_bh.LineWidth = cur_bar_line_width;

	case 'farFixations'
		cur_bh.FaceColor = 'flat';
		cur_bh.CData = object_colors;
		cur_bh.EdgeColor = cur_white;
		cur_bh.LineWidth = cur_bar_line_width;

	case 'allFixations'
		cur_bh.FaceColor = 'flat';
		cur_bh.CData = object_colors;
		cur_bh.EdgeColor = 'flat';
		cur_bh.LineWidth = cur_bar_line_width;

	otherwise
		cur_bh.FaceColor = 'flat';
		cur_bh.CData = object_colors;
		cur_bh.EdgeColor = 'none';
end
end


function object_colors = fn_local_get_goopc_bar_object_colors( ...
	pct_col_list, triallog_table, sessionID_cycle_key, color_struct)

n_objects = numel(pct_col_list);
object_colors = repmat([0.45, 0.45, 0.75], n_objects, 1);

if isempty(color_struct) || ~isstruct(color_struct)
	return
end

cur_selected_target_stem = fn_local_get_selected_target_stem(triallog_table, sessionID_cycle_key);

for i_col = 1 : n_objects
	cur_object_stem = fn_local_extract_goopc_object_stem(pct_col_list{i_col});
	if isempty(cur_object_stem)
		continue
	end

	if ~isempty(regexp(cur_object_stem, '^target\d+$', 'once'))
		if ~isempty(cur_selected_target_stem) && strcmp(cur_object_stem, cur_selected_target_stem)
			object_colors(i_col, :) = fn_local_get_color_from_struct(color_struct, 'selected_target', object_colors(i_col, :));
		else
			object_colors(i_col, :) = fn_local_get_color_from_struct(color_struct, 'other_targets', object_colors(i_col, :));
		end
	elseif strcmp(cur_object_stem, 'aims0')
		object_colors(i_col, :) = fn_local_get_color_from_struct(color_struct, 'aims0', object_colors(i_col, :));
	elseif strcmp(cur_object_stem, 'aims1')
		object_colors(i_col, :) = fn_local_get_color_from_struct(color_struct, 'aims1', object_colors(i_col, :));
	elseif strcmp(cur_object_stem, 'B_facecenter')
		object_colors(i_col, :) = fn_local_get_color_from_struct(color_struct, 'face', object_colors(i_col, :));
	end
end
end


function cur_object_stem = fn_local_extract_goopc_object_stem(pct_col_name)
cur_object_stem = '';
tok = regexp(pct_col_name, '_on_(.+)_PCT$', 'tokens', 'once');
if isempty(tok)
	return
end
if iscell(tok{1})
	cur_object_stem = tok{1}{1};
else
	cur_object_stem = tok{1};
end
end


function selected_target_stem = fn_local_get_selected_target_stem(triallog_table, sessionID_cycle_key)
selected_target_stem = '';

if isempty(triallog_table) || ~ismember('col_targ_IDX', triallog_table.Properties.VariableNames)
	return
end

[triallog_cycle_key_list, ~, ~, ~, ~] = fn_generate_key_from_selected_table_columns_CCF( ...
	{'sessionID', 'trial_num'}, triallog_table, '_');
cur_row_idx = find(strcmp(triallog_cycle_key_list, sessionID_cycle_key), 1, 'first');
if isempty(cur_row_idx)
	return
end

cur_selected_idx = triallog_table.col_targ_IDX(cur_row_idx);
if ~isfinite(cur_selected_idx)
	return
end

selected_target_stem = ['target', num2str(cur_selected_idx)];
end


function subtitle_string = fn_local_format_panel_sample_subtitle(stem_list, record2D_table, tick_idx_list, valid_sample_ldx, n_valid_epoch_samples)
shown_part_list = cell(1, numel(stem_list));

for i_stem = 1 : numel(stem_list)
	[n_shown_samples, ~, ~] = fn_local_get_trace_xy(record2D_table, tick_idx_list, stem_list{i_stem}, valid_sample_ldx);
	cur_label = fn_local_get_stem_short_label(stem_list{i_stem});
	shown_part_list{i_stem} = sprintf('%s: %d', cur_label, n_shown_samples);
end

subtitle_string = [strjoin(shown_part_list, ', '), sprintf('; of %d', n_valid_epoch_samples)];
end


function short_label = fn_local_get_stem_short_label(stem)
switch stem
	case {'aims0', 'agent0'}
		short_label = 'A0';
	case {'aims1', 'agent1'}
		short_label = 'B1';
	otherwise
		if ~isempty(regexp(stem, '^A_.*_eye$', 'once'))
			short_label = 'A0';
		elseif ~isempty(regexp(stem, '^B_.*_eye$', 'once'))
			short_label = 'B1';
		else
			digit_match = regexp(stem, '\d+$', 'match', 'once');
			if ~isempty(digit_match)
				short_label = char(digit_match);
			else
				short_label = stem;
			end
		end
end
end


function fn_local_plot_source_row_traces(cur_ah, record2D_table, tick_idx_list, stem_list, trace_colormap_name_list, valid_sample_ldx)
hold(cur_ah, 'on');

for i_stem = 1 : numel(stem_list)
	cur_stem = stem_list{i_stem};
	cur_colormap_name = trace_colormap_name_list{mod(i_stem - 1, numel(trace_colormap_name_list)) + 1};
	fn_local_plot_one_trace(cur_ah, record2D_table, tick_idx_list, cur_stem, cur_colormap_name, valid_sample_ldx);
end

hold(cur_ah, 'off');
end


function [n_shown_samples, cur_x, cur_y] = fn_local_get_trace_xy(record2D_table, tick_idx_list, stem, valid_sample_ldx)
cur_x_col = [stem, '_X'];
cur_y_col = [stem, '_Y'];
if ~all(ismember({cur_x_col, cur_y_col}, record2D_table.Properties.VariableNames))
	n_shown_samples = 0;
	cur_x = nan(size(tick_idx_list));
	cur_y = nan(size(tick_idx_list));
	return
end

cur_x = record2D_table.(cur_x_col)(tick_idx_list);
cur_y = record2D_table.(cur_y_col)(tick_idx_list);

if ~isempty(valid_sample_ldx)
	cur_valid_ldx = valid_sample_ldx(tick_idx_list);
	cur_x(~cur_valid_ldx) = nan;
	cur_y(~cur_valid_ldx) = nan;
	n_shown_samples = sum(cur_valid_ldx);
else
	n_shown_samples = sum(isfinite(cur_x) & isfinite(cur_y));
end
end


function fn_local_plot_one_trace(cur_ah, record2D_table, tick_idx_list, stem, colormap_name, valid_sample_ldx)

colormap_method_string = 'scatter'; % manipulate_ColorBinding or forloop, or scatter

[~, cur_x, cur_y] = fn_local_get_trace_xy(record2D_table, tick_idx_list, stem, valid_sample_ldx);
n_samples = numel(tick_idx_list);
if n_samples < 1
	return
end

cur_colormap = fn_local_get_trace_colormap(colormap_name, n_samples);

if n_samples == 1
	if isfinite(cur_x) && isfinite(cur_y)
		plot(cur_ah, cur_x, cur_y, 'o', 'Color', cur_colormap(1, :), 'MarkerFaceColor', cur_colormap(1, :), ...
			'MarkerSize', 4, 'HandleVisibility', 'off');
	end
	return
end


switch colormap_method_string
	case 'scatter'
		% this seems to be around twice as fast as forloop, so this is our
		% default for now
		cur_ph = plot(cur_ah, cur_x, cur_y, '-', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.0, 'HandleVisibility', 'off');
		cur_sh = scatter(cur_ah, cur_x, cur_y, [], cur_colormap, 'filled', 'Marker', 'o', 'SizeData', 8);

	case 'manipulate_ColorBinding'
		% undocumented matlab from 20160814062506 via wayback machine
		% from undocumented features Color-coded 2D line plots with color data in
		% third dimension
		% with matlab 2023b this gives: Warning: An error occurred while drawing
		% the scene: Unidentified trouble during rendering on saving for
		% each panel and fails when saving as pdf, 
		% 
		% @cursor, please leave this in the code but default to
		% scatter
		p = plot(cur_ah, cur_x, cur_y, '-', ...
			'Color', 'r', 'LineWidth', 1.25, 'HandleVisibility', 'off');
		cd = [uint8(cur_colormap*255) uint8(ones(n_samples,1)*255)].';[uint8(jet(n_samples)*255) uint8(ones(n_samples,1)*255)].';
		cd( :, isnan(cur_x)) = [];

		drawnow;
		set(p.Edge, 'ColorBinding', 'interpolated', 'ColorData', cd);
		drawnow;

	case 'forloop'
		for i_seg = 1 : (n_samples - 1)
			if isfinite(cur_x(i_seg)) && isfinite(cur_y(i_seg)) && isfinite(cur_x(i_seg + 1)) && isfinite(cur_y(i_seg + 1))
				plot(cur_ah, cur_x(i_seg:i_seg + 1), cur_y(i_seg:i_seg + 1), '-', ...
					'Color', cur_colormap(i_seg, :), 'LineWidth', 1.25, 'HandleVisibility', 'off');
			end
		end
end
end


function cur_colormap = fn_local_get_trace_colormap(colormap_name, n_samples)
n_colormap_rows = max(n_samples, 2);
switch colormap_name
	case 'autumn'
		cur_colormap = autumn(n_colormap_rows);
	case 'winter'
		cur_colormap = winter(n_colormap_rows);
	otherwise
		cur_colormap = autumn(n_colormap_rows);
end
end


function color_name = fn_local_target_id_to_color_name(target_id)
switch target_id
	case 0
		color_name = 'coop_A';
	case 1
		color_name = 'coop_B';
	case 2
		color_name = 'comp';
	case 3
		color_name = 'pun';
	case 4
		color_name = 'Solo_A';
	case 5
		color_name = 'Solo_B';
	otherwise
		color_name = '';
end
end


function cur_color = fn_local_get_color_from_struct(color_struct, color_name, fallback_color)
cur_color = fallback_color;
if isempty(color_name)
	return
end
if isstruct(color_struct) && isfield(color_struct, color_name) && ~isempty(color_struct.(color_name))
	cur_color = color_struct.(color_name);
end
end
