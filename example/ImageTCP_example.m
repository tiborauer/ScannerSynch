%% Configuration
port = 5677;
DIR = 'C:\_RT\rtData\NF_PSC\NF_Run_1';
fnList = cellstr(spm_select('FPList',DIR,'001_000007_.*'))';
[~,f,e] = fileparts(fnList{1}); firstFn = strcat(f,e);

%% TCP init
tcp = ImageTCPClass(port);
data.watch = DIR;
data.FirstFileName = firstFn;
tcp.setHeaderFromDICOM(data);
tcp.WaitForConnection;
% tcp.Quiet = true;

%% Run
for n = 1:numel(fnList)
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