%% Configuration
offline = true;

port = 5677;
DIR = 'C:\_RT\rtData\NF_PSC\NF_Run_1';

series = 7;

data.watch = DIR;
if offline
    fnList = cellstr(spm_select('FPList',DIR,sprintf('001_%06d_.*',series)))';
    [~,f,e] = fileparts(fnList{1});
    data.FirstFileName = strcat(f,e);
    nVol = numel(fnList);
else
    data.LastName = 'Test_Subject';
    data.ID = 'RHUL';
    data.FirstFileName = sprintf('001_%06d_000001.dcm',series);
    nVol = 10;
end

%% TCP init
tcp = ImageTCPClass(port);
tcp.setHeaderFromDICOM(data);
tcp.WaitForConnection;
% tcp.Quiet = true;

if ~offline, tcp.ReceiveInitial; end

%% Run
for n = 1:nVol
    fprintf('Scan #%03d\n',n);
    [hdr{n}, img{n}] = tcp.ReceiveScan;
    
    if n == 1
        t = tic;
        tcp.ResetClock;
    elseif n > 1
        e(n-1) = toc(t);
    end
    
    if ~tcp.Open, break; end
end

%% Save and cleanup
tcp.CloseConnection;
save run e hdr img
clear classes