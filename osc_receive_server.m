% test script to receieve local OSC data

receive_port = 2001;
s = osc_new_server(receive_port);

deleter = onCleanup(@()osc_free_server(s));

fprintf('OSC server started on port %i\n',receive_port);
while 1
    m = osc_recv(s, 2); 
    
    if ~isempty(m)
        fprintf('%i packets received\n',length(m));
        fprintf('1: %s\n', m{1}.path);
        m{1}.data
    end
    
end
        