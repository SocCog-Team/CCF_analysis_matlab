function [ color_struct ] = fn_define_color_struct_CCF( color_set_string )
%FN_DEFIINE_COLOR_STRUCT_CCF Summary of this function goes here
%   Detailed explanation goes here

color_struct = [];

if ~exist('color_set_string', 'var') || isempty(color_set_string)
	color_set_string = 'CCF_defaults';
end

switch color_set_string
	case 'CCF_defaults'
		% these are the fixed CCF colors
		color_struct.side_A0 = [250 114 44]/255;
		color_struct.side_B1 = [87 117 180]/255;
		% these could be mixed from the corrct ratio of side_A0 and side_B1
		color_struct.coop_A = [250 114 44]/255;
		color_struct.coop_B = [87 117 180]/255;
		color_struct.comp = [0.9 0.9 0.9];	% this should be all white but that is hard to see on white background plots
		color_struct.pun = [1 0 0];	% not used
		% these mix the fraction of color with grey
		color_struct.Solo_A = mean([color_struct.side_A0; [128 128 128]/255]);
		color_struct.Solo_B = mean([color_struct.side_B1; [128 128 128]/255]);
		%color_struct.target0
		%color_struct.target1
		%color_struct.target2
		%color_struct.target3
		%color_struct.target4
		%color_struct.target5
		%color_struct.target6
		
		color_struct.Targets = [1 0 1];
		
		color_struct.face = [227, 26, 28] / 255;
		color_struct.B_facecenter = color_struct.face;
		color_struct.face_D = color_struct.face;
		color_struct.face_S = [251, 154, 153] / 255;
		
		color_struct.selected_target = [255, 127, 0] / 255;
		color_struct.selTarg = color_struct.selected_target;
		color_struct.selTarg_D = color_struct.selected_target;
		color_struct.selTarg_S = [253, 191, 111] / 255;
		
		color_struct.other_targets = [106, 61, 154] / 255;
		color_struct.otherTarg = color_struct.other_targets;
		color_struct.otherTarg_D = color_struct.other_targets;
		color_struct.otherTarg_S = [202, 178, 214] / 255;
		
		color_struct.aims0 = [31, 120, 180] / 255;
		color_struct.ownHand = color_struct.aims0;
		color_struct.ownHand_D = color_struct.aims0;
		color_struct.ownHand_S = [166, 206, 227] / 255;
		
		color_struct.aims1 = [51, 160, 44] / 255;
		color_struct.otherHand = color_struct.aims1;
		color_struct.otherHand_D = color_struct.aims1;
		color_struct.otherHand_S = [178, 223, 138] / 255;

	otherwise
		error([mfilename, ': ERROR: unkown color_set_string: ', color_set_string]);
end

end

