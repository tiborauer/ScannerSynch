%% Configuration
DIR = 'C:\_RT\rtData\NF_PSC\NF_Run_1';
fnList = cellstr(spm_select('FPList',DIR,'001_000007_.*'))';
da = cellfun(@(x) dir(x), fnList);
fsList = [da.bytes];
imgSize = numel(dicomread(fnList{1}))*2;

%% TCP init
tcp = TCPClass(5677);
tcp.Connect('localhost');

%% Initial data
initialData = uint8(randi(255,1,1000));
tcp.SendData(uint32(numel(initialData)),'intel');
tcp.SendData(uint32(0),'intel');
tcp.SendData(initialData);

%% Run
for fn = 1:numel(fnList)
    fid = fopen(fnList{fn});
    dat = uint8(fread(fid));
    fclose(fid);
    hdrSize = fsList(fn) - imgSize;
    tcp.SendData(uint32(hdrSize),'intel');
    tcp.SendData(uint32(imgSize),'intel');
    tcp.SendData(dat);
end

%% Cleanup
tcp.CloseConnection
clear classes