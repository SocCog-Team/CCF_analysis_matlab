function [ enum_struct ] = fn_extract_python_enums( python_enum_FQN )
%FN_EXTRACT_PYTHON_ENUMS Summary of this function goes here
%   Detailed explanation goes here
enum_struct = [];

% TODO actually parse enums.py to fill this, for now, just hard code it...

% manually recreate the enums here, should try to parse enums.py instead


% # we will add these to the h5 data table so keep the meaning and naming of the states permanent
% # do not delete obsolete states, but simply stop using them and add new states to the end of this enum
% class target_state(Enum):
%     NONE = 1
%     waiting_for_agent = 2
%     collecting = 3
%     initiate_reward = 4
%     rewarding = 5
%     pre_acquisition = 6
enum_struct.target_state.ENUM.NONE = 1;
enum_struct.target_state.ENUM.waiting_for_agent = 2;
enum_struct.target_state.ENUM.collecting = 3;
enum_struct.target_state.ENUM.initiate_reward = 4;
enum_struct.target_state.ENUM.rewarding = 5;
enum_struct.target_state.ENUM.pre_acquisition = 6;

enum_struct.target_state.name_list = {'NONE', 'waiting_for_agent', 'collecting', 'initiate_reward', 'rewarding', 'pre_acquisition'};
enum_struct.target_state.value_list = [1, 2, 3, 4, 5, 6];


% # add enum for TargetID?
% # ATTENTION this is currently just for documentation, not yet wired up in backend/targets.py
% class target_id(Enum):
%     cooperative_targets_type_0 = 0
%     cooperative_targets_type_1 = 1
%     competitive_targets = 2
%     punishing_targets = 3
%     solo_targets_type_0 = 4
%     solo_targets_type_1 = 5
enum_struct.target_id.ENUM.cooperative_targets_type_0 = 0;
enum_struct.target_id.ENUM.cooperative_targets_type_1 = 1;
enum_struct.target_id.ENUM.competitive_targets = 2;
enum_struct.target_id.ENUM.punishing_targets = 3;
enum_struct.target_id.ENUM.solo_targets_type_0 = 4;
enum_struct.target_id.ENUM.solo_targets_type_1 = 5;

enum_struct.target_id.name_list = {'cooperative_targets_type_0', 'cooperative_targets_type_1', 'competitive_targets', 'punishing_targets', 'solo_targets_type_0', 'solo_targets_type_1'};
enum_struct.target_id.value_list = [0, 1, 2, 3, 4, 5];


% # add enum for DAG-style task to TDT messages
% # these interleave the actual data words
% class DO_control_word(Enum):
%     stopper_control = 0
%     INI_trial = 252
%     end_trial = 253
%     no_change = 254
%     INI_states = 255
enum_struct.DO_control_word.stopper_control = 0;
enum_struct.DO_control_word.INI_trial = 252;
enum_struct.DO_control_word.end_trial = 253;
enum_struct.DO_control_word.no_change = 254;
enum_struct.DO_control_word.INI_states = 255;

enum_struct.DO_control_word.name_list = {'stopper_control', 'INI_trial', 'end_trial', 'no_change', 'INI_states'};
enum_struct.DO_control_word.value_list = [0, 252, 253, 254, 255];


% # add any new DI lines here
% class DI_line_to_sensor_mapping(Enum):
% 	A0_right_sensor = 0
% 	A0_left_sensor = 1
% 	B1_right_sensor = 2
% 	B1_left_sensor = 3
% these are 0-based bit addresses into the DI word
enum_struct.DI_line_to_sensor_mapping.ENUM.A0_right_sensor = 0;
enum_struct.DI_line_to_sensor_mapping.ENUM.A0_left_sensor = 1;
enum_struct.DI_line_to_sensor_mapping.ENUM.B1_right_sensor = 2;
enum_struct.DI_line_to_sensor_mapping.ENUM.B1_left_sensor = 3;

enum_struct.DI_line_to_sensor_mapping.name_list = {'A0_right_sensor', 'A0_left_sensor', 'B1_right_sensor', 'B1_left_sensor'};
enum_struct.DI_line_to_sensor_mapping.value_list = [0, 1, 2, 3];

end

