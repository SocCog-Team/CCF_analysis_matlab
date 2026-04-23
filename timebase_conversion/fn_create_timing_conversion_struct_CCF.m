function [ first2second_time_conversion_struct, second2first_time_conversion_struct, time_conversion_struct] = fn_create_timing_conversion_struct_CCF( first_timebase_name, first_timebase_event_list, second_timebase_name, second_timebase_event_list )
%FN_CREATE_TIMING_CONVERSION_STRUCT calculate scale and offsets to convert
%between two time conventions based on the respective timing of common
%events
%   Different computer systems work with different clocks and time
%   definitions (e.g. Seconds versus Milliseconds, different start times).
%   To account for this variance we can use common events recorded in two
%   time bases to calclate the required conversion factor and offsets. Note
%   that this really only allows to correct for linear differences, so
%   non-linear (e.g. temperature-dependent) clock divergences will not be
%   corrected for except for their (hopefully dominant linear component).
%   The minimum required are recordings of two common events in both time
%   bases, if more events are given, this function tries to assess the
%   quality of the conversion
%
%   first_timebase_name:
%       the name of the 1st timebase, will be
%       used to name things so needs to be a valid matlab variable name
%   first_timebase_event_list:
%       list of common events measured in the 1st system
%   second_timebase_name:
%       the name of the 2nd timebase, will be
%       used to name things so needs to be a valid matlab variable name
%   second_timebase_event_list
%       list of common events measured in the 2nd system


first2second_time_conversion_struct = struct();
second2first_time_conversion_struct = struct();
time_conversion_struct = struct();

% input checking?

if length(first_timebase_event_list) ~= length(second_timebase_event_list)
    disp(['First timebase event list(', first_timebase_name,') and second timebase event list(', second_timebase_name,') have different length.']);
    error('Currently, this is an unrecoverable error.');
    return
end

if length(first_timebase_event_list) < 2
    disp('Less than two common events specified, conversion under-defined, skipping.');
    return
end

% since we want to use these as matlab variables, make sure they are sane
first_timebase_name = fn_sanitize_string_as_matlab_variable_name(first_timebase_name);
second_timebase_name = fn_sanitize_string_as_matlab_variable_name(second_timebase_name);

first2second = [first_timebase_name, '2', second_timebase_name];
second2first = [second_timebase_name, '2', first_timebase_name];
firstANDsecond = [second_timebase_name, '_AND_', first_timebase_name];

first2second_time_conversion_struct.name = first2second;
second2first_time_conversion_struct.name = second2first;
% here sequence does not matter much, still keep it
time_conversion_struct.(firstANDsecond).first_name = first_timebase_name;
time_conversion_struct.(firstANDsecond).second_name = second_timebase_name;



% okay now figure out how to convert from first timebase to second:
first_ts_first_timebase_event = first_timebase_event_list(1);
first_ts_second_timebase_event = second_timebase_event_list(1);

first2second_time_conversion_struct.first_ts_first_timebase_event = first_ts_first_timebase_event;
second2first_time_conversion_struct.first_ts_second_timebase_event = first_ts_second_timebase_event;

last_ts_first_timebase_event = first_timebase_event_list(end);
last_ts_second_timebase_event = second_timebase_event_list(end);

first2second_time_conversion_struct.last_ts_first_timebase_event = last_ts_first_timebase_event;
second2first_time_conversion_struct.last_ts_second_timebase_event = last_ts_second_timebase_event;


% the scale factors based on the range of both event lists
first2second_time_conversion_struct.scale_factor = (last_ts_second_timebase_event - first_ts_second_timebase_event) / (last_ts_first_timebase_event - first_ts_first_timebase_event);
second2first_time_conversion_struct.scale_factor = (last_ts_first_timebase_event - first_ts_first_timebase_event) / (last_ts_second_timebase_event - first_ts_second_timebase_event);

% the offsets
first2second_time_conversion_struct.offset = first_ts_second_timebase_event - (first_ts_first_timebase_event * first2second_time_conversion_struct.scale_factor);
second2first_time_conversion_struct.offset = first_ts_first_timebase_event - (first_ts_second_timebase_event * second2first_time_conversion_struct.scale_factor);


% store
time_conversion_struct.(firstANDsecond).(first2second) = first2second_time_conversion_struct;
time_conversion_struct.(firstANDsecond).(second2first) = second2first_time_conversion_struct;



% some sanity checking:
first2second_event_list = first_timebase_event_list * first2second_time_conversion_struct.scale_factor + first2second_time_conversion_struct.offset;
second2first_event_list = second_timebase_event_list * second2first_time_conversion_struct.scale_factor + second2first_time_conversion_struct.offset;

first_time_base_abs_error_sum =  sum(abs(first_timebase_event_list - second2first_event_list));
second_time_base_abs_error_sum = sum(abs(second_timebase_event_list - first2second_event_list));
disp(['Average absolute error over ', num2str(length(first_timebase_event_list)), ' events:']);
disp([second_timebase_name, ' to ', first_timebase_name,' time: ', num2str(first_time_base_abs_error_sum / length(first_timebase_event_list))]);
disp([first_timebase_name, ' to ', second_timebase_name,' time: ', num2str(second_time_base_abs_error_sum / length(second_timebase_event_list))]);



% ParaState_EvIDE_timestamps;
% ParaState_TDT_timestamps = TDT_data.epocs.(REF_EPOC).onset;
% 
% ParaState_EvIDE_timestamps2TDT_time = ParaState_EvIDE_timestamps * EvIDE2TDT_time_scale + EvIDE2TDT_time_offset;
% ParaState_TDT_timestamps2EvIDE_time = ParaState_TDT_timestamps * TDT2EvIDE_time_scale + TDT2EvIDE_time_offset;
% 
% % look at the quality of conversion?
% % calculate the sum of absolute differences
% sum(abs(ParaState_TDT_timestamps - ParaState_EvIDE_timestamps2TDT_time))
% sum(abs(ParaState_EvIDE_timestamps - ParaState_TDT_timestamps2EvIDE_time))
% 
% 
% 
% first_timebase_event_list_diff = diff(first_timebase_event_list);
% second_timebase_event_list_diff = diff(second_timebase_event_list);

% now scale both to the same total range, that way offsets and scal


% 
% 
% [R, P] = corrcoef(EvIDE_ParaState_ts_diff*EvIDE2TDT_time_scale, TDT_ParaState_ts_diff);
% % we then can use this to figure out quality of fit between the
% % different data/time sources



return
end

