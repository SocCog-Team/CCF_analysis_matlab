function [ output_rect ] = fn_set_figure_outputpos_and_size( figure_handle, left_edge_cm, bottom_edge_cm, rect_w, rect_h, fraction, PaperOrientation_string, Units_string )
%FN_SET_FIGURE_OUTPUTPOS_AND_SIZE Summary of this function goes here
%   Detailed explanation goes here
output_rect = [];

if ~ ishandle(figure_handle)
	error(['First argument needs to be a figure handle...']);
end


cm2inch = 1/2.54;
fraction = 1;
output_rect = [left_edge_cm bottom_edge_cm rect_w rect_h] * cm2inch;	% left, bottom, width, height
set(figure_handle, 'Units', Units_string, 'Position', output_rect, 'PaperPosition', output_rect);
set(figure_handle, 'PaperSize', [rect_w+2*left_edge_cm*fraction rect_h+2*bottom_edge_cm*fraction] * cm2inch, 'PaperOrientation', PaperOrientation_string, 'PaperUnits', Units_string);


return
end

