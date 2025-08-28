function [ ] = test_wrapper( )
%TEST_WRAPPER Summary of this function goes here
%   Detailed explanation goes here


pair_subdir_list = {};
runs_subdir_list_by_pair_list = {};	% should match the size of pair_subdir_list



% ready this for unix systems...
[sys_status, host_name] = system('hostname');
host_name = host_name(1:end-1); % last char of host name result is ascii 10 (LF)

use_server = 1;
switch host_name
	case {'hms-beagle3.local'}
		if use_server
			CCF_data_base_path = fullfile('/', 'Volumes', 'snd', 'taskcontroller', 'SCP_DATA', 'SCP-CTRL-01', 'CCF', 'recordings');
		else
			CCF_data_base_path = fullfile('/', 'Users', 'smoeller', 'DPZ', 'taskcontroller', 'CODE', 'CCF', 'CCF_RECORDINGS', 'recordings');
		end
	otherwise
		error(['Please add CCF_data_base_path definition for the current host name: ', host_name]);
end

% which pairs to look at
pair_subdir_list = {};

if isempty(pair_subdir_list)
	disp('Automatically detecting all pairs');
	pair_subdirstruct = dir(fullfile(CCF_data_base_path, ''));
	subdir_name_list = {pair_subdirstruct([pair_subdirstruct.isdir]).name};

	% find those with appropriate pair namin
	regexp_match = regexp(subdir_name_list, '[0-9][0-9][0-9]_[0-9][0-9][0-9]', 'match');
	valid_pair_subdir_ldx = ones([1, length(subdir_name_list)]) == 0;
	for i_pair_dir = 1 : length(subdir_name_list)
		if ~isempty(regexp_match{i_pair_dir})
			valid_pair_subdir_ldx(i_pair_dir) = true;
		end
	end
	pair_subdir_list = subdir_name_list(valid_pair_subdir_ldx);
end


% now loop over these to get the run_subdirs for each pair_subdir
runs_subdir_list_by_pair_list = cell(size(pair_subdir_list));
for i_pair_subdir = 1 : length(pair_subdir_list)
	cur_pair_subdir_name = pair_subdir_list{i_pair_subdir};
	disp(['Processing pair: ', cur_pair_subdir_name]);

	if isempty(runs_subdir_list_by_pair_list{i_pair_subdir}) 
		disp('Automatically detecting all runs for this pair');
		proto_runs_dirstruct = dir(fullfile(CCF_data_base_path, cur_pair_subdir_name, '*'));
		
		subdir_name_list = {proto_runs_dirstruct([proto_runs_dirstruct.isdir]).name};

		% find those with appropriate pair namin
		regexp_match = regexp(subdir_name_list, '[0-9]*', 'match');
		valid_subdir_ldx = ones([1, length(subdir_name_list)]) == 0;
		for i_proto_subdir = 1 : length(subdir_name_list)
			if ~isempty(regexp_match{i_proto_subdir})
				valid_subdir_ldx(i_proto_subdir) = true;
			end
		end
		runs_subdir_list_by_pair_list(i_pair_subdir) = {subdir_name_list(valid_subdir_ldx)};

	end
end








if ~exist('CCF_run_folder_FQN_list', 'var') || isempty(CCF_run_folder_FQN_list)
	% (venv_py3.10) root@LC38836:/home/smoeller@dpz.lokal/SCP_CODE/TASKS/foraging_task_2_NHP/src#
	CCF_recordings_folder_FQN = fullfile('~', 'SCP_CODE', 'TASKS', 'foraging_task_2_NHP', 'recordings');
	cur_CCF_runfolder_FQN_list = fullfile(CCF_recordings_folder_FQN, '001_101', '0');
	% use a file picker to select the desired folder
end




 [ data_struct, json_struct, h5_struct, txt_struct ] = fn_parse_CCF_data( cur_CCF_runfolder_FQN_list )






end

