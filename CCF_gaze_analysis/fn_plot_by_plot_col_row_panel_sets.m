function [ cur_plot_fh_list, panel_index_struct_arr  ] = fn_plot_by_plot_col_row_panel_sets( ...
				triallog_table, valid_cycle_ldx, triallog_cycle_key_list, record2D_table, valid_gaze_sample_ldx, per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray, ...
				gaze_on_object_prop_count_table, goopc_table_cycle_key_list, near_gaze_sample_ldx, far_gaze_sample_ldx, ...
				target_ignore_list, face_ROI, ...
				panel_request_list, short_all_epoch_name_list, gaze_src_col_name_stem, ...
				plot_unique_keys, plot_set_include_regexplist_list, plot_data_row_key_idx_arr, ...
				col_unique_keys, sorted_col_set_list, col_data_row_key_idx_arr, ...
				row_unique_keys, sorted_row_set_list, row_data_row_key_idx_arr, ...
				aggregation_type_string, out_dir, plotting_options_struct )
%FN_PLOT_BY_PLOT_COL_ROW_PANEL_SETS Summary of this function goes here
%   Detailed explanation goes here


cur_plot_fh_list = [];
panel_index_struct_arr = struct([]);
panel_index_idx = 0;

n_cols = length(col_unique_keys);
if exist('sorted_col_set_list', 'var') && ~isempty(sorted_col_set_list)
	n_cols = length(sorted_col_set_list);
end

n_rows = length(row_unique_keys);
if exist('sorted_col_set_list', 'var') && ~isempty(sorted_col_set_list)
	n_rows = length(sorted_row_set_list);
end
% we also want to step through these as additional rows
n_panels = length(panel_request_list);



for i_plot = 1 : length(plot_unique_keys)
	cur_plot_set = plot_unique_keys{i_plot};
	[cur_condition_string, cur_panel_group_key] = fn_local_parse_plot_set(cur_plot_set);
	disp([mfilename, ': INFO: Procession plot: ', cur_plot_set]);
	if ~contains(cur_plot_set, regexpPattern(plot_set_include_regexplist_list))
		disp([mfilename, ': INFO: current plot set does not contain plot_set_include_regexplist_list, skipping: ', cur_plot_set]);
		continue
	end

	cur_plot_set_ldx = plot_data_row_key_idx_arr == i_plot;
	% the actual cycle numers to include
	cur_plot_set_cycle_list = triallog_table.trial_num(cur_plot_set_ldx & valid_cycle_ldx);

	% use the full cycle IDs including the session name
	cur_triallog_cycle_key_list = triallog_cycle_key_list(cur_plot_set_ldx & valid_cycle_ldx);

	% % now translate to gaze_on_object_prop_count_table_ldx
	% cur_plot_data_row_ldx = ismember(gaze_on_object_prop_count_table.cycle, cur_plot_set_cycle_list);

	% now translate to gaze_on_object_prop_count_table_ldx
	cur_plot_data_row_ldx = ismember(goopc_table_cycle_key_list, cur_triallog_cycle_key_list);



	% create a new figure
	cur_figure_stem = cur_plot_set;
	cur_fh = figure('Name', cur_figure_stem, 'visible', plotting_options_struct.figure_visibility_string);
	n_panel_cols = n_cols;
	n_panel_rows = n_rows * n_panels;	% here we want to use the rows for panels and the actual row type

	plot_width_cm = (plotting_options_struct.panel_width_cm * n_panel_cols);
	plot_height_cm = (plotting_options_struct.panel_height_cm * n_panel_rows);
	output_rect = fn_set_figure_outputpos_and_size(cur_fh, plotting_options_struct.margin_cm, plotting_options_struct.margin_cm, plot_width_cm, plot_height_cm, 1.0, 'portrait', 'inch');

	cur_fh_th = tiledlayout(cur_fh, n_panel_rows, n_panel_cols, 'TileSpacing', 'Compact', 'Padding', 'Compact');

	cur_plot_fh_list(end+1) = cur_fh;
	
	cur_ah_list = [];


	%[cur_target_state, '_', cur_vergence_subset_string, '_']
	% use this for columns

	for i_col = 1 : n_cols
		cur_col = i_col;
		if exist('sorted_col_set_list', 'var') && ~isempty(sorted_col_set_list)
			cur_col_name = sorted_col_set_list{i_col};
			cur_col_data_row_ldx = col_data_row_key_idx_arr == (find(ismember(col_unique_keys, {cur_col_name})));
		else
			% unsorted default
			cur_col_name = col_unique_keys{i_col};
			cur_col_data_row_ldx = col_data_row_key_idx_arr == i_col;
		end

		% to find the XY data for gaze2D_per_epoch
		cur_epoch_idx = find(ismember(short_all_epoch_name_list, {cur_col_name}));
		%cur_col_per_state_valid_tick_idx_per_cycle_idx_array = per_state_valid_tick_idx_per_cycle_idx_array(:, cur_epoch_idx);
		%cur_col_ticks_in_cycles_and_epochs_ldx = ismember(per_state_valid_tick_idx_per_cycle_idx_array(:, cur_epoch_idx), cur_plot_set_cycle_list);

		% use sessionID cycles instead as that allows to operate on
		% merged sessions...
		cur_col_per_state_valid_tick_sessionID_cycle_per_cycle_idx_list = per_state_valid_tick_sessionID_cycle_per_cycle_idx_cellarray(:, cur_epoch_idx);
		cur_col_ticks_in_cycles_and_epochs_ldx = ismember(cur_col_per_state_valid_tick_sessionID_cycle_per_cycle_idx_list, cur_triallog_cycle_key_list);% this is costlier than the other method, but allows merging sessions across days


		% use vergence
		for i_row = 1 : n_rows
			cur_row = i_row;
			if exist('sorted_row_set_list', 'var') && ~isempty(sorted_row_set_list)
				cur_row_name = sorted_row_set_list{i_row};
				cur_row_data_row_ldx = row_data_row_key_idx_arr == (find(ismember(row_unique_keys, {cur_row_name})));
			else
				% unsorted default
				cur_row_name = row_unique_keys{i_row};
				cur_row_data_row_ldx = row_data_row_key_idx_arr == i_row;
			end

			coolbar = cool(256);
			switch cur_row_name
				case 'allFixations'
					cur_vergence_gaze_sample_ldx = true(size(cur_col_ticks_in_cycles_and_epochs_ldx));
					fixation_color = [10, 200, 10]/255;
				case 'nearFixations'
					cur_vergence_gaze_sample_ldx = near_gaze_sample_ldx;
					fixation_color = coolbar(1, :);
				case 'farFixations'
					cur_vergence_gaze_sample_ldx = far_gaze_sample_ldx;
					fixation_color = coolbar(end, :);
			end


			cur_panel_gaze_sample_ldx = cur_col_ticks_in_cycles_and_epochs_ldx & cur_vergence_gaze_sample_ldx;
			% only plot valid samples
			cur_panel_gaze_sample_ldx = cur_panel_gaze_sample_ldx & valid_gaze_sample_ldx;

			% get an idea of the fraction of samples
			cur_set_valid_samples_N = sum(cur_col_ticks_in_cycles_and_epochs_ldx & valid_gaze_sample_ldx);
			cur_set_valid_vergence_samples_N = sum(cur_panel_gaze_sample_ldx);
			cur_set_PCT_of_valid = 100 * cur_set_valid_vergence_samples_N / cur_set_valid_samples_N;

			for i_panel = 1 : n_panels
				cur_panel_row = ((cur_row - 1) * n_panels) + i_panel;
				cur_panel_type = panel_request_list{i_panel};

				% navigate to the intended tile
				cur_tilelocation = ((cur_panel_row - 1) * n_cols) + cur_col;

				% just select where to place the tile... that mapping needs
				cur_ah = nexttile(cur_fh_th, cur_tilelocation);
				cur_ah_list(end+1) = cur_ah;


				switch cur_panel_type
					case 'gaze2D_per_epoch'
						fixation_alpha = 0.0025;
						face_ROI_radius = face_ROI.radius;

						hold on
						plot([0 1 1 0 0], [0 0 1 1 0], 'Color', [0 0 0], 'LineWidth', 1, 'DisplayName', 'Playing field');


						unique_B_face_center_list = unique([record2D_table.B_facecenter_X(cur_col_ticks_in_cycles_and_epochs_ldx), record2D_table.B_facecenter_Y(cur_col_ticks_in_cycles_and_epochs_ldx)], 'row');
						cur_cur_row_name = cur_row_name;
						for i_unique_B_face_center = 1 : size(unique_B_face_center_list, 1)
							cur_face_ROI_center_XY = unique_B_face_center_list(i_unique_B_face_center, :);

							% find the current center_XY to pick up
							% the correct name
							cur_face_ROI_idx = find(ismember(face_ROI.center_XY, cur_face_ROI_center_XY, 'rows'));

							cur_set_paper_blocked = unique(record2D_table.paper_blocked(cur_col_ticks_in_cycles_and_epochs_ldx));


							if length(cur_set_paper_blocked) == 1
								if ~cur_set_paper_blocked
									cur_vh = viscircles(cur_face_ROI_center_XY, face_ROI_radius, 'Color', [0.7 0.7 0.7]);	% , 'DisplayName', 'Partner''s face'
								else
									cur_vh = viscircles(cur_face_ROI_center_XY, face_ROI_radius, 'Color', [0.7 0.7 0.7], 'LineStyle', '--');
								end
							else
								% default to continuos lines...
								cur_vh = viscircles(cur_face_ROI_center_XY, face_ROI_radius, 'Color', [0.7 0.7 0.7]);	% , 'DisplayName', 'Partner''s face'
							end
							set(cur_vh.Children(1), 'DisplayName', face_ROI.names{cur_face_ROI_idx});
						end

						color_by_face_center = 1;
						cur_x_data = nan(size(record2D_table.([gaze_src_col_name_stem, '_X'])));
						cur_y_data = nan(size(record2D_table.([gaze_src_col_name_stem, '_X'])));
						cur_group_data = nan(size(record2D_table.([gaze_src_col_name_stem, '_X'])));
						cur_by_group_color = nan([size(record2D_table.([gaze_src_col_name_stem, '_X']), 1), 3]);

						collected_samples = 0;

						if (color_by_face_center) && size(unique_B_face_center_list, 1) > 1 %&& strcmp('per_session', aggregation_type_string)
							for i_unique_B_face_center = 1 : size(unique_B_face_center_list, 1)
								cur_face_ROI_center_XY = unique_B_face_center_list(i_unique_B_face_center, :);
								cur_face_ROI_idx = find(ismember(face_ROI.center_XY, cur_face_ROI_center_XY, 'rows'));
								cur_face_ROI_name = face_ROI.names{cur_face_ROI_idx};
								cur_record2D_table_face_center_XY = [record2D_table.B_facecenter_X, record2D_table.B_facecenter_Y];
								cur_face_ROI_tick_ldx = ismember(cur_record2D_table_face_center_XY, cur_face_ROI_center_XY, 'rows');
								cur_color = face_ROI.colors{cur_face_ROI_idx};
								cur_cur_row_name = face_ROI.names{cur_face_ROI_idx};

								intermix_scatter_groups = 0;
								if sum(cur_panel_gaze_sample_ldx & cur_face_ROI_tick_ldx) > 0
									if ~intermix_scatter_groups
										cur_gaze2D_sh = scatter(cur_ah, record2D_table.([gaze_src_col_name_stem, '_X'])(cur_panel_gaze_sample_ldx & cur_face_ROI_tick_ldx),  record2D_table.([gaze_src_col_name_stem, '_Y'])(cur_panel_gaze_sample_ldx & cur_face_ROI_tick_ldx), 'filled', 'DisplayName', cur_cur_row_name, 'SizeData', 3, 'MarkerEdgeColor', cur_color, 'MarkerFaceColor', cur_color, 'MarkerFaceAlpha', fixation_alpha, 'MarkerEdgeAlpha', fixation_alpha);
									else
										cur_start_offset = (i_unique_B_face_center - 1) * size(unique_B_face_center_list, 1) + 1;
										cur_x_data(cur_start_offset:cur_start_offset + sum(cur_panel_gaze_sample_ldx & cur_face_ROI_tick_ldx) - 1) = record2D_table.([gaze_src_col_name_stem, '_X'])(cur_panel_gaze_sample_ldx & cur_face_ROI_tick_ldx);
										cur_y_data(cur_start_offset:cur_start_offset + sum(cur_panel_gaze_sample_ldx & cur_face_ROI_tick_ldx) - 1) = record2D_table.([gaze_src_col_name_stem, '_Y'])(cur_panel_gaze_sample_ldx & cur_face_ROI_tick_ldx);
										cur_group_data(cur_start_offset:cur_start_offset + sum(cur_panel_gaze_sample_ldx & cur_face_ROI_tick_ldx) - 1) = i_unique_B_face_center;
										collected_samples = collected_samples + sum(cur_panel_gaze_sample_ldx & cur_face_ROI_tick_ldx);
										cur_by_group_color(cur_start_offset:cur_start_offset + sum(cur_panel_gaze_sample_ldx & cur_face_ROI_tick_ldx) - 1, :) = repmat(cur_color, sum(cur_panel_gaze_sample_ldx & cur_face_ROI_tick_ldx), 1);
									end
								end
							end
							if (intermix_scatter_groups)
								% since wemight not include all samples,
								% prune the data array...
								if collected_samples < numel(cur_x_data)
									cur_x_data(collected_samples+1:end) = [];
									cur_y_data(collected_samples+1:end) = [];
									cur_group_data(collected_samples+1:end) = [];
									cur_by_group_color(collected_samples+1:end, :) = [];
								end
								% now shuffle, these 
								shuffled_idx = randperm(numel(cur_x_data))';								
								cur_gaze2D_sh = scatter(cur_ah, cur_x_data(shuffled_idx),  cur_y_data(shuffled_idx), 'filled', 'DisplayName', cur_cur_row_name, 'SizeData', 3, 'CData', cur_by_group_color(shuffled_idx, :), 'MarkerFaceAlpha', fixation_alpha, 'MarkerEdgeAlpha', fixation_alpha);
							end
						else
							if sum(cur_panel_gaze_sample_ldx) > 0
								cur_gaze2D_sh = scatter(cur_ah, record2D_table.([gaze_src_col_name_stem, '_X'])(cur_panel_gaze_sample_ldx),  record2D_table.([gaze_src_col_name_stem, '_Y'])(cur_panel_gaze_sample_ldx), 'filled', 'DisplayName', cur_cur_row_name, 'SizeData', 3, 'MarkerEdgeColor', fixation_color, 'MarkerFaceColor', fixation_color, 'MarkerFaceAlpha', fixation_alpha, 'MarkerEdgeAlpha', fixation_alpha);
							end
						end

						axis equal
						hold off

						xlabel(cur_ah,'Azimuth [relative]', 'Interpreter', 'none', 'FontSize', plotting_options_struct.labelfontsize);
						ylabel(cur_ah, 'Elevation [relative]', 'Interpreter', 'none', 'FontSize', plotting_options_struct.labelfontsize)
						title(cur_ah, [cur_col_name], 'Interpreter', 'none', 'FontSize', plotting_options_struct.titlefontsize);
						%subtitle(cur_ah, [cur_plot_set], 'Interpreter', 'none', 'FontSize', plotting_options_struct.subtitlefontsize);
						subtitle(cur_ah, [regexprep(cur_row_name, 'Fixations', ' Fixations'), ' (', num2str(round(cur_set_PCT_of_valid)), '%)'], 'Interpreter', 'none', 'FontSize', plotting_options_struct.subtitlefontsize);
						%subtitle(cur_ah, ['Partner position: ', cur_face_ROI_name, ' ', cur_set_name, ' trials around ', cur_col_name], 'Interpreter', 'none');
						%legend('Location','southeast');

						set(gca, 'XLim', [-0.2, 1.2]);
						set(gca, 'YLim', [-0.1, 1.3]);

						if (cur_col == 1)
							[matching_entry_ldx, non_matching_entry_ldx, matching_entry_idx] = fn_find_object_by_field_regexp( cur_ah.Children, 'Type', {'^scatter', '^line'});
							cur_lh = legend(cur_ah.Children(matching_entry_idx), 'Interpreter', 'none');
							cur_lh = legend(cur_ah, 'Location', 'southeast', 'FontSize', plotting_options_struct.legendfontsize, 'Box', 'off', 'Interpreter', 'none');
							cur_ah.Legend.ItemTokenSize=[10,15];	% reduce the length of the displayed line segment in the legen
						end

					case 'gaze_on_object_proportion'
						gaze_on_object_proportion.MarkerFaceAlpha = 0.5;
						gaze_on_object_proportion.MarkerEdgeAlpha = 0.5;
						gaze_on_object_proportion.data_col_name_list = {...
							'A_binocular_eye_on_aims0_PCT',...
							'A_binocular_eye_on_aims1_PCT', ...
							...'A_binocular_eye_on_agent0_PCT',...
							...'A_binocular_eye_on_agent1_PCT', ...
							'A_binocular_eye_on_target0_PCT', ...
							'A_binocular_eye_on_target1_PCT', ...
							'A_binocular_eye_on_target2_PCT', ...
							'A_binocular_eye_on_target3_PCT', ...
							'A_binocular_eye_on_target4_PCT', ...
							'A_binocular_eye_on_B_facecenter_PCT', ...
							'A_binocular_eye_on_selected_target_PCT', ...
							'A_binocular_eye_on_other_targets_PCT', ...
							};

						% find all relevant rows in gaze_on_object_prop_count_table
						cur_selected_set_ldx = cur_plot_data_row_ldx & cur_col_data_row_ldx & cur_row_data_row_ldx;

						if ~isempty(cur_condition_string)
							panel_index_idx = panel_index_idx + 1;
							panel_index_struct_arr(panel_index_idx).aggregation_type = aggregation_type_string;
							panel_index_struct_arr(panel_index_idx).plot_set = cur_plot_set;
							panel_index_struct_arr(panel_index_idx).panel_group_key = cur_panel_group_key;
							panel_index_struct_arr(panel_index_idx).condition = cur_condition_string;
							panel_index_struct_arr(panel_index_idx).epoch = cur_col_name;
							panel_index_struct_arr(panel_index_idx).vergence = cur_row_name;
							panel_index_struct_arr(panel_index_idx).goopc_row_ldx = cur_selected_set_ldx;
						end


						cur_data_array = nan([sum(cur_selected_set_ldx), length(gaze_on_object_proportion.data_col_name_list)]);
						cur_xvec_array = cur_data_array;
						cur_name_vec = cell(size(gaze_on_object_proportion.data_col_name_list));


						add_all_target_fix_pct_col = 1;
						only_include_all_target_fix_pct = 1;

						all_target_fix_PCT_col = zeros([length(find(cur_selected_set_ldx)), 1]);	% for closest target we can synthesize the all target column by adding the individual target percentages


						for i_data_col = 1 : length(gaze_on_object_proportion.data_col_name_list)
							data_col_name = gaze_on_object_proportion.data_col_name_list{i_data_col};
							cur_data = gaze_on_object_prop_count_table.(data_col_name)(cur_selected_set_ldx);
							cur_X_vec = ones(size(cur_data)) * i_data_col;
							cur_data_array(:, i_data_col) = cur_data;
							cur_xvec_array(:, i_data_col) = cur_X_vec;
							cur_name_vec{i_data_col} = regexprep(regexprep(data_col_name, 'A_binocular_eye_on_', ''), '_PCT', '');
							cur_name_vec{i_data_col} = regexprep(cur_name_vec{i_data_col}, 'B_facecenter', 'face');
							cur_name_vec{i_data_col} = regexprep(cur_name_vec{i_data_col}, 'selected_target', 'selTarg');
							cur_name_vec{i_data_col} = regexprep(cur_name_vec{i_data_col}, 'other_targets', 'otherTarg');
							cur_name_vec{i_data_col} = regexprep(cur_name_vec{i_data_col}, 'aims0', 'ownHand');
							cur_name_vec{i_data_col} = regexprep(cur_name_vec{i_data_col}, 'aims1', 'otherHand');
							% get the proper target type
							if (contains(cur_name_vec(i_data_col), regexpPattern('target[0-9]'))) && ~isempty(cur_data)

								all_target_fix_PCT_col = all_target_fix_PCT_col + cur_data;

								% get the cycle/trial number

								%cur_cycle = gaze_on_object_prop_count_table.cycle(find(cur_selected_set_ldx, 1, 'first'));
								% get record2D tick index from
								% triallog for that cycle
								%cur_tick_idx = triallog_table.collection_start_tick_idx(find(triallog_table.trial_num == cur_cycle, 1 , 'first'));


								first_row = find(cur_selected_set_ldx, 1, 'first');
								cur_cycle = gaze_on_object_prop_count_table.cycle(first_row);
								cur_sessionID = gaze_on_object_prop_count_table.sessionID(first_row);
								triallog_match_ldx = ismember(triallog_table.sessionID, cur_sessionID) & triallog_table.trial_num == cur_cycle;
								cur_tick_idx = triallog_table.collection_start_tick_idx(find(triallog_match_ldx, 1, 'first'));

								cur_target_id = record2D_table.([cur_name_vec{i_data_col}, '_id'])(cur_tick_idx);
								% see enum_struct.target_id.name_list'
								switch cur_target_id
									case 0	% cooperative_targets_type_0
										cur_name_vec{i_data_col} = 'coop_A';
									case 1	% cooperative_targets_type_1
										cur_name_vec{i_data_col} = 'coop_B';
									case 2	% competitive_targets
										cur_name_vec{i_data_col} = 'comp';
									case 3 % punishing_targets
										cur_name_vec{i_data_col} = 'pun';
									case 4	% solo_targets_type_0
										cur_name_vec{i_data_col} = 'Solo_A';
									case 5	% solo_targets_type_1
										cur_name_vec{i_data_col} = 'Solo_B';
								end
							end
						end

						ignore_target_col_ldx = false(size(cur_name_vec));
						if (add_all_target_fix_pct_col)
							% we add this as first column
							cur_data_array = [all_target_fix_PCT_col, cur_data_array];
							cur_xvec_array(:, end+1) = ones(size(cur_data)) * length(gaze_on_object_proportion.data_col_name_list) + 1;
							cur_name_vec = ['Targets', cur_name_vec];

							% if we only want aggregate target
							% fixations remove the inividual target
							% columns
							ignore_target_col_ldx = false(size(cur_name_vec));

						end

						if (only_include_all_target_fix_pct) && ~isempty(target_ignore_list)
							ignore_target_col_ldx = ismember(cur_name_vec, target_ignore_list);
						end


						include_col_ldx = ~ignore_target_col_ldx;

						% shape down to included columns
						if any(ignore_target_col_ldx)
							cur_name_vec(ignore_target_col_ldx) = [];
							cur_data_array(:, ignore_target_col_ldx) = [];
							% this next one just gives the x values
							% which we want to increment from 1
							cur_xvec_array = cur_xvec_array(:, 1:sum(include_col_ldx));
						end

						% now do some statistics across the
						% selected columns?
						% compare the distribution of face fixations in precent to
						% face_ROI.face_ratio_of_included_playing_field_PCT

						show_face_gaze_sig = 1;
						if (show_face_gaze_sig)
							face_col_idx = find(ismember(cur_name_vec, {'face'}));
							% we can not use signrank, as our data is not
							% symmetric around its mean, so the signtest will
							% need to do
							[face_area_PCT.p, face_area_PCT.h, face_area_PCT.stats] = signtest(cur_xvec_array(:, face_col_idx), face_ROI.face_ratio_of_included_playing_field_PCT);
							% now we need to report this
							if face_area_PCT.p < 0.05
								cur_face_aggregate_data = median(cur_data_array(:, face_col_idx), 'omitnan');
								if cur_face_aggregate_data < face_ROI.face_ratio_of_included_playing_field_PCT
									cur_name_vec{face_col_idx} = [cur_name_vec{face_col_idx}, ' (sig. <)'];
								elseif cur_face_aggregate_data > face_ROI.face_ratio_of_included_playing_field_PCT
									cur_name_vec{face_col_idx} = [cur_name_vec{face_col_idx}, ' (sig. >)'];
								end
							end
						end


						hold on
						if ~all(isnan(cur_data_array(:)))
							swarmchart(cur_ah, cur_xvec_array, cur_data_array, 'filled', 'MarkerFaceAlpha', gaze_on_object_proportion.MarkerFaceAlpha, 'MarkerEdgeAlpha', gaze_on_object_proportion.MarkerEdgeAlpha, 'DisplayName', ['prop' '_', cur_row_name], 'SizeData', 3);
							boxplot(cur_ah, cur_data_array, 'Symbol','');	% show no outliers, as we already show a swarmplot
							add_mean_to_plots = 1;
							if (add_mean_to_plots)
								n_groups = size(cur_data_array, 2);
								for i_group = 1 : n_groups
									plot(cur_ah, mean(cur_xvec_array(:, i_group), 'omitnan'), mean(cur_data_array(:, i_group), 'omitnan'), 'DisplayName', ['mean' '_', cur_row_name, '_', cur_name_vec{i_group}], 'LineStyle', 'none', 'Marker', '+', 'MarkerSize', 5);
								end
							end

							%xlabel(cur_ah,'gaze target', 'Interpreter', 'none', 'FontSize', plotting_options_struct.labelfontsize);
							xticklabels(cur_name_vec)
							ylabel(cur_ah, 'Proportion of gaze samples [%]', 'Interpreter', 'none', 'FontSize', plotting_options_struct.labelfontsize)
							%title(cur_ah, [cur_col_name], 'Interpreter', 'none', 'FontSize', plotting_options_struct.titlefontsize);
							%subtitle(cur_ah, '', 'Interpreter', 'none', 'FontSize', plotting_options_struct.subitlefontsize);
						
							set(cur_ah, 'YLim', [-5, 105]);
							yticks(cur_ah,  [0, 50, 100]);

							show_pairwise_significance = 0;
							if  (show_pairwise_significance)
								[ pair_id_array, test_stat_structarr, report_string_list, pair_id_list ] = fn_get_pairwise_stats( 'ranksum_approximate', cur_data_array, cur_xvec_array(1, :), cur_name_vec);
								lower_Y_limit = 0;
								if ~isempty(pair_id_array) && (show_pairwise_significance)
									cur_sigh = sigstar(pair_id_list, [test_stat_structarr.p], 1);
									delete(cur_sigh([test_stat_structarr.p] > 0.05));	% delete empty lines delete(cur_sigh([test_stat_structarr.p] <= 0.05));
									set(cur_sigh([test_stat_structarr.p] <= 0.05), 'LineWidth', plotting_options_struct.set_gca.linewidth);
									set(cur_ah, 'YLim', [lower_Y_limit (100 + (size(pair_id_array, 1) * 12))]); % scale the upper limit to allow space for the significance bars...
								end
							end
							if (show_face_gaze_sig)
								yline(cur_ah, face_ROI.face_ratio_of_included_playing_field_PCT, 'Color', [0.3 0.3 0.3], 'DisplayName', 'Expected fixation PCT on face');
							end

						end

					otherwise
						error([mfilename, ': ERROR: unkown cur_panel_type: ', cur_panel_type]);
				end

			end

		end
	end

	title(cur_fh_th, [cur_figure_stem, ', N_cycles : ', num2str(length(cur_plot_set_cycle_list))], 'Interpreter', 'none', 'FontSize', plotting_options_struct.titlefontsize+2);

	cur_out_FQN = fullfile(out_dir, aggregation_type_string, [cur_figure_stem, '.', gaze_src_col_name_stem, '.', 'gaze2D_gaze_prop', '.pdf']);
	disp(['Saving figure as: ', cur_out_FQN]);
	write_out_figure(cur_fh, cur_out_FQN, [], [], plotting_options_struct.format_string_list);
end


end


function [condition_string, panel_group_key] = fn_local_parse_plot_set(cur_plot_set)
condition_string = [];
panel_group_key = cur_plot_set;
if contains(cur_plot_set, 'dyadic')
	condition_string = 'dyadic';
	panel_group_key = regexprep(cur_plot_set, '_dyadic$', '');
elseif contains(cur_plot_set, 'solo')
	condition_string = 'solo';
	panel_group_key = regexprep(cur_plot_set, '_solo$', '');
end
% if plot_set is just "dyadic"/"solo", force common group key for pairing
if strcmp(cur_plot_set, 'dyadic') || strcmp(cur_plot_set, 'solo')
	panel_group_key = 'all';
end
if isempty(panel_group_key)
	panel_group_key = 'all';
end
end

