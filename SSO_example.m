%% Initialise
SSO = ScannerSynchClass;
% SSO = ScannerSynchClass(1);   % emulate scanner synch pulse
% SSO = ScannerSynchClass(0,1); % emulate button box
% SSO = ScannerSynchClass(1,1); % emulate scanner synch pulse and button box

%% Example for scanner synch pulse #1: - Simple case
SSO.SetSynchReadoutTime(0.5);
SSO.TR = 2;                % allows detecting missing pulses
SSO.ResetSynchCount;
while SSO.SynchCount < 10  % polls 10 pulses
    SSO.WaitForSynch;
    fprintf('Pulse %d: %2.3f. Measured TR = %2.3fs\n',...
        SSO.SynchCount,...
        SSO.TimeOfLastPulse,...
        SSO.MeasuredTR);
end

%% Example for scanner synch pulse #2 - Chance for missing pulse
SSO.SetSynchReadoutTime(0.5);
SSO.TR = 2;        % allows detecting missing pulses
SSO.ResetSynchCount;
while SSO.SynchCount < 10      % until 10 pulses
    WaitSecs(Randi(100)/1000); % in every 0-100 ms ...
    if SSO.CheckSynch(0.01)    % ... waits for 10 ms for a pulse
        fprintf('Pulse %d: %2.3f. Measured TR = %2.3fs. %d synch pulses has/have been missed\n',...
            SSO.SynchCount,...
            SSO.TimeOfLastPulse,...
            SSO.MeasuredTR,...
            SSO.MissedSynch);
    end
end

%% Example for buttons:
SSO.SetButtonReadoutTime(0.5);      % block individual buttons
% SSO.SetButtonBoxReadoutTime(0.5); % block the whole buttonbox
% SSO.Keys = {'f1','f2','f3','f4'}; % emulation Buttons #1-#4 with F1-F4
n = 0;
% SSO.BBoxTimeout = 1.5;            % Wait for button press for 1.5s
% SSO.BBoxTimeout = -1.5;           % Wait for button press for 1.5s even in case of response
SSO.ResetClock;
while n ~= 10                       % polls 10 button presses
    fprintf('Press a button!\n');
%     SSO.WaitForButtonPress;         % Wait for any button to be pressed
%     SSO.WaitForButtonRelease;       % Wait for any button to be released
%     SSO.WaitForButtonPress([],5); % Wait for Button #5
%     SSO.WaitForButtonPress(2);    % Wait for any button for 2s (overrides SSO.BBoxTimeout only for this event)
%     SSO.WaitForButtonPress(-2);   % Wait for any (number of) button(s) for 2s even in case of response (overrides SSO.BBoxTimeout only for this event)
%     SSO.WaitForButtonPress(2,5);  % Wait for Button #5 for 2s (overrides SSO.BBoxTimeout only for this event)
%     SSO.WaitForButtonPress(-2,5); % Wait for (any number of presses of) Button #5 for 2s even in case of response (overrides SSO.BBoxTimeout only for this event)
    n = n + 1;
    for b = 1:numel(SSO.ButtonPresses)
        fprintf('#%d Button %d ',b,SSO.ButtonPresses(b));
        fprintf('pressed at %2.3fs\n',SSO.TimeOfButtonPresses(b));
    end
    fprintf('Last: Button %d ',SSO.LastButtonPress);
    fprintf('pressed at %2.3fs\n\n',SSO.TimeOfLastButtonPress);
end

%% Close
SSO.delete;
