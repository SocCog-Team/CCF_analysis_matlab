function [stats_table, meta_struct] = fn_fit_dyadic_vs_solo_gaze_glme(panel_index_struct_arr, gaze_on_object_prop_count_table, qval, use_cV_one, enable_ranksum_fallback, force_ranksum_only)
%FN_FIT_DYADIC_VS_SOLO_GAZE_GLME
% Uses panel indices (from plotting function) + source GOOPC table.
% Fits dyadic vs solo per panel_group_key x epoch x vergence x object.
% Primary test: binomial GLMM; fallback: ranksum on cycle-level percentages.
% Set force_ranksum_only = 1 to bypass GLMM and use ranksum for every
% testable panel/object.
% FDR correction: fdr_adj()

timestamps.(mfilename).start = tic;
disp(['Starting: ', mfilename]);
dbstop if error

if ~exist('qval', 'var') || isempty(qval), qval = 0.05; end
if ~exist('use_cV_one', 'var') || isempty(use_cV_one), use_cV_one = 1; end
if ~exist('enable_ranksum_fallback', 'var') || isempty(enable_ranksum_fallback), enable_ranksum_fallback = 1; end
if ~exist('force_ranksum_only', 'var') || isempty(force_ranksum_only), force_ranksum_only = 0; end

% Robustness thresholds
min_rows_per_group = 5;
min_total_rows = 10;

if isempty(panel_index_struct_arr)
	stats_table = table();
	meta_struct.n_models = 0;
	meta_struct.msg = 'No panel indices';
	fn_local_report_duration(timestamps.(mfilename).start);
	return
end

idx_table = struct2table(panel_index_struct_arr, 'AsArray', 1);
[object_label_list, object_n_col_list, target_n_col_list] = fn_local_get_object_count_map(gaze_on_object_prop_count_table);

stats_struct_arr = struct([]);

scope_key = strcat(string(idx_table.aggregation_type), "__", string(idx_table.panel_group_key), "__", string(idx_table.epoch), "__", string(idx_table.vergence));
unique_scope_key = unique(scope_key);
n_tests_total = numel(unique_scope_key) * numel(object_label_list);
i_test = 0;
disp([mfilename, ': INFO: evaluating ', num2str(n_tests_total), ' dyadic-vs-solo tests (', num2str(numel(unique_scope_key)), ' panels x ', num2str(numel(object_label_list)), ' objects).']);

for i_scope = 1 : numel(unique_scope_key)
	cur_scope_ldx = scope_key == unique_scope_key(i_scope);
	cur_scope_table = idx_table(cur_scope_ldx, :);

	dyad_i = find(strcmp(cur_scope_table.condition, 'dyadic'), 1, 'first');
	solo_i = find(strcmp(cur_scope_table.condition, 'solo'), 1, 'first');
	if isempty(dyad_i) || isempty(solo_i), continue; end

	dyad_ldx = cur_scope_table.goopc_row_ldx{dyad_i};
	solo_ldx = cur_scope_table.goopc_row_ldx{solo_i};
	if ~any(dyad_ldx) || ~any(solo_ldx), continue; end

	for i_obj = 1 : numel(object_label_list)
		i_test = i_test + 1;
		cur_obj = object_label_list{i_obj};
		cur_n_col = object_n_col_list{i_obj};
		disp([mfilename, ': INFO: test ', num2str(i_test), '/', num2str(n_tests_total), ...
			' | ', char(unique_scope_key(i_scope)), ' | ', cur_obj]);

		[dyad_n, dyad_total, dyad_pct] = fn_local_extract_object_data(gaze_on_object_prop_count_table, dyad_ldx, cur_n_col, target_n_col_list, cur_obj);
		[solo_n, solo_total, solo_pct] = fn_local_extract_object_data(gaze_on_object_prop_count_table, solo_ldx, cur_n_col, target_n_col_list, cur_obj);

		successes = [dyad_n; solo_n];
		trials = [dyad_total; solo_total];
		condition = [repmat({'dyadic'}, numel(dyad_n), 1); repmat({'solo'}, numel(solo_n), 1)];
		sessionID = [gaze_on_object_prop_count_table.sessionID(dyad_ldx); gaze_on_object_prop_count_table.sessionID(solo_ldx)];

		valid_ldx = isfinite(successes) & isfinite(trials) & (trials > 0) & (successes >= 0) & (successes <= trials);
		if sum(valid_ldx) < min_total_rows
			cur_row_struct = fn_local_make_stats_row(cur_scope_table, dyad_i, cur_obj, sum(valid_ldx), ...
				'not_testable', 'insufficient_total_rows', nan, nan, nan, nan, nan, ...
				median(dyad_pct, 'omitnan'), median(solo_pct, 'omitnan'), nan, nan, ...
				sum(isfinite(dyad_pct)), sum(isfinite(solo_pct)), false);
			stats_struct_arr = fn_local_append_stats_row(stats_struct_arr, cur_row_struct);
			continue
		end

		cur_tbl = table();
		cur_tbl.successes = round(successes(valid_ldx));
		cur_tbl.trials = round(trials(valid_ldx));
		cur_tbl.solo_dyadic = categorical(condition(valid_ldx), {'dyadic', 'solo'});
		cur_tbl.sessionID = categorical(sessionID(valid_ldx));

		median_pct_dyadic = median(dyad_pct, 'omitnan');
		median_pct_solo = median(solo_pct, 'omitnan');
		n_dyadic = sum(cur_tbl.solo_dyadic == 'dyadic');
		n_solo = sum(cur_tbl.solo_dyadic == 'solo');

		if n_dyadic < min_rows_per_group || n_solo < min_rows_per_group
			cur_row_struct = fn_local_make_stats_row(cur_scope_table, dyad_i, cur_obj, height(cur_tbl), ...
				'not_testable', 'insufficient_rows_per_group', nan, nan, nan, nan, nan, ...
				median_pct_dyadic, median_pct_solo, nan, nan, n_dyadic, n_solo, false);
			stats_struct_arr = fn_local_append_stats_row(stats_struct_arr, cur_row_struct);
			continue
		end

		if force_ranksum_only
			glmm_fail_reason = 'forced_ranksum_only';
		else
			% Try GLMM directly; fallback only on actual fit failure.
			try
				glme = fitglme(cur_tbl, 'successes ~ 1 + solo_dyadic + (1|sessionID)', ...
					'Distribution', 'Binomial', ...
					'Link', 'logit', ...
					'BinomialSize', cur_tbl.trials, ...
					'FitMethod', 'Laplace');

				coef_idx = find(contains(glme.CoefficientNames, 'solo_dyadic_solo'), 1, 'first');
				if isempty(coef_idx)
					coef_idx = find(contains(glme.CoefficientNames, 'solo_dyadic'), 1, 'last');
				end
				if isempty(coef_idx)
					error([mfilename, ': missing solo_dyadic coefficient']);
				end

				beta = glme.Coefficients.Estimate(coef_idx);
				p = glme.Coefficients.pValue(coef_idx);
				ci = coefCI(glme);

				cur_row_struct = fn_local_make_stats_row(cur_scope_table, dyad_i, cur_obj, height(cur_tbl), ...
					'glme_binomial', '', beta, exp(beta), exp(ci(coef_idx, 1)), exp(ci(coef_idx, 2)), p, ...
					median_pct_dyadic, median_pct_solo, nan, nan, n_dyadic, n_solo, true);
				stats_struct_arr = fn_local_append_stats_row(stats_struct_arr, cur_row_struct);
				continue
			catch ME
				glmm_fail_reason = ME.message;
			end
		end

		% fallback path, or explicitly requested simple ranksum mode
		if enable_ranksum_fallback || force_ranksum_only
			try
				[p_rs, ~, stats_rs] = ranksum(dyad_pct, solo_pct, 'method', 'approximate');
				cur_row_struct = fn_local_make_stats_row(cur_scope_table, dyad_i, cur_obj, numel(dyad_pct) + numel(solo_pct), ...
					fn_local_get_ranksum_method_name(force_ranksum_only), glmm_fail_reason, nan, nan, nan, nan, p_rs, ...
					median_pct_dyadic, median_pct_solo, stats_rs.zval, stats_rs.ranksum, n_dyadic, n_solo, true);
				stats_struct_arr = fn_local_append_stats_row(stats_struct_arr, cur_row_struct);
			catch ME2
				cur_row_struct = fn_local_make_stats_row(cur_scope_table, dyad_i, cur_obj, numel(dyad_pct) + numel(solo_pct), ...
					'not_testable', ['fallback_failed: ', ME2.message], nan, nan, nan, nan, nan, ...
					median_pct_dyadic, median_pct_solo, nan, nan, n_dyadic, n_solo, false);
				stats_struct_arr = fn_local_append_stats_row(stats_struct_arr, cur_row_struct);
			end
		else
			cur_row_struct = fn_local_make_stats_row(cur_scope_table, dyad_i, cur_obj, numel(dyad_pct) + numel(solo_pct), ...
				'not_testable', ['glmm_failed_no_fallback: ', glmm_fail_reason], nan, nan, nan, nan, nan, ...
				median_pct_dyadic, median_pct_solo, nan, nan, n_dyadic, n_solo, false);
			stats_struct_arr = fn_local_append_stats_row(stats_struct_arr, cur_row_struct);
		end
	end
end

if isempty(stats_struct_arr)
	stats_table = table();
	meta_struct.n_models = 0;
	meta_struct.msg = 'No valid tests';
	fn_local_report_duration(timestamps.(mfilename).start);
	return
end

stats_table = struct2table(stats_struct_arr, 'AsArray', 1);
stats_table.p_adj = nan(height(stats_table), 1);
valid_p_ldx = isfinite(stats_table.p) & stats_table.is_testable;
if any(valid_p_ldx)
	[~, ~, padj] = fdr_adj(stats_table.p(valid_p_ldx), qval, use_cV_one);
	stats_table.p_adj(valid_p_ldx) = padj;
end

meta_struct.n_models = height(stats_table);
meta_struct.qval = qval;
meta_struct.use_cV_one = use_cV_one;
meta_struct.enable_ranksum_fallback = enable_ranksum_fallback;
meta_struct.force_ranksum_only = force_ranksum_only;
meta_struct.min_rows_per_group = min_rows_per_group;
meta_struct.min_total_rows = min_total_rows;
meta_struct.n_tests_total = n_tests_total;
meta_struct.n_tests_completed = i_test;
meta_struct.msg = 'OK';

fn_local_report_duration(timestamps.(mfilename).start);
end

function [object_label_list, object_n_col_list, target_n_col_list] = fn_local_get_object_count_map(goopc_table)
object_label_list = {};
object_n_col_list = {};
base_map = {
	'ownHand', 'A_binocular_eye_on_aims0_N';
	'otherHand', 'A_binocular_eye_on_aims1_N';
	'face', 'A_binocular_eye_on_B_facecenter_N';
	'selTarg', 'A_binocular_eye_on_selected_target_N';
	'otherTarg', 'A_binocular_eye_on_other_targets_N';
	'Targets', '__TARGET_SUM__';
	};
for i_row = 1 : size(base_map, 1)
	if strcmp(base_map{i_row, 2}, '__TARGET_SUM__') || ismember(base_map{i_row, 2}, goopc_table.Properties.VariableNames)
		object_label_list{end+1} = base_map{i_row, 1}; %#ok<AGROW>
		object_n_col_list{end+1} = base_map{i_row, 2}; %#ok<AGROW>
	end
end
target_n_col_ldx = ~cellfun(@isempty, regexp(goopc_table.Properties.VariableNames, '^A_binocular_eye_on_target\d+_N$', 'once'));
target_n_col_list = goopc_table.Properties.VariableNames(target_n_col_ldx);
end

function [obj_n, total_n, obj_pct] = fn_local_extract_object_data(goopc_table, row_ldx, object_n_col, target_n_col_list, object_label)
total_n = goopc_table.total_N(row_ldx);
if strcmp(object_n_col, '__TARGET_SUM__')
	if isempty(target_n_col_list)
		obj_n = nan(sum(row_ldx), 1);
	else
		obj_n = sum(goopc_table{row_ldx, target_n_col_list}, 2, 'omitnan');
	end
else
	obj_n = goopc_table.(object_n_col)(row_ldx);
end
obj_pct = 100 * (obj_n ./ total_n);
obj_pct = obj_pct(isfinite(obj_pct));
if isempty(obj_pct)
	obj_pct = nan;
end
if strcmp(object_label, 'Targets') && all(isnan(obj_n))
	obj_n = nan(sum(row_ldx), 1);
end
end

function row_struct = fn_local_make_stats_row(scope_table, dyad_i, object_label, n_obs, test_method, fallback_reason, beta, or_val, or_ci_low, or_ci_high, p, median_pct_dyadic, median_pct_solo, ranksum_zval, ranksum_ranksum, n_dyadic, n_solo, is_testable)
row_struct.aggregation_type = scope_table.aggregation_type{dyad_i};
row_struct.panel_group_key = scope_table.panel_group_key{dyad_i};
row_struct.epoch = scope_table.epoch{dyad_i};
row_struct.vergence = scope_table.vergence{dyad_i};
row_struct.object_label = object_label;
row_struct.n_obs = n_obs;
row_struct.n_dyadic = n_dyadic;
row_struct.n_solo = n_solo;
row_struct.is_testable = is_testable;
row_struct.test_method = test_method;
row_struct.fallback_reason = fallback_reason;
row_struct.beta_solo_vs_dyadic = beta;
row_struct.or_solo_vs_dyadic = or_val;
row_struct.or_ci_low = or_ci_low;
row_struct.or_ci_high = or_ci_high;
row_struct.p = p;
row_struct.median_pct_dyadic = median_pct_dyadic;
row_struct.median_pct_solo = median_pct_solo;
row_struct.ranksum_zval = ranksum_zval;
row_struct.ranksum_ranksum = ranksum_ranksum;
end


function stats_struct_arr = fn_local_append_stats_row(stats_struct_arr, cur_row_struct)
if isempty(stats_struct_arr)
	stats_struct_arr = cur_row_struct;
	return
end
cur_row_struct = orderfields(cur_row_struct, stats_struct_arr);
stats_struct_arr(end+1) = cur_row_struct;
end


function method_name = fn_local_get_ranksum_method_name(force_ranksum_only)
if force_ranksum_only
	method_name = 'ranksum_forced';
else
	method_name = 'ranksum_fallback';
end
end


function fn_local_report_duration(start_tic)
cur_duration_s = toc(start_tic);
disp([mfilename, ' took: ', num2str(cur_duration_s), ' seconds (', num2str(floor(cur_duration_s/(60*60))), ' hours ', num2str(floor(rem(cur_duration_s, 3600)/60)), ' minutes ', num2str(mod(cur_duration_s, 60)), ' seconds).']);
end
