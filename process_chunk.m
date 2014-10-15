function process_chunk(chunk, conf)
% given a eeglab style struct, process that chunk

if isempty(chunk.chanlocs(1).theta)
    chunk.chanlocs = conf.chanlocs;
end

mean_data = mean(chunk.data,2);
activity = std(chunk.data,[],2); %look at RMS? activity by channel

powerest = sum(chunk.data.^2, 2); %should z-transform this
powerest = recurz(powerest);

% if isfield(chunk,'icawinv')
%     
% end

plotarray=double(activity);
% plotarray=double(powerest);

axes(conf.h_topo);
cla;


conf.maxlim = max(plotarray(:));
conf.minlim = min([min(plotarray(:)), conf.minlim]);

% [ml, maxhist] = find_optimmax(plotarray, ml, maxhist);
% maxlim=ml;
% minlim=0;
% maxlim = max([max(plotarray(:)), maxlim]);
% Get the data range for scaling the map colors.
% symmetric_maplimits = [ -max(maxlim, -minlim) max(maxlim, -minlim)];
% maxlim=30;
maplimits = [ conf.minlim, conf.maxlim];


% [h_surf, mapout, xmesh, ymesh] = topoplot(plotarray, chunk.chanlocs,...
%     'maplimits', maplimits, 'electrodes', 'on', 'style', 'both', 'colormap',c_map,...
%     'gridscale', 32);

datmask = cellfun(@isempty, {chunk.chanlocs.X});
plotarray=plotarray(~datmask);

update='...';
fps_str = sprintf('%0.1f fps %s', conf.data_fs/size(chunk.data, 2), update(1:mod(conf.cc,3)+1) );

colormap(conf.c_map);

mapout = plot_topo_fast(chunk.chanlocs, plotarray,...
    'gridscale', 32,'style','surf','colormap',conf.c_map); %'e5lectrodes', 'on',);


set(conf.h_fps, 'horizontal','left','string', fps_str );

% vis_artifacts(testdata_bci);

mapout = (mapout -conf.minlim)./(conf.maxlim-conf.minlim); % normalize to 1
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
msg = struct('path',conf.osc_target.path, 'data', { conf.msg_formatter(packet) } );

if osc_send(conf.oscconn,msg) == 0
    error('OSC transmission failed.');
end

