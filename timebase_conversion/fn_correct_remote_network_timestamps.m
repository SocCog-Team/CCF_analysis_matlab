function [ col_header, corrected_local_timestamp_list ] = fn_correct_remote_network_timestamps( tracker_name, local_timestamp_list, remote_timetamp_list, TrackerLog_FQN )
% EventIDE_TimeStamps only recodr the time eventide imported a sample,
% while Tracker_Time_Stamps (for reliable Trackers) are closer to the real
% time of acquisition, use the traker timestamps to adjust the eventide
% timestamps
debug = 1;

col_header = 'corrected_local_timestamps';
corrected_local_timestamp_list = [];

% gracefully deal with empty trackerlogs
if isempty(local_timestamp_list)
	return
end
	
tracker_type = '';
% first deduce the type
if ~isempty(regexpi(tracker_name, 'PupilLabs', 'match'))
	tracker_type = 'pupillabs';
end
if ~isempty(regexpi(tracker_name, 'EyeLink', 'match'))
	tracker_type = 'eyelink';
end




% error out for unhandled types
switch tracker_type
	case 'pupillabs'
	case 'eyelink'
	
	otherwise
		error(['Encountered unhandled tracker type: ', tracker_name, ' please handle gracefully']);
end


%corrected_local_timestamp_list = zeros(size(local_timestamp_list));

% matching the end should be the simplest, we simlpy take the youngest
% timestamps we find for each tracker
last_EventIDE_ts = max(local_timestamp_list);
last_Tracker_ts = max(remote_timetamp_list);
% now to better match get the EventIDE_TimeStamp from the last_Tracker_ts
% sample
last_Tracker_ts_idx = find(remote_timetamp_list == last_Tracker_ts); % if multiple pick the first one
closest_matching_last_EventIDE_ts = local_timestamp_list(last_Tracker_ts_idx(1));

if (remote_timetamp_list(end) ~= last_Tracker_ts)
	disp('fn_extract_corrected_eventIDE_timestamps: last timestamp order of eventide and tracker not aligned, expected for PupilLabs data.');
end

first_EventIDE_ts = min(local_timestamp_list);	% again simple, as this is 
first_Tracker_ts = min(remote_timetamp_list);	% again simple, as this is 
% and now we want the highest Tracker_Time_Stamp with an EventIDE_TimeStamp
% <= first_EventIDE_ts, we need to do this is especially pupillabs samples
% are not strictly ordered in time
first_EventIDE_ts_sample_idx = find(local_timestamp_list <= first_EventIDE_ts);
% now get the highest Tracker_Time_Stamp in that subset
closest_matching_first_Tracker_ts = max(remote_timetamp_list(first_EventIDE_ts_sample_idx));

if (closest_matching_first_Tracker_ts ~= first_Tracker_ts)
	disp('fn_extract_corrected_eventIDE_timestamps: first timestamps of eventide and tracker not aligned, expected for PupilLabs data.');
end

ts_offset = first_EventIDE_ts;
ts_scale = (closest_matching_last_EventIDE_ts - first_EventIDE_ts) / (last_Tracker_ts - closest_matching_first_Tracker_ts);

% the actual correction will be different for the different trackers
switch tracker_type
	case 'pupillabs'
		% pupillabs data is unordered, but the main idea about aligning the
		% two timestamp series still should apply.
		corrected_local_timestamp_list = (remote_timetamp_list - closest_matching_first_Tracker_ts) * ts_scale + ts_offset;
	case 'eyelink'
		corrected_local_timestamp_list = (remote_timetamp_list - closest_matching_first_Tracker_ts) * ts_scale + ts_offset;

	otherwise
		error(['Encountered unhandled tracker type: ', tracker_name, ' please handle gracefully']);
end



if (debug)
	timestamp_correction_fh = figure('Name', 'local_timestamp_list - corrected_local_timestamp_list');
	subplot(4, 1, 1)
	hold on 
	plot(local_timestamp_list - local_timestamp_list(1), 'Color', [1 0 0]);
	legend_text = {'original EventIDE timestamps'};
	plot(corrected_local_timestamp_list - corrected_local_timestamp_list(1), 'Color', [0 1 0]);
	legend_text{end+1} = 'corrected_EventIDE_timestamps';
	plot(sort(corrected_local_timestamp_list) - corrected_local_timestamp_list(1), 'Color', [0 0 1]);
	legend_text{end+1} = 'sorted  corrected_EventIDE_timestamps';
	legend(legend_text);
	title('original and corrected timestamp series (offset by smalles timestamp)');
	hold off
	
	subplot(4, 1, 2)
	hold on 
	plot((local_timestamp_list - local_timestamp_list(1)) - (corrected_local_timestamp_list - corrected_local_timestamp_list(1)));
	title('original and corrected timestamp series');
	hold off

	subplot(4, 1, 3)
	h1 = histogram(diff(local_timestamp_list));
	hold on
	h2 = histogram(diff(sort(corrected_local_timestamp_list)));
	hold off
	
	subplot(4, 1, 4)
	h3 = histogram((local_timestamp_list - local_timestamp_list(1)) - (sort(corrected_local_timestamp_list) - corrected_local_timestamp_list(1)));
	
	
	[TrackerLog_path, TrackerLog_name] = fileparts(TrackerLog_FQN);
	write_out_figure(timestamp_correction_fh, fullfile(TrackerLog_path, [TrackerLog_name, 'Delta_corrected_uncorrected_EventIDE_TimeStamps.pdf']));
	% for automated processing, rather save a plot than keep a figure
	% open...
	drawnow;

	close(timestamp_correction_fh);
end

return
end
