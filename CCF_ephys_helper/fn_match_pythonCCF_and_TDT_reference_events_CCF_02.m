function [ ParaState_CCF_idx, ParaState_CCF_timestamps, ParaState_TDT_idx, ParaState_TDT_timestamps ] = fn_match_pythonCCF_and_TDT_reference_events_CCF_02( REF_EPOC, CCF_DO_message_table, TDT_epocs )
%FN_MATCH_PYTHONCCF_AND_TDT_REFERENCE_EVENTS_CCF_02 Match CCF DO messages to TDT DigitalInMessage.
%   Inner-join on reconstructed datetime + trial number so the same code
%   works for unmerged sessions and merged DO_messages (trial numbers restart
%   per run). If run_idx is present, keep the earliest run first.
%
%   TDT datetime bytes use the same even offset from INI=22 as CCF word_index
%   (verified for trial words 16/18 at -6/-4). Check datetime strings against
%   CCF on one unmerged tank before trusting a new DAG layout.

switch REF_EPOC
	case 'DigitalInMessage'
		% similar to Tnum, but use the higher resolution state store to get
		% to trial number and use the onset of the 255 code of the end
		% take the 8bitDO message timestamp for the second half of the trialnumber
		% this is the position of the 254 code after the lower centade of the trial number, at the offset of this octet the trialnum
		% will be logged in ExtractTrialInfo on the TDT side

		% one CCF message per INI word (22), in time order — not unique(collection_number)
		ini_ccf_idx = find(ismember(CCF_DO_message_table.word_index, 22));
		n_ccf_msg = length(ini_ccf_idx);
		ParaState_CCF_timestamps = CCF_DO_message_table.word_written_timestamp_s(ini_ccf_idx);
		ParaState_CCF_idx = (1:1:n_ccf_msg)';

		trialdatetime_year_lower_centade_idx = find(ismember(CCF_DO_message_table.word_index, 2));
		trialdatetime_month_idx = find(ismember(CCF_DO_message_table.word_index, 4));
		trialdatetime_day_idx = find(ismember(CCF_DO_message_table.word_index, 6));
		trialdatetime_hour_idx = find(ismember(CCF_DO_message_table.word_index, 8));
		trialdatetime_minute_idx = find(ismember(CCF_DO_message_table.word_index, 10));
		trialdatetime_seconds_idx = find(ismember(CCF_DO_message_table.word_index, 12));
		trialnumber_upper_centade_value_idx = find(ismember(CCF_DO_message_table.word_index, 16));
		trialnumber_lower_centade_value_idx = find(ismember(CCF_DO_message_table.word_index, 18));

		if ~isequal(n_ccf_msg, length(trialnumber_upper_centade_value_idx), ...
				length(trialnumber_lower_centade_value_idx), length(trialdatetime_seconds_idx), ...
				length(trialdatetime_year_lower_centade_idx))
			error([mfilename, ': CCF DAG word counts do not align (datetime/trial/INI)']);
		end

		reconstructed_collection_num_list = nan(n_ccf_msg, 1);
		reconstructed_datetime_string = cell(n_ccf_msg, 1);
		for i_msg = 1 : n_ccf_msg
			reconstructed_collection_num_list(i_msg) = ...
				(100 * CCF_DO_message_table.word_value_int(trialnumber_upper_centade_value_idx(i_msg))) + ...
				CCF_DO_message_table.word_value_int(trialnumber_lower_centade_value_idx(i_msg));
			reconstructed_datetime_string{i_msg} = [ ...
				num2str(CCF_DO_message_table.word_value_int(trialdatetime_year_lower_centade_idx(i_msg))), ...
				num2str(CCF_DO_message_table.word_value_int(trialdatetime_month_idx(i_msg)), '%02.0f'), ...
				num2str(CCF_DO_message_table.word_value_int(trialdatetime_day_idx(i_msg)), '%02.0f'), ...
				num2str(CCF_DO_message_table.word_value_int(trialdatetime_hour_idx(i_msg)), '%02.0f'), ...
				num2str(CCF_DO_message_table.word_value_int(trialdatetime_minute_idx(i_msg)), '%02.0f'), ...
				num2str(CCF_DO_message_table.word_value_int(trialdatetime_seconds_idx(i_msg)), '%02.0f')];
		end
		ParaState_CCF_trial_num_list = reconstructed_collection_num_list;

		% merged jsonl: keep first run if run_idx exists; unmerged: column absent → no-op
		if istable(CCF_DO_message_table) && ismember('run_idx', CCF_DO_message_table.Properties.VariableNames)
			ccf_run_idx_list = CCF_DO_message_table.run_idx(ini_ccf_idx);
			keep_ccf_run_ldx = (ccf_run_idx_list == min(ccf_run_idx_list));
			ParaState_CCF_timestamps = ParaState_CCF_timestamps(keep_ccf_run_ldx);
			ParaState_CCF_idx = ParaState_CCF_idx(keep_ccf_run_ldx);
			ParaState_CCF_trial_num_list = ParaState_CCF_trial_num_list(keep_ccf_run_ldx);
			reconstructed_datetime_string = reconstructed_datetime_string(keep_ccf_run_ldx);
			disp([mfilename, ': INFO: using CCF run_idx == ', num2str(min(ccf_run_idx_list)), ...
				' (', num2str(sum(keep_ccf_run_ldx)), ' of ', num2str(n_ccf_msg), ' messages)']);
		end

		ccf_match_key_list = strcat(reconstructed_datetime_string, '_', ...
			cellfun(@num2str, num2cell(ParaState_CCF_trial_num_list), 'UniformOutput', false));

		INI_states_TDT_epoc_idx = find(TDT_epocs.epocs.DigitalInMessage.data == 255);
		n_tdt_msg = numel(INI_states_TDT_epoc_idx);
		proto_TDT_trial_number_list = zeros(n_tdt_msg, 1);
		proto_TDT_datetime_string = cell(n_tdt_msg, 1);
		stat_data = TDT_epocs.epocs.DigitalInMessage.data;

		for i_proto_trial = 1 : n_tdt_msg
			cur_ini_idx = INI_states_TDT_epoc_idx(i_proto_trial);
			low_centade = NaN;
			high_centade = NaN;
			if cur_ini_idx > 21 ...
					&& stat_data(cur_ini_idx - 2) == 253 ...
					&& stat_data(cur_ini_idx - 3) == 254
				low_centade = stat_data(cur_ini_idx - 4);
				if stat_data(cur_ini_idx - 5) == 254
					high_centade = stat_data(cur_ini_idx - 6);
				end
			end
			cur_trial_num = (100 * high_centade) + low_centade;
			if ~isnan(cur_trial_num)
				proto_TDT_trial_number_list(i_proto_trial) = cur_trial_num;
			end

			yy = fn_tdt_dag_payload(stat_data, cur_ini_idx, 2);
			mo = fn_tdt_dag_payload(stat_data, cur_ini_idx, 4);
			dd = fn_tdt_dag_payload(stat_data, cur_ini_idx, 6);
			hh = fn_tdt_dag_payload(stat_data, cur_ini_idx, 8);
			mi = fn_tdt_dag_payload(stat_data, cur_ini_idx, 10);
			ss = fn_tdt_dag_payload(stat_data, cur_ini_idx, 12);
			if any(isnan([yy, mo, dd, hh, mi, ss]))
				proto_TDT_datetime_string{i_proto_trial} = '';
			else
				proto_TDT_datetime_string{i_proto_trial} = [ ...
					num2str(yy), num2str(mo, '%02.0f'), num2str(dd, '%02.0f'), ...
					num2str(hh, '%02.0f'), num2str(mi, '%02.0f'), num2str(ss, '%02.0f')];
			end
		end

		ParaState_TDT_trial_num = proto_TDT_trial_number_list;
		ParaState_TDT_idx = INI_states_TDT_epoc_idx(:);
		tdt_match_key_list = strcat(proto_TDT_datetime_string, '_', ...
			cellfun(@num2str, num2cell(ParaState_TDT_trial_num), 'UniformOutput', false));

		% trial 0 is ambiguous; empty TDT datetime means the DAG walk failed
		keep_tdt_ldx = (ParaState_TDT_trial_num ~= 0) & ~cellfun(@isempty, proto_TDT_datetime_string);
		keep_ccf_ldx = (ParaState_CCF_trial_num_list ~= 0);
		ParaState_TDT_idx = ParaState_TDT_idx(keep_tdt_ldx);
		ParaState_TDT_trial_num = ParaState_TDT_trial_num(keep_tdt_ldx);
		tdt_match_key_list = tdt_match_key_list(keep_tdt_ldx);
		ParaState_CCF_idx = ParaState_CCF_idx(keep_ccf_ldx);
		ParaState_CCF_timestamps = ParaState_CCF_timestamps(keep_ccf_ldx);
		ParaState_CCF_trial_num_list = ParaState_CCF_trial_num_list(keep_ccf_ldx);
		ccf_match_key_list = ccf_match_key_list(keep_ccf_ldx);

		% inner join on datetime+trial (replaces setdiff on trial number alone)
		[ccf_in_tdt_ldx, tdt_for_ccf_idx] = ismember(ccf_match_key_list, tdt_match_key_list);
		n_ccf_dropped = sum(~ccf_in_tdt_ldx);
		if n_ccf_dropped > 0
			disp([mfilename, ': INFO: dropping ', num2str(n_ccf_dropped), ...
				' CCF messages with no TDT datetime+trial (later runs or TDT stopped early)']);
		end
		ParaState_CCF_idx = ParaState_CCF_idx(ccf_in_tdt_ldx);
		ParaState_CCF_timestamps = ParaState_CCF_timestamps(ccf_in_tdt_ldx);
		ParaState_CCF_trial_num_list = ParaState_CCF_trial_num_list(ccf_in_tdt_ldx);
		ccf_match_key_list = ccf_match_key_list(ccf_in_tdt_ldx);
		tdt_keep_idx = tdt_for_ccf_idx(ccf_in_tdt_ldx);

		tdt_in_join_ldx = false(size(tdt_match_key_list));
		tdt_in_join_ldx(tdt_keep_idx) = true;
		n_tdt_dropped = sum(~tdt_in_join_ldx);
		if n_tdt_dropped > 0
			disp([mfilename, ': INFO: dropping ', num2str(n_tdt_dropped), ...
				' TDT messages with no CCF datetime+trial']);
		end
		ParaState_TDT_idx = ParaState_TDT_idx(tdt_keep_idx);
		ParaState_TDT_trial_num = ParaState_TDT_trial_num(tdt_keep_idx);
		tdt_match_key_list = tdt_match_key_list(tdt_keep_idx);

		if ~isequal(ccf_match_key_list, tdt_match_key_list)
			error([mfilename, ': pruned datetime+trial keys for CCF and TDT do not match']);
		end

	otherwise
		error([mfilename, ': Unknown reference epoch/event REF_EPOC (', REF_EPOC, ') specified, needs to be implemented...']);
end

ParaState_TDT_timestamps = TDT_epocs.epocs.(REF_EPOC).onset(ParaState_TDT_idx);

if size(ParaState_TDT_timestamps, 1) == size(ParaState_CCF_timestamps, 2)
	ParaState_TDT_timestamps = ParaState_TDT_timestamps';
end

if size(ParaState_TDT_idx, 1) == size(ParaState_CCF_idx, 2)
	ParaState_TDT_idx = ParaState_TDT_idx';
end

if length(ParaState_CCF_idx) ~= length(ParaState_TDT_idx)
	error([mfilename, ': Some events are missing/superflous in either TDT or CCF, requires better matching algorithm']);
end

end


function [ payload_value ] = fn_tdt_dag_payload(stat_data, ini_idx, word_index)
%FN_TDT_DAG_PAYLOAD DAG value for CCF word_index, relative to INI=22 at ini_idx.
%   Trial words 16/18 are ini-(22-W) and match the existing -6/-4 walk.

payload_value = NaN;
offset = 22 - word_index;
if ini_idx <= offset
	return
end
payload_value = double(stat_data(ini_idx - offset));

end
