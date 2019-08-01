%%
port = 5677;
nScan = 20;

tcp = ImageTCPClass(port);
data.watch = 'C:\RT\rt';
data.LastName = 'Test';
data.ID = 'RHUL';
data.FirstFileName = '001_000003_000001.dcm';
tcp.setHeaderFromDICOM(data);
tcp.WaitForConnection;
% tcp.Quiet = true;

for n = 1:nScan
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

tcp.Close;

%%
save run e hdr img