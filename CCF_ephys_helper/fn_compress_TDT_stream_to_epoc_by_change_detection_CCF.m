function [ output_epoc_struct ] = fn_compress_TDT_stream_to_epoc_by_change_detection_CCF(TDT_stream)
%FN_COMPRESS_TDT_STREAM_BY_CHANGE_DETECTION Summary of this function goes here
%   Detailed explanation goes here

% prepare a proto 
output_epoc_struct.name = TDT_stream.name;
output_epoc_struct.onset = zeros(size(TDT_stream.data));
output_epoc_struct.offset = zeros(size(TDT_stream.data));
output_epoc_struct.type = 'onset';
output_epoc_struct.typeStr = 'epocs';
output_epoc_struct.typeNum = 2;
output_epoc_struct.data = zeros(size(TDT_stream.data));
output_epoc_struct.dform = 4;
output_epoc_struct.size = 10;

last_val = NaN;
last_valid_epoc_item = 0;
cur_valid_epoc_item = 0;
for i_data_item = 1 : numel(TDT_stream.data)
	cur_val = TDT_stream.data(1, i_data_item);
	if (cur_val ~= last_val)
		% change detected
		cur_time =  TDT_stream.startTime + ((i_data_item - 1) * TDT_stream.fs^-1);
		cur_valid_epoc_item = cur_valid_epoc_item + 1;
		output_epoc_struct.data(1, cur_valid_epoc_item) = cur_val;
		output_epoc_struct.onset(1, cur_valid_epoc_item) = cur_time;
		if last_valid_epoc_item > 0
			% get the last pre-chanfe timestamp
			output_epoc_struct.offset(1, last_valid_epoc_item) = TDT_stream.startTime + ((i_data_item - 1 - 1) * TDT_stream.fs^-1);
		end
		last_valid_epoc_item = cur_valid_epoc_item;
	end
	last_val = cur_val;
end	

% take care of the last offset
output_epoc_struct.offset(1, last_valid_epoc_item) = TDT_stream.startTime + ((i_data_item - 1) * TDT_stream.fs^-1);


% remove the superfluous entries
output_epoc_struct.onset = output_epoc_struct.onset(1:last_valid_epoc_item);
output_epoc_struct.offset = output_epoc_struct.offset(1:last_valid_epoc_item);
output_epoc_struct.data = output_epoc_struct.data(1:last_valid_epoc_item);

	  
	   

return
end

