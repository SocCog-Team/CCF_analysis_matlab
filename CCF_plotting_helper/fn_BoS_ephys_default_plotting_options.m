function [ selected_plotting_options_struct ] = fn_BoS_ephys_default_plotting_options( set_string )
%FN_BOS_EPHYS_DEFAULT_PLOTTING_OPTIONS Summary of this function goes here
%   Detailed explanation goes here


if ~exist('set_string', 'var') || isempty(set_string)
	set_string = 'bos_ephys_01';
end


% the DEFAULTs, add every thing here
plotting_options_template.figure_visibility_string = 'on';
plotting_options_template.labelfontsize = 10;
plotting_options_template.titlefontsize = 12;
plotting_options_template.subtitlefontsize = 10;
plotting_options_template.legendfontsize = 8.0;
plotting_options_template.axisfontsize = 10.0;



% we have plots with 4 columns, so this is not wide enough
plotting_options_template.panel_width_cm = ((21-(2*1)) / 3 );	% third of a DINA4 page with 1 cm margin
plotting_options_template.panel_height_cm = ((21-(2*1)) / 3) * 0.9; % (19 / 3)

% switch to DinA4 quarter
%plotting_options_template.panel_width_cm = ((21-(2*1)) / 4 );	% quarter of a DINA4 page with 1 cm margin
%plotting_options_template.panel_height_cm = ((21-(2*1)) / 4) * 0.9; % (19 / 3)
% might need to adjust font sizes...

% the DEFAULTs, add every thing here
plotting_options_template.figure_visibility_string = 'on';
plotting_options_template.labelfontsize = 9;
plotting_options_template.titlefontsize = 11;
plotting_options_template.subtitlefontsize = 9;
plotting_options_template.legendfontsize = 7;
plotting_options_template.axisfontsize = 9;

% 20251016 smaller fonts and finer lines...
plotting_options_template.labelfontsize = 8;
plotting_options_template.titlefontsize = 10;
plotting_options_template.subtitlefontsize = 9;
plotting_options_template.legendfontsize = 7;
plotting_options_template.axisfontsize = 8;




plotting_options_template.margin_cm = 1;
plotting_options_template.format_string = '.pdf';
plotting_options_template.format_string_list = {'.pdf', '.fig'};	% this will loop over the requested formats..., '.pdf', '.png', '.fig'
%plotting_options_template.plot_legend = 1;			% show legend instead of subtitlebos_ephys_01.plot_legend = 1;			% show legend instead of subtitle
%plotting_options_template.legendlocation_string = 'southoutside'; % northoutside: on top of title, southoutside: belw xlabel
%plotting_options_template.legendbox_string = 'off'; % on or off
%plotting_options_template.legendlocation_string = 'northwest'; % best, northeast
%plotting_options_template.legendbox_string = 'on'; % on or off
plotting_options_template.linewidth = 1.5;
%for the following loop over all fields and apply to the current axis
plotting_options_template.set_gca.XTick = [-500, 0 , 500];
%plotting_options_template.set_gca.YTick = [40, 60, 80, 100]; %[0, 25, 50, 75, 100];
plotting_options_template.set_gca.linewidth = plotting_options_template.linewidth * 0.5; % the axis linewidth
plotting_options_template.set_gca.FontName = 'Arial';	% windows lacks Helvetica, so take Arial instead even on mac...
plotting_options_template.set_gca.FontSize = plotting_options_template.axisfontsize;



%plotting_options_template.violin.set_gca.XTick = [-500, 0 , 500];
%plotting_options_template.set_gca.YTick = [40, 60, 80, 100]; %[0, 25, 50, 75, 100];
plotting_options_template.violin.set_gca.linewidth = plotting_options_template.linewidth * 0.5; % the axis linewidth
plotting_options_template.violin.set_gca.FontName = 'Arial';	% windows lacks Helvetica, so take Arial instead even on mac...
plotting_options_template.violin.set_gca.FontSize = plotting_options_template.axisfontsize;

plotting_options_template.correlation.set_gca.XTick = [0 25 50 75 100];
plotting_options_template.correlation.set_gca.YTick = [0 25 50 75 100]; %[0, 25, 50, 75, 100];
plotting_options_template.correlation.set_gca.linewidth = plotting_options_template.linewidth * 0.5; % the axis linewidth
plotting_options_template.correlation.set_gca.FontName = 'Arial';	% windows lacks Helvetica, so take Arial instead even on mac...
plotting_options_template.correlation.set_gca.FontSize = plotting_options_template.axisfontsize;


% always eadd new fields to plotting_options_template 
bos_ephys_01 = plotting_options_template;
default_plotting_options_struct.bos_ephys_01 = bos_ephys_01;

% to create a new variant, first copy then modify, than add to default_plotting_options_struct
% for example: always add new fields to 
test_plot_opt_struct = bos_ephys_01;
test_plot_opt_struct.subtitlefontsize = 9;
default_plotting_options_struct.test_plot_opt_struct = test_plot_opt_struct;


% check whether the requested set exists...
defined_sets_list = fieldnames(default_plotting_options_struct);
if ~ismember({set_string}, defined_sets_list)
	error([mfilename, ': requested potting option set does not exist...: ', set_string]);
end

selected_plotting_options_struct = default_plotting_options_struct.(set_string);


return
end

