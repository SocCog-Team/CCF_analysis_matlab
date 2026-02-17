function [ timestamp_list, data_struct, cur_fh ] = fn_estimate_per_sample_timestamps_for_h5table( cur_base_name, h5_struct, json_struct )
%FN_ESTIMATE_PER_SAMPLE_TIMESTAMPS_FOR_H4TABLE Summary of this function goes here
%   We can extra/inter- polate the timestamps from our best estimates of
%   individual sample timestamps, but we can not do the same for the
%   collection number as that does not increase gradually...

timestamp_list = [];
data_struct = [];
cur_fh = [];
debug = true;


if ~isempty(h5_struct) && ismember({[cur_base_name, '_data']}, fieldnames(h5_struct))
	% create a proper header for the data and reshape to 2D table...
	data_struct.header = json_struct.([cur_base_name, '_header'])';
	data_struct.table = squeeze(h5_struct.([cur_base_name, '_data']))';
	if ~isempty(h5_struct) && ismember({[cur_base_name, '_idx_ts_data']}, fieldnames(h5_struct))
		% construct a python timestamp list
		n_samples = size(data_struct.table, 1);
		cur_header = json_struct.([cur_base_name, '_idx_ts_header'])';
		cur_data = h5_struct.([cur_base_name, '_idx_ts_data'])';

		if ~ismember({'batchsize'}, cur_header)
			%broken indexing, fix this up
			% this is a ctude fix for incorrect indexing on AI and DI sampling
			corrected_matlab_indices = cumsum(diff([0; cur_data(:, ismember(cur_header, {'python_index'}))]) + 1);
			%first_idx = corrected_matlab_indices(1);
			%last_idx = corrected_matlab_indices(end);
			cur_data(:, ismember(cur_header, {'python_index'})) = corrected_matlab_indices - 1;
		end
			
		corrected_matlab_indices = cur_data(:, ismember(cur_header, {'python_index'})) + 1;

		first_idx = corrected_matlab_indices(1);	% python indices start at 0, so convert to matlab index here
		first_ts = cur_data(1, ismember(cur_header, {'sample_timestamp_s'}));
				
		last_idx = corrected_matlab_indices(end-1);
		last_ts = cur_data(end-1, ismember(cur_header, {'sample_timestamp_s'}));


		%% this is a ctude fix for incorrect indexing on AI and DI sampling
		%corrected_matlab_indices = cumsum(diff([0; cur_data(:, ismember(cur_header, {'python_index'}))]) + 1);
		%first_idx = corrected_matlab_indices(1);
		%last_idx = corrected_matlab_indices(end);



		time_incremnent_per_sample = (last_ts - first_ts) / (last_idx - first_idx); % divide the time span by the number od real samples in between
		first_sample_ts = first_ts - (first_idx * time_incremnent_per_sample);
		last_sample_ts = first_ts + (n_samples * time_incremnent_per_sample);
		sample_timestamp_s_data = first_sample_ts + (1:1:n_samples)' * time_incremnent_per_sample;
		%sample_timestamp_s_data(end) - last_sample_ts

		timestamp_list = sample_timestamp_s_data;
		data_struct.timestamp_list = sample_timestamp_s_data;

		% the next are trivially equal
		%sample_timestamp_s_data(first_idx) - first_ts
		%sample_timestamp_s_data(last_idx) - last_ts

		if (debug)
		% calculate the difference between the actual buffer service
		% timestamps and the reconstructed timestams after the rescaling
			diff_service_vs_sampling_times_ms = (sample_timestamp_s_data(corrected_matlab_indices) - cur_data(:, ismember(cur_header, {'sample_timestamp_s'}))) * 1000;
			cur_fh = figure('Name', [cur_base_name, '_buffer_service_time_versus_estimated_true_sample_time']);
			histogram(diff_service_vs_sampling_times_ms);
			title([cur_base_name, ' buffer service time vs. estimated sample time [ms]'], 'Interpreter', 'None');
			subtitle({['Mean: ', num2str(mean(diff_service_vs_sampling_times_ms)), '; Standard deviation: ', num2str(std(diff_service_vs_sampling_times_ms, 0))], ...
				['Max: ', num2str(max(diff_service_vs_sampling_times_ms)), '; Min: ', num2str(min(diff_service_vs_sampling_times_ms))], ...
				['sample interval: ', num2str(time_incremnent_per_sample * 1000), '; sampling rate [Hz]; ', num2str(1/time_incremnent_per_sample)]});
			xlabel('Time difference [ms]')
		end

	else
		disp(['WARNING: No ', cur_base_name, '_idx_ts_data data found in h5_struct.']);
	end

else
	disp(['WARNING: No ', cur_base_name, '_data data found in h5_struct.']);
end



end

