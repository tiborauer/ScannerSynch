%%
port = 5677;
nScan = 20;
TR = 2;

% ScannerSynch
SSO = ScannerSynchClass(0,0);
SSO.SetSynchReadoutTime(0.5);
SSO.TR = TR;

% RTExport - Direct
tcp = ImageTCPClass(port);
data.watch = 'C:\RT\rt';
data.LastName = 'Test';
data.ID = 'RHUL';
data.FirstFileName = '001_000004_000001.dcm';
tcp.setHeaderFromDICOM(data);
tcp.WaitForConnection;
% tcp.Quiet = true;
tcp.ReceiveInitial;

% RTExport - Siemens
DIR = fullfile(data.watch,sprintf('%s.%s.%s',datestr(date,'yyyymmdd'),data.LastName,data.ID));

e = zeros(3,nScan);
indDirectFinished = 0;
indSiemensFinished = 0;

while (indDirectFinished < nScan) || (indSiemensFinished < nScan)
    
    % Scanner Pulse
    if ~SSO.SynchCount
        SSO.WaitForSynch;
        isPulse = true;
    else
        isPulse = SSO.CheckSynch(0.01);
    end
    if isPulse
        e(1,SSO.SynchCount) = SSO.TimeOfLastPulse;
        tcp.Log(sprintf('INFO: Pulse #%d',SSO.SynchCount))
    end
    
    % RTExport - Direct
    if tcp.Open && tcp.BytesAvailable
        indDirectFinished = indDirectFinished + 1;
        [direct_hdr{indDirectFinished}, direct_img{indDirectFinished}] = tcp.ReceiveScan;
        e(2,indDirectFinished) = SSO.Clock;
        tcp.Log(sprintf('INFO: Direct #%d',indDirectFinished))
        if indDirectFinished == nScan, tcp.Close; end
    end

    % RTExport - Siemens
    if ~e(3,indSiemensFinished+1)
        nextAvail = dir(fullfile(DIR,strrep(data.FirstFileName,'000001',sprintf('%06d',indSiemensFinished+1))));
        if ~isempty(nextAvail)
            indSiemensFinished = indSiemensFinished+1;
            [siemens_img{indSiemensFinished}, siemens_hdr{indSiemensFinished}] = dicom_read(fullfile(DIR,nextAvail.name));
            e(3,indSiemensFinished) = SSO.Clock;
            tcp.Log(sprintf('INFO: Export #%d\n',indSiemensFinished))
        end
    end

end

SSO.delete;