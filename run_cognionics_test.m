%%%
% test cognionics live

% dbstop if error

% should only need to do this if functions aren't on the path
fig_names = get( get(0,'Children'),'name');
name_match=strfind(upper( fig_names), 'BCILAB');
a = findobj(get(0,'Children'),'name','BCILAB');
if  ( iscell(name_match) && all(cellfun(@isempty, name_match)) ) || isempty(name_match)
    cd('C:\Users\mpesavento\src\BCILAB\');
    bcilab('menu',false); %start the gui
end
deleter = onCleanup(@()onl_clear());

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

datapath = 'C:\Users\mpesavento\src\BCILAB\userdata\cognionics16ch_matt';
chanlocfile = 'cognionics16ch.locs';

runlive = 0; 

target_Fs=100; %samples/sec
chunk_Fs=5; % updates/sec



if runlive
    %start the LSL reader and read any EEG stream on network, don't wait for a
    %marker stream to show up, and wait until we have accumulated enough calib
    %data
    chanlocs_cogn = readlocs(fullfile(datapath, chanlocfile))';

%     run_readlsl('MatlabStream','mystream','DataStreamQuery','type=''EEG''',...
%         'MarkerStreamQuery',[], 'BufferLength', 60);
    run_readlsl('MatlabStream','mystream','DataStreamQuery','type=''EEG''',...
        'MarkerStreamQuery',[], 'BufferLength', 60,'ChannelOverride',chanlocs_cogn);
    nchan_target=16;
    
    fprintf('collecting calib data\n');
    pause(60); %collect calib data
    fprintf('moving on\n');

else
    
%     filename = 'data:/tutorial/imag_movements1/calib/DanielS001R01.dat';
    filename = 'data:/cognionics16ch_matt/matt test 8 7 14.vhdr';

    chanlocs_cogn = readlocs(fullfile(datapath, chanlocfile))';
    
%     calibdata = exp_eval(io_loadset(filename));
    calibdata = exp_eval(io_loadset(filename,'infer_chanlocs',false));
%     calibdata = set_infer_chanlocs(calibdata);
    
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
        %the input file doesnt have channel data, load it from our file
%         calibdata.chanlocs = chanlocs_cogn;
%         calibdata.data = calibdata.data(1:nchan_target,:); %trim data to 16

        %infer channel locations if we don't know
        calibdata = set_infer_chanlocs(calibdata);
    end

    run_readdataset('mystream', calibdata, chunk_Fs, 30);
    
end



%% create pipeline

freqlim = [0.5 3; 4 7; 8 12; 13 30; 31 42]; % delta, theta, alpha, beta, gamma

%%% target filters
% flt_resample %, to 100 Hz
% flt_clean_settings, 'ArtifactRegression',true
% flt_ica('Signal',eeg, 'Variant',{'infomax' 'MaxIterations',512})
% flt_standardize %, standardize continuous eeg set causally
% flt_fir, [2 3 44 46] %, may not need to do this
% flt_analytic_phasor %, get freq components
% flt_fourier
% flt_fourier_bandpower 'filtering',{'representation','power'},'bands',{[ 4
% 7],[8 12],[12 18],[18 30],[ 30 50]}

% %projections!
% flt_sourceLocalize % localize sources for given head model, uses LORETA
% flt_srcproj % project data through inverse weighs

bandpass = [ 5 6 45 47];

pipeline.phasor = {'resample',target_Fs,...
    'clean_settings',{},...
    'ica',{'Variant','infomax'},...
    'standardize',{},...
    'fir', bandpass,...
    'analytic_phasor',{'DiffFilter',{'hilbert','FrequencyBand',bandpass },...
        'OverrideOriginal',false,'IncludeAnalyticAmplitude',true},...
    'fourier',{'Representation','power','Normalized',true,'LogTransform',true},...
    };
pipeline.cleanfirica = {'resample',target_Fs,...
    'clean_settings',{},...
    'ica',{'Variant','infomax'},...
    'standardize',{},...
    'fir', bandpass,...
    };
pipeline.clean = {'resample',target_Fs,...
    'clean_settings',{},...
    'standardize',{},...
    };

pipeline.firica = {'resample',target_Fs,...
    'ica',{'Variant','robust_sphere',''},...
    'standardize',{},...
    'fir', bandpass,...
    };
pipeline.fir= {'resample',target_Fs,...
    'fir', bandpass,...
    };
pipeline.fir_chansel = {'resample',target_Fs,...
    'fir', bandpass,...
    'selchans',{1:nchan_target,'dataset-order',true},... 
    };

pipeline.firstandard= {'resample',target_Fs,...
    'standardize',{},...
    'fir', bandpass,...
    };

% pipeline.ica_noclean = {'resample',target_Fs,...
%     'selchans',1:nchan_target,... %{1:16,'dataset-order'},... 
%     'standardize',{},...
%     'ica',{'Variant','fastica','DataCleaning','off'},...
%     };
pipeline.ica_noclean = {'resample',target_Fs,...
    'standardize',{},...
    'ica',{'Variant','fastica','DataCleaning','off'},...
    };

pipeline.ica_drycap = {'resample',target_Fs,...
    'ica',{'Variant','robust_sphere','DataCleaning','drycap'},...
    };

    
target_pipe = 'firstandard';
    

%% extract data and apply filters
calibEEG = onl_peek('mystream', 60, 'seconds'); 

%create new filter pipeline from calibration data
tmp = flt_pipeline(calibEEG, pipeline.(target_pipe){:});

%(if no stream is given, it considers anything in MATLAB workspace)
mypipe = onl_newpipeline( tmp, 'mystream');

%%
topofreqs = [4, 10, 20, 30];

osc_target.address = '127.0.0.1';
% osc_target.address = '192.168.1.198';
% osc_target.address = '10.1.3.187';
osc_target.port = 2001;
osc_target.path = '/eeg16';


%% run the analysis



maxlim=0;
minlim=9999999;

figure(102);
h_topof = axes;
txt_refreshrate = uicontrol('style','text','String','','units','normalized',...
    'Position',[0.785 0.03 0.19 0.03]);

% ryb = flipud(cbrewer('div','RdYlBu',128));
% colormap(ryb);
% c_map = ryb;
c_map = hot(128);
colormap(c_map);


oscconn = osc_new_address(osc_target.address, osc_target.port);
% oscconn = udp(osc_target.address, osc_target.port);
% if isempty(oscconn)
%     error('failed making OSC address');
% end
% fopen(oscconn); %open the OSC socket

msg_formatter = @(D) num2cell(single(D(:)));


cc=0;
maxhist=[];
ml=0;
update='...';



recurz; %initialize z-transform

fprintf('Running...\n');
while 1 %&& cc<1000

    [chunk, mypipe] = onl_filtered(mypipe); %extract anything that was appended since last call
    cc=cc+1;
    
    if all(size(chunk.data)~= 0 )
        mean_data = mean(chunk.data,2);
        activity = std(chunk.data,[],2); %look at RMS? activity by channel
        
        powerest = sum(chunk.data.^2, 2); %should z-transform this
        powerest = recurz(powerest);
        
        if isfield(chunk,'icawinv')
            
        end

        plotarray=double(activity);
%         plotarray=double(powerest);
        
        axes(h_topof);
        cla;

%         [ml, maxhist] = find_optimmax(plotarray, ml, maxhist);
%         maxlim=ml;
%         minlim=0;
%         maxlim = max([max(plotarray(:)), maxlim]);
        maxlim = max(plotarray(:));
        minlim = min([min(plotarray(:)), minlim]);
        % Get the data range for scaling the map colors.
%             symmetric_maplimits = [ -max(maxlim, -minlim) max(maxlim, -minlim)];
%             maxlim=30;
        maplimits = [ minlim, maxlim];

        
%         [h_surf, mapout, xmesh, ymesh] = topoplot(plotarray, chunk.chanlocs,...
%             'maplimits', maplimits, 'electrodes', 'on', 'style', 'both', 'colormap',c_map,...
%             'gridscale', 32);

        chanX = [chunk.chanlocs.X];
        chanY = [chunk.chanlocs.Y];
        datmask = cellfun(@isempty, {chunk.chanlocs.X});
        chanlabels = {chunk.chanlocs.labels};
        chanlabels = chanlabels(~datmask);
        plotarray=plotarray(~datmask);

        fps_str = sprintf('%0.1f fps %s', target_Fs/size(chunk.data, 2), update(1:mod(cc,3)+1) );
        
        mapout = plot_topo_fast(chunk.chanlocs, plotarray,...
            'gridscale', 32,'style','surfiso'); %'e5lectrodes', 'on','colormap',c_map,);
    
        
%         if plot_topo
%             h_c=cbar('vert', 0, maplimits);
%         end
        set(txt_refreshrate, 'horizontal','left','string', sprintf('%0.1f fps %s', target_Fs/size(chunk.data, 2), update(1:mod(cc,3)+1) ) );
    
    %     vis_artifacts(testdata_bci);


        mapout = mapout./maxlim; % normalize to 1
        mapout(mapout>1) = 1;
        mapout = mapout(2:end-1, 2:end-1);
        mapout(isnan(mapout)) = -1;

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % send over osc
        packet = mapout(:);
        if length(packet)>=1024
            warning('osc packet exceeds maximum length, trimming to 1023');
            packet=packet(1:1023);
        end
        msg = struct('path',osc_target.path, 'data', { msg_formatter(packet) } );

        if osc_send(oscconn,msg) == 0
            error('OSC transmission failed.'); 
        end
        
    else
%         fprintf('.'); %print something if we are missing frames
    end

%     pause(0.01)

end

