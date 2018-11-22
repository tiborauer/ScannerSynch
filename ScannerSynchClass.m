% Interface for National Instruments PCI 6503 card
% Version 3.2
%
% DESCRIPTION
%
% N.B.: It does not monitor pulses in the background, so you have to make sure that you wait for any pulse before it comes!
%
% Properties (internal variables):
% 	IsValid						= device set and operational
% 	TR 							= set a non-zero value (in seconds) for	emulation mode (will not detect "real" pulses)
%   Keys                        = set a cell of key names for emulation mode. For key names look for KbName.m.
%                                   N.B.: Requires PTB.
%                                   N.B.: Suppress passing keypresses to MATLAB during the whole experiment
%
% 	Clock						= interal clock (seconds past since the first scanner pulse or clock reset)
% 	Synch						= current state of the scanner synch pulse
% 	TimeOfLastPulse				= time (according to the internal clock) of the last pulse 
%   MeasuredTR                  = estimated TR
% 	SynchCount					= number of scanner synch pulses
%   MissedSynch                 = number of missed scanner synch pulses
%
%   EmulSynch                   = is scanner synch pulse emulated 
%   EmulButtons                 = is button box emulated
%
% 	Buttons						= current state of the any button
%   ButtonPresses               = index/indices of each button(s) pressed since last check
%   TimeOfButtonPresses         = time (according to the internal clock) of each button(s) pressed since last check
% 	LastButtonPress				= index/indices of the last button(s) pressed
% 	TimeOfLastButtonPress		= time (according to the internal clock) of the last button press (any) 
%   BBoxTimeout                 = set a non-Inf value (in seconds) to wait for button press only for a limited time
%                               = set a negative value (in seconds) to wait even in case of response
%   isInverted                  = is the pulse inverted (0 when signal and 1 when no signal)
%
% Methods (internal functions):
% 	ScannerSynchClass			= constructor
% 	delete						= destructor
%	ResetClock					= reset internal clock
%
% 	ResetSynchCount				= reset scanner synch pulse counter
%	SetSynchReadoutTime(t)		= blocks scanner synch pulse readout after a pulse for 't' seconds
%	WaitForSynch				= wait until a scanner synch pulse arrives
%   CheckSynch(t)               = wait for a scanner synch pulse for 't' seconds or unitl a scanner synch pulse arrives (whichever first) and returns whether a scanner synch pulse was detected
%
%	SetButtonReadoutTime(t) 	= blocks individual button readout after a button press for 't' seconds (detection of other buttons is still possible) 
%	SetButtonBoxReadoutTime(t)	= blocks the whole button box readout after a button press for 't' seconds (detection of other buttons is also not possible) 
%	WaitForButtonPress			= wait until a button is pressed
% 	WaitForButtonRelease		= wait until a button is released
%
% USAGE
%
% Initialise:
% 	SSO = ScannerSynchClass;
% 	% SSO = ScannerSynchClass(1);   % emulate scanner synch pulse
% 	% SSO = ScannerSynchClass(0,1); % emulate button box
% 	% SSO = ScannerSynchClass(1,1); % emulate scanner synch pulse and button box
%
% Close:
% 	SSO.delete;
%
% Example for scanner synch pulse #1: - Simple case
% 	SSO.SetSynchReadoutTime(0.5);
% 	SSO.TR = 2;                % allows detecting missing pulses
%	while SSO.SynchCount < 10  % polls 10 pulses
%   	SSO.WaitForSynch;
%   	fprintf('Pulse %d: %2.3f. Measured TR = %2.3fs\n',...
%           SSO.SynchCount,...
%           SSO.TimeOfLastPulse,...
%           SSO.MeasuredTR);
%	end
%
% Example for scanner synch pulse #2 - Chance for missing pulse
% 	SSO.SetSynchReadoutTime(0.5);
% 	SSO.TR = 2;                    % allows detecting missing pulses
%	while SSO.SynchCount < 10      % until 10 pulses
%       WaitSecs(Randi(100)/1000); % in every 0-100 ms ...
%   	if SSO.CheckSynch(0.01)    % ... waits for 10 ms for a pulse
%       	fprintf('Pulse %d: %2.3f. Measured TR = %2.3fs. %d synch pulses has/have been missed\n',...
%               SSO.SynchCount,...
%               SSO.TimeOfLastPulse,...
%               SSO.MeasuredTR,...
%               SSO.MissedSynch);
%       end
%	end
%
% Example for buttons:
% 	SSO.SetButtonReadoutTime(0.5);      % block individual buttons
%	% SSO.SetButtonBoxReadoutTime(0.5); % block the whole buttonbox
%   % SSO.Keys = {'f1','f2','f3','f4'}; % emulation Buttons #1-#4 with F1-F4
%	n = 0;
%   % SSO.BBoxTimeout = 1.5;            % Wait for button press for 1.5s
%   % SSO.BBoxTimeout = -1.5;           % Wait for button press for 1.5s even in case of response
%	SSO.ResetClock;
%	while n ~= 10                       % polls 10 button presses
%   	SSO.WaitForButtonPress;         % Wait for any button to be pressed
%   	% SSO.WaitForButtonRelease;       % Wait for any button to be released
%       % SSO.WaitForButtonPress([],5); % Wait for Button #5
%       % SSO.WaitForButtonPress(2);    % Wait for any button for 2s (overrides SSO.BBoxTimeout only for this event)
%       % SSO.WaitForButtonPress(-2);   % Wait for any (number of) button(s) for 2s even in case of response (overrides SSO.BBoxTimeout only for this event)
%       % SSO.WaitForButtonPress(2,5);  % Wait for Button #5 for 2s (overrides SSO.BBoxTimeout only for this event)
%       % SSO.WaitForButtonPress(-2,5); % Wait for (any number of presses of) Button #5 for 2s even in case of response (overrides SSO.BBoxTimeout only for this event)
%    	n = n + 1;
%       for b = 1:numel(SSO.ButtonPresses)
%           fprintf('#%d Button %d ',b,SSO.ButtonPresses(b));
%           fprintf('pressed at %2.3fs\n',SSO.TimeOfButtonPresses(b));
%       end
%       fprintf('Last: Button %d ',SSO.LastButtonPress);
%       fprintf('pressed at %2.3fs\n\n',SSO.TimeOfLastButtonPress);
%	end
%_______________________________________________________________________
% Copyright (C) 2018 RHUL Psychology, Egham
%
% Tibor Auer: tibor.auer@rhul.ac.uk
%_______________________________________________________________________

classdef ScannerSynchClass < handle
    
    properties (Constant = true, Access = private)
        buttList_LT = [1 2 4 8] % Lumitouch Photon Control (1 hand, 4 buttons)
        buttList_NATA = [3 7 11 15 19 23 27 31 35 39]; % NATA (2 hands, 10 buttons)
    end
    
    properties
        TR = 0 % emulated pulse frequency
        PulseWidth = 0.005 % emulated pulse width 

        Keys = {}
        BBoxTimeout = Inf % second (timeout for WaitForButtonPress)
        isInverted = false
    end
   
    properties (SetAccess = private)
        SynchCount = 0
        MissedSynch = 0
        
        ButtonPresses
        TimeOfButtonPresses
        
        LastButtonPress
        
        EmulSynch
        EmulButtons
    end
   
    properties (Access = private)        
        DAQ
        nChannels
        
        tID % internal timer
        
        Data % current data
        Datap % previous data
        TOA % time of access 1*n
        TOAp % previous time of access 1*n
        ReadoutTime = 0 % sec to store data before refresh 1*n
        BBoxReadout = false
        BBoxWaitForRealease = false % wait for release instead of press
        
        isDAQ
        isPTB
    end
    
    properties (Dependent)
        IsValid

        Clock
        
        Synch
        TimeOfLastPulse
        MeasuredTR
        
        Buttons
        TimeOfLastButtonPress
    end
    
    methods

        %% Contructor and destructor
        function obj = ScannerSynchClass(emulSynch,emulButtons)
            fprintf('Initialising Scanner Synch...');
            % test environment
            obj.isDAQ = true;
            try 
                D = daq.getDevices; D = D(strcmp({D.ID},'Dev1'));
                if isempty(D) || ...
                        ~D.isvalid ||...
                        ~any(strcmp({D.Vendor.ID},'ni')) ||...
                        ~D.Vendor.isvalid ||...
                        ~D.Vendor.IsOperational, ...
                        obj.isDAQ = false; 
                end % no NI card or not working
            catch E
                warning('\nWARNING: %s',E.message)
                obj.isDAQ = false; % no DA Toolbox
            end
            
            % Create session
            if ((nargin<2) || ~emulSynch || ~emulButtons) && obj.isDAQ
                warning off daq:Session:onDemandOnlyChannelsAdded
                obj.DAQ = daq.createSession('ni');
                % Add channels for scanner pulse
                obj.DAQ.addDigitalChannel('Dev1', 'port0/line0', 'InputOnly'); % manual
                obj.DAQ.addDigitalChannel('Dev1', 'port0/line1', 'InputOnly'); % scanner
                % Add channels for Lumitouch
                obj.DAQ.addDigitalChannel('Dev1', 'port0/line2', 'InputOnly');
                obj.DAQ.addDigitalChannel('Dev1', 'port0/line3', 'InputOnly');
                obj.DAQ.addDigitalChannel('Dev1', 'port0/line4', 'InputOnly');
                obj.DAQ.addDigitalChannel('Dev1', 'port0/line5', 'InputOnly');
                % Add channels for NATA
                obj.DAQ.addDigitalChannel('Dev1', 'port1/line0', 'InputOnly');
                obj.DAQ.addDigitalChannel('Dev1', 'port1/line1', 'InputOnly');
                obj.DAQ.addDigitalChannel('Dev1', 'port1/line2', 'InputOnly');
                obj.DAQ.addDigitalChannel('Dev1', 'port1/line3', 'InputOnly');
                obj.DAQ.addDigitalChannel('Dev1', 'port1/line4', 'InputOnly');
                obj.DAQ.addDigitalChannel('Dev1', 'port1/line5', 'InputOnly');
                
                switch nargin
                    case 2
                        obj.EmulSynch = emulSynch;
                        obj.EmulButtons = emulButtons;
                    case 1
                        obj.EmulSynch = emulSynch;
                        obj.EmulButtons = false;
                    case 0
                        obj.EmulSynch = false;
                        obj.EmulButtons = false;
                end
            else
                obj.isDAQ = false;
                obj.DAQ.isvalid = true;
                obj.DAQ.Vendor.isvalid = true;
                obj.DAQ.Vendor.IsOperational = true;
                obj.EmulSynch = true;
                obj.EmulButtons = true;
                
                obj.DAQ.Channels = 1:(1 + numel(obj.buttList_LT) + numel(obj.buttList_LT));
                fprintf('\n');
                fprintf('WARNING: DAQ card is not in use!\n');
            end
            
            obj.isPTB = exist('KbCheck','file') == 2;
            
            if ~obj.IsValid
                warning('WARNING: Scanner Synch is not open!');
                obj.delete;
                return
            end
            
            if obj.EmulSynch
                fprintf('Emulation: Scanner synch pulse is not in use --> ');
                fprintf('You may need to set TR!\n');
            end
            if obj.EmulButtons
                fprintf('Emulation: ButtonBox is not in use           --> ');
                fprintf('You may need to set Keys!\n');
            end

            obj.nChannels = 1 + numel(obj.buttList_LT) + numel(obj.buttList_NATA);
            
            obj.Data = zeros(1,obj.nChannels);
            obj.Datap = zeros(1,obj.nChannels);
            obj.ReadoutTime = obj.ReadoutTime * ones(1,obj.nChannels);
            obj.ResetClock;
            fprintf('Done\n');
        end
        
        function delete(obj)
            fprintf('Scanner Synch is closing...');
            if obj.isDAQ
                obj.DAQ.release();
                delete(obj.DAQ);
                warning on daq:Session:onDemandOnlyChannelsAdded
            end                        
            if obj.isPTB, ListenChar(0); end
            fprintf('Done\n');
        end
        
        %% Utils
        function val = get.IsValid(obj)
            val = ~isempty(obj.DAQ) &&...
                obj.DAQ.isvalid &&...
                obj.DAQ.Vendor.isvalid &&...
                obj.DAQ.Vendor.IsOperational &&...
                (~obj.EmulButtons || (obj.EmulButtons && obj.isPTB));
        end
        
        function ResetClock(obj)
            obj.tID = tic;
            obj.TOA = zeros(1,obj.nChannels);
            obj.TOAp = zeros(1,obj.nChannels);
        end
        
        function val = get.Clock(obj)
            val = toc(obj.tID);
        end
        
        function set.Keys(obj,val)
            obj.Keys = val;
            if obj.EmulButtons && obj.isPTB, ListenChar(2); end % suppress passing keypresses to MATLAB
        end
        
        %% Scanner Pulse
        function ResetSynchCount(obj)
            obj.SynchCount = 0;
        end
        
        function SetSynchReadoutTime(obj,t)
            obj.ReadoutTime(1) = t;
        end
        
        function WaitForSynch(obj)
            while ~obj.Synch
            end
            obj.NewSynch;
        end
        
        function val = CheckSynch(obj,timeout)
            SynchQuery = obj.Clock;
            
            val = false;
            
            while (obj.Clock - SynchQuery) < timeout
                if obj.Synch
                    obj.NewSynch;
                    val = true;
                    break;
                end
            end
        end
        
        function val = get.TimeOfLastPulse(obj)
            val = obj.TOA(1);
        end
        
        function val = get.MeasuredTR(obj)
            val = (obj.TOA(1)-obj.TOAp(1))/(obj.MissedSynch+1);
        end
        
        %% Buttons
        function SetButtonReadoutTime(obj,t)
            obj.ReadoutTime(2:end) = t;
            obj.BBoxReadout = false;
        end
        
        function SetButtonBoxReadoutTime(obj,t)
            obj.ReadoutTime(2:end) = t;
            obj.BBoxReadout = true;
        end
        
        function WaitForButtonPress(obj,timeout,ind)
            BBoxQuery = obj.Clock;
            
            % Reset indicator
            obj.ButtonPresses = [];
            obj.TimeOfButtonPresses = [];
            obj.LastButtonPress = [];
            
            % timeout
            if (nargin < 2 || isempty(timeout)), timeout = obj.BBoxTimeout; end
            wait = timeout < 0; % wait until timeout even in case of response
            timeout = abs(timeout);
                       
            while (~obj.Buttons ||... % button pressed
                    wait || ...
                    (nargin >= 3 && ~isempty(ind) && ~any(obj.LastButtonPress == ind))) && ... % correct button pressed
                    (obj.Clock - BBoxQuery) < timeout % timeout
                if ~isempty(obj.LastButtonPress)
                    if nargin >= 3 && ~isempty(ind) && ~any(obj.LastButtonPress == ind), continue; end % incorrect button
                    if ~isempty(obj.TimeOfButtonPresses) && (obj.TimeOfButtonPresses(end) == obj.TimeOfLastButtonPress), continue; end % same event
                    obj.ButtonPresses = horzcat(obj.ButtonPresses,obj.LastButtonPress); 
                    obj.TimeOfButtonPresses = horzcat(obj.TimeOfButtonPresses,ones(1,numel(obj.LastButtonPress))*obj.TimeOfLastButtonPress);
                end                
            end            
        end
        
        function WaitForButtonRelease(obj,varargin)
            % backup settings
            rot = obj.ReadoutTime(2:end);
            bbro = obj.BBoxReadout;
            
            % config for release
            obj.BBoxWaitForRealease = true;            
            obj.SetButtonBoxReadoutTime(0);
            
            WaitForButtonPress(obj,varargin);
            
            % restore settings
            obj.BBoxWaitForRealease = false;
            obj.ReadoutTime(2:end) = rot;
            obj.BBoxReadout = bbro;
        end
        
        function val = get.TimeOfLastButtonPress(obj)
            val = max(obj.TOA(2:end)) * ~isempty(obj.LastButtonPress);
        end
        
        function [b, t] = ReadButton(obj)
            b = obj.LastButtonPress;
            t = obj.TimeOfLastButtonPress;
            obj.LastButtonPress = [];
            obj.ButtonPresses = [];
            obj.TimeOfButtonPresses = [];
        end
        
        %% Low level access
        function val = get.Synch(obj)
            val = 0;
            obj.Refresh;
            if obj.Data(1)
                obj.Data(1) = 0;
                val = 1;
            end
        end
        function val = get.Buttons(obj)
            val = 0;
            obj.Refresh;
            if obj.BBoxWaitForRealease
                if any(obj.Datap(2:end)) && all(~(obj.Data(2:end).*obj.Datap(2:end)))
                    obj.LastButtonPress = find(obj.Datap(2:end));
                    obj.Datap(2:end) = 0;
                    val = 1;
                end
            else
                if any(obj.Data(2:end))
                    obj.LastButtonPress = find(obj.Data(2:end));
                    obj.Data(2:end) = 0;
                    val = 1;
                end
            end
        end
    end
       
    methods (Access = private)
        function Refresh(obj)
            t = obj.Clock;
            
            % get data
            if obj.isDAQ 
                data = xor(obj.isInverted, inputSingleScan(obj.DAQ));
                data(1) = any(data(1:2)); data(2) = []; % combine manual and scanner
                data(3) = 0; % CAVE - Lumitouch: button two is not working
                if all(data([2 4 5])), data(2:5) = 0; end % CAVE - Lumitouch: random signal on all channels
%                 data(2:5) = 0; % TEMP: Lumitouch not connected
%                 data(6:11) = 0; % TEMP: NATA not connected
            else
                data = zeros(1,numel(obj.DAQ.Channels));
            end
            
%             if any(data), data, end
            data = [data(1) obj.buttList_LT == binvec2dec(data(2:5)) obj.buttList_NATA == binvec2dec(data(6:11))];
%             if any(data), data, end
            
            % scanner synch pulse emulation
            if obj.EmulSynch && obj.TR
                data(1) = ~obj.SynchCount || ((t-obj.TOA(1) >= obj.TR) && (mod(t-obj.TOA(1),obj.TR) <= obj.PulseWidth));
            end
            
            % button press emulation (keyboard) via PTB
            if obj.EmulButtons
                nKeys = numel(obj.Keys);
                if obj.isPTB && nKeys
                    [ ~, ~, keyCode ] = KbCheck;
                    data(2:2-1+nKeys) = keyCode(KbName(obj.Keys));
                end
            end
            if obj.BBoxReadout, obj.TOA(2:end) = max(obj.TOA(2:end)); end
            ind = obj.ReadoutTime < (t-obj.TOA);
            obj.Datap = obj.Data;
            obj.Data(ind) = data(ind);
            obj.TOAp = obj.TOA;
            obj.TOA(logical(obj.Data)) = t;
        end
        
        function NewSynch(obj)
            if ~obj.SynchCount
                obj.ResetClock;
                obj.SynchCount = 1;            
            else
                if obj.TR
                    obj.MissedSynch = 0;
                    obj.MissedSynch = round(obj.MeasuredTR/obj.TR)-1; 
                end
                obj.SynchCount = obj.SynchCount + 1 + obj.MissedSynch;
            end
        end
    end
end