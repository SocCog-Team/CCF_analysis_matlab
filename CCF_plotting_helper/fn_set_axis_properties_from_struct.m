function [ ] = fn_set_axis_properties_from_struct( cur_ah, plotting_options_struct_set_gca)
%FN_SET_AXIS_PROPERTIES_FRM_ Summary of this function goes here
%   Detailed explanation goes here

% just take a list of options to set for the axis and loop over them

axis_attributes_to_set_list = fieldnames(plotting_options_struct_set_gca);
for i_axis_attributes_to_set = 1 : length(axis_attributes_to_set_list)
	cur_axis_attribute_name = axis_attributes_to_set_list{i_axis_attributes_to_set};
	set(cur_ah, cur_axis_attribute_name, plotting_options_struct_set_gca.(cur_axis_attribute_name));
end

end

