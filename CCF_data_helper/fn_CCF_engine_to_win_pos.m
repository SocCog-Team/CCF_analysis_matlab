function [X_rel, Y_rel] = fn_CCF_engine_to_win_pos(X_pixel, Y_pixel, field_size, target_radius, field_x_offset, field_y_offset)
%FN_CCF_ENGINE_TO_WIN_POS Summary of this function goes here
%   Convert from pixel space to relative CCF game playing field coordinates
% Note to convert to EventIDE/D3D coordinates y needs to be flipped (screen_hight-pixel - Y_pixel)
% This converts from CCF relative position within the playing field to
% screen pixel coordinates. This is based on CCF's utils.to_win_pos()
% function
% for x lower to higher: left to right
% for y lower to higher: bottom to top
% ATTENTION: EventIDE convention is flipped for y:
%	y: lower to higher: top to bottom

scale = field_size - (2 * target_radius * field_size);

offset_x = field_x_offset + (target_radius * field_size);
offset_y = field_y_offset + (target_radius * field_size);

X_rel = (X_pixel - offset_x) / scale;
Y_rel = (Y_pixel - offset_y) / scale;

end

