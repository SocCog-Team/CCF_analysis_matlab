function [ converted_event_list ] = fn_convert_time_between_named_timebases_CCF( event_list, time_conversion_struct, from_timebase_name, to_timebase_name )
%FN_CONVERT_TIME_FROM_NAME2NAME Summary of this function goes here
%   Detailed explanation goes here
% either read in a

converted_event_list = [];
defined_conversions_list = fieldnames(time_conversion_struct);


if ~exist('time_conversion_struct', 'var') || isempty(time_conversion_struct)
    error('No time_conversion_struct specified');
end

if ~exist('from_timebase_name', 'var') || isempty(from_timebase_name)
    error('No time base specified');
end

if ~exist('to_timebase_name', 'var') || isempty(to_timebase_name)
    to_timebase_name = [];
end

% single conversion request, by BASEONE2BASETWO with a dedicated
% directional conversion struct
if  ismember('offset', defined_conversions_list) && ismember('scale_factor', defined_conversions_list) && isempty(from_timebase_name) && isempty(to_timebase_name)
    disp('Conversion requested without named timebases.'),
    converted_event_list = event_list * time_conversion_struct.scale_factor + time_conversion_struct.offset;
    return
end

if ismember('name', defined_conversions_list) && strcmp(time_conversion_struct.name, from_timebase_name) && isempty(to_timebase_name)
    converted_event_list = event_list * time_conversion_struct.scale_factor + time_conversion_struct.offset;
    return
end

% full conversion struct
to_from_base_fieldname = [from_timebase_name, '_AND_', to_timebase_name];
from_to_base_fieldname = [to_timebase_name, '_AND_', from_timebase_name];

if ~ismember(to_from_base_fieldname, defined_conversions_list) && ~ismember(from_to_base_fieldname, defined_conversions_list)
    disp(['Requested conversion from ', from_timebase_name, ' to ', to_timebase_name, ' not defined yet.']);
    disp('Please create this by running fn_create_timing_conversion_struct.m with two lists of common event timings.' );
    converted_event_list = [];
    return
end
% if one matches we are fine, just brute force which, if both are
% define pick the latter.
if ismember(to_from_base_fieldname, defined_conversions_list)
    base_fieldname = to_from_base_fieldname;
end
if ismember(from_to_base_fieldname, defined_conversions_list)
    base_fieldname = from_to_base_fieldname;
end

to_from_struct_fieldname = [from_timebase_name, '2', to_timebase_name];
%from_to_struct_fieldname = [to_timebase_name, '2', from_timebase_name];
converted_event_list = event_list * time_conversion_struct.(base_fieldname).(to_from_struct_fieldname).scale_factor + time_conversion_struct.(base_fieldname).(to_from_struct_fieldname).offset;


return
end

