function [img, hdr] = dicom_read(img_file,hdr)
if nargin < 2, hdr = dicom_hdr(img_file); end

% mosaic = [];
% while isempty(mosaic)
%     try mosaic = double(dicomread(img_file)); catch; mosaic = []; end
% end
mosaic = double(dicomread(img_file));


nm = ceil(sqrt(hdr.Dimensions(3)));
for s = 1:hdr.Dimensions(3)
    nx = rem(s-1,nm)+1;
    ny = ceil(s/nm);
    %     fprintf('Slice %d: X = %d, Y = %d\n',s,nx,ny)
    img(:,:,s) = rot90(mosaic((ny-1)*hdr.Dimensions(2)+1:ny*hdr.Dimensions(2),...
        (nx-1)*hdr.Dimensions(1)+1:nx*hdr.Dimensions(1)),-1);
end
end

function hdr = dicom_hdr(img_file)
MinimalDicomDictionary = struct(...
    'group',[2 24 32 32 40 40 40 40 40 41 32736],...
    'element',[16 136 50 55 48 16 17 258 259 4112 16],...
    'values',struct(...
        'name',{'TransferSyntaxUID' 'SpacingBetweenSlices' 'ImagePositionPatient' 'ImageOrientationPatient' 'PixelSpacing' 'Rows' 'Columns' 'HighBit' 'PixelRepresentation' 'CSAImageHeaderInfo' 'PixelData'},...
        'vr',{{'UI'} {'DS'} {'DS'} {'DS'} {'DS'} {'US'} {'US'} {'US'} {'US'} {'OB'} {'OW' 'OB'} },...
        'vm',{'1' '1' '3' '6' '2' '1' '1' '1' '1' '1' '1'}...
        )...
    );
hdr = spm_dicom_header(img_file,MinimalDicomDictionary,struct('abort',false, 'all_fields',false));
CSA = hdr.CSAImageHeaderInfo;

mat = reshape(cellfun(@(x) str2double(x),regexp(CSA(cellfun(@(x) contains(x,'AcquisitionMatrixText'), {CSA.name})).item(1).val,'[0-9]*[0-9]*','match')),1,[]);
nSl = str2double(CSA(cellfun(@(x) contains(x,'NumberOfImagesInMosaic'), {CSA.name})).item(1).val);

hdr.Dimensions = [mat nSl];
hdr.PixelDimensions = [hdr.PixelSpacing(:)' hdr.SpacingBetweenSlices];

analyze_to_dicom = [diag([1 -1 1]) [0 (mat(2)-1) 0]'; 0 0 0 1]*[eye(4,3) [-1 -1 -1 1]'];

vox    = hdr.PixelDimensions';
pos    = hdr.ImagePositionPatient(:);
orient = reshape(hdr.ImageOrientationPatient,[3 2]);
orient(:,3) = null(orient');
if det(orient)<0, orient(:,3) = -orient(:,3); end

dicom_to_patient = [orient*diag(vox) pos ; 0 0 0 1];
truepos          = dicom_to_patient *[([hdr.Columns hdr.Rows]-mat)/2 0 1]';
dicom_to_patient = [orient*diag(vox) truepos(1:3) ; 0 0 0 1];
patient_to_tal   = diag([-1 -1 1 1]);
mat              = patient_to_tal*dicom_to_patient*analyze_to_dicom;

% Maybe flip the image depending on SliceNormalVector from 0029,1010
%-------------------------------------------------------------------
SliceNormalVector = str2num([CSA(cellfun(@(x) contains(x,'SliceNormalVector'), {CSA.name})).item.val]);
if det([reshape(hdr.ImageOrientationPatient,[3 2]) SliceNormalVector(:)])<0
    mat    = mat*[eye(3) [0 0 -(dim(3)-1)]'; 0 0 0 1];
end
hdr.mat = mat;
end

