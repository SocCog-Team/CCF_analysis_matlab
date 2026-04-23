function [ first2second_time_conversion_struct, second2first_time_conversion_struct, time_conversion_struct ] = fn_translate_between_named_timebases_CCF( REF_EPOC, Timebase1_name, ParaState_Timebase1_timestamps, Timebase2_name, ParaState_Timebase2_timestamps, TDT_sess_base_dir )
%FN_TRANSLATE_TDT_AND_EVENTIDE_TIMEBASES Summary of this function goes here
%   Detailed explanation goes here

disp(['Using the following event source for timing conversion between ', Timebase1_name,' and ', Timebase2_name,': ', REF_EPOC]);

[first2second_time_conversion_struct, second2first_time_conversion_struct, time_conversion_struct] = fn_create_timing_conversion_struct_CCF(...
	Timebase1_name, ParaState_Timebase1_timestamps, Timebase2_name, ParaState_Timebase2_timestamps);

ParaState_Timebase2_timestamps2TDT_time = fn_convert_time_between_named_timebases(ParaState_Timebase2_timestamps, time_conversion_struct, Timebase2_name, Timebase1_name);
ParaState_Timebase1_timestamps2EvIDE_time = fn_convert_time_between_named_timebases(ParaState_Timebase1_timestamps, time_conversion_struct, Timebase1_name, Timebase2_name);
if size(ParaState_Timebase2_timestamps2TDT_time, 1) == size(ParaState_Timebase1_timestamps2EvIDE_time, 2)
	ParaState_Timebase1_timestamps2EvIDE_time = ParaState_Timebase1_timestamps2EvIDE_time';
end


timing_fh = figure('Name', 'Time conversion error by trial in Seconds');
plotting_options.margin_cm = 1.0;
plotting_options.margin_cm = 1.0;
plot_width_cm = 25;
plot_height_cm = 15;
output_rect = fn_set_figure_outputpos_and_size(timing_fh, plotting_options.margin_cm, plotting_options.margin_cm, plot_width_cm, plot_height_cm, 1.0, 'portrait', 'inch');



subplot(2, 1, 1);
%tmp = ParaState_Timebase1_timestamps2EvIDE_time - ParaState_Timebase2_timestamps;
histogram(ParaState_Timebase1_timestamps2EvIDE_time*1000 - ParaState_Timebase2_timestamps*1000);
cur_diff_sum = sum(ParaState_Timebase1_timestamps2EvIDE_time - ParaState_Timebase2_timestamps);


xlabel(['Converted ', Timebase1_name,'event times minus', Timebase2_name,' event times [ms]']);
ylabel('count');
title({['Time conversion (', Timebase1_name,' to ', Timebase2_name,') using: ', REF_EPOC]}, {['sum: ', num2str(cur_diff_sum), ' s', '; span ', Timebase2_name,': ', num2str(ParaState_Timebase1_timestamps(end) - ParaState_Timebase1_timestamps(1))]}, 'FontSize', 14);

subplot(2, 1, 2);
%tmp = ParaState_Timebase2_timestamps2TDT_time - ParaState_Timebase1_timestamps;
histogram(ParaState_Timebase2_timestamps2TDT_time*1000 - ParaState_Timebase1_timestamps*1000);
cur_diff_sum = sum(ParaState_Timebase2_timestamps2TDT_time - ParaState_Timebase1_timestamps);
xlabel(['Converted ', Timebase2_name,' event times minus ', Timebase1_name,' event times [ms]']);
ylabel('count');
title({['Time conversion (', Timebase2_name,' to ', Timebase1_name,') using: ', REF_EPOC]}, {['sum: ', num2str(cur_diff_sum), ' s', '; span ', Timebase1_name,': ', num2str(ParaState_Timebase2_timestamps(end) - ParaState_Timebase2_timestamps(1))]}, 'FontSize', 14);

write_out_figure(timing_fh, fullfile(TDT_sess_base_dir, ['Timing_conversion_differences_', Timebase1_name,'-', Timebase2_name,'.', REF_EPOC, '.pdf']));



return
end

