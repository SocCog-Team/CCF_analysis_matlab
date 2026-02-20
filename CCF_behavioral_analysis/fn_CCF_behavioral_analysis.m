function [ output ] = fn_CCF_behavioral_analysis( cur_sessiondir_FQD, requested_analyses_list )
%FN_CCF_BEHAVIORAL_ANALYSIS Summary of this function goes here
%   Detailed explanation goes here
output = [];

% define plotting options
plot_opts = struct();


% start by parsing the session CCF data
session_info = fn_parse_session_id(cur_sessiondir_FQD);
session_id = session_info.session_id;

[CCF_data.triallog_table, CCF_data.record_struct, CCF_data.record2D_table, CCF_data.AI_samples_struct, CCF_data.DI_samples_struct, CCF_data.json_struct, CCF_data.h5_struct, CCF_data.txt_struct, CCF_data.jsonl_struct, CCF_data.enum_struct, CCF_data.fixations_SOA ] = fn_parse_CCF_data(cur_sessiondir_FQD);

% now 

cur_analysis_name = 'per_collection_2D_reach_and_fix_analysis';
if ismember({cur_analysis_name}, requested_analyses_list)
	disp([mfilename, ': requested analysis: ', cur_analysis_name]);

	% which fixations to operate on
	gaze_sources_list = [];% prepare for this but keep it empty for now
	reach_sources_list = {'aims0', 'aims1'};	% for drawing traces
	fixation_sources_list = {'aims0', 'aims1'};	% for adding fixation information, likely should be subset of reach_sources_list
	cur_output = fn_per_collection_2D_reach_and_fix_analysis(CCF_data.triallog_table, CCF_data.record2D_table, CCF_data.json_struct.conf, CCF_data.enum_struct, CCF_data.fixations_SOA, reach_sources_list, gaze_sources_list, fixation_sources_list, plot_opts);


end


end

