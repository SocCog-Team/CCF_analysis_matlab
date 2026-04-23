function [ ParaState_CCF_idx, ParaState_CCF_timestamps, ParaState_TDT_idx, ParaState_TDT_timestamps ] = fn_match_pythonCCF_and_TDT_reference_events_CCF( REF_EPOC, CCF_DO_message_table, TDT_epocs )
%FN_MATCH_EVENTIDE_AND_TDT_REFERENCE_EVENTS Summary of this function goes here
%   Detailed explanation goes here

% TODO use the fuull transmitted message string for matching, as that will
% allow matching across runs... (for this to make sense there needs to be a merged TDT_epoc with appropriately adjusted timestamps)


switch REF_EPOC
    case 'DigitalInMessage'
        % similar to Tnum, but use the higher resolution state store to get
        % to trial number and use the onset of the 255 code of the end
        % take the 8bitDO message timestamp for the second half of the trialnumber
        % this is the position of the 254 code after the lower centade of the trial number, at the offset of this octet the trialnum
        % will be logged in ExtractTrialInfo on the TDT side
        %cur_trial_num_MessageNameString_idx_code = find(ismember(report_struct.DigitalOutMessage.unique_lists.MessageNameString, 'ITI: DIGITALOUTOCTET: 19'));
        
        % % get relevant messages to search for
        % cur_trial_num_high_centade_MessageNameString_idx_code = find(ismember(CCF_DO_message_table.word_index, 16));	% upper centade
        % cur_trial_num_low_centade_MessageNameString_idx_code = find(ismember(CCF_DO_message_table.word_index, 18));		% lower centade
        % % use this for timing, but restricted to the subset in which TDT
        % % and EvIDE report the same trial numbers...
        % cur_INI_states_end_MessageNameString_idx_code = find(ismember(CCF_DO_message_table.word_index, 22));	% INI_states (255)
		% 
        % cur_INI_states_end_Message_idx = find(ismember(CCF_DO_message_table.word_index, 22));
        % proto_trial_number_list = zeros(size(cur_INI_states_end_Message_idx));
		% 
        % for i_proto_trial = 1 : numel(cur_INI_states_end_Message_idx)
        %     cur_Message_idx = cur_INI_states_end_Message_idx(i_proto_trial);
        %     if i_proto_trial > 1
        %         search_limit = cur_INI_states_end_Message_idx(i_proto_trial - 1);
        %     else
        %         search_limit = 0;
        %     end
        %     cur_search_idx = cur_Message_idx;
        %     low_centade = NaN;
        %     high_centade = NaN;
        %     while cur_search_idx > search_limit
        %         if (report_struct.DigitalOutMessage.data(cur_search_idx, report_struct.DigitalOutMessage.cn.MessageNameString_idx) == cur_trial_num_low_centade_MessageNameString_idx_code)
        %             low_centade = report_struct.DigitalOutMessage.data(cur_search_idx, report_struct.DigitalOutMessage.cn.MessageCode);
        %         end
        %         if (report_struct.DigitalOutMessage.data(cur_search_idx, report_struct.DigitalOutMessage.cn.MessageNameString_idx) == cur_trial_num_high_centade_MessageNameString_idx_code)
        %             high_centade = report_struct.DigitalOutMessage.data(cur_search_idx, report_struct.DigitalOutMessage.cn.MessageCode);
        %         end
        %         cur_search_idx = cur_search_idx - 1;
        %     end
		% 
        %     cur_trial_num = (100 * high_centade) + low_centade;
        %     if ~isnan(cur_trial_num)
        %         proto_trial_number_list(i_proto_trial) = cur_trial_num;
		% 	end
		% end

		
		% TODO construct the full timestamp string as well and compare
		trialdatetime_year_lower_centade_idx =  find(ismember(CCF_DO_message_table.word_index, 2));
		trialdatetime_month_idx =  find(ismember(CCF_DO_message_table.word_index, 4));
		trialdatetime_day_idx =  find(ismember(CCF_DO_message_table.word_index, 6));
		trialdatetime_hour_idx =  find(ismember(CCF_DO_message_table.word_index, 8));
		trialdatetime_minute_idx =  find(ismember(CCF_DO_message_table.word_index, 10));
		trialdatetime_seconds_idx =  find(ismember(CCF_DO_message_table.word_index, 12));


		%T = datetime(1765881936.50281, 'ConvertFrom', 'posixtime', 'TimeZone', 'Europe/Zurich', 'Format', 'yyyyMMdd HH:mm:ss.SSS')


		trialnumber_upper_centade_value_idx = find(ismember(CCF_DO_message_table.word_index, 16));	% upper centade
		trialnumber_lower_centade_value_idx = find(ismember(CCF_DO_message_table.word_index, 18));		% lower centade
		% reconstruct the sent trial number and
		unique_CCF_collection_num_list = unique(CCF_DO_message_table.collection_number);
		reconstructed_collection_num_list = nan(size(unique_CCF_collection_num_list));
		reconstructed_datetime_string = cell(size(reconstructed_collection_num_list));
		for i_collection_num = 1 : length(unique_CCF_collection_num_list)
				reconstructed_collection_num_list(i_collection_num) = (100 * CCF_DO_message_table.word_value_int(trialnumber_upper_centade_value_idx(i_collection_num))) + CCF_DO_message_table.word_value_int(trialnumber_lower_centade_value_idx(i_collection_num));
				reconstructed_datetime_string(i_collection_num) = {[	num2str(CCF_DO_message_table.word_value_int(trialdatetime_year_lower_centade_idx(i_collection_num))), ...
																	num2str(CCF_DO_message_table.word_value_int(trialdatetime_month_idx(i_collection_num)), '%02.0f'), ...
																	num2str(CCF_DO_message_table.word_value_int(trialdatetime_day_idx(i_collection_num)), '%02.0f'), ...
																	num2str(CCF_DO_message_table.word_value_int(trialdatetime_hour_idx(i_collection_num)), '%02.0f'), ...
																	num2str(CCF_DO_message_table.word_value_int(trialdatetime_minute_idx(i_collection_num)), '%02.0f'), ...
																	num2str(CCF_DO_message_table.word_value_int(trialdatetime_seconds_idx(i_collection_num)), '%02.0f'), ...
																	]};
		end

       
        %trialnum_message_octet_idx = find(report_struct.DigitalOutMessage.data(:, report_struct.DigitalOutMessage.cn.MessageNameString_idx) == cur_trial_num_MessageNameString_idx_code);
        %ParaState_CCF_timestamps = report_struct.DigitalOutMessage.data(cur_INI_states_end_Message_idx, report_struct.DigitalOutMessage.cn.Timestamp);

		% we use the INI_states word (255) on both sides... which is the
		% last word of the DAG style message
		ParaState_CCF_timestamps = CCF_DO_message_table.word_written_timestamp_s(find(ismember(CCF_DO_message_table.word_index, 22)));
        %ParaState_CCF_timestamps = ParaState_CCF_timestamps + 0; % the DO8 octets are raised for 5 ms, but TDT triggers on falling flank so DO8 offset
		ParaState_CCF_idx = (1:1:numel(ParaState_CCF_timestamps));	% just an collection index, starting at 1

		% ParaState_CCF_trial_num_list = fn_find_trial_number_for_timestamped_event(ParaState_CCF_timestamps, ...
        %     report_struct.data(:, report_struct.cn.TrialNumber), ...
        %     report_struct.data(:, report_struct.cn.TrialStartTime_ms), ...
        %     report_struct.data(:, report_struct.cn.TrialEndTime_ms));
		ParaState_CCF_trial_num_list = reconstructed_collection_num_list;
        
        % now search in the state epoc
        %epocized_TDT_stat = fn_compress_TDT_stream_to_epoc_by_change_detection(TDT_streams.streams.stat);
        %TDT_epocs.epocs.DigitalInMessage = epocized_TDT_stat;
        INI_states_TDT_epoc_idx = find(TDT_epocs.epocs.DigitalInMessage.data == 255);	% this is the end of each message
        
        % find the matching trial numbers from the TDT data
        proto_TDT_trial_number_list = zeros(size(INI_states_TDT_epoc_idx));
        
		% also reconstruct the date time string and check for match between
		% the two...


		% TODO reconstruct session date and time and use that together with
		% trial number to match events, report errors if datetimes do not
		% match...
        for i_proto_trial = 1 : numel(INI_states_TDT_epoc_idx)
            cur_Message_idx = INI_states_TDT_epoc_idx(i_proto_trial);
            if i_proto_trial > 1
                search_limit = INI_states_TDT_epoc_idx(i_proto_trial - 1);
            else
                search_limit = 0;
            end
            cur_search_idx = cur_Message_idx;
            low_centade = NaN;
            high_centade = NaN;
            
            if cur_search_idx > 21
                if (TDT_epocs.epocs.DigitalInMessage.data(cur_search_idx - 2) == 253)
                    if (TDT_epocs.epocs.DigitalInMessage.data(cur_search_idx - 3) == 254)
                        low_centade = TDT_epocs.epocs.DigitalInMessage.data(cur_search_idx - 4);
                        if(TDT_epocs.epocs.DigitalInMessage.data(cur_search_idx - 5) == 254)
                            high_centade = TDT_epocs.epocs.DigitalInMessage.data(cur_search_idx - 6);
						end
                    end
                end
            end
            
            cur_trial_num = (100 * high_centade) + low_centade;
            if ~isnan(cur_trial_num)
                proto_TDT_trial_number_list(i_proto_trial) = cur_trial_num;
            end
        end
        
        % the Tnum field with the received trial numbers
        ParaState_TDT_trial_num = proto_TDT_trial_number_list;
        ParaState_TDT_idx = INI_states_TDT_epoc_idx;
		
		% TDT has more trials than EventIDE
        % exclude trial numbers not in ParaState_CCF_trial_num_list
        [unique_TDT_trial_nums, in_A_idx] =  setdiff(ParaState_TDT_trial_num, ParaState_CCF_trial_num_list);
        if ~isempty(unique_TDT_trial_nums)
            in_A_idx = []; % setdiff does not give repetitions
            for i_unique_trial_num = 1 : numel(unique_TDT_trial_nums)
                in_A_idx = [in_A_idx, find(ParaState_TDT_trial_num == unique_TDT_trial_nums(i_unique_trial_num))];
            end
            disp(['Removing ', num2str(numel(unique_TDT_trial_nums)), ' unique trials from ParaState_TDT_trial_num.']);
            ParaState_TDT_idx(in_A_idx) = [];
            ParaState_TDT_trial_num(in_A_idx) = [];
		end
        		
		
		%CCF has more trials than TDT (can happen when TDT crashes)
        [unique_CCF_trial_nums, in_A_idx] = setdiff(ParaState_CCF_trial_num_list, ParaState_TDT_trial_num);
        if ~isempty(unique_CCF_trial_nums)    
            in_A_idx = []; % setdiff does not give repetitions
            for i_unique_trial_num = 1 : numel(unique_CCF_trial_nums)
                in_A_idx = [in_A_idx, find(ParaState_CCF_trial_num_list == unique_CCF_trial_nums(i_unique_trial_num))];
                % needs checking...
                %keyboard
			end
            disp(['Removing ', num2str(numel(unique_CCF_trial_nums)), ' unique trials from ParaState_CCF_timestamps.']);
			disp('This can happen if TDT crashes or is shut off early...');
            ParaState_CCF_timestamps(in_A_idx) = [];
            ParaState_CCF_idx(in_A_idx) = [];
			ParaState_CCF_trial_num_list(in_A_idx) = [];
		end

		% trialnum 0 is ambiguous, so remove all of these
		non_zero_TDT_trial_idx = find(ParaState_TDT_trial_num ~= 0);
		ParaState_TDT_idx = ParaState_TDT_idx(non_zero_TDT_trial_idx);
		ParaState_TDT_trial_num = ParaState_TDT_trial_num(non_zero_TDT_trial_idx);

		non_zero_CCF_trial_idx = find(ParaState_CCF_trial_num_list ~= 0);
		ParaState_CCF_idx = ParaState_CCF_idx(non_zero_CCF_trial_idx);
		ParaState_CCF_timestamps = ParaState_CCF_timestamps(non_zero_CCF_trial_idx);
		ParaState_CCF_trial_num_list = ParaState_CCF_trial_num_list(non_zero_CCF_trial_idx)';
		
		if ~isequal(ParaState_TDT_trial_num, ParaState_CCF_trial_num_list)
			error('The pruned trial number lists for CCF and TDT do not match, bailing out...');
		end	
	%ParaState_TDT_timestamps = TDT_epocs.epocs.(REF_EPOC).onset(ParaState_TDT_idx);		
		
    otherwise
        error(['Unknown reference epoch/event REF_EPOC (', REF_EPOC, ') specified, needs to be implemented...']);
end

ParaState_TDT_timestamps = TDT_epocs.epocs.(REF_EPOC).onset(ParaState_TDT_idx);


%for symmetry/completeness make sure to return these with the same dimensionality 
if size(ParaState_TDT_timestamps, 1) == size(ParaState_CCF_timestamps, 2)
	ParaState_TDT_timestamps = ParaState_TDT_timestamps';
end
%ParaState_TDT_timestamps = TDT_epocs.epocs.(REF_EPOC).onset(ParaState_TDT_idx)';

%for symmetry/completeness make sure to return these with the same dimensionality 
if size(ParaState_TDT_idx, 1) == size(ParaState_CCF_idx, 2)
	ParaState_TDT_idx = ParaState_TDT_idx';
end
%ParaState_TDT_timestamps = TDT_epocs.epocs.(REF_EPOC).onset(ParaState_TDT_idx)';


if length(ParaState_CCF_idx) ~= length(ParaState_TDT_idx)
    error('Some events are missing/superflous in either TDT or CCF, requires better matching algorithm');
end

return
end

