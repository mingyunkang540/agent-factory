# 명령어

PowerShell 7.4 이상에서 Factory 루트의 `. .\scripts\profile.ps1`을 실행하면 현재 세션에 함수를 등록한다. 생성 앱에서는 `. .\automation\scripts\profile.ps1`로 앱 실행 함수를 등록한다. 이미 등록된 원본 Factory의 `ai-new`는 유지된다. 새 앱 생성에는 원본 Factory의 template/presets가 필요하다. 현재 폴더를 앱 루트로 이동하거나 `-ProjectPath`로 앱 경로를 지정한다.

## 함수

| 명령 | 동작과 선행 조건 |
| --- | --- |
| `ai-new NAME -Preset PRESET -Destination PARENT` | 새 앱 생성. 부모 폴더는 존재하고 앱 폴더는 없어야 한다. 기본 프리셋은 `react-web`. `-NoGit`이면 Git 초기화 생략 |
| `ai-init` | 작성된 IDEA를 읽고 실제 Codex 세션 3개로 PRD·설계·UX·ROADMAP 생성. 재초기화는 거절 |
| `ai-approve -Gate product -Note '이유'` | 계획을 검토한 사람이 방향 승인 기록 |
| `ai-next` | 현재 product 승인 아래 실행 가능한 작업 하나 구현·검증. 최대 3회 시도 |
| `ai-run 3` | 최대 3개 작업 사이클 실행. 1–5 허용, 설정 상한 준수. 실패·차단·빈 큐에서 중단 |
| `ai-check` | 실제 lint/typecheck/test/build 실행. 누락·실패는 통과 처리하지 않음 |
| `ai-review` | 마지막 완료 작업과 현재 변경사항의 실제 품질 검사 및 세 독립 리뷰를 다시 실행. 구현·작업 상태 변경 없음 |
| `ai-status` | 완료·남은 작업, 현재 작업, 차단 이유, 품질과 승인 상태 출력 |
| `ai-resume` | 정확히 하나인 차단·중단 작업을 todo로 되돌림. 구현은 시작하지 않음 |
| `ai-pr` | 최신 품질·독립 리뷰 통과 시 `.agent-factory/PR_BODY.md` 작성과 Git·draft PR 명령 출력. Git 쓰기와 원격 작업은 실행하지 않음 |
| `ai-approve -Gate mvp -Note '이유'` | 모든 작업 완료와 최신 검증 뒤 사람이 MVP 수락 기록 |
| `ai-approve -Gate release -Note '이유'` | 최신 MVP 승인 뒤 사람이 릴리스 승인 기록 |
| `ai-release` | 품질 명령 재실행, 모든 작업 완료·최신 리뷰·세 승인·버전·CHANGELOG 검사. 성공하면 `.agent-factory/release.json` 기록. 배포하지 않음 |

이 함수들은 스크립트 인자를 그대로 전달한다. `ai-check`는 `-ProjectPath`만 받는다. `ai-new`의 이름은 소문자로 시작하는 1–63자 kebab-case이며 Windows 예약 이름과 마지막 하이픈을 허용하지 않는다.

## 실행 옵션

`ai-init`, `ai-next`, `ai-run`, `ai-review`는 `-Model MODEL`, `-CodexCommand PATH`, `-TimeoutSeconds SECONDS`를 받는다. timeout은 역할별 프로세스의 실행과 출력 수집에 적용되며 기본 900초, 허용 범위 1–3600초이다. 품질 명령은 각각 900초 제한이다. `-CodexCommand`는 테스트용 대체 CLI를 지정할 때도 사용한다.

`-Model`이 없으면 Codex CLI의 기본 모델을 사용한다. 런타임은 `--ignore-user-config`로 개인 모델·provider 설정을 읽지 않으며 `--ephemeral`로 세션을 실행한다. 구현은 `workspace-write`와 `on-request` 자동 승인 검토를 사용하고, 계획과 리뷰는 `read-only`와 `never` 승인을 사용한다. 이 구분은 비대화형 구현 세션의 작업공간 쓰기를 허용하면서 계획·검토 세션의 변경을 막는다. 프롬프트와 구조화된 응답 스키마를 전달하며 별도 API 키 대신 Codex CLI 계정 인증을 사용한다.

```powershell
ai-init -DryRun
ai-next -DryRun
ai-run 3 -DryRun
```

`-DryRun`은 이 세 동작만 지원한다. 선택 작업과 실행 상한을 출력하며 모델 호출, 계획 문서 생성, 작업 구현을 하지 않는다. 따라서 DryRun 성공은 실제 초기화 성공을 뜻하지 않는다.

## 승인과 복구

계획 파일을 바꾸면 product 승인이 만료되므로 내용을 확인하고 다시 승인한다. 소스·설정 등 지문 대상 파일을 바꾸면 이전 품질·리뷰와 MVP·릴리스 승인은 현재 파일에 대한 근거가 되지 않는다. `ai-check`만으로 독립 리뷰 통과를 대체할 수 없다.

완료한 작업의 코드를 수동 수정했다면 `ai-review`로 실제 검사와 독립 리뷰를 갱신한 뒤 `ai-pr`을 실행한다. 이 명령은 완료 작업을 다시 구현하거나 다음 작업으로 이동하지 않는다. `ai-status`는 파일이 바뀐 뒤의 과거 통과 결과를 `stale`로 표시한다.

실패 시 `ai-status`와 `.agent-factory/runs/`, `.agent-factory/logs/`의 로그를 확인한다. 원인을 수정하고 `ai-resume`으로 같은 작업을 재개 가능한 상태로 되돌린 뒤 `ai-next`를 실행한다. 상태를 강제로 done으로 바꾸지 않는다. 재개하면 다음 사이클에서 다시 최대 3회 시도할 수 있으므로 반복 실행의 모델 사용량을 확인한다.

런타임에는 프로젝트 잠금이 있어 같은 앱에서 실행 명령을 동시에 수행할 수 없다. 별도 Codex 리뷰 세션은 런타임 내부에서 병렬로 실행되고 모든 결과를 기다린다.

상태 저장 중 프로세스가 중단되면 다음 명령이 `.agent-factory/state-transaction.json`의 기록으로 두 상태 파일을 복구한다. 복구된 작업이 in_progress라면 로그를 확인한 후 여전히 `ai-resume`이 필요하다. 미완료 상태 기록이 있는 동안 DryRun은 복구를 수행하지 않고 중단한다.

## 함수 없이 실행

생성 앱 루트에서 현재 세션 함수 등록 없이 같은 동작을 실행할 수 있다.

```powershell
pwsh -NoProfile -File .\automation\scripts\agent.ps1 status
pwsh -NoProfile -File .\automation\scripts\quality.ps1
```

실제 모델 호출 예제는 이번 구축에서 서비스 종단 간 검증을 수행하지 않았다. fake CLI로 인자·상태 전환·승인·재시도 동작을 검증한 범위는 [검증 기록](VERIFICATION.md)을 참고한다.
