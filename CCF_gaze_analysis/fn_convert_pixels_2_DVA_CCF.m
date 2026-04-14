function  [x_position_list_deg, y_position_list_deg] = fn_convert_pixels_2_DVA_CCF(x_position_list_pix, y_position_list_pix, x_screen_clostest2eye_pix, y_screen_clostest2eye_pix, screen_pix2mm_x, screen_pix2mm_y, eye2srceen_distance_mm, origin_X_pix, origin_Y_pix)
%FN_CONVERT_PIXELS_2_DVA, what is says on the tin...
% SCP event, gaze, touch data is calibrated to screen pixels as common
% reference frame; however for some analyses of gaze behavior, like
% saccades it is customary to operate in the reference frame of degrees
% of visual angle, to account for the fact that the eye movements are
% rotations of the spherical eyeballs.
% Inputs:
%	x_position_list_pix: the gaze azimuth position in screen pixel units
%	y_position_list_pix: the gaze elevation position in screen pixel units
%	x_screen_clostest2eye_pix: the x position in pixels of the subjects eye
%	y_screen_clostest2eye_pix: the y position in pixels of the subjects eye
%	screen_pix2mm_x: the number of pixels per millimeter in X/azimuth
%	screen_pix2mm_y: the number of pixels per millimeter in Y/elevation
%	eye2srceen_distance_mm: closest distance between eye and screen in
%		millimeters
%	origin_X_pix: the pixel X coordinate to use as zero for azimuth
%	origin_Y_pix: the pixel X coordinate to use as zero for elevation


% default works for SCP_01 (DIP and hDIP with the Samsung 55" OLED)
if ~exist('screen_pix2mm_x', 'var') || isempty(screen_pix2mm_x)
	screen_pix2mm_x = 1920/1209.4;
end
% default works for SCP_01 (DIP and hDIP with the Samsung 55" OLED)
if ~exist('screen_pix2mm_y', 'var') || isempty(screen_pix2mm_y)
	screen_pix2mm_y = 1080/680.4;
end

if ~exist('eye2srceen_distance_mm', 'var') || isempty(eye2srceen_distance_mm)
	eye2srceen_distance_mm = 300; % 300 or 350mm
end


% this defines the 0 azimuth coordinate for DVA space
if ~exist('origin_Y_pix', 'var') || isempty(origin_Y_pix)
	origin_Y_pix = 500;
end
% this defines the 0 elevation coordinate for DVA space
if ~exist('origin_X_pix', 'var') || isempty(origin_X_pix)
	origin_X_pix = 960;
end


if ~exist('x_screen_clostest2eye_pix', 'var') || isempty(x_screen_clostest2eye_pix)
	%distance_of_x_screen_clostest2eye_pix_2_ITF_mm = 0; % positions to the right of IFT are positive
	%x_screen_clostest2eye_pix = origin_X_pix + (distance_of_x_screen_clostest2eye_pix_2_ITF_mm * screen_pix2mm_x);
	%x_screen_clostest2eye_pix = 960 + (0 * 1920/1209.4);
	x_screen_clostest2eye_pix = 960;
end

% for the experiements in the DIP we adjust the eye height ot be 128cm
% above ground, which with the normal screen position results in pixel 
if ~exist('y_screen_clostest2eye_pix', 'var') || isempty(y_screen_clostest2eye_pix)
	%distance_of_y_screen_clostest2eye_pix_2_ITF_mm = -100; % positions above the IFT are negative
	%y_screen_clostest2eye_pix = origin_Y_pix + (distance_of_y_screen_clostest2eye_pix_2_ITF_mm * screen_pix2mm_y);
	%y_screen_clostest2eye_pix = 500 + (-100 * 1080/680.4);	
	y_screen_clostest2eye_pix = 341.27;
end


% recalculate based on current eye position...
delta_x_position_list_pix = x_position_list_pix - x_screen_clostest2eye_pix;
delta_y_position_list_pix = (y_position_list_pix - y_screen_clostest2eye_pix) * -1; % we want positive values for positions above the reference point
delta_x_position_list_mm = delta_x_position_list_pix / screen_pix2mm_x;
delta_y_position_list_mm = delta_y_position_list_pix / screen_pix2mm_y;

% trigonometry for th win... atanD operates on degrees so in the space we
% want for DVA...
x_position_list_deg = atand(delta_x_position_list_mm / eye2srceen_distance_mm);
y_position_list_deg = atand(delta_y_position_list_mm / eye2srceen_distance_mm);

return

% Some left overs from developing this.
% screen_w_pix=1920;
% 
% screen_h_pix=1080;
% 
% screen_w_cm=120.94;
% 
% screen_h_cm=68.04;
% 
% % viewing_dist=50;
% % center_x_pix = SETTINGS.screen_w_pix / 2;
% center_y_pix = screen_h_pix / 2;
% center_x_pix = screen_w_pix / 2;
% % center_y_pix = SETTINGS.screen_h_pix*SETTINGS.screen_uh_cm/SETTINGS.screen_h_cm;
% 
% 
% % distance to the center in pix
% dist_pix_x = pix_x - center_x_pix;
% dist_pix_y = center_y_pix - pix_y;
% 
% 
% pixels_per_cm_x = screen_w_pix / screen_w_cm;
% pixels_per_cm_y = screen_h_pix / screen_h_cm;
% 
% dist_cm_x = dist_pix_x/pixels_per_cm_x;
% dist_cm_y = dist_pix_y/pixels_per_cm_y;
% 
% %deg_x = cm2deg(SETTINGS.vd, dist_cm_x);
% 
% deg_x = 2 * atan((dist_cm_x / 2)/viewing_dist) / (pi / 180);
% deg_y = 2 * atan((dist_cm_y / 2)/viewing_dist) / (pi / 180);
% 
% %
% % deg_y = cm2deg(SETTINGS.vd, dist_cm_y);
% %  SETTINGS.screen_w_pix = 1600; % 1024;
% %         SETTINGS.screen_h_pix = 1200; %768;
% %         SETTINGS.screen_w_cm = 41;
% %         SETTINGS.screen_h_cm = 31;
% % %
% % SETTINGS.screen_uh_cm       = task.screen_uh_cm;
% % SETTINGS.screen_lh_deg      = atan((SETTINGS.screen_h_cm - SETTINGS.screen_uh_cm)/SETTINGS.vd)/(pi/180);
% % SETTINGS.screen_uh_deg      = atan(SETTINGS.screen_uh_cm/SETTINGS.vd)/(pi/180);
% % SETTINGS.screen_h_deg       = SETTINGS.screen_lh_deg + SETTINGS.screen_uh_deg;
% 
% % SETTINGS.screen_w_deg   = cm2deg(SETTINGS.vd,SETTINGS.screen_w_cm);
% % SETTINGS.screen_h_deg   = cm2deg(SETTINGS.vd,SETTINGS.screen_h_cm);
end
