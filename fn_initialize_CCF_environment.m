function [ output_args ] = fn_initialize_CCF_environment( input_args )
%fn_parse_CCF_data Summary of this function goes here
%   silly little wrapper to get the current path into the matlab path

path_string = path;
% where does this script live
start_dir = fileparts(mfilename('fullpath'));
% change there to be sure about the calling directory 
cd(start_dir);


% delete existing paths containing the calling directory
% this is a work around for matlab's inability to detect changed files on
% most network shares
if ~isempty(strfind(path_string, [start_dir, pathsep]))
	disp('Current directory already in the path; deleting all subdirectories from the path to work around network share issues...');
	% turn the path into cell array
	while length(path_string) > 0
		[cur_path_item, remain] = strtok(path_string, ';:');
		path_string = remain(2:end);
		if ~isempty(strfind(cur_path_item, start_dir))
			rmpath(cur_path_item);
		end
	end
end
% now add them again
addpath(genpath(start_dir));
disp(['Added ', start_dir, ' to the path, unless you save the path to disk this is only transient (allowing to switch wave clus versions).']);

% start planner
%EntryPoint
% open('./wave_clus3preprocess2TD_SCP01_v00.m');
%open('./fn_UltraSort_preprocessing_TDT_SCP01_v02.m');
open('./fn_parse_CCF_data.m');

return
