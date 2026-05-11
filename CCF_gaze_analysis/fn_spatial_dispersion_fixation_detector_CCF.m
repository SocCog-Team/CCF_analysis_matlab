function [ fixation ] = fn_spatial_dispersion_fixation_detector_CCF(data_struct_of_arr, max_dispersion_threshold, min_fixation_duration_threshold_ms, isDraw)
% see Salvucci D, Goldberg J (2000) Identifying fixations and saccades in eye-tracking protocols. In, pp 71/78.
% this is Anton's code modified for BoS data with pupillabs tracking...
% note: we allow missing values (NaNs) e.g. for blinks, but only if the
% fixation location dispersion allows, that is if after a blink the
% fixation positin qualifies we extend te fixation over the NaNs, otherwise
% we end before that...
% inputs:
%	data_struct_of_arr: AOS with "trials" as array dimension, for all data
%	just feed a singe structure
%	data_struct_of_arr.timestamp: 
%		vector of timestamps in milliseconds
%	data_struct_of_arr.X:
%		vector of X coordinates
%	data_struct_of_arr.Y: 
%		vector of Y coordinates
%	max_dispersion_threshold: 
%		should be in the same units as X and Y and sensibly scaled
%	min_fixation_duration_threshold_ms: 
%		arguably this should be in the same units as the timestamp vector,
%		so if this is in ms so should be the vector
%	isDraw:	
%		show fixation result plots
%
% outputs:
%	fixation: AOS giving fixation staistics per trial

% TODO: optionally return boolean vector for each trial and timestamp
% whether a sample was from a fixation or not


verbose = 0;

% we only have single trials...
nTrial = length(data_struct_of_arr);
% todo add start and end indices...
fixation = repmat(struct('TrialNumber', [], 'TimeStamp', [], 'mean_X', [], 'mean_Y', [], 'mean_ABDepthPix', [], 'onset_timestamp_ms', [], 'fix_onset_idx', [], 'end_timestamp_ms', [], 'fix_end_idx', [], 'duration_ms', [], 'per_sample_fixID', []), 1, nTrial);
if (isDraw)
	nTrialCol = floor(sqrt(2*nTrial));
	nTrialRow = ceil(nTrial/nTrialCol);
end
for iTrial = 1:nTrial
	nFix = 0;
	fixWindowStart = 1;
	isFix = false;
	fixWindowEnd = find(data_struct_of_arr(iTrial).timestamp > data_struct_of_arr(iTrial).timestamp(fixWindowStart) + min_fixation_duration_threshold_ms, 1);
	nDataPoints = length(data_struct_of_arr(iTrial).X);

	NaN_masked_data = data_struct_of_arr(iTrial).X; % need this to check for masked values...
	sample_period = data_struct_of_arr(iTrial).timestamp(2) - data_struct_of_arr(iTrial).timestamp(1);	% the duration of each sample

	fixation(iTrial).per_sample_fixID = zeros(size(NaN_masked_data));

	if (isDraw)
		xfix = zeros(size(data_struct_of_arr(iTrial).X));
		yfix = xfix;
	end
	while (fixWindowEnd <= nDataPoints)
		fixIndices = fixWindowStart:fixWindowEnd;
		% here we could decide what to do with NaNs?
		dx = max(data_struct_of_arr(iTrial).X(fixIndices), [], 'omitnan') - min(data_struct_of_arr(iTrial).X(fixIndices), [], 'omitnan');	% sm we ignore NaNs here to hobble over missing values and blinks, need to clean up the end of the fixation span window later
		dy = max(data_struct_of_arr(iTrial).Y(fixIndices), [], 'omitnan') - min(data_struct_of_arr(iTrial).Y(fixIndices), [], 'omitnan');
		dispersion = (dx + dy)/2;

		if (dispersion < max_dispersion_threshold)
			isFix = true;
			fixWindowEnd = fixWindowEnd + 1;
		else
			if (isFix)   %save fixation
				
				fixIndices = fixWindowStart:fixWindowEnd-1;	% the last value pushed us over the dispersion threshold...
				% remove trailling NaNs here, but critically allow internal NaN stretches, either for individual rejected noisy samples or for blinks that do not change the fixation
				[ fixIndices ] = fn_curate_fixation_indices(fixIndices, NaN_masked_data);
				% for i_fixSample = length(fixIndices):-1:1
				% 	if isnan(data_struct_of_arr(iTrial).X(fixIndices(i_fixSample)))
					% 	% keep going...
				% 	else
					% 	% found the last non-NaN index, truncate fixIndices
					% 	% to end here
					% 	fixIndices = fixIndices(1:i_fixSample);
					% 	break
				% 	end
				% end
				% TODO replace by calculating the duration from the
				% timestamp vector instead to allow for non-uniformly
				% spaced sampling (as produced by e.g. pupillabs)
				cur_fix_duration_ms = data_struct_of_arr(iTrial).timestamp(fixIndices(end)) - data_struct_of_arr(iTrial).timestamp(fixIndices(1));
				%if ((length(fixIndices) * sample_period) >= min_fixation_duration_threshold_ms)
				if (cur_fix_duration_ms >= min_fixation_duration_threshold_ms)
					nFix = nFix + 1;
					%fixation time is sum of all times
					%fixation(iTrial).t(nFix) =
					%sum(data_struct_of_arr(iTrial).timestamp(fixIndices)); %thiswill not work
					fixation(iTrial).TrialNumber(nFix) = iTrial;
					fixation(iTrial).TimeStamp(nFix) = data_struct_of_arr(iTrial).timestamp(fixIndices(1));
					%fixation(iTrial).duration_ms(nFix) = length(fixIndices) * sample_period;
					%fixation(iTrial).duration_ms(nFix) = data_struct_of_arr(iTrial).timestamp(fixIndices(end)) - data_struct_of_arr(iTrial).timestamp(fixIndices(1));
					fixation(iTrial).duration_ms(nFix) = cur_fix_duration_ms;
					fixation(iTrial).onset_timestamp_ms(nFix) = data_struct_of_arr(iTrial).timestamp(fixIndices(1));
					fixation(iTrial).fix_onset_idx(nFix) = fixIndices(1);
					fixation(iTrial).end_timestamp_ms(nFix) = data_struct_of_arr(iTrial).timestamp(fixIndices(end));
					fixation(iTrial).fix_end_idx(nFix) = fixIndices(end);

					%SM: seems too complicated for essentially a centroid
					%fixation pos is the average of all pos (taking time of each pos into account)
					%fixation(iTrial).X(nFix) = dot(data_struct_of_arr(iTrial).X(fixIndices), data_struct_of_arr(iTrial).timestamp(fixIndices))/fixation(iTrial).t(nFix);
					%fixation(iTrial).Y(nFix) = dot(data_struct_of_arr(iTrial).Y(fixIndices), data_struct_of_arr(iTrial).timestamp(fixIndices))/fixation(iTrial).t(nFix);
					fixation(iTrial).mean_X(nFix) = mean(data_struct_of_arr(iTrial).X(fixIndices), 'omitnan');
					fixation(iTrial).mean_Y(nFix) = mean(data_struct_of_arr(iTrial).Y(fixIndices), 'omitnan');
					if isfield(data_struct_of_arr, 'ABDepthPix')
						fixation(iTrial).mean_ABDepthPix(nFix) = mean(data_struct_of_arr(iTrial).ABDepthPix(fixIndices), 'omitnan');
					end
					fixation(iTrial).per_sample_fixID(fixIndices) = nFix;
					%SM move later
					%isFix = false;
					%fixWindowStart = fixWindowEnd;

					if (isDraw)
						xfix(fixIndices) = fixation(iTrial).mean_X(nFix);
						yfix(fixIndices) = fixation(iTrial).mean_Y(nFix);
					end
				else
					if (verbose)
						disp([mfilename, ': protofixation too short, skipping. onset_idx: ', num2str(fixIndices(1)), ' offset_idx: ',   num2str(fixIndices(end))]);
					end
				end
				isFix = false;
				fixWindowStart = fixWindowEnd;
			else
				fixWindowStart = fixWindowStart + 1;
			end
			if (fixWindowStart > nDataPoints)
				break;
			end
			fixWindowEnd = find(data_struct_of_arr(iTrial).timestamp > data_struct_of_arr(iTrial).timestamp(fixWindowStart) + min_fixation_duration_threshold_ms, 1);
		end
	end
	if (isFix)  %save last fixation
		% remove trailling NaNs here, but critically allow internal NaN stretches, either for individual rejected noisy samples or for blinks that do not change the fixation
		[ fixIndices ] = fn_curate_fixation_indices(fixIndices, NaN_masked_data);

		cur_fix_duration_ms = data_struct_of_arr(iTrial).timestamp(fixIndices(end)) - data_struct_of_arr(iTrial).timestamp(fixIndices(1));

		%if ((length(fixIndices) * sample_period) >= min_fixation_duration_threshold_ms)
		if (cur_fix_duration_ms >= min_fixation_duration_threshold_ms)
			nFix = nFix + 1;
			%fixation time is sum of all times
			%fixation(iTrial).t(nFix) = sum(data_struct_of_arr(iTrial).timestamp(fixIndices));
			fixation(iTrial).TrialNumber(nFix) = iTrial;
			fixation(iTrial).TimeStamp(nFix) = data_struct_of_arr(iTrial).timestamp(fixIndices(1));
			%fixation(iTrial).duration_ms(nFix) = length(fixIndices) * sample_period;
			%fixation(iTrial).duration_ms(nFix) = data_struct_of_arr(iTrial).timestamp(fixIndices(end)) - data_struct_of_arr(iTrial).timestamp(fixIndices(1));
			fixation(iTrial).duration_ms(nFix) = cur_fix_duration_ms;
			fixation(iTrial).onset_timestamp_ms(nFix) = data_struct_of_arr(iTrial).timestamp(fixIndices(1));
			fixation(iTrial).fix_onset_idx(nFix) = fixIndices(1);
			fixation(iTrial).end_timestamp_ms(nFix) = data_struct_of_arr(iTrial).timestamp(fixIndices(end));
			fixation(iTrial).fix_end_idx(nFix) = fixIndices(end);

			%SM: seems too complicated for essentially a centroid
			%fixation pos is the average of all pos (taking time of each pos into account)
			%fixation(iTrial).X(nFix) = dot(data_struct_of_arr(iTrial).X(fixIndices), data_struct_of_arr(iTrial).timestamp(fixIndices))/fixation(iTrial).t(nFix);
			%fixation(iTrial).Y(nFix) = dot(data_struct_of_arr(iTrial).Y(fixIndices), data_struct_of_arr(iTrial).timestamp(fixIndices))/fixation(iTrial).t(nFix);
			fixation(iTrial).mean_X(nFix) = mean(data_struct_of_arr(iTrial).X(fixIndices), 'omitnan');
			fixation(iTrial).mean_Y(nFix) = mean(data_struct_of_arr(iTrial).Y(fixIndices), 'omitnan');
			if isfield(data_struct_of_arr, 'ABDepthPix')
				fixation(iTrial).mean_ABDepthPix(nFix) = mean(data_struct_of_arr(iTrial).ABDepthPix(fixIndices), 'omitnan');
			end
			fixation(iTrial).per_sample_fixID(fixIndices) = nFix;
		else
			if (verbose)
				disp([mfilename, ': protofixation too short, skipping. onset_idx: ', num2str(fixIndices(1)), ' offset_idx: ',   num2str(fixIndices(end))]);
			end	
		end
	end

	if (isDraw)
		maxY = max(data_struct_of_arr(iTrial).Y);
		maxX = max(data_struct_of_arr(iTrial).X);
		subplot(nTrialRow, nTrialCol, iTrial);
		hold on;
		plot(data_struct_of_arr(iTrial).X/maxX, 'b-')
		plot(-data_struct_of_arr(iTrial).Y/maxY, 'b--')
		plot(xfix/maxX, 'r--')
		plot(-yfix/maxY, 'm--')

		hold off;
	end
end
end

function [ fixIndices ] = fn_curate_fixation_indices(fixIndices, NaN_masked_data)
% remove trailling NaNs here, but critically allow internal NaN stretches, either for individual rejected noisy samples or for blinks that do not change the fixation
for i_fixSample = length(fixIndices):-1:1
	if isnan(NaN_masked_data(fixIndices(i_fixSample)))
		% keep going...
	else
		% found the last non-NaN index, truncate fixIndices
		% to end here
		fixIndices = fixIndices(1:i_fixSample);
		break
	end
end
end





