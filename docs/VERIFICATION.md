# Agent Factory v0.1 검증 기록

최종 검증일: 2026-09-20. 원본 보고서를 보존하고 Factory 자체만 구축했다.

## 결과

| 검증 | 실제 결과 |
| --- | --- |
| 전체 자가 테스트 | **49 passed, 0 failed**, 종료 코드 0 |
| React Web 생성 앱 | npm ci, lint, typecheck, test, build 통과 |
| React + Capacitor 생성 앱 | npm ci, lint, typecheck, test, 웹 build 통과 |
| 프리셋 smoke test | 각 시드 1개 통과 |
| 데이터·설정 | JSON 15개, TOML 9개 파싱; 역할 등록 8개 경로·이름 및 명령 인자 배열 검증 |
| PowerShell | 런타임·테스트 파일의 내장 AST 구문 검사 통과 |
| 신규 소스 파일 | 공백 오류·충돌 마커 검사 통과 |
| 원본 DOCX | 최초·최종 SHA-256 일치 |

확인 환경: Windows, PowerShell 7.6.6, Codex CLI 0.147.0, Git 2.50.1.windows.1,
Node.js 22.17.1, npm 10.9.2. GitHub Actions의 Windows/Ubuntu 실행 정의는 작성했으며
원격 실행 결과를 주장하지 않는다.

## 재현 명령과 증거 위치

```powershell
pwsh -NoProfile -File tests/self-test.ps1
```

최종 실행 원문은 로컬 `.agent-factory/verification/self-test.log`에 보존했다.
검사 대상 중에는 subprocess 출력 파이프의 timeout, 경로 보호, 유효하지 않은 ROADMAP,
의존성·우선순위 선택, 계획 승인, 한 작업 종료, 최대 시도 횟수, 실제 명령 실패,
누락 스크립트, 독립 리뷰 실패, 잘못된 JSON 응답, controller 변경 탐지, 잠금,
명시적 재개, 두 상태 파일의 중단 복구, profile 유지, stale 근거, 리뷰 갱신,
PR의 Git 비변경, 세 human gate와 릴리스 결과가 포함된다.

가짜 Codex는 실제 호출 인자와 stdin을 받고 스키마에 맞는 출력 또는 의도적인 실패를
만든다. 품질 명령 fixture는 실제 node 프로세스의 종료 코드를 사용한다.
이 테스트는 모델/API를 호출하지 않으며 AI 구현 능력이나 샌드박스 강제 적용을 검증하지 않는다.

실제 패키지 검사는 `.test-work/factory-web-smoke`와 `.test-work/factory-cap-smoke`에서
수행했다. 최종 런타임을 복사한 뒤 생성 앱의 다음 명령을 다시 통과시켰다.

```powershell
npm ci
pwsh -NoProfile -File automation/scripts/quality.ps1
```

실제 명령 로그는 각 앱의 `.agent-factory/logs/`, 결과 사본은 Factory의
`.agent-factory/verification/web-quality.json`, `capacitor-quality.json`, `presets.json`에 있다.
테스트 앱은 Git 제외 경로의 기본 골격이며 특정 제품을 구현하지 않았다.
초기 시드 검증 산출물도 무시되는 `presets/*/.validation/`에 보존되어 있다.

## 리뷰에서 확인하고 수정한 항목

독립 코드 리뷰가 찾아낸 네 항목을 수정했다.

1. 부모 종료 후 자식이 출력 파이프를 유지하면 timeout이 무시되는 문제:
   입력·프로세스 종료·출력 수집에 동일 deadline을 적용하고 종료 코드 124로 실패 처리.
2. Ubuntu에서 Windows용 npm 경로를 가정한 문제: Windows shim 변환만 적용하고
   Unix에서는 native npm 실행 파일 사용. 실제 Linux 실행은 CI에서 추가 확인해야 한다.
3. 생성 앱 profile이 원본 Factory의 ai-new를 망가뜨리는 문제: 생성 앱은 앱 실행
   함수만 등록하며 원본 Factory의 ai-new 유지. 새 프로젝트 추가 생성 회귀 테스트 통과.
4. ROADMAP/STATUS 저장 사이의 중단 문제: 원자적 전환 기록으로 두 파일 복구.
   시작·완료 전환의 부분 저장 회귀 테스트 통과.

2026-09-20 실제 냉장고 관리 앱 시험에서 비대화형 구현 세션의 승인 정책과 통과 리뷰의
근거 배열 판정 문제가 추가로 드러났다. 구현 역할에 `workspace-write`, `on-request`,
자동 승인 검토를 적용하고, schema-valid `pass` verdict가 수락 근거를 findings에
기록할 수 있도록 판정 계약을 고쳤다. 해당 인자와 리뷰 판정 회귀 테스트를 추가했다.
최종 변경은 위 49개 테스트 및 기존 실제 웹 품질 검사로 확인했다.
PSScriptAnalyzer는 설치되어 있지 않아 실행하지 않았다. 내장 PowerShell 구문 검사와
동작 테스트를 수행했으며 이를 PSScriptAnalyzer 실행 결과로 표현하지 않는다.

## 확인하지 않은 범위와 알려진 위험

후속 구조 검토에서 독립 코드 리뷰를 다시 수행했다. 리뷰 갱신의 범위 충돌 등
미수정 항목 3개와 재현·정적 분석 근거는 [구조 검토](STRUCTURE_REVIEW.md)에 기록했다.
위 49개 테스트 통과는 이 후속 발견이 해결됐다는 뜻이 아니다. 독립 설계 검토는
지정 모델의 계정 미지원으로 실행하지 못했다.

- 실제 Codex 서비스로 계획→구현→리뷰 전체 사이클 실행.
- 실제 브라우저 E2E 및 제품 UX 검수.
- Android/iOS 플랫폼 생성, 네이티브 SDK 빌드·서명·스토어 제출.
- 원격 GitHub Actions 실행 결과, required checks 설정, 실제 PR·배포.
- 변경 가능한 로컬 승인·로그의 위변조 방지.
- 부모 종료 후 분리된 자식 프로세스에 대한 OS 수준 격리.

React Web의 npm audit 결과는 0건이다. Capacitor CLI에는 간접 개발 의존성의 moderate
3건이 있으며 [위험 설명과 advisory](../presets/react-capacitor/README.md)에 기록했다.
이 결과는 자동 코드·의존성 검토를 면제하지 않는다.

## 원본 보존

파일: `Agent_Factory_자동화_개발_시스템_구축_보고서.docx`

SHA-256:
`7DB0E830B9CE923700C451821138352FC08F2B88D7E03EA542E4C340A61CFC0C`

## 호환성 근거

설치된 `codex --help`, `codex exec --help`의 실제 옵션을 확인했다. 에이전트 역할은
명시적인 프롬프트와 config override로 전달하며 존재하지 않는 `--agent` 플래그를 사용하지 않는다.

- [공식 비대화형 실행](https://learn.chatgpt.com/docs/noninteractive)
- [공식 에이전트 구성](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- [공식 설정 참조](https://learn.chatgpt.com/docs/config-file/config-reference)
- [Node 22.17.1의 Unix npm 설치 경로](https://github.com/nodejs/node/blob/v22.17.1/tools/install.py#L83-L109)

정적 설정 파싱은 실제 모델 서비스·계정별 모든 기능의 동작을 보증하지 않는다.
