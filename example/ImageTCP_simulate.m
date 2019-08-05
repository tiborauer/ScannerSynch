DIR = 'C:\_RT\rtData\NF_PSC\NF_Run_1';
fnList = cellstr(spm_select('FPList',DIR,'001_000007_.*'))';
da = cellfun(@(x) dir(x), fnList);
fsList = [da.bytes];
imgSize = numel(dicomread(fnList{1}))*2;

%%
tcp = TCPClass(5677);
tcp.Connect('localhost');

%%
for fn = 1:numel(fnList)
    fid = fopen(fnList{fn});
    dat = uint8(fread(fid));
    fclose(fid);
    hdrSize = fsList(fn) - imgSize;
    tcp.SendData(uint32(hdrSize),'intel');
    tcp.SendData(uint32(imgSize),'intel');
    tcp.SendData(dat(1:hdrSize));
    tcp.SendData(dat(hdrSize+1:end));
end

%%
tcp.CloseConnection

%%
clear classes