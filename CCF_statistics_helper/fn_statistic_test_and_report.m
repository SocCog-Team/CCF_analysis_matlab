function [ aggregate_struct, report_string, short_report_string ] = fn_statistic_test_and_report(group_1_name, group_1_data, group_2_name, group_2_data, stat_type, verbose)

% TODO add permutation tests... 

if ~exist('verbose', 'var') || isempty(verbose)
	verbose = 0;
end
aggregate_struct = [];
report_string = [];
short_report_string = [];

if isempty(group_1_data) || isempty(group_2_data)
	disp([mfilename, ': at least one group empty, no statistics possible...']);
	return
end

aggregate_struct.group_1_name = group_1_name;
aggregate_struct.group_2_name = group_2_name;
% aggregate_struct.([group_1_name, '_mean']) = mean(group_1_data(:), 'omitnan');
% aggregate_struct.([group_2_name, '_mean']) = mean(group_2_data(:), 'omitnan');
% aggregate_struct.([group_1_name, '_median']) = median(group_1_data(:), 'omitnan');
% aggregate_struct.([group_2_name, '_median']) = median(group_2_data(:), 'omitnan');
% aggregate_struct.([group_1_name, '_std']) = std(group_1_data(:), 'omitnan');
% aggregate_struct.([group_2_name, '_std']) = std(group_2_data(:), 'omitnan');
% aggregate_struct.([group_1_name, '_n']) = length(group_1_data(~isnan(group_1_data)));
% aggregate_struct.([group_2_name, '_n']) = length(group_2_data(~isnan(group_2_data)));

aggregate_struct.stat_type = stat_type;
aggregate_struct.group_1_name_mean = mean(group_1_data(:), 'omitnan');
aggregate_struct.group_2_name_mean = mean(group_2_data(:), 'omitnan');
aggregate_struct.group_1_name_median = median(group_1_data(:), 'omitnan');
aggregate_struct.group_2_name_median = median(group_2_data(:), 'omitnan');
aggregate_struct.group_1_name_std = std(group_1_data(:), 'omitnan');
aggregate_struct.group_2_name_std = std(group_2_data(:), 'omitnan');
aggregate_struct.group_1_name_n = length(group_1_data(~isnan(group_1_data)));
aggregate_struct.group_2_name_n = length(group_2_data(~isnan(group_2_data)));


switch stat_type
	case {'ttest', 'paired_ttest'}
		% paired t-test
		[aggregate_struct.h, aggregate_struct.p, aggregate_struct.ci, aggregate_struct.stats] = ttest(group_1_data(:), group_2_data(:));
		report_stat = 'mean_t';
	case 'ttest2'
		[aggregate_struct.h, aggregate_struct.p, aggregate_struct.ci, aggregate_struct.stats] = ttest2(group_1_data(:), group_2_data(:));
		report_stat = 'mean_t';
	case 'ttest2_unequalvariance'
		[aggregate_struct.h, aggregate_struct.p, aggregate_struct.ci, aggregate_struct.stats] = ttest2(group_1_data(:), group_2_data(:), 'Vartype','unequal');
		report_stat = 'mean_t';
	case 'ranksum'
		if (aggregate_struct.group_1_name_n + aggregate_struct.group_2_name_n) > 20
			disp([mfilename, ': WARN: ranksum exact gets slow for large N... consider using ranksum_approximate.']);
		end
		if isempty(group_1_data) || isempty(group_2_data)
			aggregate_struct.p = NaN;
			aggregate_struct.h = NaN;
			aggregate_struct.stats = struct();
		else
			[aggregate_struct.p, aggregate_struct.h, aggregate_struct.stats] = ranksum(group_1_data(:), group_2_data(:), 'method', 'exact');
		end
		report_stat = 'median';
		%[~, ~, aggregate_struct.stats_approximate] = ranksum(group_1_data(:), group_2_data(:), 'method', 'approximate');
		%report_stat = 'median
	case 'ranksum_approximate'
		if isempty(group_1_data) || isempty(group_2_data) || all(isnan(group_1_data)) || all(isnan(group_2_data))
			aggregate_struct.p = NaN;
			aggregate_struct.h = NaN;
			aggregate_struct.stats = struct();
		else
			[aggregate_struct.p, aggregate_struct.h, aggregate_struct.stats] = ranksum(group_1_data(:), group_2_data(:), 'method', 'approximate');
		end
		report_stat = 'median';	
	case 'signrank'
		% paired test
		[aggregate_struct.p, aggregate_struct.h, aggregate_struct.stats] = signrank(group_1_data(:), group_2_data(:), 'method', 'exact');
		report_stat = 'median';
	case 'signrank_approximate'
		% paired test
		[aggregate_struct.p, aggregate_struct.h, aggregate_struct.stats] = signrank(group_1_data(:), group_2_data(:), 'method', 'approximate');
		report_stat = 'median';
	otherwise
		error(['Unhandled statistics requested: ', stat_type]);
end

report_string = [stat_type, ': ', ];
switch report_stat
	case 'mean_t'
		% for t-tests....
		% the first mean and SD
		report_string = [report_string, group_1_name, ': (M: ', num2str(mean(group_1_data(:), 'omitnan'), '%.5f'), '; SD: ', num2str(std(group_1_data(:), 'omitnan')), '; N: ', num2str(aggregate_struct.group_1_name_n), '); ', ...
			group_2_name, ': (M: ', num2str(mean(group_2_data(:), 'omitnan'), '%.5f'), '; SD: ', num2str(std(group_2_data(:), 'omitnan')), '; N: ', num2str(aggregate_struct.group_2_name_n), '); ', ...
			't(', num2str(aggregate_struct.stats.df, '%.4f'), '): ', num2str(aggregate_struct.stats.tstat, '%.4f'), '; p:< ', num2str(aggregate_struct.p, '%.10f')];
		%disp(report_string);
		%disp(' ');
		if nargout == 3
			short_report_string = [stat_type, ': ', group_1_name, '(M', num2str(mean(group_1_data(:), 'omitnan'), '%.2f'), '); ', ...
			group_2_name, '(M', num2str(mean(group_2_data(:), 'omitnan'), '%.2f'), '); ', ...
			't(', num2str(aggregate_struct.stats.df, '%.2f'), '): ', num2str(aggregate_struct.stats.tstat, '%.4f'), '; p:< ', num2str(aggregate_struct.p, '%.4f')];
		end
	case 'median'
		% the first median and SD
		%disp(stat_type);
		report_string = [report_string, group_1_name, ': (MD: ', num2str(median(group_1_data(:), 'omitnan'), '%.5f'), '; N: ', num2str(aggregate_struct.group_1_name_n), '); ', ...																		]);
			group_2_name, ': (MD: ', num2str(median(group_2_data(:), 'omitnan'), '%.5f'), '; N: ', num2str(aggregate_struct.group_2_name_n), '); ', ...
			'p:< ', num2str(aggregate_struct.p, '%.10g')];
		if isfield(aggregate_struct.stats, 'ranksum')
			report_string = [report_string, '; ', 'ranksum: ', num2str(aggregate_struct.stats.ranksum, '%.4g')];
		end
		if isfield(aggregate_struct.stats, 'signrank')
			report_string = [report_string, '; ', 'signrank: ', num2str(aggregate_struct.stats.signrank, '%.4g')];
		end
		if isfield(aggregate_struct.stats, 'zval')
			 report_string = [report_string, '; ', 'Z: ', num2str(aggregate_struct.stats.zval)]; %', r: ', num2str(aggregate_struct.stats.zval/sqrt(aggregate_struct.([group_1_name, '_n'])))]};
			 if (aggregate_struct.group_1_name_n == aggregate_struct.group_2_name_n)
				 report_string = [report_string, '; ','r: ', num2str(aggregate_struct.stats.zval/sqrt(aggregate_struct.group_1_name_n), '%.4g')];
			 end
		end
		%disp(report_string);
		%disp(' ');
		if nargout == 3
			short_report_string = [stat_type, ': ', group_1_name, ': (MD: ', num2str(median(group_1_data(:), 'omitnan'), '%.5f'), '; N: ', num2str(aggregate_struct.group_1_name_n), '); ', ...																		]);
			group_2_name, ': (MD: ', num2str(median(group_2_data(:), 'omitnan'), '%.5f'), '; N: ', num2str(aggregate_struct.group_2_name_n), '); ', ...
			'p:< ', num2str(aggregate_struct.p, '%.7g')];
		end
end

if (verbose)
	disp(report_string);
end

return
end

