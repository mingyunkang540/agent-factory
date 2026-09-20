# Agent Factory v0.1

아이디어를 제품 정의, 설계, 작업별 구현, 검증, PR 준비, 릴리스 준비로 연결하는 재사용 가능한 로컬 개발 시스템이다. PowerShell이 작업과 상태를 관리하고 Codex CLI가 역할별 세션을 실행한다. 특정 제품을 개발하는 저장소가 아니다.

## 시작하기

단계별로 복사할 명령은 [한국어 사용 예시 텍스트](Agent_Factory_사용_예시.txt)에 있다. 처음 사용, 다음 날 이어 하기, 실패 복구 순서로 설명한다.

Windows에서 PowerShell **7.4 이상**을 사용한다. Windows PowerShell 5.1은 지원하지 않는다. 검증 환경은 PowerShell 7.6.6, Node.js 22.17.1, npm 10.9.2, Git 2.50.1, Codex CLI 0.147.0이다. 현재 프리셋의 지원 범위는 Node.js 22.x이며 22.17.1 이상을 권장한다. 다른 Node 메이저 버전은 이번에 검증하지 않았다.

```powershell
Set-Location 'C:\Users\ttn20\Desktop\agent factory'
. .\scripts\profile.ps1
ai-new my-app -Preset react-capacitor -Destination 'C:\Users\ttn20\Desktop'
Set-Location 'C:\Users\ttn20\Desktop\my-app'
. .\automation\scripts\profile.ps1
npm ci
```

`my-app` 폴더가 없어야 하며 `-Destination`에는 이미 존재하는 부모 폴더를 지정한다. 생성은 의존성을 설치하지 않는다. `IDEA.md` 안내문을 문제, 사용자, MVP 범위와 성공 기준으로 바꾸고 `State: UNINITIALIZED` 줄을 제거한 뒤 [첫 실행 가이드](docs/GETTING_STARTED.md)를 따른다. 위 명령은 새 프로젝트 파일과 Git 저장소를 생성한다.

Codex CLI 계정 로그인으로 실행하며 별도 OpenAI API 키는 필요하지 않다. `ai-init`, `ai-next`, `ai-run`, `ai-review`는 실제 모델을 호출하고 사용량을 소비한다. 실행 시 `--ignore-user-config`를 사용하므로 개인 Codex 설정의 모델·provider 설정을 상속하지 않는다. 필요한 모델은 `-Model`로 명시한다.

## 제공 범위

| 구성 | v0.1 동작 |
| --- | --- |
| `react-web` | React·TypeScript·Vite 앱 골격과 lint/typecheck/test/build |
| `react-capacitor` | 웹 골격, Capacitor 설정과 패키지; 네이티브 플랫폼 생성은 별도 |
| `toss-miniapp`, `unity` | 확장 명세만 제공; 생성 명령은 지원하지 않는 프리셋으로 거절 |
| 초기화 | product → architect → UX 세션으로 계획 문서와 ROADMAP 생성 |
| 구현 | 우선순위·의존성을 만족하는 작업 하나씩, 최대 3회 시도 |
| 검증 | 실제 품질 명령과 독립 tester/reviewer/security 세션 |
| 승인 | 사람이 product, mvp, release 게이트를 명시적으로 기록 |
| PR·릴리스 | PR 본문과 명령 안내, 릴리스 준비 검증; 배포 기능 없음 |

`ai-run 3`은 최대 세 작업을 처리하며 실패 시 중단한다. 작업 완료는 실제 품질 명령과 세 리뷰가 모두 통과한 뒤 런타임만 기록한다. 릴리스 역할 설정은 제공하지만 `ai-release` 자체는 모델 호출 없이 준비 조건을 검증한다.

## 저장소

- `template/`: 프로젝트 규칙, 8개 역할 설정, 계획 문서, 프롬프트·응답 스키마, CI.
- `presets/`: 스택별 명세, 앱 골격, 고정된 의존성 lockfile.
- `scripts/`: 프로젝트 생성과 실행 런타임. 생성 앱의 `automation/scripts/`에 복사된다.
- `tests/`: 모델을 호출하지 않는 fake Codex 기반 상태·게이트 검증.
- `docs/`: 시스템 설계, 결정, 사용법과 검증 기록.

생성 앱은 원본 Factory 경로 없이 복사된 런타임으로 실행할 수 있다. 현재 세션 함수는 `. .\automation\scripts\profile.ps1`로 등록한다. 이 명령은 사용자 `$PROFILE`을 수정하지 않는다.

## 검증과 제한

```powershell
Set-Location 'C:\Users\ttn20\Desktop\agent factory'
pwsh -NoProfile -File .\tests\self-test.ps1
```

자가 테스트는 fake Codex와 가짜 품질 명령으로 제어 흐름을 검증한다. 실제 생성 앱의 품질 결과와 전체 검증 범위는 [검증 기록](docs/VERIFICATION.md)에 남긴다. 이번 구축에서는 실제 Codex 서비스의 전체 개발 사이클, 브라우저 E2E, Android/iOS 빌드를 검증하지 않았다. 로컬 상태·승인·로그는 변경 가능한 파일이며 위변조 방지 증명이 아니다. 사람이 코드 변경과 제품 결과를 확인해야 한다.

후속 [구조 검토](docs/STRUCTURE_REVIEW.md)에서 `ai-review`의 전체 변경 검토 요청과 작업 한정 역할 지시가 충돌하는 문제를 확인했다. 수정 전에는 통과 결과를 마지막 작업 밖의 변경까지 검토했다는 근거로 사용하면 안 된다. ROADMAP의 프로젝트 식별 검증 누락도 개선 항목으로 남아 있다.

Capacitor CLI 개발 의존성의 moderate 취약점과 처리 판단은 [프리셋 설명](presets/react-capacitor/README.md)을 참고한다. v0.2에는 Toss·Unity 실행 지원, 네이티브 SDK 검증, 브라우저 E2E, 런타임 업그레이드·마이그레이션, 실제 아이디어 파일럿이 남아 있다.

원본 `Agent_Factory_자동화_개발_시스템_구축_보고서.docx`는 수정하지 않는다.

## 문서

[사용 예시 TXT](Agent_Factory_사용_예시.txt) · [구조 검토](docs/STRUCTURE_REVIEW.md) · [구축 결과](docs/BUILD_REPORT.md) · [검증 기록](docs/VERIFICATION.md) · [첫 실행](docs/GETTING_STARTED.md) · [명령어](docs/COMMANDS.md) · [구조](docs/ARCHITECTURE.md) · [설계 결정](docs/DECISIONS.md) · [변경 기록](CHANGELOG.md)
