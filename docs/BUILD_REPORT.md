# Agent Factory v0.1 구축 결과

완료 대상은 재사용 가능한 개발 자동화 시스템이다. 특정 앱의 제품 기능은 개발하지 않았다.
제공된 DOCX는 설계 참고 자료로 읽었고 원본을 보존했다.

## A. Environment

2026-09-19에 다시 확인한 로컬 실행 환경:

| 도구 | 버전 |
| --- | --- |
| Codex CLI | 0.147.0 |
| Git | 2.50.1.windows.1 |
| Node.js | 22.17.1 |
| npm | 10.9.2 |
| PowerShell | 7.6.6 |

처음에는 보고서만 있던 폴더였다. 로컬 Git 저장소를 main 브랜치로 초기화했다.
커밋·remote 설정·push·실제 PR 생성은 수행하지 않았다. 사용자 프로필과 전역 Codex 설정도 변경하지 않았다.

## B. Created Structure

아래는 생성된 주요 파일과 디렉터리이다. 실행 로그·설치된 의존성·테스트 산출물은 Git 제외 경로에 있다.

```text
agent factory/
├── AGENTS.md
├── README.md
├── VERSION
├── CHANGELOG.md
├── .gitignore / .gitattributes
├── .github/workflows/factory-ci.yml
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DECISIONS.md
│   ├── IMPLEMENTATION_PLAN.md
│   ├── COMMANDS.md
│   ├── GETTING_STARTED.md
│   ├── VERIFICATION.md
│   └── BUILD_REPORT.md
├── scripts/
│   ├── new-app.ps1
│   ├── agent.ps1
│   ├── common.ps1
│   ├── quality.ps1
│   ├── codex.ps1
│   ├── workflow.ps1
│   ├── state.ps1
│   └── profile.ps1
├── template/
│   ├── AGENTS.md / IDEA.md / CHANGELOG.md
│   ├── .codex/config.toml
│   ├── .codex/agents/{product,architect,ux,implementer,tester,reviewer,security,release}.toml
│   ├── docs/{PRD,ARCHITECTURE,UX,DECISIONS,QA}.md
│   ├── docs/{ROADMAP,STATUS}.json
│   ├── automation/{bootstrap,next-task,review,release}.md
│   ├── automation/prompts/  (8개 역할)
│   ├── automation/schemas/  (5개 응답 스키마)
│   └── .github/workflows/ci.yml
├── presets/
│   ├── react-web/         (preset.json, README, files/)
│   ├── react-capacitor/   (preset.json, README, files/)
│   ├── toss-miniapp/      (preset.json, README)
│   └── unity/             (preset.json, README)
└── tests/
    ├── self-test.ps1
    ├── README.md
    └── fixtures/{fake-codex,descendant-parent}.ps1
```

새 앱에는 `agent-factory.json`과 복사된 `automation/scripts/`도 생성된다.

## C. Implemented Features

- React Web·React + Capacitor 골격 생성, 파일 덮어쓰기 거부, 한글·공백 부모 경로 지원.
- IDEA에서 세 역할의 구조화된 출력을 받아 계획 문서 작성. 미작성 IDEA와 재초기화 차단.
- JSON ROADMAP의 의존성·우선순위·ID에 따른 결정적 작업 선택.
- next 한 번에 한 작업, 작업당 총 3회 이하 시도, run 최대 5작업, 실패 시 차단.
- 실제 lint/typecheck/test/build 종료 코드와 독립 tester/reviewer/security 리뷰를 모두 요구.
- 파일 지문에 연결한 승인·검증 근거, 오래된 결과 표시, 수동 수정 후 리뷰 갱신.
- 프로젝트 잠금, UTF-8 입출력, 프로세스 시간 제한, 상태 전환 기록을 통한 중단 복구.
- 제품 방향·MVP 체험·릴리스의 사람 승인, PR 본문 준비, 배포 없는 릴리스 준비 검사.
- Factory 버전 기록, 생성 앱에 포함되는 런타임, Windows·Ubuntu CI 정의.

YAML 대신 JSON을 선택한 이유와 기타 변경 판단은 [설계 결정](DECISIONS.md)에 기록했다.

## D. Commands

```powershell
Set-Location 'C:\Users\ttn20\Desktop\agent factory'
. .\scripts\profile.ps1
ai-new my-app -Preset react-web -Destination 'C:\Users\ttn20\Desktop'
Set-Location 'C:\Users\ttn20\Desktop\my-app'
npm ci
# IDEA.md를 작성하고 State: UNINITIALIZED 줄을 제거한 후:
ai-init
# 생성된 계획을 사람이 검토한 후:
ai-approve -Gate product -Note 'MVP 방향과 수락 기준 검토'
ai-next
ai-run 3
ai-check
ai-status
ai-pr
```

`ai-resume`, `ai-review`, `ai-approve -Gate mvp|release`, `ai-release`의 선행 조건과 전체 인자는
[명령어 문서](COMMANDS.md)에 있다. 실제 모델 호출은 계정 사용량을 소비한다.

## E. Remaining Work

v0.2 이후 범위: 실제 아이디어로 Codex 서비스 전체 사이클 검증, 브라우저 E2E,
Android/iOS SDK·서명·네이티브 빌드, Toss·Unity 실행기, 기존 앱의 안전한 런타임 업그레이드,
GitHub의 required checks 설정과 원격 PR 운영. Production 자동 배포는 구현하지 않았다.

## F. Risks

가짜 Codex 테스트는 제어 흐름을 증명하며 실제 AI의 구현·리뷰 품질을 증명하지 않는다.
실제 모델 서비스 호출, 운영 배포, 네이티브 빌드와 원격 GitHub Actions 실행은 이번 검증에서 제외했다.
로컬 승인과 로그는 변경 가능한 파일이다. 구현 에이전트의 workspace-write 권한은 프로젝트 안의
파일별 보안 경계가 아니므로 코드 검토와 최소 권한 인증이 필요하다.

Capacitor CLI 간접 개발 의존성의 npm audit moderate 3건은
[프리셋 위험 기록](../presets/react-capacitor/README.md)에 명시했다. 강제 업데이트하지 않았다.
품질 명령의 백그라운드/watch 실행은 지원하지 않는다. 이미 부모 프로세스가 종료된 뒤 분리된
자식 프로세스까지 .NET Process가 이식 가능한 방식으로 종료한다고 보장할 수 없다.

## G. First Test

아래 절차는 모델을 호출하지 않는다. 원본 보고서와 사용자 앱을 수정하지 않고 일회용 골격을 만든다.

```powershell
Set-Location 'C:\Users\ttn20\Desktop\agent factory'
pwsh -NoProfile -File .\tests\self-test.ps1
. .\scripts\profile.ps1
$trialParent = Join-Path ([IO.Path]::GetTempPath()) ('factory-first-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $trialParent | Out-Null
ai-new first-test -Preset react-capacitor -Destination $trialParent
Set-Location (Join-Path $trialParent 'first-test')
. .\automation\scripts\profile.ps1
npm ci
ai-check
ai-status
ai-init -DryRun
```

실제 검증 결과와 재현 명령은 [검증 기록](VERIFICATION.md), 이후 아이디어 작성과 승인 순서는
[첫 실행 가이드](GETTING_STARTED.md)에 있다.
