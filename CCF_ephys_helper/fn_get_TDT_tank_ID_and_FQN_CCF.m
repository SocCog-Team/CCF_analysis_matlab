function [ TDT_tank_ID, TDT_tank_FQN, TDT_sess_base_dir ] = fn_get_TDT_tank_ID_and_FQN_CCF( sess_dir, session_ID , TDT_data_subdir )
%FN_GET_TDT_TANK_ID_AND_FQN Summary of this function goes here
%   Get the TDT tank ID and full file path

TDT_tank_ID = [];
TDT_tank_FQN = [];
TDT_sess_base_dir = [];

% the TDT data
TDT_sess_base_dir = fullfile(sess_dir, TDT_data_subdir);

if ~isfolder(TDT_sess_base_dir)
	disp([mfilename, ': WARN: expected TDT sub-folder does not exist: ', TDT_sess_base_dir]);
	TDT_sess_base_dir = [];
	return
end

if isfolder(session_ID)
	[tmp_dir, tmp_session_ID, tmp_ext] = fileparts(session_ID);
	session_date = tmp_session_ID(3:8);
else
	session_date = session_ID(3:8);
end
proto_tank_list = dir(TDT_sess_base_dir);
TDT_tank_ID = [];
for i_direntry = 1 : length(proto_tank_list)
	cur_name = proto_tank_list(i_direntry).name;
	% tanks are really directories, but with arbitrary names... this allows
	% additional files in the TDT folder...
	if ~isempty(strfind(cur_name, session_date)) && (proto_tank_list(i_direntry).isdir) && isempty(strfind(cur_name, 'exclude.')) && isempty(strfind(cur_name, 'EXCLUDE.')) && ~isempty(strfind(cur_name, 'SCP_'))
		TDT_tank_ID = cur_name;
		break
	end
end

if ~isempty(TDT_tank_ID)
	%TDT_tank_ID = 'SCP_DAG_04-201021-163832';
	TDT_tank_FQN = fullfile(TDT_sess_base_dir, TDT_tank_ID);
	%TDT_data = TDTbin2mat(TDT_tank_FQN);
end

return
end


