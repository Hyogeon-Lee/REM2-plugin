function stableFlag = frf_closed_loop_stable(loopContinuous)
% 지연 루프 폐루프 안정성 판정 (design_lead_lag / run_frf_ms_workflow 공유 헬퍼)
% isstable 은 지연 폐루프(internal delay)에서 실패 -> allmargin 판정, Pade(8) 근사 fallback
% Pade fallback 패턴은 이 파일 한 곳에만 존재해야 함 (복제 금지)
try
    loopMargins = allmargin(loopContinuous);
    if isscalar(loopMargins) && isfinite(loopMargins.Stable)
        stableFlag = logical(loopMargins.Stable);
        return
    end
catch
end
try
    stableFlag = isstable(feedback(pade(minreal(loopContinuous, [], false), 8), 1));
catch
    stableFlag = false;
end
end
