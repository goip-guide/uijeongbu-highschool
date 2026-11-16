# 의정부시 고등학교 목록과 녹양중 위치로 schools.json을 만든다.
# 실행: powershell -ExecutionPolicy Bypass -File tools\build_schools.ps1
# - NEIS 인증키 없이 동작한다. 키가 없으면 NEIS가 한 번에 5개까지만 돌려주고 페이지 번호를 무시하므로,
#   학교 이름 일부로 나눠 조회한 뒤 주소가 '의정부시'인 학교만 모은다.
# - 새 학교가 생기면 아래 $NAMES에 이름 일부를 추가한다. (근거: NEIS 학교기본정보, 위키백과 '의정부시' 학교 목록과 대조)
# - 좌표는 OpenStreetMap(Nominatim)에서 찾고 tools\geocode_cache.json에 저장해 다시 실행할 때 재사용한다.

$ErrorActionPreference = 'Stop'
$root  = Split-Path -Parent $PSScriptRoot
$cacheFile = Join-Path $PSScriptRoot 'geocode_cache.json'
$outFile   = Join-Path $root 'schools.json'

$NAMES = '의정부','경민','광동','발곡','부용','상우','송현','효자','호원','송양','영석','훈민','과학','한국','IT','비즈니스'
$MIDDLE = '녹양중학교'      # 기준 중학교

# NEIS에 아직 없는 새 학교 (NEIS에 같은 이름이 생기면 자동으로 NEIS 정보를 쓴다)
# 근거: 경기도교육청 「2027학년도 경기도 고교 평준화 학군 학생 배정 방안」 78쪽 '의정부학군 일반고 소재지 현황'
#       (가칭 고산고 = 훈민고, 2027. 3. 1. 개교). 좌표는 같은 주소(홈다리길 10)의 훈민중학교 위치.
$EXTRA = @(
  [ordered]@{ ATPT_OFCDC_SC_CODE = 'J10'; SD_SCHUL_CODE = 'NEW-HUNMIN'; SCHUL_NM = '훈민고등학교'; ENG_SCHUL_NM = $null
              FOND_SC_NM = '공립'; COEDU_SC_NM = '남여공학'; HS_SC_NM = '일반고'; HS_GNRL_BUSNS_SC_NM = '일반계'; SPCLY_PURPS_HS_ORD_NM = $null
              ENE_BFE_SEHF_SC_NM = '후기'; ORG_RDNZC = $null; ORG_RDNMA = '경기도 의정부시 홈다리길 10'; ORG_RDNDA = $null
              ORG_TELNO = '031-869-2500'; HMPG_ADRES = $null; FOND_YMD = '20270301'; lat = 37.7362967; lng = 127.1120729 }
)

function Neis($q){
  $u = 'https://open.neis.go.kr/hub/schoolInfo?Type=json&pSize=5&ATPT_OFCDC_SC_CODE=J10&' + $q
  $r = Invoke-WebRequest $u -UseBasicParsing
  $j = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()) | ConvertFrom-Json
  if($j.schoolInfo){ return @($j.schoolInfo[1].row) } else { return @() }
}

$cache = @{}
if(Test-Path $cacheFile){
  (Get-Content $cacheFile -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $cache[$_.Name] = $_.Value }
}
function Geocode($name, $addr){
  if($cache.ContainsKey($name)){ return $cache[$name] }
  $hit = $null
  $short = $name -replace '^.+?대학교사범대학부[속설]','' -replace '^의정부',''
  foreach($q in @("$name 의정부", "$short 의정부", ($addr -replace '\(.*?\)','').Trim())){
    $u = 'https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=kr&q=' + [uri]::EscapeDataString($q)
    $r = Invoke-WebRequest $u -UseBasicParsing -Headers @{ 'User-Agent' = 'uijeongbu-highschool-guide/1.0' }
    $j = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()) | ConvertFrom-Json
    Start-Sleep -Milliseconds 1100     # Nominatim 이용 규칙: 초당 1회
    # 도로 이름만 맞은 결과(학교가 아닌 곳)는 버린다
    if($j -and $j[0].display_name -match '고등학교|중학교'){ $hit = @{ lat = [double]$j[0].lat; lng = [double]$j[0].lon }; break }
  }
  if($hit){ $cache[$name] = $hit }
  return $hit
}

$keep = 'ATPT_OFCDC_SC_CODE','SD_SCHUL_CODE','SCHUL_NM','ENG_SCHUL_NM','FOND_SC_NM','COEDU_SC_NM','HS_SC_NM','HS_GNRL_BUSNS_SC_NM','SPCLY_PURPS_HS_ORD_NM','ENE_BFE_SEHF_SC_NM','ORG_RDNZC','ORG_RDNMA','ORG_RDNDA','ORG_TELNO','HMPG_ADRES','FOND_YMD'
function Pick($x){
  $o = [ordered]@{}
  foreach($k in $keep){ $o[$k] = $x.$k }
  $g = Geocode $x.SCHUL_NM $x.ORG_RDNMA
  $o.lat = if($g){ $g.lat } else { $null }
  $o.lng = if($g){ $g.lng } else { $null }
  return $o
}

$seen = @{}; $list = @()
foreach($n in $NAMES){
  foreach($x in (Neis ('SCHUL_KND_SC_NM=' + [uri]::EscapeDataString('고등학교') + '&SCHUL_NM=' + [uri]::EscapeDataString($n)))){
    if($x.ORG_RDNMA -like '*의정부시*' -and -not $seen[$x.SD_SCHUL_CODE]){ $seen[$x.SD_SCHUL_CODE] = 1; $list += ,(Pick $x) }
  }
}
$mid = (Neis ('SCHUL_NM=' + [uri]::EscapeDataString($MIDDLE))) | Where-Object { $_.SCHUL_NM -eq $MIDDLE } | Select-Object -First 1
if(-not $mid){ throw "$MIDDLE 을(를) NEIS에서 찾지 못했습니다." }

foreach($x in $EXTRA){
  if(-not ($list | Where-Object { $_.SCHUL_NM -eq $x.SCHUL_NM })){ $list += ,$x }
}

# 지도에서 못 찾은 학교는 주소가 같은 학교(같은 캠퍼스)의 좌표를 쓴다
foreach($s in $list){
  if($s.lat -ne $null){ continue }
  $twin = $list | Where-Object { $_.lat -ne $null -and $_.ORG_RDNMA -eq $s.ORG_RDNMA } | Select-Object -First 1
  if($twin){ $s.lat = $twin.lat; $s.lng = $twin.lng }
}
$list = $list | Sort-Object { $_.SCHUL_NM }
$data = [ordered]@{ updated = (Get-Date -Format 'yyyy-MM-dd'); middle = (Pick $mid); schools = @($list) }
$enc = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($outFile, ($data | ConvertTo-Json -Depth 6 -Compress), $enc)
[IO.File]::WriteAllText($cacheFile, ($cache | ConvertTo-Json -Depth 4), $enc)

$noPos = @($list | Where-Object { $_.lat -eq $null })
"schools.json: 고등학교 $($list.Count)개교 (일반고 $(@($list | Where-Object { $_.HS_SC_NM -eq '일반고' }).Count)개교), 기준 중학교 $($mid.SCHUL_NM)"
if($noPos.Count){ "좌표 없음: " + (($noPos | ForEach-Object { $_.SCHUL_NM }) -join ', ') }
