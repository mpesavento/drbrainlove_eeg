function osc_server_gui()
    handles = createGUI();
    osc = [];
    
    osc_port=2001;

    function h = createGUI()
        h.fig = figure('Menubar','none', 'Resize','off', ...
            'CloseRequestFcn',@onClose, ...
            'Name','OSC Server', 'Position',[100 100 400 250]);
        movegui(h.fig, 'center')
        h.start = uicontrol('Style','pushbutton', 'String','Start', ...
            'Callback',{@onClick,'start'}, ...
            'Parent',h.fig, 'Position',[20 20 80 20]);
        h.stop = uicontrol('Style','pushbutton', 'String','Stop', ...
            'Callback',{@onClick,'stop'}, ...
            'Parent',h.fig, 'Position',[120 20 80 20]);
        h.porttxt = uicontrol('Style','text', 'String','OSC server',...
            'Parent',h.fig, 'Position',[20 220 140 20]);
        h.txt = uicontrol('Style','edit', 'String','', ...
            'horizontalAlignment', 'left','Enable','off',...
            'max',2,'min',0,...
            'Parent',h.fig, 'Position',[20 50 360 150]);
        set(h.stop, 'Enable','off');
        drawnow expose

        h.timer = timer('TimerFcn',@receive, 'BusyMode','drop', ...
            'ExecutionMode','fixedRate', 'Period',0.11);
    end

    function onClick(~,~,action)
        switch lower(action)
            case 'start'
                set(handles.start, 'Enable','off')
                set(handles.stop, 'Enable','on')
                set(handles.porttxt, 'String',['listening on port ' num2str(osc_port)]);
                osc = osc_new_server(osc_port);
                start(handles.timer);
            case 'stop'
                set(handles.start, 'Enable','on')
                set(handles.stop, 'Enable','off')
                set(handles.porttxt,'String','');
                set(handles.txt,'String','');
                osc_free_server(osc); osc = [];
                stop(handles.timer);
        end
        drawnow expose
    end

    function receive(~,~)
        if isempty(osc), return; end
        m = osc_recv(osc, 0.1);
        if isempty(m), return; end
%         set(handles.txt, 'String',num2str(m{1}.data{1}))
        packet_str = sprintf('%0.2f ', [m{1}.data{:}]);
        set(handles.txt, 'String', sprintf('%s:[%i] %s',...
            m{1}.path, length([m{1}.data{:}]), packet_str ) )
        drawnow expose
    end

    function onClose(~,~)
        if ~isempty(osc)
            osc_free_server(osc);
        end
        stop(handles.timer); delete(handles.timer);
        delete(handles.fig);
        clear handles osc
    end
end

