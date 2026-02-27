function [merged_data, merged_timestamp_list, merged_header, merged_idx_ts_data, merged_idx_ts_header] = fn_merge_sampled_data(raw_data_list, sample_type, fill_value)
%FN_MERGE_SAMPLED_DATA Merge AI or DI sample data across runs with gap filling.
%   Reconstructs per-sample timestamps for each run (mirroring
%   fn_estimate_per_sample_timestamps_for_h5table), then concatenates the
%   data with gap-filled intervals between runs.
%
%   sample_type : 'AI_samples' or 'DI_samples'
%   fill_value  : NaN for AI, 0 for DI
%
%   Gap sizing ensures the global linear timestamp interpolation used by
%   fn_estimate_per_sample_timestamps_for_h5table remains valid for the
%   merged file (uniform sample spacing including the synthetic gap rows).

timestamps.(mfilename).start = tic;
disp(['Starting: ', mfilename, ' for: ', sample_type]);
dbstop if error

merged_data = [];
merged_timestamp_list = [];
merged_header = {};
merged_idx_ts_data = [];
merged_idx_ts_header = {'python_index', 'sample_timestamp_s', 'batchsize'};

data_field = [sample_type, '_data'];
idx_ts_field = [sample_type, '_idx_ts_data'];
header_field = [sample_type, '_header'];
idx_ts_header_field = [sample_type, '_idx_ts_header'];


% --- Reconstruct per-sample timestamps for each run ---
per_run_data = {};
per_run_ts = {};
per_run_interval_s = [];

for i_run = 1 : length(raw_data_list)
	cur_raw = raw_data_list{i_run};

	if ~isfield(cur_raw.h5_struct, data_field) || isempty(cur_raw.h5_struct.(data_field))
		disp([mfilename, ': WARN: run ', num2str(i_run), ' has no ', sample_type, ' data.']);
		continue
	end
	if ~isfield(cur_raw.h5_struct, idx_ts_field)
		disp([mfilename, ': WARN: run ', num2str(i_run), ' has no ', sample_type, ' idx_ts data.']);
		continue
	end

	cur_data = squeeze(cur_raw.h5_struct.(data_field))';
	n_samples = size(cur_data, 1);

	cur_idx_ts_data = cur_raw.h5_struct.(idx_ts_field)';
	cur_idx_ts_header = cur_raw.json_struct.(idx_ts_header_field)';

	% Mirror the index correction logic from fn_estimate_per_sample_timestamps_for_h5table
	python_idx_col = ismember(cur_idx_ts_header, {'python_index'});
	ts_col = ismember(cur_idx_ts_header, {'sample_timestamp_s'});

	if ~ismember({'batchsize'}, cur_idx_ts_header)
		corrected_indices = cumsum(diff([0; cur_idx_ts_data(:, python_idx_col)]) + 1);
		cur_idx_ts_data(:, python_idx_col) = corrected_indices - 1;
	end

	matlab_indices = cur_idx_ts_data(:, python_idx_col) + 1;

	first_idx = matlab_indices(1);
	first_ts = cur_idx_ts_data(1, ts_col);
	last_idx = matlab_indices(end-1);
	last_ts = cur_idx_ts_data(end-1, ts_col);

	interval_s = (last_ts - first_ts) / (last_idx - first_idx);
	first_sample_ts = first_ts - (first_idx * interval_s);
	sample_ts_list = first_sample_ts + (1:n_samples)' * interval_s;

	per_run_data{end+1} = cur_data;
	per_run_ts{end+1} = sample_ts_list;
	per_run_interval_s(end+1) = interval_s;

	% Grab header from first valid run
	if isempty(merged_header) && isfield(cur_raw.json_struct, header_field)
		merged_header = cur_raw.json_struct.(header_field)';
	end
end

if isempty(per_run_data)
	disp([mfilename, ': no valid runs found for ', sample_type]);
	return
end


% --- Verify channel count consistency ---
n_channels = size(per_run_data{1}, 2);
for i_run = 2 : length(per_run_data)
	if size(per_run_data{i_run}, 2) ~= n_channels
		error([mfilename, ': channel count mismatch between runs for ', sample_type]);
	end
end


% --- Merge with gap filling ---
merged_data_cell = {};
merged_ts_cell = {};
cumulative_n_samples = 0;
idx_ts_anchor_list = [];

for i_run = 1 : length(per_run_data)

	% Gap fill between consecutive runs
	if i_run > 1
		prev_last_ts = per_run_ts{i_run-1}(end);
		cur_first_ts = per_run_ts{i_run}(1);
		mean_interval = mean([per_run_interval_s(i_run-1), per_run_interval_s(i_run)]);

		t_gap = cur_first_ts - prev_last_ts;
		n_gap = max(0, round(t_gap / mean_interval) - 1);

		if n_gap > 0
			gap_ts = prev_last_ts + (1:n_gap)' * mean_interval;
			if isnan(fill_value)
				gap_data = NaN(n_gap, n_channels);
			else
				gap_data = repmat(fill_value, n_gap, n_channels);
			end
			merged_data_cell{end+1} = gap_data;
			merged_ts_cell{end+1} = gap_ts;
			cumulative_n_samples = cumulative_n_samples + n_gap;
		end
	end

	% idx_ts anchor at start of this run (0-based python index)
	idx_ts_anchor_list(end+1, :) = [cumulative_n_samples, per_run_ts{i_run}(1), 1];

	merged_data_cell{end+1} = per_run_data{i_run};
	merged_ts_cell{end+1} = per_run_ts{i_run};
	n_cur = size(per_run_data{i_run}, 1);

	% idx_ts anchor at end of this run
	idx_ts_anchor_list(end+1, :) = [cumulative_n_samples + n_cur - 1, per_run_ts{i_run}(end), 1];

	cumulative_n_samples = cumulative_n_samples + n_cur;
end

merged_data = vertcat(merged_data_cell{:});
merged_timestamp_list = vertcat(merged_ts_cell{:});
merged_idx_ts_data = idx_ts_anchor_list;

disp([mfilename, ': merged ', num2str(length(per_run_data)), ' runs, ', ...
	num2str(cumulative_n_samples), ' total samples for ', sample_type]);

timestamps.(mfilename).end = toc(timestamps.(mfilename).start);
disp([mfilename, ' took: ', num2str(timestamps.(mfilename).end), ' seconds.']);

end
