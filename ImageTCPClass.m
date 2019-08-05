% TCP Interface for DICOM Direct RTExport
% Version 1.0
%
% DESCRIPTION
%   Methods
%       obj = ImageTCPClass(port, [switches])   Constructor. See obj = TCPClass(port, [switches]) for reference
%       setHeaderFromDICOM(data)        Header read from DICOM file received via the standard RTExport, when DICOM files appear in <watch> or <watch>/<date>.<LastName>.<ID>
%           data (structure)            Initialisation information
%               Obligatory fields
%                   watch               Main directory for incoming DICOM files
%               Optional field
%                   watchport_command   System command to open watchport
%                   LastName            Last name of the subject as specified during "Patient Registration" (in case <watch> is the common real-time folder)
%                   ID                  Patient ID of the subject as specified during "Patient Registration" (in case <watch> is the common real-time folder)
%                   FirstFileName       First DICOM file to read
%               
%       ReceiveInitial                  Reads initial header explicitely
%
%       [hdr, img] = ReceiveScan        Reads image and convert for analysis
%           hdr                         Header structure. 
%               Full DICOM header (only in case, when DICOM file as header source has been used.
%               AcquisitionMatrix       In-plane resolution
%               NumberOfImagesInMosaic  Number of slices
%               SliceNormalVector       Information required to calculate "mat"
%               SliceTimes              Acquisition time (within TR) of each slice
%               Dimensions              3D resolution (based on "AcquisitionMatrix" and "NumberOfImagesInMosaic")
%               PixelDimensions         Voxel size
%               mat                     Transformation matrix
%           img                         3D volume
%
% DEVELOPMENT ONLY
%   Private properties
%       Header                          Header stored for the whole session
%       HeaderComplete                  Indicator showing whether all information is available to construct the header
%       DICOMWatchDir                   Main directory for incoming DICOM files (for standard RTExport)
%       DICOMLastName                   Last name of the subject as specified during "Patient Registration" (for standard RTExport)
%       DICOMID                         Patient ID of the subject as specified during "Patient Registration" (for standard RTExport)
%   Private methods
%       [hdr, img] = ReceiveImageData
%   Util function (not part of the class)
%       val = getHeaderDataFromDump(dump,field,[multiple])  Retrieve information from header obtained via DICOM Direct RTExport
%       hdr = convertHeader(inf)                            Convert DICOM header to 'minimal' NIfTI header
%       ind = cell_index(dump,field)                        Give index of a string stored in a cell array
%
% ACKNOWLEDGEMENT
%   Some codes has been copied from spm_dicom_convert.m Id 6190 2014-09-23 16:10:50Z guillaume $
%       by John Ashburner & Jesper Andersson
%       Part of SPM by Wellcome Trust Centre for Neuroimaging
%
% REQUIREMENTS
%   TCPClass
%       by Tibor Auer (tibor.auer@mrc-cbu.cam.ac.uk)
%       Part of this package
%   spm_dicom_headers.m Id 5250 2013-02-15 21:04:36Z john $
%       by John Ashburner
%       Part of SPM by Wellcome Trust Centre for Neuroimaging
%       Download: http://www.fil.ion.ucl.ac.uk/spm/software/download.html
%   TCP/UDP/IP Toolbox 2.0.6
%       by Peter Rydesäter (Peter@Rydesater.se)
%       Download: http://uk.mathworks.com/matlabcentral/fileexchange/345-tcp-udp-ip-toolbox-2-0-6
%_______________________________________________________________________
% Copyright (C) 2015 MRC CBSU Cambridge
%
% Tibor Auer: tibor.auer@mrc-cbu.cam.ac.uk
%_______________________________________________________________________

classdef ImageTCPClass < TCPClass
    properties (Access=private)
        Header = struct()
        
        DICOMWatchDir
        DICOMLastName
        DICOMID
        DICOMFirstFileName
    end
    properties (Access=private, Dependent=true)
        HeaderComplete
    end
    
    methods
        function obj = ImageTCPClass(varargin)
            obj = obj@TCPClass(varargin{:});
        end
        
        function setHeaderFromDICOM(obj,data)
            obj.DICOMWatchDir = data.watch;
            if isfield(data,'watchport_command') && ~isempty(data.watchport_command), system(data.watchport_command); end
            if isfield(data,'LastName') && ~isempty(data.LastName), obj.DICOMLastName = data.LastName; end
            if isfield(data,'ID') && ~isempty(data.ID), obj.DICOMID = data.ID; end
            if isfield(data,'FirstFileName') && ~isempty(data.FirstFileName), obj.DICOMFirstFileName = data.FirstFileName; end
        end
        
        function ReceiveInitial(obj)
            dump = '';
            while isempty(dump) && obj.Open
                dump = obj.ReceiveImageData;
            end
            
            if isempty(obj.DICOMWatchDir), obj.parseIntroHeader; end
        end
        
        function [hdr, img] = ReceiveScan(obj)
            hdr = ''; img = [];
            mosaic = [];
            while isempty(mosaic) && obj.Open
                [dump, mosaic] = obj.ReceiveImageData;
            end
            
            % Parse header
            if ~obj.HeaderComplete
                % Read header from file
                if ~isempty(obj.DICOMWatchDir)
                    DIR = obj.DICOMWatchDir;
                    if ~isempty(obj.DICOMLastName) && ~isempty(obj.DICOMID), DIR = fullfile(DIR,sprintf('%s.%s.%s',datestr(date,'yyyymmdd'),obj.DICOMLastName,obj.DICOMID)); end
                    if ~isempty(obj.DICOMFirstFileName)
                        img_file = fullfile(DIR,obj.DICOMFirstFileName);
                        while isempty(dir(img_file)), end
                    else
                        while true
                            d = dir(fullfile(DIR,sprintf('*_*_%06d.dcm',1)));
                            if ~isempty(d)
                                dat = sscanf(d(1).name,'%03d_%06d_000001.dcm');
                                subject = dat(1);
                                session = dat(2);
                                break
                            end
                        end
                        img_file = fullfile(DIR,sprintf('%03d_%06d_%06d.dcm',subject,session,1));
                    end
                    d = dir(img_file);
                    while d.bytes < (180*1024) % 180kB header
                        d = dir(img_file);
                    end
                    inf = spm_dicom_headers(img_file);
                    obj.Header = inf{1};
                    CSA = obj.Header.CSAImageHeaderInfo;
                    val = str2double(regexp(CSA(cell_index({CSA.name},'AcquisitionMatrixText')).item(1).val,'[^0-9]','split'));
                    obj.Header.AcquisitionMatrix = val(~isnan(val))';
                    obj.Header.NumberOfImagesInMosaic = str2double(CSA(cell_index({CSA.name},'NumberOfImagesInMosaic')).item(1).val);
                    obj.Header.SliceNormalVector = str2num([CSA(cell_index({CSA.name},'SliceNormalVector')).item.val]);
                    obj.Header.SliceTimes = str2num([CSA(cell_index({CSA.name},'MosaicRefAcqTimes')).item.val]);
% TODO                    echospacing = 1/(str2num([CSA(cell_index({CSA.name},'BandwidthPerPixelPhaseEncode')).item.val]) * obj.Header.NumberOfPhaseEncodingSteps); % in s
                else
                    % Read header from Direct
                    if isempty(fieldnames(obj.Header)), obj.parseIntroHeader; end
                    if numel(fieldnames(obj.Header)) == 2, obj.parseHeader; end
                end
                if obj.HeaderComplete, obj.Header = convertHeader(obj.Header); end
            end
            
            % Header
            hdr = obj.Header;
            
            % Image
            if ~isempty(mosaic) && obj.HeaderComplete
                mosaic = reshape(mosaic,[hdr.Columns hdr.Rows])';
                nm = ceil(sqrt(hdr.Dimensions(3)));
                for s = 1:hdr.Dimensions(3)
                    nx = rem(s-1,nm)+1;
                    ny = ceil(s/nm);
                    img(:,:,s) = rot90(mosaic((ny-1)*hdr.Dimensions(2)+1:ny*hdr.Dimensions(2),...
                        (nx-1)*hdr.Dimensions(1)+1:nx*hdr.Dimensions(1)),-1);
                end
            end
        end
        
        function val = get.HeaderComplete(obj)
            reqFields = {...
                'AcquisitionMatrix'...
                'NumberOfImagesInMosaic'...
                'PixelSpacing'...
                'SpacingBetweenSlices'...
                'ImagePositionPatient'...
                'ImageOrientationPatient'...
                'Columns'...
                'Rows'...
                'SliceNormalVector'...
                };
            val = numel(intersect(fieldnames(obj.Header),reqFields)) == numel(reqFields);
        end
    end
    
    methods (Access=private)
        function [hdr, img] = ReceiveImageData(obj)
            hdr = ''; img = [];
            
            sHeader = obj.ReceiveData(1,'uint32','intel');
            sImg = obj.ReceiveData(1,'uint32','intel');
            
            obj.Log(sprintf('Header size = %d B',sHeader));
            obj.Log(sprintf('Image size  = %d B',sImg));
            
            if sHeader == 0 && sImg == 0
                obj.CloseConnection;
                if  ~obj.HeaderComplete % at the beginning --> reopen
                    obj.WaitForConnection
                end
                return
            end
            
            h = obj.ReceiveData(sHeader,'uint8');
            nl = [0 find(h == 10)];
            for i = 1:numel(nl)-1
                hdr{i} = char(h(nl(i)+1:nl(i+1)-1));
            end
            %t = textscan(obj.ReceiveData(sHeader,'char'),'%s','Delimiter','\n');
            %hdr = t{1};
            img = obj.ReceiveData(sImg/2,'uint16','intel');
        end
        
        function parseIntroHeader(obj,dump)
            t = [...
                getHeaderDataFromDump(dump,'ParamLong."NImageLins"'); ...
                getHeaderDataFromDump(dump,'ParamLong."NImageCols"') ...
                ];
            if ~any(isnan(t)), obj.Header.AcquisitionMatrix = t; end
            t = [...
                getHeaderDataFromDump(dump,'ParamDouble."RoFOV"');...
                getHeaderDataFromDump(dump,'ParamDouble."PeFOV"') ...
                ];
            if ~any(isnan(t)), obj.Header.PixelSpacing= t./obj.Header.AcquisitionMatrix; end % 2x1 [3; 3]
        end
        
        function parseHeader(obj,dump)
            t = getHeaderDataFromDump(dump,'DICOM.ImagesInMosaic');
            if ~any(isnan(t)), obj.Header.NumberOfImagesInMosaic = round(t); end
            t = getHeaderDataFromDump(dump,'DICOM.SpacingBetweenSlices');
            if ~any(isnan(t)), obj.Header.SpacingBetweenSlices = getHeaderDataFromDump(dump,'DICOM.SpacingBetweenSlices'); end
% TODO                obj.Header.ImagePositionPatient = []; % 3x1
            t = [...
                getHeaderDataFromDump(dump,'RowVec.dSag'); ...
                getHeaderDataFromDump(dump,'RowVec.dCor'); ...
                getHeaderDataFromDump(dump,'RowVec.dTra'); ...
                getHeaderDataFromDump(dump,'ColumnVec.dSag'); ...
                getHeaderDataFromDump(dump,'ColumnVec.dCor'); ...
                getHeaderDataFromDump(dump,'ColumnVec.dTra') ...
                ];
            if ~any(isnan(t)), obj.Header.ImageOrientationPatien = t; end
            t = getHeaderDataFromDump(dump,'DICOM.NoOfCols');
            if ~any(isnan(t)), obj.Header.Columns = round(t); end
            t = getHeaderDataFromDump(dump,'DICOM.NoOfRows');
            if ~any(isnan(t)), obj.Header.Rows = round(t); end
            t = getHeaderDataFromDump(dump,'DICOM.SlcNormVector',true);
            if ~any(isnan(t)), obj.Header.SliceNormalVector = t; end
            t = getHeaderDataFromDump(dump,'DICOM.MosaicRefAcqTimes',true);
            if ~any(isnan(t)), obj.Header.SliceTimes = t; end
        end        
        
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%% UTILS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function val = getHeaderDataFromDump(dump,field,multiple)
ind = cell_index(dump,field);
if isempty(ind)
    val(1) = NaN;
    return;
end
if nargin < 3 || ~multiple, ind = ind(1); end

field0 = field;
for l = 1:numel(ind)
    if numel(ind) > 1, field = sprintf('%s.%d',field0,l-1); 
    else, field = field0; end
    t = textscan(dump{ind(l)},[field ' = %f']); dat = t{1};
    if isempty(dat), t = textscan(dump{ind(l)},['<' field '>  { %f  }']); dat = t{1}; end % intro header v1"
    if isempty(dat), t = textscan(dump{ind(l)},['<' field '>  { <Precision> 16  %f  }']); dat = t{1}; end % intro header v2"
    if ~isempty(dat), val(l) = dat;
    else, val(l) = NaN; end
end
end

function hdr = convertHeader(inf)
%   Based on spm_dicom_convert Id 6190 2014-09-23 16:10:50Z guillaume $
%       by John Ashburner & Jesper Andersson
%       Part of SPM by Wellcome Trust Centre for Neuroimaging
hdr = inf;

% Resolution
% -------------------------------------------------------------------------
hdr.Dimensions = [inf.AcquisitionMatrix' inf.NumberOfImagesInMosaic];
hdr.PixelDimensions = [inf.PixelSpacing(:)' inf.SpacingBetweenSlices];

% Transformation matrix
% -------------------------------------------------------------------------
analyze_to_dicom = [diag([1 -1 1]) [0 (inf.AcquisitionMatrix(2)-1) 0]'; 0 0 0 1]*[eye(4,3) [-1 -1 -1 1]'];

vox    = hdr.PixelDimensions';
pos    = inf.ImagePositionPatient(:);
orient = reshape(inf.ImageOrientationPatient,[3 2]);
orient(:,3) = null(orient');
if det(orient)<0, orient(:,3) = -orient(:,3); end
dicom_to_patient = [orient*diag(vox) pos ; 0 0 0 1];
truepos          = dicom_to_patient *[([inf.Columns inf.Rows]-inf.AcquisitionMatrix')/2 0 1]';
dicom_to_patient = [orient*diag(vox) truepos(1:3) ; 0 0 0 1];

patient_to_tal   = diag([-1 -1 1 1]);

mat              = patient_to_tal*dicom_to_patient*analyze_to_dicom;

% Flip depending on SliceNormalVector
if det([reshape(inf.ImageOrientationPatient,[3 2]) inf.SliceNormalVector(:)])<0
    mat    = mat*[eye(3) [0 0 -(dim(3)-1)]'; 0 0 0 1];
end
hdr.mat = mat;
end

function ind = cell_index(dump,field)
ind = find(cellfun(@(x) strcmpi(x,field), dump));
end
