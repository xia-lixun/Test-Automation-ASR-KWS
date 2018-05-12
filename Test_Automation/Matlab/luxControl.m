function varargout = luxControl(varargin)
% LUXCONTROL M-file for luxControl.fig
%      LUXCONTROL, by itself, creates a new LUXCONTROL or raises the existing
%      singleton*.
%
%      H = LUXCONTROL returns the handle to a new LUXCONTROL or the handle to
%      the existing singleton*.
%
%      LUXCONTROL('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in LUXCONTROL.M with the given input arguments.
%
%      LUXCONTROL('Property','Value',...) creates a new LUXCONTROL or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before luxControl_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to luxControl_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help luxControl

% Last Modified by GUIDE v2.5 27-Apr-2018 13:23:00

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @luxControl_OpeningFcn, ...
    'gui_OutputFcn',  @luxControl_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

% --- Executes just before luxControl is made visible.
function luxControl_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to luxControl (see VARARGIN)

% Choose default command line output for luxControl
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

plot(1);
zoom on, grid on

% UIWAIT makes luxControl wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = luxControl_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

% --------------------------------------------------------------------
% --- Executes on button press in pushbuttonInit.
function pushbuttonInit_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonInit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
luxInit();

% --- Executes on button press in pushbuttonPlay.
function pushbuttonPlay_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonPlay (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[filename, pathname] = uigetfile('*.wav','File Selector');
if 0 ~= filename
    luxPlay(filename);
end

% --- Executes on button press in pushbuttonRecord.
function pushbuttonRecord_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonRecord (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
time = str2num(char(get(handles.editRecTime,'String')));
luxRecord(time, getStreams(handles));


% --- Executes on button press in pushbuttonPlayAndRecord.
function pushbuttonPlayAndRecord_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonPlayAndRecord (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[filename, pathname] = uigetfile('*.wav','File Selector');
if 0 ~= filename
    time = str2num(char(get(hEdit,'String')));
    luxPlayAndRecord(filename, time);
end


% --- Executes on button press in pushbuttonPlot.
function pushbuttonPlot_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonPlot (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% --- Plots the first channel of a raw file.
[filename, pathname] = uigetfile('*.raw','File Selector');
if 0 ~= filename
    fid = fopen(filename,'rb');
    if     strfind(filename,'AEC') > 0; precision = 'float';
    elseif strfind(filename,'GlobalEq') > 0 ; precision = 'float';
    elseif strfind(filename,'FixedBeamFormer') > 0; precision = 'float';
    else
        precision = 'int16';
    end
        x = fread(fid,[8,inf],precision);
    fclose(fid);
    plot(x(1,:));
    zoom on, grid on
end


% --- Collects name of all checked output streams.
function s = getStreams(handles)
s = {};
if 1 == get(handles.checkbox_MicIn,'Value')
    s = [s get(handles.checkbox_MicIn,'String')];
end
if 1 == get(handles.checkbox_MicRef,'Value')
    s = [s get(handles.checkbox_MicRef,'String')];
end
if 1 == get(handles.checkbox_MicInput,'Value')
    s = [s get(handles.checkbox_MicInput,'String')];
end
if 1 == get(handles.checkbox_DCBlock,'Value')
    s = [s get(handles.checkbox_DCBlock,'String')];
end
if 1 == get(handles.checkbox_AEC,'Value')
    s = [s get(handles.checkbox_AEC,'String')];
end
if 1 == get(handles.checkbox_FixedBeamFormer,'Value')
    s = [s get(handles.checkbox_FixedBeamFormer,'String')];
end
if 1 == get(handles.checkbox_GlobalEq,'Value')
    s = [s get(handles.checkbox_GlobalEq,'String')];
end
if 1 == get(handles.checkbox_SpectralBeamSteering,'Value')
    s = [s get(handles.checkbox_SpectralBeamSteering,'String')];
end
if 1 == get(handles.checkbox_AdaptiveBeamFormer,'Value')
    s = [s get(handles.checkbox_AdaptiveBeamFormer,'String')];
end
if 1 == get(handles.checkbox_NoiseReduction,'Value')
    s = [s get(handles.checkbox_NoiseReduction,'String')];
end
if 1 == get(handles.checkbox_NoiseReduction,'Value')
    s = [s get(handles.checkbox_NoiseReduction,'String')];
end
if 1 == get(handles.checkbox_ASRLeveler,'Value')
    s = [s get(handles.checkbox_ASRLeveler,'String')];
end
if 1 == get(handles.checkbox_ASRLimiter,'Value')
    s = [s get(handles.checkbox_ASRLimiter,'String')];
end
if 1 == get(handles.checkbox_CallLeveler,'Value')
    s = [s get(handles.checkbox_CallLeveler,'String')];
end
if 1 == get(handles.checkbox_Expander,'Value')
    s = [s get(handles.checkbox_Expander,'String')];
end
if 1 == get(handles.checkbox_CallEq,'Value')
    s = [s get(handles.checkbox_CallEq,'String')];
end
if 1 == get(handles.checkbox_CallLimiter,'Value')
    s = [s get(handles.checkbox_CallLimiter,'String')];
end
if 1 == get(handles.checkbox_MicOut,'Value')
    s = [s get(handles.checkbox_MicOut,'String')];
end

% --- Executes on button press in checkbox_DumpAll.
function checkbox_DumpAll_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_DumpAll (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% get the dump-all check box value
DumpAll_Value = get(handles.checkbox_DumpAll,'Value');
% set all checkboxes to this value
set(handles.checkbox_MicIn,'Value',DumpAll_Value);
set(handles.checkbox_MicRef,'Value',DumpAll_Value);
set(handles.checkbox_MicInput,'Value',DumpAll_Value);
set(handles.checkbox_DCBlock,'Value',DumpAll_Value);
set(handles.checkbox_AEC,'Value',DumpAll_Value);
set(handles.checkbox_FixedBeamFormer,'Value',DumpAll_Value);
set(handles.checkbox_GlobalEq,'Value',DumpAll_Value);
set(handles.checkbox_SpectralBeamSteering,'Value',DumpAll_Value);
set(handles.checkbox_AdaptiveBeamFormer,'Value',DumpAll_Value);
set(handles.checkbox_NoiseReduction,'Value',DumpAll_Value);
set(handles.checkbox_NoiseReduction,'Value',DumpAll_Value);
set(handles.checkbox_ASRLeveler,'Value',DumpAll_Value);
set(handles.checkbox_ASRLimiter,'Value',DumpAll_Value);
set(handles.checkbox_CallLeveler,'Value',DumpAll_Value);
set(handles.checkbox_Expander,'Value',DumpAll_Value);
set(handles.checkbox_CallEq,'Value',DumpAll_Value);
set(handles.checkbox_CallLimiter,'Value',DumpAll_Value);
set(handles.checkbox_MicOut,'Value',DumpAll_Value);
