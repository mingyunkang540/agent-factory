# 첫 실행 가이드

이 가이드는 일회용 앱 골격에서 명령을 익힌 뒤 아이디어 기반 개발을 시작하는 순서이다. Factory 원본 폴더와 보고서를 앱 개발 작업 공간으로 사용하지 않는다.

## 1. 환경 확인

PowerShell 7.4 이상이 필요하다. 테스트 환경은 PowerShell 7.6.6, Node.js 22.17.1, npm 10.9.2, Git 2.50.1, Codex CLI 0.147.0이다. 프리셋은 Node.js 22.x를 지원하며 22.17.1 이상을 권장한다.

```powershell
pwsh --version
node --version
npm --version
git --version
codex --version
codex login status
```

로그인되지 않았다면 `codex login`으로 계정을 인증한다. API 키를 입력할 필요는 없다. 모델 실행은 계정의 사용량 제한과 비용 조건을 따른다. 설치·로그인 과정은 이번 자동 검증에서 수행하지 않았다.

## 2. 모델 호출 없이 첫 점검

새 PowerShell 7 세션에서 아래 명령을 실행한다. 임시 폴더의 경로는 출력되며 앱은 기존 폴더를 덮어쓰지 않는다.

```powershell
Set-Location 'C:\Users\ttn20\Desktop\agent factory'
. .\scripts\profile.ps1
$trialParent = Join-Path ([IO.Path]::GetTempPath()) ('agent-factory-first-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $trialParent | Out-Null
ai-new first-test -Preset react-capacitor -Destination $trialParent
Set-Location (Join-Path $trialParent 'first-test')
. .\automation\scripts\profile.ps1
npm ci
ai-check
ai-status
ai-init -DryRun
```

생성만으로 의존성은 설치되지 않으므로 `npm ci`를 직접 실행한다. 웹 품질 검사 4개가 통과해야 한다. DryRun은 초기화 미리보기이며 계획 문서를 만들거나 모델을 호출하지 않는다. 이 앱은 테스트 골격이다. 실제 제품 아이디어가 준비되면 새 이름과 원하는 부모 폴더로 다시 생성한다.

함수 등록은 현재 세션에만 적용된다. 매번 등록하려면 PowerShell의 `$PROFILE`에 Factory `profile.ps1`을 dot-source하는 줄을 직접 추가할 수 있다. Factory는 사용자 프로필을 수정하지 않는다. 생성 앱에서 복사된 `automation/scripts/profile.ps1`을 등록하면 원본 Factory 없이도 실행한다.

## 3. 아이디어와 계획

생성 앱의 `IDEA.md`를 수정한다. 해결할 문제, 대상 사용자, 기대 결과, MVP 범위, 제외 범위, 플랫폼·데이터 제약과 관찰 가능한 성공 기준을 구체적으로 작성한다. 템플릿 안내문을 실제 내용으로 바꾸고 `State: UNINITIALIZED` 줄을 제거한다. 이 줄이 남아 있으면 초기화가 모델 호출 전에 중단된다.

```powershell
ai-init
ai-status
```

`ai-init`은 실제 Codex product·architect·UX 세션을 실행한다. `docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `docs/UX.md`, `docs/ROADMAP.json`을 확인한다. 구현 코드를 작성하는 단계는 아니다. 잘못된 방향이나 작업 범위를 수정한 뒤 사람이 다음 승인을 기록한다.

```powershell
ai-approve -Gate product -Note '사용자 문제, MVP 범위와 작업 수락 기준을 검토함'
ai-next
ai-status
ai-run 3
ai-check
```

작업은 의존성이 완료된 todo 중 우선순위와 ID 순으로 선택된다. 한 사이클은 최대 3번 구현을 시도하며 실제 명령과 독립 tester/reviewer/security가 모두 통과해야 done이 된다. `ai-run 3`은 무한 루프가 아니며 첫 실패에서 멈춘다.

## 4. 실패 복구와 변경

`ai-status`의 차단 이유와 `.agent-factory/` 아래 로그를 읽고 원인을 수정한다. 중단된 작업을 재시도하려면 다음 순서로 실행한다.

```powershell
ai-resume
ai-next
```

`ai-resume`은 같은 작업을 todo로 돌릴 뿐 구현하지 않는다. 계획을 수정했다면 product 승인을 다시 기록해야 한다. 상태 저장 도중 중단된 경우 다음 명령이 두 상태 파일을 기록된 전환으로 복구하며, in_progress 작업에는 명시적 재개가 필요하다.

완료 작업을 수동 수정했거나 버전·변경 기록을 갱신했다면 다음 명령으로 현재 파일에 대한 검사와 독립 리뷰를 다시 확보한다. `ai-review`는 구현하거나 작업 상태를 바꾸지 않는다. `ai-check`만으로 독립 리뷰를 대신할 수 없다.

```powershell
ai-review
ai-pr
```

## 5. PR과 릴리스 준비

```powershell
ai-pr
```

최신 검증이 통과하면 PR 본문 파일을 만들고 브랜치·커밋·push·draft PR 명령을 출력한다. 도우미가 이 명령을 실행하지 않는다. 사람은 변경 내용을 검토하고 필요한 경로만 스테이징한 뒤 Git 작업을 수행한다. 실제 PR에는 remote 설정과 GitHub 인증·권한이 필요하다.

모든 ROADMAP 작업이 완료되면 제품 결과를 직접 확인하고 앱의 `package.json` 버전과 `CHANGELOG.md`를 준비한다. 이 파일을 바꾼 뒤에는 현재 파일에 대한 품질·리뷰 근거가 필요하다. 최신 검증이 준비된 상태에서 다음을 실행한다.

```powershell
ai-review
ai-approve -Gate mvp -Note '전체 작업 결과와 MVP 사용자 흐름을 직접 확인함'
ai-approve -Gate release -Note '버전, 변경 기록과 릴리스 범위를 검토함'
ai-release
```

`ai-release`는 실제 품질 명령을 다시 실행하고 product·mvp·release 승인, 최신 독립 리뷰, 작업 완료, 버전·변경 기록을 검사한다. 준비 결과만 기록하며 배포·태그·스토어 제출은 수행하지 않는다.

## 검증 범위

모델을 호출하는 예제는 fake CLI로 제어 흐름을 검증했으며 실제 Codex 개발 사이클은 이번에 실행하지 않았다. 웹 골격의 실제 품질 검사, 자가 테스트 결과와 한계는 [검증 기록](VERIFICATION.md)에 남긴다. Capacitor 앱의 Android/iOS SDK·빌드·서명과 브라우저 E2E는 별도 검증이 필요하다. CLI 개발 의존성의 moderate 취약점은 [프리셋 설명](../presets/react-capacitor/README.md)을 참고한다.
