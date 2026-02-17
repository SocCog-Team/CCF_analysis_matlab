function [ categorical_LeftRight, categorical_UpDown, deltaXY, polarThetaRho, polarDegRho ] = fn_categorize_reach_from_start_and_end_XY( start_XY_list, end_XY_list )
%FN_CATEGORIZE_REACH_FROM_START_AND_END_XY Summary of this function goes here
%   Detailed explanation goes here

categorical_LeftRight = [];
categorical_UpDown = [];
deltaXY = [];
polarThetaRho = [];
polarDegRho = [];

if length(start_XY_list) ~= length(end_XY_list)
	error('Start_XY_list differs in length from end_XY_listm bailing out');
	return
end


categorical_LeftRight = cell([size(start_XY_list, 1),1]);
categorical_UpDown = cell([size(start_XY_list, 1),1]);
deltaXY = nan(size(start_XY_list));
polarThetaRho = nan(size(start_XY_list));
polarDegRho = nan(size(start_XY_list));


for i_item = 1 : length(start_XY_list)
	cur_start_XY = start_XY_list(i_item, :);
	cur_end_XY = end_XY_list(i_item, :);

	% NaNs denote missing data, nothing we can do there
	if ~any(isnan(cur_start_XY)) && ~any(isnan(cur_end_XY))
		cur_deltaXY = cur_end_XY - cur_start_XY;
		deltaXY(i_item, :) = cur_deltaXY;
		[polarThetaRho((i_item), 1), polarThetaRho((i_item), 2)] = cart2pol(cur_deltaXY(1), cur_deltaXY(2));
		
		polarDegRho((i_item), 1) = rad2deg(polarThetaRho((i_item), 1));
		polarDegRho((i_item), 2) = polarThetaRho((i_item), 2);

		%rad2deg(polarThetaRho((i_item), 1))
		if cur_deltaXY(1) == 0
			cur_categorical_LeftRight = 'NONE';	% neither left nor right
		elseif (cur_deltaXY(1) > 0)
			cur_categorical_LeftRight = 'RIGHT';
		elseif (cur_deltaXY(1) < 0)
			cur_categorical_LeftRight = 'LEFT';
		end

		if cur_deltaXY(2) == 0
			cur_categorical_UpDown = 'NONE';	% neither left nor right
		elseif (cur_deltaXY(2) > 0)
			cur_categorical_UpDown = 'UP';
		elseif (cur_deltaXY(2) < 0)
			cur_categorical_UpDown = 'DOWN';
		end

		categorical_LeftRight(i_item) = {cur_categorical_LeftRight};
		categorical_UpDown(i_item) = {cur_categorical_UpDown};
	else
		categorical_LeftRight(i_item) = {'NONE'};
		categorical_UpDown(i_item) = {'NONE'};
		%deltaXY(i_item, :) = [NaN, NaN];
		%polarThetaRho((i_item), :) =  [NaN, NaN];
	end

end



end

