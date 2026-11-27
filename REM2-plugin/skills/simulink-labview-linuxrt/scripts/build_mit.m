function soFiles = build_mit(models, opts)
%BUILD_MIT Build Simulink models as NI Model Interface Toolkit (MIT) shared
%   libraries (.so) for NI Linux Real-Time x64 (e.g. PXIe-8840).
%
%   build_mit(models)                         full build, .so files in the current folder
%   build_mit(models, OutputDir=dir)          build in dir; the .so files land there
%   build_mit(models, GenCodeOnly=true)       generate code only, no cross-compile
%   build_mit(models, SystemTargetFile=stf)   other NI system target file
%   soFiles = build_mit(...)                  full paths of the built .so files
%
%   models: model names, e.g. ["noise_gen", "signal_filter"]. Each model and the
%   files its MATLAB Function blocks call (e.g. *_core.m) must be in OutputDir or
%   on the MATLAB path.
%
%   Prerequisites on the Windows host:
%     - NI VeriStand Model Framework 2020 (ships with MIT / VeriStand).
%       Run addpath('C:\VeriStand'); NIVeriStandAddPaths once per MATLAB session.
%       MF 2020 has one target, VeriStand.tlc; the OS is picked by the toolchain.
%     - C & C++ Development Tools for NI Linux Real-Time 2017 (registry key
%       gccToolchain\17.0). Without it MF does not register the Linux64
%       toolchain, and only a code-generation-only run works.
%     - MATLAB R2025b: the MF 2020 patches in scripts/patches (MF 2020 supports up to
%       R2020a; R2020b to R2025a are unverified).
%
%   Each model is built from a temporary copy of its active configuration set
%   switched to the given target. The copy is removed afterwards, also on
%   error, so the model's own settings (and any unsaved edits) stay as they were.

arguments
    models (1,:) string {mustBeNonempty}
    opts.OutputDir (1,1) string {mustBeFolder} = pwd
    opts.SystemTargetFile (1,:) char = 'VeriStand.tlc'
    opts.GenCodeOnly (1,1) logical = false
end
stf = opts.SystemTargetFile;

% Custom targets (NI) are found on the MATLAB path, built-in ones under matlabroot/rtw/c.
if isempty(which(stf)) && ~isfile(fullfile(matlabroot, 'rtw', 'c', erase(stf, '.tlc'), stf))
    error('build_mit:noTlc', ['%s not found. Install the NI VeriStand Model Framework ' ...
        'and addpath the folder that holds it.'], stf);
end

outDir = char(opts.OutputDir);
oldDir = cd(outDir);                 % build folders and the .so files are created here
restoreDir = onCleanup(@() cd(oldDir));
outDir = pwd;                        % absolute path

for mdl = models
    if exist(mdl, 'file') ~= 4
        error('build_mit:noModel', '%s.slx is not in %s or on the MATLAB path.', mdl, outDir);
    end
    % A loaded model wins over the file on disk, so a same-named copy from another folder would be built.
    localFile = fullfile(outDir, mdl + ".slx");
    if bdIsLoaded(mdl) && isfile(localFile) && ~strcmpi(get_param(mdl, 'FileName'), localFile)
        error('build_mit:otherCopyLoaded', '%s is loaded from %s, not %s. Close it first: close_system(''%s'')', ...
            mdl, get_param(mdl, 'FileName'), localFile, mdl);
    end
end

soFiles = strings(0, 1);
for mdl = models
    buildOne(char(mdl), stf, opts.GenCodeOnly);
    if ~opts.GenCodeOnly
        so = fullfile(outDir, mdl + ".so");
        if ~isfile(so)
            error('build_mit:noSo', 'The build of %s finished but %s was not created.', mdl, so);
        end
        soFiles(end+1, 1) = so; %#ok<AGROW>
    end
end
end

%--------------------------------------------------------------------------
function buildOne(mdl, stf, genCodeOnly)
wasLoaded = bdIsLoaded(mdl);
if ~wasLoaded, load_system(mdl); end
wasDirty = get_param(mdl, 'Dirty');

csOrig = getActiveConfigSet(mdl);
csMit  = copy(csOrig);
csMit.Name = 'MIT_LinuxRT';
attachConfigSet(mdl, csMit, true);               % true: rename if the name is taken
restoreMdl = onCleanup(@() restoreModel(mdl, csOrig.Name, csMit.Name, wasLoaded, wasDirty)); % runs on exit or error
setActiveConfigSet(mdl, csMit.Name);
switchTarget(csMit, stf, []);                    % runs the target's own setup callback
% With NoDefaultCurrentDirectoryInExePath set (e.g. MATLAB started by Claude Code), cmd does not
% find "<model>.bat" by bare name, so Simulink's make step fails. Then generate code only and
% run the batch file by explicit path below.
runBatByPath = ~genCodeOnly && ~isempty(getenv('NoDefaultCurrentDirectoryInExePath'));
set_param(csMit, 'StopTime', 'inf', 'GenCodeOnly', char(matlab.lang.OnOffSwitchState(genCodeOnly || runBatByPath)));
% Linux 64 word sizes (long = 64 bit); a Windows 64 setting fails the rtwtypes size check on the target.
set_param(csMit, 'ProdHWDeviceType', 'Intel->x86-64 (Linux 64)');

tc = 'VeriStand Compiler for Linux64 targets | gmake makefile (64-bit Linux)';
try
    set_param(csMit, 'Toolchain', tc);
catch ME
    if ~genCodeOnly
        error('build_mit:noToolchain', ['"%s" is not registered. Install the C & C++ ' ...
            'Development Tools for NI Linux Real-Time 2017, then run NIVeriStandAddPaths.\n%s'], tc, ME.message);
    end
    warning('build_mit:noToolchain', 'Linux64 toolchain not registered; generating code with "%s".', ...
        get_param(csMit, 'Toolchain'));
end
set_param(csMit, 'BuildConfiguration', 'Faster Runs');   % -O2; the default 'Faster Builds' is -O0

slbuild(mdl);

if runBatByPath
    buildDir = RTW.getBuildDir(mdl).BuildDirectory;
    status = system(sprintf('cd /d "%s" && .\\%s.bat', buildDir, mdl), '-echo');
    if status ~= 0
        error('build_mit:makeFailed', 'make failed for %s (exit %d). See the compiler output above.', mdl, status);
    end
end
end

%--------------------------------------------------------------------------
function restoreModel(mdl, origName, mitName, wasLoaded, wasDirty)
% Reactivate the original configuration set and drop the temporary copy.
setActiveConfigSet(mdl, origName);
detachConfigSet(mdl, mitName);
if ~wasLoaded
    close_system(mdl, 0);
elseif strcmp(wasDirty, 'off')
    set_param(mdl, 'Dirty', 'off');              % content equals the saved file again
end
end
