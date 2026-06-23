function [ ] = fn_merge_same_session_CCF_sessiondirs_SM( sessiondir_merge_list_FQN )
%FN_MERGE_SAME_SESSION_CCF_SESSIONDIRS Summary of this function goes here
%   For a given session we might have recorded several independen
%   runs/blocks of data with the same subject(s). Especially with array
%   recordings we assume all of these runs to contain the same units, and
%   we already take this into account when preprocessing the recorded data
%   and spikesorting. Now find a way to full merge the behavioral and
%   neuronal data from such runs into a new merged directory. We might need
%   some preprocessing already don ein each of the input sessions to deal
%   properly with the .SEV, .datafilr, and datafilt2 files. To make this
%   happen we need to translate all TDT data into CCF timebase 


dbstop if error
fq_mfilename = mfilename('fullpath');


% we want a clean string
here = pwd;
CCF_analysis_path = fullfile(fileparts(fq_mfilename), '..');
cd(CCF_analysis_path)
CCF_analysis_path = pwd;
cd(here);

% delete existing paths containing the calling directory
% this is a work around for matlab's inability to detect changed files on
% most network shares
if ~isempty(strfind(path, [CCF_analysis_path, pathsep]))
	path_string = path;
	disp('Current directory already in the path; deleting all subdirectories from the path to work around network share issues...');
	% turn the path into cell array
	while length(path_string) > 0
		[cur_path_item, remain] = strtok(path_string, ';:');
		path_string = remain(2:end);
		if ~isempty(strfind(cur_path_item, CCF_analysis_path))
			rmpath(cur_path_item);
		end
	end
end
% now add them again
addpath(genpath(CCF_analysis_path));






dbstop if error
fq_mfilename = mfilename('fullpath');

timestamps.(mfilename).start = tic;
disp(['Starting: ', mfilename]);

% 
if ~exist('sessiondir_merge_list_FQN', 'var') || isempty(sessiondir_merge_list_FQN)
	sessiondir_merge_list_FQN = uigetdir(fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS'), 'Select the session directory to merge');
    sessiondir_merge_list_FQN = {fullfile('Y:', 'SCP_DATA', 'SCP-CTRL-01', 'SESSIONLOGS', '2025', '251219', '20251219TNNNNNNM.A_Elmo.B_MIXED.SCP_01.sessiondir', 'merge_CCF_sessiondir_list.txt')};
end


% read in the list of sessiondirs to merge data from
sessiondir_merge_list = readlines(sessiondir_merge_list_FQN);

merge_struct.sessiondir_merge_list_FQN = sessiondir_merge_list_FQN;
merge_struct.sessiondir_merge_list = sessiondir_merge_list;



end

