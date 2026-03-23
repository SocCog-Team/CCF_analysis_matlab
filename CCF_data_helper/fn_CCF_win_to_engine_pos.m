function [ X_pixel, Y_pixel ] = fn_CCF_win_to_engine_pos( X_rel, Y_rel, field_size, target_radius, field_x_offset, field_y_offset)
%FN_CCF_RELATIVE_TO_PIXEL_POS Summary of this function goes here
%   Convert from relative CCF game playing field coordinates to pixel space
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

X_pixel = (X_rel * scale) + offset_x;
Y_pixel = (Y_rel * scale) + offset_y;

end

