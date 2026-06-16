function [ ret_val ] = write_out_figure(img_fh, outfile_fqn, verbosity_str, print_options_str, output_type_list)
%WRITE_OUT_FIGURE save the figure referenced by img_fh to outfile_fqn,
% using .ext of outfile_fqn to decide which image type to save as.
%   Detailed explanation goes here
% write out the data

if ~exist('verbosity_str', 'var') || isempty(verbosity_str)
	verbosity_str = 'verbose';
end

% try to add the filename
add_filename = 0;
if (add_filename)
	[outfile_path, outfile_name, outfile_ext] = fileparts(outfile_fqn);
	% idea add one axis over the full figure...
	%text_ah = axes(img_fh, 'Units', 'normalized', 'Position', [0 0 1 1], 'Visible', 'off');
	%text(text_ah, 0.01, 0.05, outfile_name, 'Position', [1 0 0], 'HorizontalAlignment', 'Left', 'Units', 'normalized', 'Interpreter', 'None', 'FontSize', 6, 'Color', [0.3 0.3 0.3]);
	%text(gca, 0.01, 0.05, outfile_name, 'Position', [0 0 0], 'HorizontalAlignment', 'Left', 'Units', 'normalized', 'Interpreter', 'None', 'FontSize', 6, 'Color', [0.3 0.3 0.3]);
	th = text(gca, 0.01, 0.05, outfile_name, 'HorizontalAlignment', 'Left', 'Units', 'normalized', 'Interpreter', 'None', 'FontSize', 2, 'Color', [0.3 0.3 0.3]);
	set(th, 'Position', [-0.16, -0.23]); % to move this outside the axis we need to play tricks...
	%img_fh = gcf;
end
warning_struct =  warning('off', 'MATLAB:print:ContentTypeImageSuggested');

% check whether the path exists, create if not...
[pathstr, img_name, img_type] = fileparts(outfile_fqn);
if isempty(dir(pathstr))
	mkdir(pathstr);
end


if ~exist('print_options_str', 'var') || isempty(print_options_str)
	print_options_str = '';
else
	print_options_str = [', ''', print_options_str, ''''];
end


if ~exist('output_type_list', 'var') || isempty(output_type_list)
	output_type_list = {img_type};
end


for i_output_type = 1 : length(output_type_list)
	img_type = output_type_list{i_output_type};
	cur_outfile_fqn = fullfile(pathstr, [img_name, img_type]);

	% deal with r2016a changes, needs revision
	if (strcmp(version('-release'), '2016a'))
		set(img_fh, 'PaperPositionMode', 'manual');
		if ~ismember(img_type, {'.png', '.tiff', '.tif'})
			print_options_str = '-bestfit';
		end
	end
	resolution_str = ', ''-r600''';


	device_str = [];

	switch img_type(2:end)
		case 'pdf'
			% pdf in 7.3.0 is slightly buggy...
			%print(img_fh, '-dpdf', outfile_fqn);
			device_str = '-dpdf';
		case 'ps3'
			%print(img_fh, '-depsc2', outfile_fqn);
			device_str = '-depsc';
			print_options_str = '';
			cur_outfile_fqn = [cur_outfile_fqn, '.eps'];
		case {'ps', 'ps2'}
			%print(img_fh, '-depsc2', outfile_fqn);
			device_str = '-depsc2';
			print_options_str = '';
			cur_outfile_fqn = [cur_outfile_fqn, '.eps'];
		case {'tiff', 'tif'}
			% tiff creates a figure
			%print(img_fh, '-dtiff', outfile_fqn);
			device_str = '-dtiff';
		case 'png'
			% tiff creates a figure
			%print(img_fh, '-dpng', outfile_fqn);
			device_str = '-dpng';
			resolution_str = ', ''-r1200''';
		case 'eps'
			%print(img_fh, '-depsc', '-r300', outfile_fqn);
			device_str = '-depsc';
		case 'fig'
			%sm: allows to save figures for further refinements
			try 
				saveas(img_fh, cur_outfile_fqn, 'fig');
			catch MEsavaeas
				MEsavaeas
				[cur_path, cur_name, cur_ext] = fileparts(cur_outfile_fqn);
				if (length(cur_name) > 250) && ispc
					disp([mfilename, ': WARN: name (without extension) exceeds 250 characters, windows is not going to be happy, so we truncate the name to 250']);
					disp([mfilename, ': WARN: better use shorter names']);
					disp(cur_name);
					disp(cur_name(1:250));
					saveas(img_fh, fullfile(cur_path, [cur_name(1:250), cur_ext]));
				end
			end
		otherwise
			% default to uncompressed images
			disp(['Image type: ', img_type, ' not handled yet...']);
	end

	if ismember(img_type(2:end), {'pdf', 'eps'})
		% exportgraphics has issues with overwriting existing files on windows
		% shares
		if isfile(cur_outfile_fqn)
			delete(cur_outfile_fqn);
			disp([mfilename, ': File already exists, let''s delete it to avoid silly windows errors...'])
		end
		try
			exportgraphics(img_fh, cur_outfile_fqn, 'BackgroundColor', 'none', 'ContentType', 'vector'); % otherwise pdf export choes on multiple transparent overlapping patches
		catch ME
			ME

			try
				% if the name is too long try to get creative
				[cur_path, cur_name, cur_ext] = fileparts(cur_outfile_fqn);

				% at least windows only allows names up to 250
				% characters...
				if (length(cur_name) > 250) && ispc
					disp([mfilename, ': WARN: name (without extension) exceeds 250 characters, windows is not going to be happy, so we truncate the name to 250']);
					disp([mfilename, ': WARN: better use shorter names']);
					disp(cur_name);
					disp(cur_name(1:250));
					exportgraphics(img_fh, fullfile(cur_path, [cur_name(1:250), cur_ext]), 'BackgroundColor', 'none', 'ContentType', 'vector');
				else
					%cc = setdiff(' ':'~', ['a':'z','A':'Z', '0':'9']);
					valid_chars_list = ['a':'z','A':'Z', '0':'9'];
					intermediate_name = valid_chars_list(randi(length(valid_chars_list), 1, 24)); % to avoid clobbering the same file from multiple writers use random names...

					intermediate_name_ext = [intermediate_name, cur_ext];
					if ispc
						% argh, windows is special here
						[status, win_temp_dir_FQD] = system('ECHO %TEMP%'); % NOTE this carries a CR at the end or a LF, so ignore the last position
						intermediate_fqn = fullfile(win_temp_dir_FQD(1:end-1), intermediate_name_ext)
					else
						% this seems to work on linux and macos (so for ~ispc)
						intermediate_fqn = fullfile('/temp', intermediate_name_ext);
					end
					exportgraphics(img_fh, intermediate_fqn, 'BackgroundColor', 'none', 'ContentType', 'vector');
					[status,msg,msgID] = movefile(intermediate_fqn, cur_outfile_fqn);
				end

			catch ME2
				ME2
				keyboard % fix the borked save and continue with dbcont
			end


		end
	else
		if ~isempty(device_str)
			device_str = [', ''', device_str, ''''];
			command_str = ['print(img_fh', device_str, print_options_str, resolution_str, ', cur_outfile_fqn)'];
			eval(command_str);
		end
	end

	if strcmp(verbosity_str, 'verbose')
		if ~isnumeric(img_fh)
			disp(['Saved figure (', num2str(img_fh.Number), ') to: ', cur_outfile_fqn]);	% >R2014b have structure figure handles
		else
			disp(['Saved figure (', num2str(img_fh), ') to: ', cur_outfile_fqn]);			% older Matlab has numeric figure handles
		end
	end
end

ret_val = 0;
warning(warning_struct);

return
end
