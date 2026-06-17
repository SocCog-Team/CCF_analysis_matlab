function [plot_fh_list] = fn_plot_dyadic_solo_paired_objects(panel_index_struct_arr, gaze_on_object_prop_count_table, stats_table, aggregation_type_string, out_dir, plotting_options_struct, sorted_col_set_list, sorted_row_set_list, target_ignore_list)
%FN_PLOT_DYADIC_SOLO_PAIRED_OBJECTS
% Uses panel indices + source table to plot D/S pairs in tiled figures.
%
% Expected panel index fields:
%   aggregation_type, panel_group_key, condition, epoch, vergence, goopc_row_ldx
%
% Behavior:
% - Draws paired object groups as:
%   ownHand_D, ownHand_S, otherHand_D, otherHand_S, face_D, face_S, ...
% - Draws local significance brackets ONLY for significant adjusted effects
%   (isfinite(p_adj) & p_adj < 0.05) and only if row is testable when
%   stats_table.is_testable is present.

plot_fh_list = [];
if isempty(panel_index_struct_arr)
	return
end

idx_table = struct2table(panel_index_struct_arr, 'AsArray', 1);
idx_table = idx_table(strcmp(idx_table.aggregation_type, aggregation_type_string), :);
if isempty(idx_table)
	return
end

pair_order = {'ownHand', 'otherHand', 'face', 'selTarg', 'otherTarg', 'Targets'};
if ~exist('target_ignore_list', 'var') || isempty(target_ignore_list)
	target_ignore_list = {};
end
pair_order = pair_order(~ismember(pair_order, target_ignore_list));
[obj_label_list, obj_pct_col_map, target_pct_col_list] = fn_local_get_object_pct_map(gaze_on_object_prop_count_table);
object_color_map = fn_local_get_object_color_map();

panel_group_key_list = unique(string(idx_table.panel_group_key), 'stable');
if exist('sorted_col_set_list', 'var') && ~isempty(sorted_col_set_list)
	epoch_list = string(sorted_col_set_list);
else
	epoch_list = unique(string(idx_table.epoch), 'stable');
end
if exist('sorted_row_set_list', 'var') && ~isempty(sorted_row_set_list)
	vergence_list = string(sorted_row_set_list);
else
	vergence_list = unique(string(idx_table.vergence), 'stable');
end

for i_group = 1 : numel(panel_group_key_list)
	cur_panel_group_key = char(panel_group_key_list(i_group));

	cur_group_ldx = string(idx_table.panel_group_key) == panel_group_key_list(i_group);
	if ~any(cur_group_ldx)
		continue
	end

	cur_fh = figure( ...
		'Name', ['dyadic_solo_pairs_', aggregation_type_string, '_', cur_panel_group_key], ...
		'visible', plotting_options_struct.figure_visibility_string);
	plot_fh_list(end+1) = cur_fh; %#ok<AGROW>

	n_rows = numel(vergence_list);
	n_cols = numel(epoch_list);
	plot_width_cm = (plotting_options_struct.panel_width_cm * n_cols);
	plot_height_cm = (plotting_options_struct.panel_height_cm * n_rows);
	fn_set_figure_outputpos_and_size(cur_fh, plotting_options_struct.margin_cm, plotting_options_struct.margin_cm, plot_width_cm, plot_height_cm, 1.0, 'portrait', 'inch');

	cur_tl = tiledlayout(cur_fh, n_rows, n_cols, 'TileSpacing', 'Compact', 'Padding', 'Compact');

	for i_row = 1 : n_rows
		cur_vergence = char(vergence_list(i_row));

		for i_col = 1 : n_cols
			cur_epoch = char(epoch_list(i_col));
			cur_tile_idx = ((i_row - 1) * n_cols) + i_col;
			cur_ah = nexttile(cur_tl, cur_tile_idx);

			cur_panel_ldx = cur_group_ldx ...
				& strcmp(idx_table.epoch, cur_epoch) ...
				& strcmp(idx_table.vergence, cur_vergence);
			cur_panel = idx_table(cur_panel_ldx, :);

			dyad_i = find(strcmp(cur_panel.condition, 'dyadic'), 1, 'first');
			solo_i = find(strcmp(cur_panel.condition, 'solo'), 1, 'first');
			if isempty(dyad_i) || isempty(solo_i)
				axis(cur_ah, 'off');
				continue
			end

			dyad_ldx = cur_panel.goopc_row_ldx{dyad_i};
			solo_ldx = cur_panel.goopc_row_ldx{solo_i};

			has_data = fn_local_plot_one_paired_tile( ...
				cur_ah, dyad_ldx, solo_ldx, gaze_on_object_prop_count_table, stats_table, ...
				aggregation_type_string, cur_panel_group_key, cur_epoch, cur_vergence, ...
				pair_order, obj_label_list, obj_pct_col_map, target_pct_col_list, object_color_map, plotting_options_struct);

			if ~has_data
				axis(cur_ah, 'off');
				continue
			end

			if i_row == 1
				title(cur_ah, cur_epoch, 'Interpreter', 'none', 'FontSize', plotting_options_struct.titlefontsize);
			end
			if i_col == 1
				ylabel(cur_ah, {cur_vergence; 'Gaze samples [%]'}, 'Interpreter', 'none', 'FontSize', plotting_options_struct.labelfontsize);
			else
				ylabel(cur_ah, '');
			end

			if i_row < n_rows
				set(cur_ah, 'XTickLabel', []);
			end
		end
	end

	title(cur_tl, [aggregation_type_string, ' dyadic vs solo gaze proportions: ', cur_panel_group_key], 'Interpreter', 'none', 'FontSize', plotting_options_struct.titlefontsize + 2);

	cur_out_FQN = fullfile(out_dir, aggregation_type_string, ['dyadic_solo_pairs.', cur_panel_group_key, '.tiled.pdf']);
	write_out_figure(cur_fh, cur_out_FQN, [], [], plotting_options_struct.format_string_list);
end

end


function has_data = fn_local_plot_one_paired_tile(cur_ah, dyad_ldx, solo_ldx, gaze_on_object_prop_count_table, stats_table, aggregation_type_string, cur_panel_group_key, cur_epoch, cur_vergence, pair_order, obj_label_list, obj_pct_col_map, target_pct_col_list, object_color_map, plotting_options_struct)
has_data = false;

x_tick_labels = {};
x_tick_pos_list = [];
sig_pairs = {};
sig_pvals = [];
x_cursor = 1;
all_box_data = [];
all_box_group = [];
all_box_color_arr = [];
swarm_x_cell = {};
swarm_y_cell = {};
swarm_color_cell = {};

for i_obj = 1 : numel(pair_order)
	cur_obj = pair_order{i_obj};
	if ~ismember(cur_obj, obj_label_list)
		continue
	end

	d_pct = fn_local_get_object_pct(gaze_on_object_prop_count_table, dyad_ldx, cur_obj, obj_pct_col_map, target_pct_col_list);
	s_pct = fn_local_get_object_pct(gaze_on_object_prop_count_table, solo_ldx, cur_obj, obj_pct_col_map, target_pct_col_list);

	d_pct = d_pct(isfinite(d_pct));
	s_pct = s_pct(isfinite(s_pct));
	if isempty(d_pct) || isempty(s_pct)
		continue
	end

	x_d = x_cursor;
	x_s = x_cursor + 1;
	d_color = fn_local_get_condition_color(object_color_map, cur_obj, 'D');
	s_color = fn_local_get_condition_color(object_color_map, cur_obj, 'S');

	all_box_data = [all_box_data; d_pct(:); s_pct(:)]; %#ok<AGROW>
	all_box_group = [all_box_group; repmat(x_d, numel(d_pct), 1); repmat(x_s, numel(s_pct), 1)]; %#ok<AGROW>
	all_box_color_arr = [all_box_color_arr; d_color; s_color]; %#ok<AGROW>
	swarm_x_cell{end+1} = x_d * ones(size(d_pct)); %#ok<AGROW>
	swarm_y_cell{end+1} = d_pct; %#ok<AGROW>
	swarm_color_cell{end+1} = d_color; %#ok<AGROW>
	swarm_x_cell{end+1} = x_s * ones(size(s_pct)); %#ok<AGROW>
	swarm_y_cell{end+1} = s_pct; %#ok<AGROW>
	swarm_color_cell{end+1} = s_color; %#ok<AGROW>

	x_tick_labels{end+1} = [cur_obj, '_D']; %#ok<AGROW>
	x_tick_labels{end+1} = [cur_obj, '_S']; %#ok<AGROW>
	x_tick_pos_list = [x_tick_pos_list, x_d, x_s]; %#ok<AGROW>
	sig_pairs{end+1} = [x_d, x_s]; %#ok<AGROW>
	sig_pvals(end+1) = fn_local_lookup_adj_p(stats_table, aggregation_type_string, cur_panel_group_key, cur_epoch, cur_vergence, cur_obj); %#ok<AGROW>

	x_cursor = x_cursor + 2;
end

if isempty(all_box_data)
	return
end

has_data = true;
hold(cur_ah, 'on');
for i_swarm = 1 : numel(swarm_x_cell)
	swarmchart(cur_ah, swarm_x_cell{i_swarm}, swarm_y_cell{i_swarm}, 5, 'filled', ...
		'MarkerFaceColor', swarm_color_cell{i_swarm}, 'MarkerEdgeColor', swarm_color_cell{i_swarm}, ...
		'MarkerFaceAlpha', 0.45, 'MarkerEdgeAlpha', 0.45);
end

boxplot(cur_ah, all_box_data, all_box_group, 'Positions', unique(all_box_group, 'stable'), 'Symbol', '', 'Colors', [0.2, 0.2, 0.2]);
set(findobj(cur_ah, 'Tag', 'Box'), 'LineWidth', 1.0, 'Color', [0.2, 0.2, 0.2]);
set(findobj(cur_ah, 'Tag', 'Median'), 'LineWidth', 1.5, 'Color', [0.2, 0.2, 0.2]);
set(findobj(cur_ah, 'Tag', 'Whisker'), 'LineWidth', 1.0, 'Color', [0.2, 0.2, 0.2]);
set(findobj(cur_ah, 'Tag', 'Upper Whisker'), 'LineWidth', 1.0, 'Color', [0.2, 0.2, 0.2]);
set(findobj(cur_ah, 'Tag', 'Lower Whisker'), 'LineWidth', 1.0, 'Color', [0.2, 0.2, 0.2]);
set(findobj(cur_ah, 'Tag', 'Upper Adjacent Value'), 'LineWidth', 1.0, 'Color', [0.2, 0.2, 0.2]);
set(findobj(cur_ah, 'Tag', 'Lower Adjacent Value'), 'LineWidth', 1.0, 'Color', [0.2, 0.2, 0.2]);

valid_p_ldx = isfinite(sig_pvals) & (sig_pvals < 0.05);
if any(valid_p_ldx)
	fn_local_plot_significance_bars(cur_ah, sig_pairs(valid_p_ldx), sig_pvals(valid_p_ldx), 104);
end

set(cur_ah, ...
	'XTick', x_tick_pos_list, ...
	'XTickLabel', x_tick_labels, ...
	'XTickMode', 'manual', ...
	'XTickLabelMode', 'manual', ...
	'XTickLabelRotation', 60, ...
	'TickLabelInterpreter', 'none', ...
	'XLim', [min(x_tick_pos_list) - 0.5, max(x_tick_pos_list) + 0.5]);
set(cur_ah, 'YLim', [0, 120]);
yticks(cur_ah, [0, 50, 100]);
box(cur_ah, 'off');
hold(cur_ah, 'off');

if isfield(plotting_options_struct, 'set_gca') && isfield(plotting_options_struct.set_gca, 'linewidth')
	set(cur_ah, 'LineWidth', plotting_options_struct.set_gca.linewidth);
end
if isfield(plotting_options_struct, 'set_gca') && isfield(plotting_options_struct.set_gca, 'FontName')
	set(cur_ah, 'FontName', plotting_options_struct.set_gca.FontName);
end
set(cur_ah, 'FontSize', plotting_options_struct.axisfontsize);
end


function [obj_label_list, obj_pct_col_map, target_pct_col_list] = fn_local_get_object_pct_map(goopc_table)
obj_label_list = {'ownHand', 'otherHand', 'face', 'selTarg', 'otherTarg', 'Targets'};

obj_pct_col_map = containers.Map();
obj_pct_col_map('ownHand') = 'A_binocular_eye_on_aims0_PCT';
obj_pct_col_map('otherHand') = 'A_binocular_eye_on_aims1_PCT';
obj_pct_col_map('face') = 'A_binocular_eye_on_B_facecenter_PCT';
obj_pct_col_map('selTarg') = 'A_binocular_eye_on_selected_target_PCT';
obj_pct_col_map('otherTarg') = 'A_binocular_eye_on_other_targets_PCT';

target_pct_col_ldx = ~cellfun(@isempty, regexp(goopc_table.Properties.VariableNames, '^A_binocular_eye_on_target\d+_PCT$', 'once'));
target_pct_col_list = goopc_table.Properties.VariableNames(target_pct_col_ldx);
end


function pct = fn_local_get_object_pct(goopc_table, row_ldx, obj_label, obj_pct_col_map, target_pct_col_list)
if strcmp(obj_label, 'Targets')
	if isempty(target_pct_col_list)
		pct = nan(sum(row_ldx), 1);
	else
		pct = sum(goopc_table{row_ldx, target_pct_col_list}, 2, 'omitnan');
	end
else
	col = obj_pct_col_map(obj_label);
	if ismember(col, goopc_table.Properties.VariableNames)
		pct = goopc_table.(col)(row_ldx);
	else
		pct = nan(sum(row_ldx), 1);
	end
end
end


function p_adj = fn_local_lookup_adj_p(stats_table, aggregation_type, panel_group_key, epoch, vergence, object_label)
p_adj = nan;
if isempty(stats_table)
	return
end

row_ldx = strcmp(stats_table.aggregation_type, aggregation_type) ...
	& strcmp(stats_table.panel_group_key, panel_group_key) ...
	& strcmp(stats_table.epoch, epoch) ...
	& strcmp(stats_table.vergence, vergence) ...
	& strcmp(stats_table.object_label, object_label);

if any(row_ldx)
	row_idx = find(row_ldx, 1, 'first');

	% Suppress brackets for non-testable rows
	if ismember('is_testable', stats_table.Properties.VariableNames)
		if ~stats_table.is_testable(row_idx)
			return
		end
	end

	p_adj = stats_table.p_adj(row_idx);
end
end


function fn_local_plot_significance_bars(cur_ah, sig_pair_list, p_val_list, y_bar)
%FN_LOCAL_PLOT_SIGNIFICANCE_BARS Draw simple sigstar-like brackets.
%   sig_pair_list is a cell array of [x1, x2] pairs; p_val_list is numeric.

if isempty(sig_pair_list) || isempty(p_val_list)
	return
end
if ~exist('y_bar', 'var') || isempty(y_bar)
	y_bar = 110;
end

axes(cur_ah);
bar_height = 2.0;
text_y = y_bar + bar_height;

hold_state = ishold(cur_ah);
hold(cur_ah, 'on');

for i_pair = 1 : numel(sig_pair_list)
	cur_pair = sig_pair_list{i_pair};
	cur_p = p_val_list(i_pair);
	if numel(cur_pair) ~= 2 || ~isfinite(cur_p)
		continue
	end

	x1 = cur_pair(1);
	x2 = cur_pair(2);

	line(cur_ah, [x1, x1, x2, x2], [y_bar, y_bar + bar_height, y_bar + bar_height, y_bar], ...
		'Color', [0, 0, 0], 'LineWidth', 1.0, 'Clipping', 'off');
	text(cur_ah, mean([x1, x2]), text_y, fn_local_p_to_stars(cur_p), ...
		'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
		'Color', [0, 0, 0], 'FontWeight', 'bold', 'Clipping', 'off');
end

if ~hold_state
	hold(cur_ah, 'off');
end
end


function star_string = fn_local_p_to_stars(p_val)
if p_val < 0.001
	star_string = '***';
elseif p_val < 0.01
	star_string = '**';
elseif p_val < 0.05
	star_string = '*';
else
	star_string = 'n.s.';
end
end


function object_color_map = fn_local_get_object_color_map()
%FN_LOCAL_GET_OBJECT_COLOR_MAP ColorBrewer Paired-like D/S color pairs.
% Darker colors are used for dyadic (_D); lighter colors for solo (_S).

object_color_map = containers.Map();

object_color_map('ownHand_D') = [31, 120, 180] / 255;
object_color_map('ownHand_S') = [166, 206, 227] / 255;

object_color_map('otherHand_D') = [51, 160, 44] / 255;
object_color_map('otherHand_S') = [178, 223, 138] / 255;

object_color_map('face_D') = [227, 26, 28] / 255;
object_color_map('face_S') = [251, 154, 153] / 255;

object_color_map('selTarg_D') = [255, 127, 0] / 255;
object_color_map('selTarg_S') = [253, 191, 111] / 255;

object_color_map('otherTarg_D') = [106, 61, 154] / 255;
object_color_map('otherTarg_S') = [202, 178, 214] / 255;
end


function cur_color = fn_local_get_condition_color(object_color_map, object_label, condition_suffix)
cur_key = [object_label, '_', condition_suffix];
if isKey(object_color_map, cur_key)
	cur_color = object_color_map(cur_key);
else
	cur_color = [0.5, 0.5, 0.5];
end
end