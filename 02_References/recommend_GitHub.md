---
title: recommend_GitHub
type: reference
language: none
category: curation
author: REM2
year: 2026
status: stable
tags: [github, tools, ai-agent, matlab, robotics, document-conversion]
---

# 연구실 활용 GitHub Repository 모음

정밀생산메카트로닉스 연구실에서 전자기 해석, 모델링, 제어기 설계, 로보틱스, 문서 처리, AI 기반 연구 보조에 활용할 수 있는 GitHub repository를 정리한 문서입니다.

\---

## 1\. AI Agent 및 Claude Code Workflow

|Repository|설명|Link|
|-|-|-|
|Harness|프로젝트 설명을 바탕으로 Claude Code용 agent team과 skill 구조를 생성하는 meta-skill입니다. 복잡한 연구·개발 작업을 역할별 agent로 분해할 때 유용합니다.|[revfactory/harness](https://github.com/revfactory/harness)|
|oh-my-claudecode|Claude Code에서 multi-agent workflow를 구성하기 위한 도구입니다. 여러 agent가 협업하는 개발·문서화 흐름을 만들 때 참고할 수 있습니다.|[Yeachan-Heo/oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode)|
|codex-plugin-cc|Claude Code 안에서 Codex를 호출해 코드 리뷰나 작업 위임을 수행할 수 있게 해주는 plugin입니다. 코드 검토, 리팩터링, 보조 구현에 활용할 수 있습니다.|[openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc)|
|codegraph|코드베이스를 local knowledge graph로 색인해 AI coding agent가 코드를 이해하도록 돕는 도구입니다. 대형 연구 코드베이스 분석에 적합합니다.|[colbymchenry/codegraph](https://github.com/colbymchenry/codegraph)|
|andrej-karpathy-skills|LLM coding pitfall 관련 관찰을 바탕으로 Claude Code의 코딩 행동을 개선하는 skill 구성입니다. AI 코딩 품질 관리용 참고 자료로 사용할 수 있습니다.|[multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)|
|caveman|Claude Code 응답을 짧고 압축적으로 만들어 token 사용량을 줄이는 skill입니다. 반복적인 코딩 세션에서 context 소모를 줄이고 싶을 때 사용할 수 있습니다.|[JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)|

\---

## 2\. 연구·논문·과학 작업 보조 Skill

|Repository|설명|Link|
|-|-|-|
|academic-research-skills|연구, 작성, 검토, 수정, 최종화 흐름을 지원하는 Claude Code용 academic research skill 모음입니다. 논문 작성, literature review, 연구 문서 정리에 활용할 수 있습니다.|[Imbad0202/academic-research-skills](https://github.com/Imbad0202/academic-research-skills)|
|scientific-agent-skills|AI agent를 과학 연구 보조 도구로 사용하기 위한 skill library입니다. 과학 데이터베이스 연계와 연구 자동화 workflow를 참고할 수 있습니다.|[K-Dense-AI/scientific-agent-skills](https://github.com/K-Dense-AI/scientific-agent-skills)|
|k-skill|한국 사용자를 위한 Claude Code skill 모음입니다. 법령, 특허, 맞춤법, 국내 서비스 검색 등 한국어 기반 작업을 자동화할 때 유용합니다.|[NomaDamas/k-skill](https://github.com/NomaDamas/k-skill)|
|im-not-ai|AI가 작성한 것처럼 보이는 문장을 자연스럽게 다듬는 한국어 윤문 skill입니다. 보고서, 이메일, 발표문, 행정 문서의 문체를 정리할 때 활용할 수 있습니다.|[epoko77-ai/im-not-ai](https://github.com/epoko77-ai/im-not-ai)|

\---

## 3\. MATLAB 및 Simulink 기반 연구 개발

|Repository|설명|Link|
|-|-|-|
|MATLAB Agentic Toolkit|AI agent가 MATLAB 기능을 활용해 공학·과학 계산 workflow를 수행하도록 지원하는 toolkit입니다. 수치해석, 신호처리, 제어기 설계 작업과 연결하기 좋습니다.|[matlab/matlab-agentic-toolkit](https://github.com/matlab/matlab-agentic-toolkit)|
|Simulink Agentic Toolkit|AI agent가 Simulink와 Model-Based Design 작업을 수행할 수 있도록 도구와 지식을 제공하는 toolkit입니다. 제어기 모델링, 시스템 시뮬레이션, block diagram 기반 설계에 적합합니다.|[matlab/simulink-agentic-toolkit](https://github.com/matlab/simulink-agentic-toolkit)|
|MATLAB MCP Core Server|AI application에서 MATLAB을 실행할 수 있도록 지원하는 공식 MATLAB MCP server입니다. Claude Code, VS Code 등 coding agent와 MATLAB을 연결할 때 사용할 수 있습니다.|[matlab/matlab-mcp-core-server](https://github.com/matlab/matlab-mcp-core-server)|

\---

## 4\. 해석, 로보틱스, 메카트로닉스 개발

|Repository|설명|Link|
|-|-|-|
|PyAEDT|Ansys Electronics Desktop을 Python에서 제어하기 위한 client package입니다. Maxwell, HFSS 등 전자기 해석 자동화와 parametric study에 활용할 수 있습니다.|[ansys/pyaedt](https://github.com/ansys/pyaedt)|
|MoveIt 2|ROS 2 기반 motion planning framework입니다. 로봇 매니퓰레이터의 경로 계획, 충돌 회피, motion planning 연구에 사용할 수 있습니다.|[moveit/moveit2](https://github.com/moveit/moveit2)|

\---

## 5\. 문서 변환, 검색, 연구 자료 관리

|Repository|설명|Link|
|-|-|-|
|Docufinder|HWPX, PDF, Office 문서 본문을 local 환경에서 검색하는 도구입니다. 연구실 내부 문서, 과제 자료, 보고서 검색에 활용할 수 있습니다.|[chrisryugj/Docufinder](https://github.com/chrisryugj/Docufinder)|
|kordoc|HWP, HWPX, PDF, Office 문서를 Markdown으로 변환하고 MCP server와 연동할 수 있는 도구입니다. 한글 기반 행정 문서나 연구 문서를 AI workflow에 넣을 때 유용합니다.|[chrisryugj/kordoc](https://github.com/chrisryugj/kordoc)|
|MarkItDown|Office 문서와 다양한 파일을 Markdown으로 변환하는 Python tool입니다. 논문 자료, 실험 기록, 회의록, 매뉴얼을 Markdown 기반 workflow로 옮길 때 사용할 수 있습니다.|[microsoft/markitdown](https://github.com/microsoft/markitdown)|

\---

## 추천 활용 방식

|목적|추천 Repository|
|-|-|
|전자기 해석 자동화|[PyAEDT](https://github.com/ansys/pyaedt), [MATLAB Agentic Toolkit](https://github.com/matlab/matlab-agentic-toolkit), [MATLAB MCP Core Server](https://github.com/matlab/matlab-mcp-core-server)|
|제어기 및 시스템 모델링|[Simulink Agentic Toolkit](https://github.com/matlab/simulink-agentic-toolkit), [MATLAB Agentic Toolkit](https://github.com/matlab/matlab-agentic-toolkit)|
|로보틱스 및 motion planning|[MoveIt 2](https://github.com/moveit/moveit2)|
|AI 기반 코드 분석|[codegraph](https://github.com/colbymchenry/codegraph), [codex-plugin-cc](https://github.com/openai/codex-plugin-cc), [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)|
|연구 문서 작성 및 검토|[academic-research-skills](https://github.com/Imbad0202/academic-research-skills), [scientific-agent-skills](https://github.com/K-Dense-AI/scientific-agent-skills), [im-not-ai](https://github.com/epoko77-ai/im-not-ai)|
|한글 문서 처리 및 자료 검색|[kordoc](https://github.com/chrisryugj/kordoc), [Docufinder](https://github.com/chrisryugj/Docufinder), [MarkItDown](https://github.com/microsoft/markitdown), [k-skill](https://github.com/NomaDamas/k-skill)|
|Claude Code agent workflow 설계|[Harness](https://github.com/revfactory/harness), [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode), [caveman](https://github.com/JuliusBrussee/caveman)|

\---

## 비고

각 repository의 기능과 설치 방법은 업데이트될 수 있으므로, 실제 사용 전에는 각 GitHub page의 `README`, `license`, `issue`, 최근 commit 여부를 확인하는 것이 좋습니다.

