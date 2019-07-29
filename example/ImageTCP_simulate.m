DIR = 'D:\Temp\NFT\RT\20190729.19910811IOSA.RH';
fnList = cellstr(spm_select('FPList',DIR,'001_000006_.*'))';

d = dir(fnList{1}); 
fileSize = d.bytes;
imgSize = numel(dicomread(fnList{1}))*2;
hdrSize = fileSize-imgSize;

%%
tcp = TCPClass(5677);
tcp.Connect('localhost');

for fn = fnList
    fid = fopen(fn{1});
    dat = uint8(fread(fid));
    fclose(fid);
    tcp.SendData(uint32(hdrSize),'intel');
    tcp.SendData(uint32(imgSize),'intel');
    tcp.SendData(dat(1:hdrSize));
    tcp.SendData(dat(hdrSize+1:hdrSize+imgSize));
end

tcp.Close

%%
clear classes