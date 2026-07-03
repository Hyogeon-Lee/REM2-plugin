scriptPath = mfilename("fullpath");
scriptsDir = fileparts(scriptPath);
skillRoot = fileparts(scriptsDir);
addpath(scriptsDir);

examples = ["example_FRF1.xlsx", "example_FRF2.xlsx"];
exampleDir = fullfile(skillRoot, "examples");
validationRoot = fullfile(skillRoot, "validation_outputs");
if ~exist(validationRoot, "dir")
    mkdir(validationRoot);
end

validationResults = struct([]);
for idx = 1:numel(examples)
    excelFile = fullfile(exampleDir, examples(idx));
    [~, exampleName] = fileparts(excelFile);
    outputDir = fullfile(validationRoot, exampleName);

    result = run_frf_ms_workflow(char(excelFile), char(outputDir), ...
        MaxDenominatorOrder=6, ...
        SamplingFrequencyHz=1000);

    validationResults(idx).Example = examples(idx);
    validationResults(idx).OutputDir = outputDir;
    validationResults(idx).TargetCrossoverHz = result.DesignInfo.TargetCrossoverHz;
    validationResults(idx).ControllerStructure = result.DesignInfo.ControllerStructure;
    validationResults(idx).TimeDelaySeconds = result.FitInfo.TimeDelaySeconds;
    validationResults(idx).PhaseMarginDeg = result.DesignInfo.PhaseMarginDeg;
    validationResults(idx).GainMarginDb = result.DesignInfo.GainMarginDb;
    validationResults(idx).ClosedLoopStable = result.AnalysisInfo.ClosedLoopStable;
    validationResults(idx).SettlingTime = result.AnalysisInfo.StepInfo.SettlingTime;
    validationResults(idx).Overshoot = result.AnalysisInfo.StepInfo.Overshoot;
    validationResults(idx).FigurePngPath = result.PlotInfo.PngPath;

    fprintf("%s: target %.3f Hz, structure %s, delay %.4g s, PM %.2f deg, GM %.2f dB, stable %d, settling %.4g s, overshoot %.2f %%\n", ...
        examples(idx), ...
        validationResults(idx).TargetCrossoverHz, ...
        validationResults(idx).ControllerStructure, ...
        validationResults(idx).TimeDelaySeconds, ...
        validationResults(idx).PhaseMarginDeg, ...
        validationResults(idx).GainMarginDb, ...
        validationResults(idx).ClosedLoopStable, ...
        validationResults(idx).SettlingTime, ...
        validationResults(idx).Overshoot);
end

save(fullfile(validationRoot, "validation_results.mat"), "validationResults");
