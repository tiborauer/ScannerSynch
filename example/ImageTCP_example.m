%%
dbstop if error
initialHeader = 0;

tcp = ImageTCPClass(5677);

data.watch = 'D:\Temp\NFT\RT';
data.watch_portcommand = '';
data.LastName = '19910811IOSA';
data.ID = 'RH';
tcp.setHeaderFromDICOM(data);

tcp.WaitForConnection;
% tcp.Quiet = true;
for n = 1-initialHeader:101
    fprintf('Scan #%03d\n',n);
    [hdr{n+initialHeader}, img{n+initialHeader}] = tcp.ReceiveScan;

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
clear classes