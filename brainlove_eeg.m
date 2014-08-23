function varargout = brainlove_eeg(varargin)
% BRAINLOVE_EEG MATLAB code for brainlove_eeg.fig
%      BRAINLOVE_EEG, by itself, creates a new BRAINLOVE_EEG or raises the existing
%      singleton*.
%
%      H = BRAINLOVE_EEG returns the handle to a new BRAINLOVE_EEG or the handle to
%      the existing singleton*.
%
%      BRAINLOVE_EEG('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in BRAINLOVE_EEG.M with the given input arguments.
%
%      BRAINLOVE_EEG('Property','Value',...) creates a new BRAINLOVE_EEG or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before brainlove_eeg_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to brainlove_eeg_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help brainlove_eeg

% Last Modified by GUIDE v2.5 22-Aug-2014 16:21:47

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @brainlove_eeg_OpeningFcn, ...
    'gui_OutputFcn',  @brainlove_eeg_OutputFcn, ...
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


% --- Executes just before brainlove_eeg is made visible.
function brainlove_eeg_OpeningFcn(hObject, eventdata, handles, varargin) %#ok
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to brainlove_eeg (see VARARGIN)

% Choose default command line output for brainlove_eeg
handles.output = hObject;


%%% load BCILAB

% fig_names = get( get(0,'Children'),'name');
% name_match=strfind(upper( fig_names), 'BCILAB');
% if  ( iscell(name_match) && all(cellfun(@isempty, name_match)) ) || isempty(name_match)
if ~exist('env_startup.m','file')
    cd('C:\Users\mpesavento\src\BCILAB\');
    %     bcilab('menu',false); %start the gui
    bcilab; %start the gui
end


handles.chanloc_file = 'C:\Users\mpesavento\src\DrBrainlove_eeg\data\cognionics16ch.locs';
set(handles.edit_chanfile,'string',handles.chanloc_file,...
    'horizontalalignment','right');

hax = handles.axis_topo;
set(hax,'XTickLabel',[]);
set(hax,'YTickLabel',[]);

set(handles.panel_streamselect,'userdata', 2);
set(handles.panel_streamselect,'selectedobject',handles.radio_recordstream);

set(handles.btn_start, 'userdata',0);

set(handles.edit_updaterate,'string',num2str( 5 ));

% UIWAIT makes brainlove_eeg wait for user response (see UIRESUME)
% uiwait(handles.figure1);

% Update handles structure
guidata(hObject, handles);


% --- Outputs from this function are returned to the command line.
function varargout = brainlove_eeg_OutputFcn(hObject, eventdata, handles)  %#ok
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This is the main function, and will do all the loading and preprocessing
% once it is pushed. That will change the text and 'value' internally to
% tell if it is running, and stop the stream if we hit it again

% --- Executes on button press in btn_start.
function btn_start_Callback(hObject, eventdata, handles) %#ok
% hObject    handle to btn_start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

runstate = get(hObject,'userdata');

streamsource = get(handles.panel_streamselect,'userdata'); %default to recorded

if streamsource == 2
    datafile = get(handles.edit_dataset, 'string');
    if isempty(datafile) || strcmpi(datafile, 'load data')
        msgbox('No datafile selected, choose a file to run','No datafile selected')
        return;
    end
    if ~exist(datafile,'file')
        msgbox('Selected datafile doesn''t exist','File does not exist')
        return;
    end
end


if isempty(runstate) || runstate == 0 % want to start running
    set(hObject,'userdata',1,'string','Stop');

    deleter = onCleanup(@()onl_clear());
    
    drawnow;
%     refresh;


    %% load the conf

    conf.chunk_fs = str2double(get(handles.edit_updaterate,'string'));
    conf.data_fs = 100; %downsample from 300
    conf.bandpass = [ 5 6 45 47];

    %%% set up OSC
    osc_target.address = get(handles.edit_oscip,'string');
    ipmatch=regexp(osc_target.address,'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}');
    if isempty(ipmatch) || ipmatch~=1
        msgbox('Invalid IP address for OSC.','Invalid IP');
        return;
    end
    osc_target.port = str2double(get(handles.edit_oscport,'string'));
    osc_target.path = '/eeg16';
    conf.osc_target = osc_target;


    % define potential pipelines
    pipeline.fir_standard= {'resample',conf.data_fs,...
        'standardize',{},...
        'fir', conf.bandpass,...
        };
    pipeline.ica_noclean = {'resample',conf.data_fs,...
        'standardize',{},...
        'ica',{'Variant','fastica','DataCleaning','off'},...
        };
    target_pipe = 'fir_standard';


    conf.pipeline = pipeline;
    conf.target_pipe = target_pipe;

    %%% load cognionics channel locations
    if ~exist(handles.chanloc_file,'file')
        msgbox('Selected channel locations file doesn''t exist','File does not exist')
        return;
    end
    chanlocs_cogn = readlocs(handles.chanloc_file)';


    % we are about to start the streams, switch things around
    stateval = get(hObject,'userdata');
    if ~stateval %START the app
    else
    end
    set(handles.txt_status,'string','Starting the stream');

    %%% set up the streams
    switch streamsource
        case 1 %live stream from cognionics

            run_readlsl('MatlabStream','mystream','DataStreamQuery','type=''EEG''',...
                'MarkerStreamQuery',[], 'BufferLength', 60,'ChannelOverride',chanlocs_cogn);
            nchan_target=16;

            fprintf('collecting calib data\n');
            set(handles.txt_status, 'Collecting calibration data, wait 60 sec');
            pause(60); %collect calib data
            fprintf('moving on\n');
            set(handles.txt_status, 'Calibrated.');

        case 2 %load prerecorded data
            set(handles.txt_status,'String', 'Loading dataset...');

            calibdata = exp_eval(io_loadset(datafile,'infer_chanlocs',false));
            if length(calibdata.chanlocs)~=length(chanlocs_cogn) && length(calibdata.chanlocs)~=length(chanlocs_cogn)+5
                % use embedded chanlocs
                nchan_target = length(calibdata.chanlocs);
            else
                %use cognionics channels, want 16 or 21
                nchan_target=length(chanlocs_cogn);
                if length(calibdata.chanlocs) ~= nchan_target
                    calibdata = exp_eval(flt_selchans(calibdata, 1:nchan_target));
                end
                calibdata.chanlocs = chanlocs_cogn;
            end
            if all(isempty([calibdata.chanlocs.theta]))
                calibdata = set_infer_chanlocs(calibdata);
            end
            run_readdataset('mystream', calibdata, conf.chunk_fs, 30);
    end

    %% extract data and apply filters
    calibEEG = onl_peek('mystream', 60, 'seconds');

    %create new filter pipeline from calibration data
    tmp = flt_pipeline(calibEEG, conf.pipeline.(conf.target_pipe){:});
    %(if no stream is given, it considers anything in MATLAB workspace)
    mypipe = onl_newpipeline( tmp, 'mystream');



    conf.maxlim=0;
    conf.minlim=9999999;
    conf.c_map = hot(128);

    conf.h_topo = handles.axis_topo;
    conf.h_fps = handles.txt_fps;

    conf.oscconn = osc_new_address(osc_target.address, osc_target.port);
    conf.msg_formatter = @(D) num2cell(single(D(:)));

    conf.cc=0; %call count

    recurz; %initialize z-transform

    fprintf('Running stream...\n');
    set(handles.txt_status, 'String','Running stream');

    while 1
        [chunk, mypipe] = onl_filtered(mypipe); %extract anything that was appended since last call
        conf.cc=conf.cc+1;
        if all(size(chunk.data)~= 0 )
            process_chunk(chunk, conf);
        end
        
        if get(hObject,'userdata')==0
            set(handles.txt_status,'string','Stopped.');
%             onl_clear();
            break;
        end

    end

    
    
else %runstate == 1, running already
    
    set(hObject,'userdata',0,'string','Start');
    set(handles.txt_status,'string','Attempting to stop');


end %runstate









%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%





% --- Executes on button press in btn_loadrecord.
function btn_loadrecord_Callback(hObject, eventdata, handles) %#ok
% hObject    handle to btn_loadrecord (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

[locpath, ~, ~] = fileparts(mfilename('fullpath'));
cd(fullfile(locpath,'data'));
[datafile, datapath] = uigetfile('*.*','Load EEG data');

if datafile==0 %canceled out
    set(handles.txt_status, 'string','no data file selected');
    set(handles.edit_dataset,'string','',...
        'horizontalalignment','left');
else
    set(handles.edit_dataset,'string',fullfile(datapath,datafile),...
        'horizontalalignment','right');
    set(handles.txt_status, 'string','Set eeg data file');
end

% --- Executes on button press in btn_loadchan.
function btn_loadchan_Callback(hObject, eventdata, handles)%#ok
% hObject    handle to btn_loadchan (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

[locpath, ~, ~] = fileparts(mfilename('fullpath'));
cd(fullfile(locpath,'data'));

[datafile, datapath] = uigetfile('*.*','Load channel location data');

if datafile==0 %canceled out
    set(handles.txt_status, 'string','no data file selected');
    set(handles.edit_dataset,'string','',...
        'horizontalalignment','left');
else
    handles.chanloc_file = fullfile(datapath,datafile);
    set(handles.edit_dataset,'string',handles.chanloc_file,...
        'horizontalalignment','right');
    set(handles.txt_status, 'string','Set channel loc file');
    
end
% Update handles structure
guidata(hObject, handles);


function edit_oscip_Callback(hObject, eventdata, handles) %#ok
% hObject    handle to edit_oscip (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_oscip as text
%        str2double(get(hObject,'String')) returns contents of edit_oscip as a double


% --- Executes during object creation, after setting all properties.
function edit_oscip_CreateFcn(hObject, eventdata, handles) %#ok
% hObject    handle to edit_oscip (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_oscport_Callback(hObject, eventdata, handles) %#ok
% hObject    handle to edit_oscport (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_oscport as text
%        str2double(get(hObject,'String')) returns contents of edit_oscport as a double


% --- Executes during object creation, after setting all properties.
function edit_oscport_CreateFcn(hObject, eventdata, handles) %#ok
% hObject    handle to edit_oscport (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_dataset_Callback(hObject, eventdata, handles) %#ok
% hObject    handle to edit_dataset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_dataset as text
%        str2double(get(hObject,'String')) returns contents of edit_dataset as a double


% --- Executes during object creation, after setting all properties.
function edit_dataset_CreateFcn(hObject, eventdata, handles) %#ok
% hObject    handle to edit_dataset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function edit_updaterate_Callback(hObject, eventdata, handles) %#ok
% hObject    handle to edit_updaterate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_updaterate as text
%        str2double(get(hObject,'String')) returns contents of edit_updaterate as a double


% --- Executes during object creation, after setting all properties.
function edit_updaterate_CreateFcn(hObject, eventdata, handles) %#ok
% hObject    handle to edit_updaterate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes when selected object is changed in panel_streamselect.
function panel_streamselect_SelectionChangeFcn(hObject, eventdata, handles) %#ok
% hObject    handle to the selected object in panel_streamselect
% eventdata  structure with the following fields (see UIBUTTONGROUP)
%	EventName: string 'SelectionChanged' (read only)
%	OldValue: handle of the previously selected object or empty if none was selected
%	NewValue: handle of the currently selected object
% handles    structure with handles and user data (see GUIDATA)

newButton=get(eventdata.NewValue,'tag');
switch newButton
    case 'radio_livestream'
        set(handles.txt_status,'string','Selected live stream');
        set(hObject,'userdata',1);
    case 'radio_recordstream'
        set(handles.txt_status,'string','Selected recorded stream');
        set(hObject,'userdata',2)
end



function edit_chanfile_Callback(hObject, eventdata, handles)
% hObject    handle to edit_chanfile (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_chanfile as text
%        str2double(get(hObject,'String')) returns contents of edit_chanfile as a double


% --- Executes during object creation, after setting all properties.
function edit_chanfile_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_chanfile (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
