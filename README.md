# 녹양중 고입 길잡이 (의정부 학군)

녹양중학교 3학년을 위한 의정부 학군 고등학교 안내 정적 웹페이지입니다.
- 의정부 학군 일반고 13개교를 지도에서 찾습니다. 학교를 누르거나 검색하면 학년별 학생 수, 졸업생 진학 현황, 녹양중·집에서 가는 네이버지도·카카오맵 길찾기가 나옵니다.
- 2027학년도 전형 계획에 맞춰 지망 순위(남 12지망, 여 11지망)를 적어 보고 확인할 수 있습니다.

서버와 인증키가 필요 없습니다. [서울 고등학교 길잡이](https://github.com/jooane12/seoul-highschool)와 같은 구성입니다.

## 구성
| 파일 | 설명 |
|---|---|
| `index.html` | 화면 전체 (HTML+CSS+JS 한 파일) |
| `schools.json` | 의정부시 고등학교 17개교(일반고 13개교)와 녹양중의 정보·좌표·학생수·진로 현황 (아래 스크립트로 생성) |
| `tools/build_schools.ps1` | NEIS에서 학교 목록을 받아 `schools.json` 생성 |
| `tools/build_stats.ps1` | 학교알리미에서 학년별 학생수·학급수와 졸업생 진로 현황을 받아 `schools.json`에 합침 |
| `tools/serve.ps1` | 내 컴퓨터에서 확인할 때 쓰는 간이 서버 (Python이 없어도 됨) |

## 1. 학교 정보 만들기 (학교 정보를 갱신하고 싶을 때)
```
powershell -ExecutionPolicy Bypass -File tools\build_schools.ps1
powershell -ExecutionPolicy Bypass -File tools\build_stats.ps1
```
반드시 이 순서로 실행합니다(`build_schools`가 `schools.json`을 새로 만들기 때문).

### 1-1. 학교 목록 (`build_schools.ps1`)
- NEIS 인증키 없이 동작합니다. 키가 없으면 NEIS가 한 번에 5개까지만 돌려주므로, 학교 이름 일부(`$NAMES`)로 나눠 조회해 주소가 의정부시인 학교만 모읍니다. 학교가 새로 생기거나 이름이 바뀌면 `$NAMES`에 추가하세요.
- 아직 NEIS에 없는 새 학교는 `$EXTRA`에 직접 적습니다. 지금은 **훈민고**(2027. 3. 개교, 배정 방안의 가칭 '고산고')가 들어 있습니다. NEIS에 같은 이름이 생기면 자동으로 NEIS 정보를 씁니다.
- 좌표는 OpenStreetMap에서 찾고 `tools/geocode_cache.json`에 저장합니다. 지도에서 못 찾은 학교(경민비즈니스고)는 주소가 같은 학교(경민고)의 좌표를 씁니다.

### 1-2. 학생수·진로 현황 (`build_stats.ps1`)
- 학교알리미 인증키 없이, 학교알리미 '학교별 공시정보' 화면이 쓰는 주소에서 받습니다. 4~5분 걸립니다.
  - 「학년별·학급별 학생수」: 올해 4월 1일 기준 학년별 남녀 학생수, 학급수, 특수학급
  - 「졸업생의 진로 현황」: 최근 3개 공시연도(그해 2월 졸업생). 4년제·전문대·국외 진학, 취업, 기타
- 받은 원본은 `tools/raw`에 저장됩니다. 원본으로 다시 합치기만 하려면 `-Offline`을 붙입니다.
- 학교알리미 화면 구조가 바뀌면 받지 못할 수 있습니다. 그때는 '학생수 합침: 0개교'처럼 나옵니다.
- 학교알리미에 아직 없는 학교(훈민고)는 건너뛰고, 화면에 '개교 예정이라 공시 정보가 없음'으로 나옵니다.

## 2. 내 컴퓨터에서 확인
```
powershell -ExecutionPolicy Bypass -File tools\serve.ps1
```
브라우저에서 http://localhost:8000 접속. (`index.html`을 더블클릭하면 `schools.json`을 못 읽습니다.) Python이 있으면 `python -m http.server 8000`도 됩니다.

## 3. GitHub Pages로 공유
서울 저장소와 같은 방법입니다.

1. github.com → `+` → **New repository** → 이름 `uijeongbu-highschool`, **Public** → Create repository
2. **uploading an existing file** → `index.html`, `schools.json`, `README.md`, `tools`를 끌어다 놓고 **Commit changes**
   - `tools/raw`, `tools/geocode_cache.json`, `_ref`(요강 PDF와 글자 추출 도구)는 올리지 마세요.
3. **Settings → Pages** → Branch `main` / `(root)` → Save
4. 1~2분 뒤 `https://jooane12.github.io/uijeongbu-highschool/` 로 접속됩니다.

## 해마다 갱신할 내용
새 학년도 「평준화 지역 후기 일반고등학교 신입생 전형 계획」과 「고교 평준화 학군 학생 배정 방안」이 나오면 `index.html`에서 아래를 고치세요.
- `ADMIT_YEAR`, `ADMIT`: 학교별 모집 학급·정원·체육특기자 (전형 계획 '학교별 모집 현황', 2027학년도는 27쪽)
- `AUTONOMOUS`: 자율형 공립고 (2027학년도: 의정부고, 의정부여고)
- `일정과 배정 규칙` 부분의 날짜와 녹양중 원서 제출일 (전형 계획 8·14·17쪽, 31~32쪽)
- 지망 수: 화면은 성별로 지원할 수 있는 일반고 수만큼 칸을 만듭니다(남 12, 여 11). 학교가 늘거나 줄면 1번 스크립트를 다시 실행하면 됩니다.

주의
- 저장소는 **공개**입니다. 비밀번호·API 키·개인정보를 올리지 마세요. (현재 파일에는 키가 없습니다.)
- `schools.json`을 갱신해서 다시 올릴 때는 `index.html` 아래쪽 `DATA_VERSION` 값도 바꿔야 이미 접속했던 사람에게 새 데이터가 보입니다.
- 교원 수는 넣지 않았습니다(서울판은 학교알리미 인증키로 받음).
