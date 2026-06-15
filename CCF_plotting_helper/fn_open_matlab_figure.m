function [ cur_fh, cur_fh_ah_list, openable_by_openfig ] = fn_open_matlab_figure( cur_fig_fqn )
%FN_OPEN_MATLAB_FIGURE Summary of this function goes here
%   Detailed explanation goes here

% return the handle of the open figure
cur_fh = [];

% also collect the axis handles annd return those
cur_fh_ah_list = [];

openable_by_openfig = false;


try
	disp([mfilename, ': opening input file (openfig): ', cur_fig_fqn]);
	cur_fh = openfig(cur_fig_fqn); % this fails
	openable_by_openfig = true;
catch ME
	% see https://undocumentedmatlab.com/articles/serializing-deserializing-matlab-data
	disp(ME.identifier);
	% delete the partially written file
	disp([mfilename, ': Could not open current figure using openfig: ', cur_fig_fqn]);
	disp([mfilename, ': Trying to load most of thefigure manually instead']);

	[cur_fig_path, cur_fig_name, cur_fig_ext] = fileparts(cur_fig_fqn);
	tmp_fig_fqn = fullfile(cur_cache_FQD, ['defanged.', cur_fig_name, cur_fig_ext]);


	% try to get to the figure core part... by loading the fig as mat (matlab .fig files are structured .mat internally)
	hgDataVars = load(cur_fig_fqn, '-mat', '-regexp', '^hg[S]'); % hgDataVars.hgS_070000
	hgS_070000 = hgDataVars.hgS_070000;
	% now save it out as fig again...
	save(tmp_fig_fqn, 'hgS_070000');
	% and use openfig to get make cur_fh to point at the desired figure
	cur_fh = openfig(tmp_fig_fqn);
	disp([mfilename, ': deleting temporary figure file: ', tmp_fig_fqn]);
	delete(tmp_fig_fqn);
end


% now try to collect the axis handles for the given figure
% see: https://stackoverflow.com/questions/3938348/matlab-how-to-obtain-all-the-axes-handles-in-a-figure-handle
if ~isempty(cur_fh)
	% allAxesInFigure = findall(cur_fh,'type','axes');
	% isAxes = strcmp('axes',get(allAxesInFigure,'type'));
	% axNoLegendsOrColorbars = allAxesInFigure(~ismember(get(allAxesInFigure,'Tag'),{'legend','Colobar'}));
	% cur_fh_ah_list = axNoLegendsOrColorbars;
	tmp_cur_fh_ah_list = findobj(cur_fh, 'Type', 'Axes');
	for i_axis = 1 : size(tmp_cur_fh_ah_list, 1)
		cur_fh_ah_list{i_axis} = tmp_cur_fh_ah_list(i_axis, 1);
	end
end

% try to fail gracefully
if isempty(cur_fh)
	cur_fh = gobjects(0);
	cur_fh_ah_list = gobjects(0);
end

end

