function [ TDT_header, TDT_epocs, TDT_streams ] = fn_load_TDT_header_epocs_narrowband_streams_CCF( TDT_tank_FQN, TDT_tank_ID, narrowband_streams_mat_suffix, load_TDT_analog_in_data )
%FN_LOAD_TDT_HEADER_EPOCS_NARROWBAND_STREAMS Summary of this function goes here
%   Detailed explanation goes here

TDT_header = TDTbin2mat(TDT_tank_FQN, 'HEADERS', 1);   % contains the epochs but translated
TDT_epocs = TDTbin2mat(TDT_tank_FQN, 'HEADERS', TDT_header, 'TYPE', {'epocs'});

% try to load the analog IN data recorded from the RZ2
% TDTbin2mat always wants to read all streams (including broadband),
% so we need to make sure it sees no streams to avoid OOM situations
% TODO see whether TDTsev2mat can read the analog in datafile directly?
TDT_RZ2_streams_FQN = fullfile(TDT_tank_FQN, [TDT_tank_ID, '.TDT_RZ2_streams.mat']);
if (load_TDT_analog_in_data) && isempty(dir(TDT_RZ2_streams_FQN))
	% TODO only do once and load mat file instead if it exists...
	[TDT_dir, TDT_header_name, TDT_header_ext] = fileparts(TDT_header.tevPath);
	tmp_TDT_no_headstage_data_dir = fullfile(TDT_dir, 'tmp_TDT_no_headstage_data');
	if isempty(dir(tmp_TDT_no_headstage_data_dir))
		mkdir(tmp_TDT_no_headstage_data_dir);
	end
	% create a temporary copy, needed if phantomstores are used
	disp('Copying TDT data to access the analog-in channels independent of the broadband data, might take a while...');
	copyfile(fullfile(TDT_dir, [TDT_header_name, '.*']), tmp_TDT_no_headstage_data_dir, 'f');
	% read in the data
	TDT_streams = TDTbin2mat(tmp_TDT_no_headstage_data_dir, 'TYPE', {'all'});
	%clear TDT_all_no_headstage_data;
	disp(['Deleting temporary directory: ', tmp_TDT_no_headstage_data_dir]);
	[status, message, messageid] = rmdir(tmp_TDT_no_headstage_data_dir, 's');
	if ~status
		disp(message);
	end
	save(TDT_RZ2_streams_FQN, 'TDT_streams', '-v7.3');
else
	disp(['Loading existing TDT_RZ2_streams_FQN: ', TDT_RZ2_streams_FQN]);
	load(TDT_RZ2_streams_FQN, 'TDT_streams');
end



return
end

