function [ onset_offset_events_struct ] = fn_extract_event_ts_from_photodiode_AI_samples( analog_signal_timestamp_list, analog_signal_data_list, collection_per_sample_list, analog_threshold_V)
%FN_EXTRACT_EVENT_TS_FROM_PHOTODIODE_AI_SAMPLES Summary of this function goes here
%   Detailed explanation goes here

onset_offset_events_struct = [];

n_samples = length(analog_signal_data_list);
n_collections = length(unique(collection_per_sample_list(~isnan(collection_per_sample_list))));


debug = 0;

if (debug)
	all_start_idx = 1;
	all_end_idx = n_samples;
	% sanity check, plot some of the data, say 5 minutes from the middle
	midtime_s = analog_signal_timestamp_list(floor(n_samples*0.5));
	start_idx = find(analog_signal_timestamp_list >= (midtime_s - (0.1 * 60)));
	start_idx = start_idx(1);
	end_idx = find(analog_signal_timestamp_list < (midtime_s + (0.1 * 60)));
	end_idx = end_idx(end);
	figure('Name', 'PhotodiodeSignal');
	plot(analog_signal_timestamp_list(start_idx:end_idx), analog_signal_data_list(start_idx:end_idx));
end

% now detect onsets and offsets of photodiode (pd) pulse trains
diff_pd_voltage = diff(analog_signal_data_list);

if (debug)
	hold on
	plot(analog_signal_timestamp_list(start_idx:end_idx), diff_pd_voltage(start_idx:end_idx));
	%plot(signallog.data(:, :));
	plot(analog_signal_timestamp_list(start_idx:end_idx), analog_signal_data_list(start_idx:end_idx));
	hold off
end

analog_threshold_V = 2.5;	% this is the change in amlitude between two samples.
% note on the falling edge the photodiode/spot detector box has
% noticeable skew
pd_onset_sample_idx = find(diff_pd_voltage >= analog_threshold_V) + 1; % +1 accounts for diff chopping off the first element
%% this is unprecise
%pd_offset_sample_idx = find(diff_pd_voltage <= -analog_threshold_V) + 1;

pd_offset_sample_idx = zeros(size(pd_onset_sample_idx));
for i_pd_onset = 1 : length(pd_onset_sample_idx)
	cur_pd_onset_idx = pd_onset_sample_idx(i_pd_onset);
	sample_offset = 1;
	% 3.45 Volts seems to work
	
	% the last value recorded is a rising flank
	if ((cur_pd_onset_idx + sample_offset) > n_samples)
		% or use NaN
		pd_offset_sample_idx(i_pd_onset) = cur_pd_onset_idx + 0;
		disp('The last sample of the photodiode data in the signallog is a rising flank (pd_onset). Setting the pd_offset to the same idx.');
	else
		while (analog_signal_data_list(cur_pd_onset_idx+sample_offset) >= 3.45)
			sample_offset = sample_offset + 1;
			if ((cur_pd_onset_idx + sample_offset) >= n_samples)
				if ((cur_pd_onset_idx + sample_offset) > n_samples)
					sample_offset = sample_offset -1;
				end
				% we reached the end and pretend that there is an pd offset
				% here, so onsets and offsets are paired
				break
			end
		end
		pd_offset_sample_idx(i_pd_onset) = cur_pd_onset_idx + sample_offset;
	end
end

% these are the individual pulses that reflect individual screen refreshes
% at the panels refresh rate (for the OLED likely 120 Hz)
pd_onset_sample_timestamp_list = analog_signal_timestamp_list(pd_onset_sample_idx);
pd_offset_sample_timestamp_list = analog_signal_timestamp_list(pd_offset_sample_idx);

% we might stop within a pulse so catch that
if length(pd_onset_sample_idx) ~= length(pd_offset_sample_idx)
	error('Unequal number of pulse on abnd offsets found, not handled yet');
end

onset_offset_events_struct.pd_onset_sample_timestamp_list = pd_onset_sample_timestamp_list;
onset_offset_events_struct.pd_offset_sample_timestamp_list = pd_offset_sample_timestamp_list;
pd_puls_dur_list = pd_offset_sample_timestamp_list - pd_onset_sample_timestamp_list;

% if we start within a pulse this would be wonky...
if pd_puls_dur_list(1) < 0
	error('Sampling started during PDD on epoch/pulse, not handled yet');
end


diff_pd_onset_sample_timestamp_list = diff(pd_onset_sample_timestamp_list);
diff_pd_offset_sample_timestamp_list = diff(pd_offset_sample_timestamp_list);

same_onset_sample_timestamp_list = find(abs(diff_pd_onset_sample_timestamp_list) <= 0.0 + (2 * eps));
same_offset_sample_timestamp_list = find(abs(diff_pd_offset_sample_timestamp_list) <= 0.0 + (2 * eps));

if ~isempty(same_onset_sample_timestamp_list) || ~isempty(same_offset_sample_timestamp_list)
	disp('Photodiode pulse detection seems to have cought the same onset of offset twice. This should not be, so investigate!');
	keyboard
end

if isempty(pd_onset_sample_timestamp_list) && isempty(pd_offset_sample_timestamp_list)
	disp([mfilename, ': No photodiode onsets or offsets detected, bailing out...']);
	return
end


% at this time it is guaranteed that these list are equally long and onsets
% happen before offsets
pd_pulse_dur_s_list = pd_offset_sample_timestamp_list - pd_onset_sample_timestamp_list;
%histogram(pd_pulse_dur_s_list)
% these should all be canonical, so averaging will work
avg_pulse_duration = mean(pd_pulse_dur_s_list);
%median_pulse_duration = median(pd_pulse_dur_s_list);


% these start at pd_offset_sample_timestamp_list timestamps
% the off periods between positive excursion pulses
pd_intra_pulse_dur_s_list = [(pd_onset_sample_timestamp_list(2:end) - pd_offset_sample_timestamp_list(1:end-1)); 0];
% the actual temporal distance between rising flanks of conscutive pulses
pd_inter_pulse_dur_s_list = [(pd_onset_sample_timestamp_list(2:end) - pd_onset_sample_timestamp_list(1:end-1)); 0];

%max(pd_inter_pulse_dur_s_list)
% these contain much larger variations, like real interstate delays
median_pd_inter_pulse_dur_s = median(pd_inter_pulse_dur_s_list);
%histogram(pd_inter_pulse_dur_s_list)


% find the display periods of the PhotoDiodeDriver stimulus
% the first sample is an offset of offset by definition, so make sure we
% get a delta showing this
pd_onset_diff = diff([pd_onset_sample_idx(1); pd_onset_sample_idx]);
pd_offset_diff = diff([pd_offset_sample_idx(1); pd_offset_sample_idx]);

pd_onset_sample_timestamp_diff_list = diff([pd_onset_sample_timestamp_list(1); pd_onset_sample_timestamp_list]);
pd_offset_sample_timestamp_diff_list = diff([pd_offset_sample_timestamp_list(1); pd_offset_sample_timestamp_list]);


histogram_fh = figure('Name', 'PhotoDiodeInterOnsetInterval');
%histogram((pd_onset_sample_timestamp_diff_list(find((pd_onset_sample_timestamp_diff_list * 1000) < 30)) * 1000));
%pd_onset_sample_timestamp_diff_list * 1000
tmp_data_idx = pd_onset_sample_timestamp_diff_list <= (0.030); % 30 ms would be 1/0.03sec or 33.3 Hz, we use refreshrates larger than that
tmp_data = pd_onset_sample_timestamp_diff_list(tmp_data_idx);
histogram( tmp_data );

if ~debug
	close(histogram_fh);
end



% this should be
median_inter_onset_dur_s = median(pd_onset_sample_timestamp_diff_list);
%mean_inter_onset_dur_s = mean(pd_onset_sample_timestamp_diff_list);
mean_inter_onset_dur_s = mean(tmp_data);

% calculate the screen refresh times:
% the OLED operates at 120Hz so
avg_interframe_delay_s = mean(tmp_data(find(tmp_data <= 0.018 & tmp_data >= 0.005)));	
refresh2frame_ratio = 2;	% the 120 Hz OLED only gets new inputs every other OLED-frame
% assume CRT @60Hz
if isnan(avg_interframe_delay_s)
	avg_interframe_delay_s = mean(tmp_data(find(tmp_data <= 0.020 & tmp_data >= 0.012)));
	refresh2frame_ratio = 1;
end

avg_screen_framerate = 1/avg_interframe_delay_s;
disp(['PhotoDiode pulses coming in at ~' num2str(avg_screen_framerate), ' Hz, with ', num2str(avg_interframe_delay_s*1000), 'ms inter pulse delay']);
% the OLED panel runds at ~ 120 Hz, so get the best matching
disp(['Actual screen probably refreshes at ~' num2str((1/refresh2frame_ratio) * avg_screen_framerate), ' Hz, with ', num2str(2.0 * avg_interframe_delay_s*1000), 'ms inter pulse delay']);

% now find the gaps in the pulse patterns caused by changes of the
% PhotoDiodeDriver stimulus


% special case CRTs?
switch refresh2frame_ratio
	case 1
		min_frames_per_gap = 3;
	case 2
		min_frames_per_gap = 2.1; %1.9;
	otherwise
		min_frames_per_gap = 2;
end

% initialize too large, will be pruned later
pd_block_onset_s_list = zeros(size(pd_pulse_dur_s_list));
pd_block_offset_s_list = pd_block_onset_s_list;
pd_block_onset_collection_num_list = nan(size(pd_block_onset_s_list));
pd_block_offset_collection_num_list = nan(size(pd_block_onset_s_list));
block_counter = 0; % blocks of pulses, aka preiods during which the PDD stimulus was shown
pd_block_onset_s_list(1) = pd_onset_sample_timestamp_list(1); % the first block starts with the first recorded pulse
for i_pulse = 1 : length(pd_inter_pulse_dur_s_list)
	cur_inter_pulse_dur_s = pd_inter_pulse_dur_s_list(i_pulse);
	% CCF paradigm state changes with visible elements will toggle the
	% stimulus below the photodiode, so we want to look for longer switches
	% between on and off states
	if (cur_inter_pulse_dur_s >= median_inter_onset_dur_s * min_frames_per_gap)
		% seems to be a genuine block start, get the matching onset and
		% offset times
		% pd_inter_pulse_dur_ms_list = [(pd_onset_sample_timestamp_list(2:end) - pd_offset_sample_timestamp_list(1:end-1)); 0];
		block_counter = block_counter + 1;
		pd_block_onset_s_list(block_counter + 1) = pd_onset_sample_timestamp_list(i_pulse + 1);
		pd_block_offset_s_list(block_counter) = pd_offset_sample_timestamp_list(i_pulse);

		% these should well be witin an collection period
		pd_block_onset_collection_num_list(block_counter) = collection_per_sample_list(find(analog_signal_timestamp_list == pd_block_onset_s_list(block_counter)));

		% but these suffer from the stimulation running on its own clock,
		% potentially lagging the state machine clock...
		pd_block_offset_collection_num_list(block_counter) = collection_per_sample_list(find(analog_signal_timestamp_list == pd_block_offset_s_list(block_counter)));	% due to our collection counting the photodiode driver offset will be one collection_num higher than the onset....
		%pd_block_collection_num_list(block_counter) = mean(collection_per_sample_list([cur_onset_ts_idx, cur_offset_ts_idx]));
	end
	
end
% prune the lists to remove unfilled rows.
pd_block_onset_s_list = pd_block_onset_s_list(1:block_counter);
pd_block_offset_s_list = pd_block_offset_s_list(1:block_counter);


% % can npot happen right now...
% % now find what happened first, transition onset or offset transition
% if pd_block_onset_s_list(1) == pd_block_offset_s_list(1)
% 	error([mfilename, ': this should npot happen, investigate...']);
% elseif pd_block_onset_s_list(1) < pd_block_offset_s_list(1)
% 	% expected order, we started with PDD off
% elseif pd_block_onset_s_list(1) > pd_block_offset_s_list(1)
% 	% unexpected order, we started with PDD on
% end

pd_block_dur_s = pd_block_offset_s_list - pd_block_onset_s_list;
pd_inter_block_dur_s = [(pd_block_onset_s_list(2:end) - pd_block_offset_s_list(1:end-1)); 0];


onset_offset_events_struct.pd_block_onset_s_list = pd_block_onset_s_list;
onset_offset_events_struct.pd_block_offset_s_list = pd_block_offset_s_list;
onset_offset_events_struct.pd_block_onset_collection_num_list = pd_block_onset_collection_num_list(1:block_counter);
onset_offset_events_struct.pd_block_offset_collection_num_list = pd_block_offset_collection_num_list(1:block_counter);


pd_fh = figure('Name', 'PhotoDiode Signal with Block Onset and Offset');
legend_list = {};
hold on
legend_list{end+1} = 'PhotoDiode';
plot(analog_signal_timestamp_list, analog_signal_data_list);

% show the detected block onsets and offsets
y_lim = get(gca, 'YLim');
set(gca, 'YLim', [-0.5 y_lim(2)]);

y_lim = get(gca, 'YLim');

% plot the detected block borders
for i_PD_block_onset = 1 : length(pd_block_onset_s_list)
	plot([pd_block_onset_s_list(i_PD_block_onset), pd_block_onset_s_list(i_PD_block_onset)], [0 y_lim(2)], 'Color', [0 1 0]);
end
legend_list{end+1} = 'PD_block_onset';
for i_PD_block_offset = 1 : length(pd_block_offset_s_list)
	plot([pd_block_offset_s_list(i_PD_block_offset), pd_block_offset_s_list(i_PD_block_offset)], [0 y_lim(2)], 'Color', [1 0 0]);
end
legend_list{end+1} = 'PD_block_offset';




% % plot the photo diode times as well
% PD_transition_visibility = output_struct.PhotoDiodeRenderer.data(:, output_struct.PhotoDiodeRenderer.cn.Visible);
% PD_onset_timestamps = output_struct.PhotoDiodeRenderer.data((PD_transition_visibility == 1), output_struct.PhotoDiodeRenderer.cn.Timestamp);
% PD_offset_timestamps = output_struct.PhotoDiodeRenderer.data((PD_transition_visibility == 0), output_struct.PhotoDiodeRenderer.cn.Timestamp);
% for i_PhotoDiodeRenderer_onset = 1 : length(PD_onset_timestamps)
% 	plot([PD_onset_timestamps(i_PhotoDiodeRenderer_onset), PD_onset_timestamps(i_PhotoDiodeRenderer_onset)], [y_lim(1) 0], 'Color', [0 0.6 0]);
% end
% legend_list{end+1} = 'PhotoDiodeRenderer_onset';
% for i_PhotoDiodeRenderer_offset = 1 : length(PD_offset_timestamps)
% 	plot([PD_offset_timestamps(i_PhotoDiodeRenderer_offset), PD_offset_timestamps(i_PhotoDiodeRenderer_offset)], [y_lim(1) 0], 'Color', [0.6 0 0]);
% end
% legend_list{end+1} = 'PhotoDiodeRenderer_offset';
% 
% hold off
% %scrollplot;
% write_out_figure(pd_fh, fullfile(signallog_base_dir, ['PhotoDiode_Signal_with_Block_Onset_and_Offset', '.pdf']));
if ~debug
	close(pd_fh);
end





end



% for reference
function [ output_struct ] = fnFixVisualChangeTimesFromPhotodiodeSignallog( output_struct, signallog_base_FQN )


% % check for sufficient information, for the new complete PhotoDiodeRenderer
% % information.
% if ~isfield(output_struct, 'PhotoDiodeRenderer') || ~isfield(output_struct.PhotoDiodeRenderer, 'cn')
% 	disp(['fnFixVisualChangeTimesFromPhotodiodeSignallog: PhotoDiodeRenderer does not exist or is empty, no timing correction possible.']);
% 	output_struct.FixUpReport{end+1} = 'fnFixVisualChangeTimesFromPhotodiodeSignallog: PhotoDiodeRenderer does not exist or is empty, no timing correction possible.';
% 	return
% end	
% 
% debug = 0;
% 
% [signallog_base_dir, signallog_base_name]  = fileparts(signallog_base_FQN);
% 
% 
% % load the most refined version of the signallog
% signallog = fnParseEventIDETrackerLog_v01( signallog_base_FQN, [], [], []);
% n_samples = size(signallog.data, 1);
% 
% % get the relevant channel/column
% if isfield(signallog, 'info') && isfield(signallog.info, 'patient_id')
% 	%signallog.info.patient_id
% 	channel_name_list = textscan(signallog.info.patient_id, '%s','Delimiter',',')';
% 	channel_name_list = channel_name_list{1};
% 	photo_diode_signal_col = [];
% 	tmp_list = strfind(channel_name_list, 'SpotDetector');
% 	for i_col = 1 : length(channel_name_list)
% 		if ~isempty(tmp_list{i_col})
% 			photo_diode_signal_col = i_col;
% 		end
% 	end
% 
% 	timestamp_col = [];
% 	tmp_list = strfind(channel_name_list, 'EventIDE_TimeStamp');
% 	for i_col = 1 : length(channel_name_list)
% 		if ~isempty(tmp_list{i_col})
% 			timestamp_col = i_col;
% 		end
% 	end
% else
% 	error('Find the photodiode column for old data, not implemented yet');
% end

% for testing the uncorrcted eventIDE timestamps
% these show no drift, while the corrected timestamps change a bit over
% time, linerly, so the correction code needs a bit of corrective work
%timestamp_col = signallog.cn.UncorrectedEventIDE_TimeStamp;

% 
% if (debug)
% 	% sanity check, plot some of the data, say 5 minutes from the middle
% 	midtime_ms = signallog.data(floor(n_samples*0.5), timestamp_col);
% 	start_idx = find(signallog.data(:, timestamp_col) >= (midtime_ms - (5 * 60 * 2000)));
% 	start_idx = start_idx(1);
% 	end_idx = find(signallog.data(:, timestamp_col) < (midtime_ms + (5 * 60 * 2000)));
% 	end_idx = end_idx(end);
% 	figure('Name', 'PhotodiodeSignal?');
% 	plot(signallog.data(start_idx:end_idx, timestamp_col), signallog.data(start_idx:end_idx, photo_diode_signal_col));
% end

% % now detect onsets and offsets of photodiode (pd) pulse trains
% diff_pd_voltage = diff(signallog.data(:, photo_diode_signal_col));
% 
% if (debug)
% 	hold on
% 	plot(diff_pd_voltage);
% 	%plot(signallog.data(:, :));
% 	plot(signallog.data(:, photo_diode_signal_col));
% 	hold off
% end
% 
% % the rising flank is nice and steep but the falling flank is a bit
% % broader


% analog_threshold_V = 2.5;	% this is the change in amlitude between two samples.
% % note on the falling edge the photodiode/spot detector box has
% % noticeable skew
% pd_onset_sample_idx = find(diff_pd_voltage >= analog_threshold_V) + 1; % +1 accounts for diff chopping off the first element
% %% this is unprecise
% %pd_offset_sample_idx = find(diff_pd_voltage <= -analog_threshold_V) + 1;
% 
% pd_offset_sample_idx = zeros(size(pd_onset_sample_idx));
% for i_pd_onset = 1 : length(pd_onset_sample_idx)
% 	cur_pd_onset_idx = pd_onset_sample_idx(i_pd_onset);
% 	sample_offset = 1;
% 	% 3.45 Volts seems to work
% 
% 	% the last value recorded is a rising flank
% 	if ((cur_pd_onset_idx+sample_offset) > n_samples)
% 		% or use NaN
% 		pd_offset_sample_idx(i_pd_onset) = cur_pd_onset_idx + 0;
% 		disp('The last sample of the photodiode data in the signallog is a rising flank (pd_onset). Setting the pd_offset to the same idx.');
% 	else
% 		while (signallog.data(cur_pd_onset_idx+sample_offset, photo_diode_signal_col) >= 3.45)
% 			sample_offset = sample_offset + 1;
% 			if ((cur_pd_onset_idx+sample_offset) >= n_samples)
% 				if ((cur_pd_onset_idx+sample_offset) > n_samples)
% 					sample_offset = sample_offset -1;
% 				end
% 				% we reached the end and pretend that there is an pd offset
% 				% here, so onsets and offsets are paired
% 				break
% 			end
% 		end
% 		pd_offset_sample_idx(i_pd_onset) = cur_pd_onset_idx + sample_offset;
% 	end
% end
% 
% pd_onset_sample_timestamp_list = signallog.data(pd_onset_sample_idx, timestamp_col);
% pd_offset_sample_timestamp_list = signallog.data(pd_offset_sample_idx, timestamp_col);


% pd_puls_dur_list = pd_offset_sample_timestamp_list - pd_onset_sample_timestamp_list;
% diff_pd_onset_sample_timestamp_list = diff(pd_onset_sample_timestamp_list);
% diff_pd_offset_sample_timestamp_list = diff(pd_offset_sample_timestamp_list);
% 
% same_onset_sample_timestamp_list = find(abs(diff_pd_onset_sample_timestamp_list) <= 0.0 + (2 * eps));
% same_offset_sample_timestamp_list = find(abs(diff_pd_offset_sample_timestamp_list) <= 0.0 + (2 * eps));
% 
% if ~isempty(same_onset_sample_timestamp_list) || ~isempty(same_offset_sample_timestamp_list)
% 	disp('Photodiode pulse detection seems to have cought the same onset of offset twice. This should not be, so investigate!');
% 	keyboard
% end
% 
% 
% if isempty(pd_onset_sample_timestamp_list) && isempty(pd_offset_sample_timestamp_list)
% 	disp(['fnFixVisualChangeTimesFromPhotodiodeSignallog: No photodiode onsets or offsets detected, bailing out...']);
% 	output_struct.FixUpReport{end+1} = 'fnFixVisualChangeTimesFromPhotodiodeSignallog: No PhotoDiode data found; could not correct the PhotoDiodeRenderer times from recorded PhotoDiode data';
% 	return
% end
	
% pd_pulse_dur_s_list = pd_offset_sample_timestamp_list - pd_onset_sample_timestamp_list;
% %histogram(pd_pulse_dur_s_list)
% % these should all be canonical, so averaging will work
% avg_pulse_duration = mean(pd_pulse_dur_s_list);
% %median_pulse_duration = median(pd_pulse_dur_s_list);
% 
% 
% % these start at pd_offset_sample_timestamp_list timestamps
% pd_inter_pulse_dur_ms_list = [(pd_onset_sample_timestamp_list(2:end) - pd_offset_sample_timestamp_list(1:end-1)); 0];
% %max(pd_inter_pulse_dur_ms_list)
% % these contain much larger variations, like real interstate delays
% median_pd_inter_pulse_dur_ms = median(pd_inter_pulse_dur_ms_list);
% %histogram(pd_inter_pulse_dur_ms_list)
% 
% 
% % find the display periods of the PhotoDiodeDriver stimulus
% % the first sample is an offset of offset by definition, so make sure we
% % get a delta showing this
% pd_onset_diff = diff([pd_onset_sample_idx(1); pd_onset_sample_idx]);
% pd_offset_diff = diff([pd_offset_sample_idx(1); pd_offset_sample_idx]);
% 
% pd_onset_sample_timestamp_diff_list = diff([pd_onset_sample_timestamp_list(1); pd_onset_sample_timestamp_list]);
% pd_offset_sample_timestamp_diff_list = diff([pd_offset_sample_timestamp_list(1); pd_offset_sample_timestamp_list]);
% 
% 
% histogram_fh = figure('Name', 'PhotoDiodeInterOnsetInterval');
% %histogram((pd_onset_sample_timestamp_diff_list(find((pd_onset_sample_timestamp_diff_list * 1000) < 30)) * 1000));
% %pd_onset_sample_timestamp_diff_list * 1000
% tmp_data_idx = pd_onset_sample_timestamp_diff_list <= (30); % 30 ms would be 1/0.03sec or 33.3 Hz, we use refreshrates larger than that
% tmp_data = pd_onset_sample_timestamp_diff_list(tmp_data_idx);
% histogram( tmp_data );
% 
% if ~debug
% 	close(histogram_fh);
% end

% this should be
median_inter_onset_dur_ms = median(pd_onset_sample_timestamp_diff_list);
%mean_inter_onset_dur_ms = mean(pd_onset_sample_timestamp_diff_list);
mean_inter_onset_dur_ms = mean(tmp_data);

% calculate the screen refresh times:
% the OLED operates at 120Hz so
avg_interframe_delay_s = mean(tmp_data(find(tmp_data <= 16 & tmp_data >= 5)));
refresh2frame_ratio = 2;	% the 120 Hz OLED only gets new inputs every other OLED-frame
% assume CRT @60Hz
if isnan(avg_interframe_delay_s)
	avg_interframe_delay_s = mean(tmp_data(find(tmp_data <= 20 & tmp_data >= 12)));
	refresh2frame_ratio = 1;
end

avg_screen_framerate = 1000/avg_interframe_delay_s;
disp(['PhotoDiode pulses coming in at ~' num2str(avg_screen_framerate), ' Hz, with ', num2str(avg_interframe_delay_s), 'ms inter pulse delay']);
% the OLED panel runds at ~ 120 Hz, so get the best matching
disp(['Actual screen probably refreshes at ~' num2str((1/refresh2frame_ratio) * avg_screen_framerate), ' Hz, with ', num2str(2.0 * avg_interframe_delay_s), 'ms inter pulse delay']);

% now find the gaps in the pulse patterns caused by changes of the
% PhotoDiodeDriver stimulus


% special case CRTs?
switch refresh2frame_ratio
	case 1
		min_frames_per_gap = 3;
	case 2
		min_frames_per_gap = 1.9;
	otherwise
		min_frames_per_gap = 2;
end

% initialize too large, will be pruned later
pd_block_onset_ms_list = zeros(size(pd_pulse_dur_s_list));
pd_block_offset_ms_list = pd_block_onset_ms_list;
block_counter = 0;
pd_block_onset_ms_list(1) = pd_onset_sample_timestamp_list(1); % the first block starts with the first recorded pulse
for i_pulse = 1 : length(pd_inter_pulse_dur_ms_list)
	cur_inter_pulse_dur_ms = pd_inter_pulse_dur_ms_list(i_pulse);
	% EventIDE paradigm state changes with visible elements will toggle the
	% stimulus beow the photodiode, so we want to look for longer switches
	% between on and off states
	if (cur_inter_pulse_dur_ms >= median_inter_onset_dur_ms * min_frames_per_gap)
		% seems to be a genuine block start, get the matching onset and
		% offset times
		% pd_inter_pulse_dur_ms_list = [(pd_onset_sample_timestamp_list(2:end) - pd_offset_sample_timestamp_list(1:end-1)); 0];
		block_counter = block_counter + 1;
		pd_block_onset_ms_list(block_counter + 1) = pd_onset_sample_timestamp_list(i_pulse + 1);
		pd_block_offset_ms_list(block_counter) = pd_offset_sample_timestamp_list(i_pulse);
	end
	
end
% prune the lists to remove unfilled rows.
pd_block_onset_ms_list = pd_block_onset_ms_list(1:block_counter);
pd_block_offset_ms_list = pd_block_offset_ms_list(1:block_counter);
pd_block_dur_ms = pd_block_offset_ms_list - pd_block_onset_ms_list;
pd_inter_block_dur_ms = [(pd_block_onset_ms_list(2:end) - pd_block_offset_ms_list(1:end-1)); 0];


pd_fh = figure('Name', 'PhotoDiode Signal with Block Onset and Offset');
legend_list = {};
hold on
legend_list{end+1} = 'PhotoDiode';
plot(signallog.data(:, timestamp_col), signallog.data(:, photo_diode_signal_col));

% show the detected block onsets and offsets
y_lim = get(gca, 'YLim');
set(gca, 'YLim', [-0.5 y_lim(2)]);

y_lim = get(gca, 'YLim');

% plot the detected block borders
for i_PD_block_onset = 1 : length(pd_block_onset_ms_list)
	plot([pd_block_onset_ms_list(i_PD_block_onset), pd_block_onset_ms_list(i_PD_block_onset)], [0 y_lim(2)], 'Color', [0 1 0]);
end
legend_list{end+1} = 'PD_block_onset';
for i_PD_block_offset = 1 : length(pd_block_offset_ms_list)
	plot([pd_block_offset_ms_list(i_PD_block_offset), pd_block_offset_ms_list(i_PD_block_offset)], [0 y_lim(2)], 'Color', [1 0 0]);
end
legend_list{end+1} = 'PD_block_offset';

% plot the photo diode times as well
PD_transition_visibility = output_struct.PhotoDiodeRenderer.data(:, output_struct.PhotoDiodeRenderer.cn.Visible);
PD_onset_timestamps = output_struct.PhotoDiodeRenderer.data((PD_transition_visibility == 1), output_struct.PhotoDiodeRenderer.cn.Timestamp);
PD_offset_timestamps = output_struct.PhotoDiodeRenderer.data((PD_transition_visibility == 0), output_struct.PhotoDiodeRenderer.cn.Timestamp);
for i_PhotoDiodeRenderer_onset = 1 : length(PD_onset_timestamps)
	plot([PD_onset_timestamps(i_PhotoDiodeRenderer_onset), PD_onset_timestamps(i_PhotoDiodeRenderer_onset)], [y_lim(1) 0], 'Color', [0 0.6 0]);
end
legend_list{end+1} = 'PhotoDiodeRenderer_onset';
for i_PhotoDiodeRenderer_offset = 1 : length(PD_offset_timestamps)
	plot([PD_offset_timestamps(i_PhotoDiodeRenderer_offset), PD_offset_timestamps(i_PhotoDiodeRenderer_offset)], [y_lim(1) 0], 'Color', [0.6 0 0]);
end
legend_list{end+1} = 'PhotoDiodeRenderer_offset';

hold off
%scrollplot;
write_out_figure(pd_fh, fullfile(signallog_base_dir, ['PhotoDiode_Signal_with_Block_Onset_and_Offset', '.pdf']));
if ~debug
	close(pd_fh);
end

% now find the corresponding events for the photodiode

if isfield(output_struct, 'PhotoDiodeRenderer') && (size(output_struct.PhotoDiodeRenderer.data, 1) > 1)
	% we need to correct output_struct.PhotoDiodeRenderer.cn.Timestamp and output_struct.PhotoDiodeRenderer.cn.RenderTimestamp_ms
	% Visible denotes the state transition
	% we need to correct RendererState and (main) data onset and offsets
	% as well as Render
	
	% prepare the PhotoDiodeRenderer record
	output_struct.PhotoDiodeRenderer.header{end + 1} = 'uncorrected_Timestamp';
	output_struct.PhotoDiodeRenderer.header{end + 1} = 'uncorrected_RenderTimestamp_ms';
	output_struct.PhotoDiodeRenderer.cn = local_get_column_name_indices(output_struct.PhotoDiodeRenderer.header);
	output_struct.PhotoDiodeRenderer.data(:, output_struct.PhotoDiodeRenderer.cn.uncorrected_Timestamp) = output_struct.PhotoDiodeRenderer.data(:, output_struct.PhotoDiodeRenderer.cn.Timestamp);
	output_struct.PhotoDiodeRenderer.data(:, output_struct.PhotoDiodeRenderer.cn.uncorrected_RenderTimestamp_ms) = output_struct.PhotoDiodeRenderer.data(:, output_struct.PhotoDiodeRenderer.cn.RenderTimestamp_ms);
	
	PD_transition_timestamps = output_struct.PhotoDiodeRenderer.data(:, output_struct.PhotoDiodeRenderer.cn.Timestamp);
	PD_transition_visibility = output_struct.PhotoDiodeRenderer.data(:, output_struct.PhotoDiodeRenderer.cn.Visible);
	
	RenderTimestamp_ms_photodiode_diff_list = zeros(size(PD_transition_timestamps));
	
	for i_PD_transition = 1 : length(PD_transition_timestamps)
		cur_PD_transition_timestamp = PD_transition_timestamps(i_PD_transition);
		
		if (PD_transition_visibility(i_PD_transition) == 1)
			% Visible == 1 means the renderer was activated -> pd_block_onset
			tmp_idx = find(pd_block_onset_ms_list >= cur_PD_transition_timestamp, 1);
			if ~isempty(tmp_idx)
				cur_corrected_time = pd_block_onset_ms_list(tmp_idx);
				output_struct.PhotoDiodeRenderer.data(i_PD_transition, output_struct.PhotoDiodeRenderer.cn.Timestamp) = cur_corrected_time;
				output_struct.PhotoDiodeRenderer.data(i_PD_transition, output_struct.PhotoDiodeRenderer.cn.RenderTimestamp_ms) = cur_corrected_time;
			end
		else
			% Visible == 0 means the renderer was deactivated -> pd_block_offset
			tmp_idx = find(pd_block_offset_ms_list >= cur_PD_transition_timestamp, 1);
			if ~isempty(tmp_idx)
				cur_corrected_time = pd_block_offset_ms_list(tmp_idx);
				output_struct.PhotoDiodeRenderer.data(i_PD_transition, output_struct.PhotoDiodeRenderer.cn.Timestamp) = cur_corrected_time;
				output_struct.PhotoDiodeRenderer.data(i_PD_transition, output_struct.PhotoDiodeRenderer.cn.RenderTimestamp_ms) = cur_corrected_time;
			end
		end
		% save the time correction, if one was made
		if ~isempty(tmp_idx)
			RenderTimestamp_ms_photodiode_diff_list(i_PD_transition) = cur_corrected_time - cur_PD_transition_timestamp;
		end
	end
	output_struct.FixUpReport{end+1} = 'fnFixVisualChangeTimesFromPhotodiodeSignallog: Corrected the PhotoDiodeRenderer times from recorded PhotoDiode data';
	
	
	PD_overview_fh = figure('Name', 'PhotoDiodeBlockTimes minus EventIDE RenderTimes');
	subplot(2, 2, 1)
	histogram(RenderTimestamp_ms_photodiode_diff_list(find(PD_transition_visibility == 1)), (30:1:100)),
	title('Block Onset: difference histogram between PhotoDiode Time and RenderTimes');
	
	subplot(2, 2, 2)
	plot(PD_transition_timestamps(find(PD_transition_visibility == 1)), RenderTimestamp_ms_photodiode_diff_list(find(PD_transition_visibility == 1))),
	title('Block Onset: difference between PhotoDiode Time and RenderTimes over time');
	
	subplot(2, 2, 3)
	histogram(RenderTimestamp_ms_photodiode_diff_list(find(PD_transition_visibility == 0)), (30:1:100)),
	title('Block Offset: difference histogram between PhotoDiode Time and RenderTimes');
	
	subplot(2, 2, 4)
	plot(PD_transition_timestamps(find(PD_transition_visibility == 0)), RenderTimestamp_ms_photodiode_diff_list(find(PD_transition_visibility == 0))),
	title('Block Offset: difference between PhotoDiode Time and RenderTimes over time');
	
	write_out_figure(PD_overview_fh, fullfile(signallog_base_dir, [signallog_base_name, '.VisualOnsetOffset.pdf']))
	
	if ~debug
		close(PD_overview_fh);
	end
	
	
	% now correct
	
	% we need to correct RendererState and (main) data onset and offsets
	% as well as Render
	
	% prepare the Render record
	output_struct.Render.header{end + 1} = 'uncorrected_Timestamp';
	output_struct.Render.cn = local_get_column_name_indices(output_struct.Render.header);
	output_struct.Render.data(:, output_struct.Render.cn.uncorrected_Timestamp) = output_struct.Render.data(:, output_struct.Render.cn.Timestamp);
	
	for i_PhotoDiodeRendererChange = 1 : size(output_struct.PhotoDiodeRenderer.data, 1)
		cur_corrected_RenderTimestamp_ms = output_struct.PhotoDiodeRenderer.data(i_PhotoDiodeRendererChange, output_struct.PhotoDiodeRenderer.cn.RenderTimestamp_ms);
		cur_uncorrected_RenderTimestamp_ms  = output_struct.PhotoDiodeRenderer.data(i_PhotoDiodeRendererChange, output_struct.PhotoDiodeRenderer.cn.uncorrected_RenderTimestamp_ms);
		% find the occurance of uncorrected timestamp and replace with
		% corrected value
		tmp_idx = find(output_struct.Render.data(:, output_struct.Render.cn.Timestamp) == cur_uncorrected_RenderTimestamp_ms);
		if ~isempty(tmp_idx)
			output_struct.Render.data(tmp_idx, output_struct.Render.cn.Timestamp) = cur_corrected_RenderTimestamp_ms;
		end
	end
	output_struct.FixUpReport{end+1} = 'fnFixVisualChangeTimesFromPhotodiodeSignallog: Corrected the Render times from recorded PhotoDiode data';
	
	
	to_be_corrected_data_filed_list = {'Timestamp', 'RenderTimestamp_ms'};
	for i_field = 1 : length(to_be_corrected_data_filed_list)
		if isfield(output_struct, 'RendererState') && isfield(output_struct.RendererState, 'data')
			cur_fieldname = to_be_corrected_data_filed_list{i_field};
			cur_uncorrected_fieldname = ['uncorrected_', cur_fieldname];
			if isfield(output_struct.RendererState.cn, cur_fieldname)
				output_struct.RendererState.header{end + 1} = cur_uncorrected_fieldname;
				output_struct.RendererState.cn = local_get_column_name_indices(output_struct.RendererState.header);
				output_struct.RendererState.data(:, output_struct.RendererState.cn.(cur_uncorrected_fieldname)) = output_struct.RendererState.data(:, output_struct.RendererState.cn.(cur_fieldname));
				
				for i_PhotoDiodeRendererChange = 1 : size(output_struct.PhotoDiodeRenderer.data, 1)
					cur_corrected_RenderTimestamp_ms = output_struct.PhotoDiodeRenderer.data(i_PhotoDiodeRendererChange, output_struct.PhotoDiodeRenderer.cn.RenderTimestamp_ms);
					cur_uncorrected_RenderTimestamp_ms  = output_struct.PhotoDiodeRenderer.data(i_PhotoDiodeRendererChange, output_struct.PhotoDiodeRenderer.cn.uncorrected_RenderTimestamp_ms);
					% find the occurance of uncorrected timestamp and replace with
					% corrected value
					tmp_idx = find(output_struct.RendererState.data(:, output_struct.RendererState.cn.(cur_uncorrected_fieldname)) == cur_uncorrected_RenderTimestamp_ms);
					if ~isempty(tmp_idx)
						output_struct.RendererState.data(tmp_idx, output_struct.RendererState.cn.(cur_fieldname)) = cur_corrected_RenderTimestamp_ms;
					end
				end
				output_struct.FixUpReport{end+1} = ['fnFixVisualChangeTimesFromPhotodiodeSignallog: Corrected the RendererState times from recorded PhotoDiode data for ', cur_fieldname];
			end
		end
	end
	
	
	
	% prepare the data record
	to_be_corrected_data_filed_list = {'A_InitialFixationOnsetTime_ms', 'B_InitialFixationOnsetTime_ms', ...
		'A_TargetOnsetTime_ms', 'B_TargetOnsetTime_ms', ...
		'A_TargetOffsetTime_ms', 'B_TargetOffsetTime_ms', ...
		'A_GoSignalTime_ms', 'B_GoSignalTime_ms'};
	for i_field = 1 : length(to_be_corrected_data_filed_list)
		cur_fieldname = to_be_corrected_data_filed_list{i_field};
		% only try to correct existing fields.
		if isfield(output_struct.cn, cur_fieldname)
			cur_uncorrected_fieldname = ['uncorrected_', cur_fieldname];
			output_struct.header{end + 1} = cur_uncorrected_fieldname;
			output_struct.cn = local_get_column_name_indices(output_struct.header);
			output_struct.data(:, output_struct.cn.(cur_uncorrected_fieldname)) = output_struct.data(:, output_struct.cn.(cur_fieldname));
			
			for i_PhotoDiodeRendererChange = 1 : size(output_struct.PhotoDiodeRenderer.data, 1)
				cur_corrected_RenderTimestamp_ms = output_struct.PhotoDiodeRenderer.data(i_PhotoDiodeRendererChange, output_struct.PhotoDiodeRenderer.cn.RenderTimestamp_ms);
				cur_uncorrected_RenderTimestamp_ms  = output_struct.PhotoDiodeRenderer.data(i_PhotoDiodeRendererChange, output_struct.PhotoDiodeRenderer.cn.uncorrected_RenderTimestamp_ms);
				% find the occurance of uncorrected timestamp and replace with
				% corrected value
				tmp_idx = find(output_struct.data(:, output_struct.cn.(cur_uncorrected_fieldname)) == cur_uncorrected_RenderTimestamp_ms);
				if ~isempty(tmp_idx)
					output_struct.data(tmp_idx, output_struct.cn.(cur_fieldname)) = cur_corrected_RenderTimestamp_ms;
				end
			end
			output_struct.FixUpReport{end+1} = ['fnFixVisualChangeTimesFromPhotodiodeSignallog: Corrected the data times from recorded PhotoDiode data for: ', cur_fieldname];
		end
	end
	
elseif isfield(output_struct, 'PhotoDiodeDriver') && (size(output_struct.PhotoDiodeDriver.data, 1) > 1)
	% old style photodiode data, can we actually correct anything?
	error('Not Implemented yet.');
	return
end


return
end