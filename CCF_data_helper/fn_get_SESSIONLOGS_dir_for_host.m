function [ cur_SESSIONLOGS_dir, cur_SCP_DATA_BaseDir ] = fn_get_SESSIONLOGS_dir_for_host( )
%fn_get_SESSIONLOGS_dir_for_host get and cache the current SESSIONLOGS
%directory
%  GetDirectoriesByHostName is relatively heavy so allow to cache the data
%  in a persistent variable and simply return that.

persistent persistent_SESSIONLOGS_dir persistent_SCP_DATA_BaseDir
cur_SESSIONLOGS_dir = [];
cur_SCP_DATA_BaseDir = [];
override_directive ='local_code';
debug = 0;

% if ~exist('hostname', 'var')||isempty(hostname)
% 	[sys_status, host_name] = system('hostname');
% 	host_name = strtrim(host_name(1:end-1)); % last char of host name result is ascii 10 (LF)
% end
% % extract the short host name by removing the domain parts
% dot_idx=strfind(host_name, '.');
% if ~isempty(dot_idx)
% 	short_host_name = host_name(1:dot_idx(1)-1);
% end

% we only want to do the expensive stuff once...
if isempty(persistent_SCP_DATA_BaseDir)
	by_host_DirectoriesStruct = GetDirectoriesByHostName( override_directive );
	if isfield(by_host_DirectoriesStruct, 'remote') && isfolder(by_host_DirectoriesStruct.remote.SCP_DATA_BaseDir)
		persistent_SCP_DATA_BaseDir = by_host_DirectoriesStruct.remote.SCP_DATA_BaseDir;
	else
		error([mfilename, ': ERROR: by_host_DirectoriesStruct does not seem to contain a remote SCP_DATA_BaseDir']);
	end
else
	if (debug)
		disp([mfilename, ': INFO: Using already assigned persistent persistent_SCP_DATA_BaseDir: ', persistent_SCP_DATA_BaseDir]);
	end
end

% we only want to do the expensive stuff once...
if isempty(persistent_SESSIONLOGS_dir)
	by_host_DirectoriesStruct = GetDirectoriesByHostName( override_directive );
	if isfield(by_host_DirectoriesStruct, 'remote') && isfolder(by_host_DirectoriesStruct.remote.SCP_DATA_BaseDir)
		remote_SCP_DATA_BaseDir = by_host_DirectoriesStruct.remote.SCP_DATA_BaseDir;
		persistent_SESSIONLOGS_dir = fullfile(remote_SCP_DATA_BaseDir, 'SCP-CTRL-01', 'SESSIONLOGS');
	else
		error([mfilename, ': ERROR: by_host_DirectoriesStruct does not seem to contain a remote SCP_DATA_BaseDir']);
	end
else
	if (debug)
		disp([mfilename, ': INFO: Using already assigned persistent persistent_SESSIONLOGS_dir: ', persistent_SESSIONLOGS_dir]);
	end
end



cur_SESSIONLOGS_dir = persistent_SESSIONLOGS_dir;
cur_SCP_DATA_BaseDir = persistent_SCP_DATA_BaseDir;

if ~isfolder(cur_SCP_DATA_BaseDir)
	error([mfilename, ': ERROR: cur_SCP_DATA_BaseDir does not seem to exist as directory: ', cur_SCP_DATA_BaseDir]);
end


if ~isfolder(cur_SESSIONLOGS_dir)
	error([mfilename, ': ERROR: cur_SESSIONLOGS_dir does not seem to exist as directory: ', cur_SESSIONLOGS_dir]);
end


end

