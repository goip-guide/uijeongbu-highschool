# 학교알리미 공시에서 학년별 학생수·학급수와 졸업생 진로 현황을 받아 schools.json에 합친다.
# 실행: powershell -ExecutionPolicy Bypass -File tools\build_stats.ps1            (받아서 합치기)
#       powershell -ExecutionPolicy Bypass -File tools\build_stats.ps1 -Offline   (tools\raw에 받아 둔 원본으로 다시 합치기)
# - 인증키가 필요 없다. 학교알리미 '학교별 공시정보' 화면이 쓰는 주소에서 받는다(화면 구조가 바뀌면 실패할 수 있음).
#   · 학교 목록:   /ei/ss/pneiss_a03_s0_school_json.do  (의정부시 고등학교, 학교알리미 학교 식별번호 SHL_IDF_CD)
#   · 3-가-3 학년별·학급별 학생수: /ei/pp/Pneipp_b03_s0p.do  (올해 4월 1일 기준)
#   · 6-가 직위별 교원 현황:        /ei/pp/Pneipp_b08_s0p.do  (올해 5월 공시, '합계(A+B)' 줄의 총계 = 교원 수)
#   · 13-다 졸업생의 진로 현황:   /ei/pp/Pneipp_b06_s0p.do  (해마다 11월 공시, 그해 2월 졸업생)
#   · 13-라 특성화고 · 산업수요 맞춤형고 졸업생의 취업 등 진로 현황: /ei/pp/Pneipp_b64_s0p.do (특성화고는 13-다가 비어 있어 이것을 쓴다)
#     11월 공시 항목이라 올해 항목 목록에는 아직 없고, 지난해(JG_YEAR) 목록에서 찾았다.
# - 먼저 build_schools.ps1로 schools.json을 만든 뒤 실행한다. 학교알리미에 아직 없는 학교(새로 여는 학교)는 건너뛴다.
param([switch]$Offline)

$ErrorActionPreference = 'Stop'
$root    = Split-Path -Parent $PSScriptRoot
$rawDir  = Join-Path $PSScriptRoot 'raw'
$outFile = Join-Path $root 'schools.json'
New-Item -ItemType Directory -Force $rawDir | Out-Null

$STATS_YEAR   = (Get-Date).Year                 # 학생수 공시연도 (4월 1일 기준)
$CAREER_YEARS = 1..3 | ForEach-Object { (Get-Date).Year - $_ }   # 최근 3개 공시연도 (예: 2025, 2024, 2023)
$EUC = [Text.Encoding]::GetEncoding(51949)      # 공시 화면은 EUC-KR
$UTF = New-Object System.Text.UTF8Encoding($false)

function Fetch($name, $url, $form, $enc){
  $file = Join-Path $rawDir $name
  if($Offline){ if(Test-Path $file){ return [IO.File]::ReadAllText($file, $UTF) } else { return $null } }
  $r = Invoke-WebRequest ('https://www.schoolinfo.go.kr' + $url) -Method Post -Body $form -UseBasicParsing `
         -ContentType 'application/x-www-form-urlencoded; charset=UTF-8' -Headers @{ 'X-Requested-With' = 'XMLHttpRequest' }
  $t = $enc.GetString($r.RawContentStream.ToArray())
  [IO.File]::WriteAllText($file, $t, $UTF)
  Start-Sleep -Milliseconds 400                 # 학교알리미에 부담을 주지 않게
  return $t
}
# 표를 [행][칸] 문자열 배열로 (태그 제거)
function Rows($html){
  $html = $html -replace '(?s)<script.*?</script>', '' -replace '(?s)<style.*?</style>', '' -replace '(?s)<!--.*?-->', ''
  [regex]::Matches($html, '(?s)<tr[^>]*>(.*?)</tr>') | ForEach-Object {
    ,@([regex]::Matches($_.Groups[1].Value, '(?s)<t[dh][^>]*>(.*?)</t[dh]>') | ForEach-Object {
      (($_.Groups[1].Value -replace '<[^>]+>', ' ') -replace '&nbsp;', ' ' -replace '\s+', '').Trim()
    })
  }
}
function Num($v){ if($v -match '^-?\d+$'){ return [int]$v } return 0 }

$form = @{ GS_TYPE = 'Y'; JG_GUBUN = '1' }
function Form($extra){ $h = @{} + $form; foreach($k in $extra.Keys){ $h[$k] = $extra[$k] }; return $h }

# ---- 학교 목록 (학교알리미 식별번호)
$listJson = Fetch 'schools_ujb.json' '/ei/ss/pneiss_a03_s0_school_json.do' @{ HG_JONGRYU_GB = '04'; SIDO_CODE = '4100000000'; GUGUN_CODE = '4115000000' } $UTF
$idOf = @{}
foreach($x in ($listJson | ConvertFrom-Json)){ $idOf[$x.SHL_NM] = $x.SHL_IDF_CD }

$data = [IO.File]::ReadAllText($outFile, $UTF) | ConvertFrom-Json
$nStats = 0; $nCareer = 0; $skipped = @()
foreach($s in $data.schools){
  $id = $idOf[$s.SCHUL_NM]
  if(-not $id){ $skipped += $s.SCHUL_NM; continue }
  $code = $s.SD_SCHUL_CODE

  # ---- 학년별·학급별 학생수
  $y = "$STATS_YEAR"
  $html = Fetch "${code}_b03_$y.html" '/ei/pp/Pneipp_b03_s0p.do' (Form @{ GS_HANGMOK_CD = '03'; GS_HANGMOK_NO = '3-가-3'; GS_BURYU_CD = 'JG010'; JG_BURYU_CD = 'JG030'; JG_HANGMOK_CD = '09'; SHL_IDF_CD = $id; JG_YEAR = $y; JG_YEAR2 = $y; CHOSEN_JG_YEAR = $y; PRE_JG_YEAR = $y }) $EUC
  $stats = $null
  if($html){
    $rows = @(Rows $html)
    # 첫 표(차트용 hidden_table): 1·2·3학년, 특수, 순회 × (남, 여, 전체) 15칸. tbody에 <tr> 없이 칸만 있다
    $tb = [regex]::Match($html, '(?s)hidden_table.*?<tbody>(.*?)</tbody>').Groups[1].Value
    $sum = @([regex]::Matches($tb, '(?s)<td[^>]*>(.*?)</td>') | ForEach-Object { ($_.Groups[1].Value -replace '<[^>]+>', '' -replace '\s+', '') })
    if($sum.Count -ge 15){
      # 둘째 표: 반마다 한 줄 ('일반학과1-01(단식)' 등). 학년 칸에 숫자가 있는 줄 수 = 그 학년 학급 수
      $cls = @(0, 0, 0); $spCls = 0
      foreach($r in $rows){
        if($r.Count -lt 13 -or $r[0] -match '^(합계|학과\(과정|남$)' ){ continue }   # 머리글·합계 줄 ('일반학과1-01'은 반 이름이라 센다)
        for($g = 0; $g -lt 3; $g++){ if($r[3 + $g*3] -match '^\d+$'){ $cls[$g]++ } }
        if($r[12] -match '^\d+$'){ $spCls++ }
      }
      $byGrade = @(0..2 | ForEach-Object { [ordered]@{ boys = (Num $sum[$_*3]); girls = (Num $sum[$_*3+1]) } })
      $students = (Num $sum[2]) + (Num $sum[5]) + (Num $sum[8])
      $classes = $cls[0] + $cls[1] + $cls[2]
      # 직위별 교원 현황: 교장 ~ 강사까지 더한 총계 (휴직교원은 별도 줄이라 빠짐)
      $teachers = $null
      $th = Fetch "${code}_b08_$y.html" '/ei/pp/Pneipp_b08_s0p.do' (Form @{ GS_HANGMOK_CD = '08'; GS_HANGMOK_NO = '6-가'; GS_BURYU_CD = 'JG050'; JG_BURYU_CD = 'JG060'; JG_HANGMOK_CD = '22'; SHL_IDF_CD = $id; JG_YEAR = $y; JG_YEAR2 = $y; CHOSEN_JG_YEAR = $y; PRE_JG_YEAR = $y }) $EUC
      if($th){
        $tr = @(Rows $th) | Where-Object { $_[0] -like '합계*' -and $_.Count -ge 15 } | Select-Object -First 1
        if($tr){ $teachers = Num $tr[14] }
      }
      $stats = [ordered]@{
        year = $STATS_YEAR; students = $students; classes = $classes; teachers = $teachers
        perClass = $(if($classes){ [math]::Round($students / $classes, 1) } else { $null })
        classesByGrade = $cls; byGrade = $byGrade
        special = [ordered]@{ classes = $spCls; students = (Num $sum[11]) }
      }
      $nStats++
    }
  }
  $s | Add-Member -NotePropertyName stats -NotePropertyValue $stats -Force

  # ---- 졸업생의 진로 현황 (최근 3개 공시연도)
  $career = @()
  if($s.HS_SC_NM -eq '특성화고'){
    $majors = $null
    foreach($cy in $CAREER_YEARS){
      $y = "$cy"
      $html = Fetch "${code}_b64_$y.html" '/ei/pp/Pneipp_b64_s0p.do' (Form @{ GS_HANGMOK_CD = '64'; GS_HANGMOK_NO = '13-라'; GS_BURYU_CD = 'JG040'; JG_BURYU_CD = 'JG130'; JG_HANGMOK_CD = '53'; SHL_IDF_CD = $id; JG_YEAR = $y; JG_YEAR2 = $y; CHOSEN_JG_YEAR = $y; PRE_JG_YEAR = $y }) $EUC
      if(-not $html){ continue }
      $sel = [regex]::Match($html, '(?s)<option[^>]*selected[^>]*>(.*?)</option>').Groups[1].Value
      if($sel -and $sel -notmatch $y){ continue }
      $rows = @(Rows $html)
      # 합계 줄: 졸업자, 진학(전문대, 대학교, 계), 취업자, 공식 취업률, 입대자, 제외인정자, 미취업자
      $row = $rows | Where-Object { $_[0] -eq '합계' -and $_.Count -ge 10 } | Select-Object -First 1
      if(-not $row){ continue }
      $career += [ordered]@{
        year = $cy; voc = $true; grads = (Num $row[1]); college2 = (Num $row[2]); college4 = (Num $row[3]); abroad = 0
        advance = (Num $row[4]); job = (Num $row[5]); jobRate = [double]$row[6]
        army = (Num $row[7]); exempt = (Num $row[8]); unemployed = (Num $row[9])
        etc = (Num $row[7]) + (Num $row[8]) + (Num $row[9])
      }
      # 학과별 (가장 최근 연도만): 계열, 학과, 성별, 졸업자, 전문대, 대학교, 진학 계, 취업자, 취업률, 입대자, 제외인정자, 미취업자 → 남녀 합산
      if(-not $majors){
        $m = [ordered]@{}
        foreach($r in $rows){
          if($r.Count -lt 12 -or $r[2] -notmatch '^(남|여)$'){ continue }
          if(-not $m.Contains($r[1])){ $m[$r[1]] = [ordered]@{ name = $r[1]; field = $r[0]; grads = 0; advance = 0; job = 0; army = 0; exempt = 0 } }
          $x = $m[$r[1]]; $x.grads += Num $r[3]; $x.advance += Num $r[6]; $x.job += Num $r[7]; $x.army += Num $r[9]; $x.exempt += Num $r[10]
        }
        $majors = [ordered]@{ year = $cy; list = @($m.Values) }
      }
    }
    $s | Add-Member -NotePropertyName majors -NotePropertyValue $majors -Force
  }
  foreach($cy in $(if($s.HS_SC_NM -eq '특성화고'){ @() } else { $CAREER_YEARS })){
    $y = "$cy"
    $html = Fetch "${code}_b06_$y.html" '/ei/pp/Pneipp_b06_s0p.do' (Form @{ GS_HANGMOK_CD = '06'; GS_HANGMOK_NO = '4-다'; GS_BURYU_CD = 'JG030'; JG_BURYU_CD = 'JG130'; JG_HANGMOK_CD = '52'; SHL_IDF_CD = $id; JG_YEAR = $y; JG_YEAR2 = $y; CHOSEN_JG_YEAR = $y; PRE_JG_YEAR = $y }) $EUC
    if(-not $html){ continue }
    # 공시연도가 화면에 실제로 있는지 확인 (없는 연도를 요청하면 최근 연도가 대신 나옴)
    $sel = [regex]::Match($html, '(?s)<option[^>]*selected[^>]*>(.*?)</option>').Groups[1].Value
    if($sel -and $sel -notmatch $y){ continue }
    $row = @(Rows $html) | Where-Object { $_[0] -eq '합계' -and $_.Count -ge 10 } | Select-Object -First 1
    if(-not $row){ continue }
    # 합계 줄: 졸업자, 진학(전문대, 대학교, 국외, 진학 중 취업 2칸), 진학 계, 취업자, 기타
    $career += [ordered]@{
      year = $cy; grads = (Num $row[1]); college2 = (Num $row[2]); college4 = (Num $row[3]); abroad = (Num $row[4])
      advance = (Num $row[7]); job = (Num $row[8]); etc = (Num $row[9])
    }
  }
  if($career.Count){ $nCareer++ }
  $s | Add-Member -NotePropertyName career -NotePropertyValue @($career) -Force
}
$data | Add-Member -NotePropertyName statsUpdated -NotePropertyValue (Get-Date -Format 'yyyy-MM-dd') -Force
[IO.File]::WriteAllText($outFile, ($data | ConvertTo-Json -Depth 8 -Compress), $UTF)

"학생수 합침: ${nStats}개교, 진로 현황 합침: ${nCareer}개교"
if($skipped.Count){ "학교알리미에 없어 건너뜀: " + ($skipped -join ', ') }
