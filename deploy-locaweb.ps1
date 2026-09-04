param(
  [string]$CommitMessage = "Corrige SEO remove mensagens antigas e publica JVFoods na Locaweb"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectPath = $PSScriptRoot
if (-not $ProjectPath) {
  $ProjectPath = Split-Path -Parent $MyInvocation.MyCommand.Path
}

Set-Location $ProjectPath

$FtpHosts = @(
  "ftp.jvfoods.com.br",
  "ftp.jvfoods1.hospedagemdesites.ws"
)
$FtpUser = "jvfoods1"
$RemotePath = "/public_html"

function Write-Step {
  param([string]$Message)
  Write-Host $Message -ForegroundColor Cyan
}

function Normalize-Text {
  param([string]$Text)

  if ([string]::IsNullOrEmpty($Text)) {
    return ""
  }

  $normalized = $Text.Normalize([System.Text.NormalizationForm]::FormD)
  $builder = New-Object System.Text.StringBuilder

  foreach ($ch in $normalized.ToCharArray()) {
    $category = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
    if ($category -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
      [void]$builder.Append($ch)
    }
  }

  return $builder.ToString().ToLowerInvariant()
}

function Assert-FileExists {
  param([string]$RelativePath)

  if (-not (Test-Path -LiteralPath $RelativePath)) {
    throw "Arquivo obrigatorio nao encontrado: $RelativePath"
  }
}

function Get-FtpPassword {
  $envPassword = $env:JVFOODS_FTP_PASSWORD
  if (-not [string]::IsNullOrWhiteSpace($envPassword)) {
    return $envPassword
  }

  $securePassword = Read-Host "Informe a senha do FTP" -AsSecureString
  $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
  try {
    return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
  } finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
  }
}

function Write-RequiredSeoFiles {
  $robotsContent = @"
User-agent: *
Allow: /

Sitemap: https://jvfoods.com.br/sitemap.xml
"@

  $sitemapDate = Get-Date -Format "yyyy-MM-dd"
  $sitemapContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://jvfoods.com.br/</loc>
    <lastmod>$sitemapDate</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
</urlset>
"@

  $htaccessContent = @"
RewriteEngine On

RewriteCond %{HTTPS} !=on
RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

RewriteCond %{HTTP_HOST} ^www\.jvfoods\.com\.br$ [NC]
RewriteRule ^ https://jvfoods.com.br%{REQUEST_URI} [L,R=301]

<IfModule mod_headers.c>
  Header set X-Robots-Tag "index, follow"
</IfModule>
"@

  Set-Content -LiteralPath "robots.txt" -Value $robotsContent -Encoding ASCII
  Set-Content -LiteralPath "sitemap.xml" -Value $sitemapContent -Encoding ASCII
  Set-Content -LiteralPath ".htaccess" -Value $htaccessContent -Encoding ASCII
}

function Assert-IndexSeo {
  $index = Get-Content -LiteralPath "index.html" -Raw -Encoding UTF8
  $normalizedIndex = Normalize-Text $index

  if ($index -notmatch '(?is)<title>') {
    throw "Deploy bloqueado: tag title nao encontrada."
  }

  if ($normalizedIndex -notmatch 'jvfoods') {
    throw "Deploy bloqueado: nome JVFoods nao encontrado no index.html."
  }

  if ($normalizedIndex -notmatch 'carnes de qualidade') {
    throw "Deploy bloqueado: expressao Carnes de Qualidade nao encontrada no index.html."
  }

  if ($normalizedIndex -notmatch 'conveniencia') {
    throw "Deploy bloqueado: palavra Conveniencia nao encontrada no index.html."
  }

  if ($normalizedIndex -match 'convivencia') {
    throw "Deploy bloqueado: palavra incorreta Convivencia encontrada no index.html. Use Conveniencia."
  }

  foreach ($blocked in @(
    "site em construcao",
    "preparando uma nova experiencia digital",
    "distribuicao de alimentos, atacado e solucoes para empresas"
  )) {
    if ($normalizedIndex -match [regex]::Escape($blocked)) {
      throw "Deploy bloqueado: conteudo antigo encontrado em index.html -> $blocked"
    }
  }

  if ($normalizedIndex -notmatch 'https://jvfoods\.com\.br/') {
    throw "Deploy bloqueado: canonical ou URL definitiva nao encontrada no index.html."
  }

  if ($normalizedIndex -notmatch '5511940283463') {
    throw "Deploy bloqueado: WhatsApp oficial nao encontrado no index.html."
  }

  if ($normalizedIndex -notmatch 'name="robots"\s+content="index,\s*follow"') {
    throw "Deploy bloqueado: meta robots index, follow nao encontrada."
  }

  if ($normalizedIndex -match 'name="robots"[^>]*noindex') {
    throw "Deploy bloqueado: noindex encontrado em meta robots do index.html."
  }

  if ($normalizedIndex -match 'name="robots"[^>]*nofollow') {
    throw "Deploy bloqueado: nofollow encontrado em meta robots do index.html."
  }

  if ($normalizedIndex -notmatch 'meta name="description" content="a jvfoods oferece carnes de qualidade, produtos selecionados e solucoes de conveniencia alimentar com praticidade, confianca e atendimento pelo whatsapp\.?"') {
    throw "Deploy bloqueado: meta description definitiva nao encontrada."
  }

  if ($normalizedIndex -notmatch 'meta property="og:title" content="jvfoods \| carnes de qualidade"') {
    throw "Deploy bloqueado: og:title nao encontrado."
  }

  if ($normalizedIndex -notmatch 'meta property="og:description" content="conveniencia, qualidade e praticidade em produtos alimenticios selecionados\."') {
    throw "Deploy bloqueado: og:description nao encontrado."
  }

  if ($normalizedIndex -notmatch 'meta property="og:type" content="website"') {
    throw "Deploy bloqueado: og:type nao encontrado."
  }

  if ($normalizedIndex -notmatch 'meta property="og:url" content="https://jvfoods\.com\.br/"') {
    throw "Deploy bloqueado: og:url nao encontrado."
  }

  if ($normalizedIndex -notmatch 'meta name="twitter:card" content="summary_large_image"') {
    throw "Deploy bloqueado: twitter:card nao encontrado."
  }

  if ($normalizedIndex -notmatch 'meta name="twitter:title" content="jvfoods \| carnes de qualidade"') {
    throw "Deploy bloqueado: twitter:title nao encontrado."
  }

  if ($normalizedIndex -notmatch 'meta name="twitter:description" content="conveniencia, qualidade e praticidade em produtos alimenticios selecionados\."') {
    throw "Deploy bloqueado: twitter:description nao encontrado."
  }
}

function Assert-RobotsTxt {
  $robots = Get-Content -LiteralPath "robots.txt" -Raw -Encoding UTF8
  $normalizedRobots = Normalize-Text $robots

  if ($normalizedRobots -notmatch '^user-agent:\s*\*\s*allow:\s*/\s*sitemap:\s*https://jvfoods\.com\.br/sitemap\.xml\s*$') {
    throw "Deploy bloqueado: robots.txt nao esta no formato esperado."
  }

  if ($normalizedRobots -match 'disallow:\s*/') {
    throw "Deploy bloqueado: robots.txt nao pode conter Disallow: /."
  }

  if ($normalizedRobots -match '\bnoindex\b') {
    throw "Deploy bloqueado: robots.txt nao pode conter noindex."
  }

  if ($normalizedRobots -match '\bnofollow\b') {
    throw "Deploy bloqueado: robots.txt nao pode conter nofollow."
  }
}

function Assert-SitemapXml {
  $sitemap = Get-Content -LiteralPath "sitemap.xml" -Raw -Encoding UTF8
  $normalizedSitemap = Normalize-Text $sitemap

  if ($normalizedSitemap -notmatch '<loc>\s*https://jvfoods\.com\.br/\s*</loc>') {
    throw "Deploy bloqueado: sitemap.xml nao aponta para https://jvfoods.com.br/."
  }

  if ($normalizedSitemap -notmatch '<lastmod>\d{4}-\d{2}-\d{2}</lastmod>') {
    throw "Deploy bloqueado: sitemap.xml nao contem lastmod no formato YYYY-MM-DD."
  }
}

function Assert-NoOldGoogleSnippet {
  $blockedPatterns = @(
    "site em construcao",
    "preparando uma nova experiencia digital",
    "distribuicao de alimentos, atacado e solucoes para empresas",
    "convivencia",
    "noindex"
  )

  $allowedExtensions = @(".html", ".htm", ".txt", ".xml", ".json", ".js", ".css", ".webmanifest")
  $files = Get-ChildItem -LiteralPath $ProjectPath -Recurse -File | Where-Object {
    $_.FullName -notmatch '\\(\.git|\.idea|node_modules|dist)(\\|$)' -and (
      $allowedExtensions -contains $_.Extension.ToLowerInvariant() -or $_.Name -eq '.htaccess'
    )
  }

  $hits = New-Object System.Collections.Generic.List[object]

  foreach ($file in $files) {
    $lines = Get-Content -LiteralPath $file.FullName -ErrorAction SilentlyContinue
    if ($null -eq $lines) {
      continue
    }

    for ($i = 0; $i -lt $lines.Count; $i++) {
      $line = $lines[$i]
      $normalizedLine = Normalize-Text $line
      foreach ($pattern in $blockedPatterns) {
        if ($normalizedLine -like "*$pattern*") {
          $hits.Add([pscustomobject]@{
            Path = $file.FullName
            LineNumber = $i + 1
            Line = $line
          }) | Out-Null
          break
        }
      }
    }
  }

  if ($hits.Count -gt 0) {
    Write-Host "Mensagem antiga encontrada:" -ForegroundColor Red
    foreach ($hit in $hits) {
      Write-Host "$($hit.Path):$($hit.LineNumber) - $($hit.Line)" -ForegroundColor Red
    }
    throw "Deploy bloqueado: mensagem antiga do Google ainda existe no projeto."
  }
}

function New-DeployStage {
  param([string]$StageRoot)

  if (Test-Path -LiteralPath $StageRoot) {
    Remove-Item -LiteralPath $StageRoot -Recurse -Force
  }

  New-Item -ItemType Directory -Path $StageRoot | Out-Null

  $copyItems = @(
    "index.html",
    "404.html",
    "assets",
    "css",
    "js",
    "favicon.ico",
    "icon.png",
    "icon.svg",
    "robots.txt",
    "sitemap.xml",
    "site.webmanifest",
    "CNAME",
    ".htaccess"
  )

  foreach ($item in $copyItems) {
    $source = Join-Path $ProjectPath $item
    if (Test-Path -LiteralPath $source) {
      Copy-Item -LiteralPath $source -Destination $StageRoot -Recurse -Force
    }
  }

  $licensePath = Join-Path $ProjectPath "LICENSE.txt"
  if (Test-Path -LiteralPath $licensePath) {
    Copy-Item -LiteralPath $licensePath -Destination $StageRoot -Force
  }
}

function Invoke-WinScpDeploy {
  param(
    [string]$WinScpPath,
    [string]$StageRoot,
    [string]$FtpPassword
  )

  $scriptPath = Join-Path $env:TEMP "jvfoods-winscp-deploy.txt"
  $lastError = $null

  try {
    foreach ($host in $FtpHosts) {
      $winscpScript = @"
option batch abort
option confirm off
option transfer binary
open ftp://$FtpUser@$host/ -password="%1%"
cd $RemotePath
synchronize remote -delete "$StageRoot" .
close
exit
"@

      Set-Content -Path $scriptPath -Value $winscpScript -Encoding ASCII
      & $WinScpPath "/ini=nul" "/script=$scriptPath" "/parameter" $FtpPassword

      if ($LASTEXITCODE -eq 0) {
        return $host
      }

      $lastError = "WinSCP returned code $LASTEXITCODE on host $host"
    }
  } finally {
    if (Test-Path -LiteralPath $scriptPath) {
      Remove-Item -LiteralPath $scriptPath -Force
    }
  }

  if ($lastError) {
    throw $lastError
  }

  throw "Failed to update FTP."
}

Write-Step "Validating required files and updating SEO..."

foreach ($file in @(
  "index.html",
  "404.html",
  "robots.txt",
  "sitemap.xml",
  "site.webmanifest",
  "favicon.ico",
  "icon.png",
  "icon.svg",
  "CNAME"
)) {
  Assert-FileExists $file
}

foreach ($folder in @("assets", "css", "js")) {
  if (-not (Test-Path -LiteralPath $folder)) {
    throw "Required folder not found: $folder"
  }
}

Write-RequiredSeoFiles
Assert-IndexSeo
Assert-RobotsTxt
Assert-SitemapXml
Assert-NoOldGoogleSnippet

Write-Host "SEO definitivo validado." -ForegroundColor Green
Write-Host "Convivencia corrigido para Conveniencia." -ForegroundColor Green
Write-Host "Mensagens antigas nao encontradas." -ForegroundColor Green
Write-Host "robots.txt atualizado." -ForegroundColor Green
Write-Host "sitemap.xml atualizado." -ForegroundColor Green
Write-Host ".htaccess atualizado." -ForegroundColor Green

Write-Step "Executing Git..."
git status
git add .

git diff --cached --quiet
$hasStagedChanges = ($LASTEXITCODE -ne 0)

if ($hasStagedChanges) {
  git commit -m $CommitMessage
  Write-Host "Commit created." -ForegroundColor Green
} else {
  Write-Host "Nenhuma alteracao local para commit." -ForegroundColor Yellow
}

git push origin main
Write-Host "Commit/push concluido." -ForegroundColor Green

Write-Step "Preparing FTP upload..."

$winscpCandidates = @(
  "C:\Program Files (x86)\WinSCP\WinSCP.com",
  "C:\Program Files\WinSCP\WinSCP.com"
)

$WinScp = $winscpCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $WinScp) {
  throw "WinSCP nao encontrado. Instale o WinSCP ou ajuste o caminho no script."
}

$ftpPassword = Get-FtpPassword
$stageRoot = Join-Path $env:TEMP "jvfoods-deploy-stage"
New-DeployStage -StageRoot $stageRoot

try {
  $activeHost = Invoke-WinScpDeploy -WinScpPath $WinScp -StageRoot $stageRoot -FtpPassword $ftpPassword
  Write-Host "FTP published in /public_html." -ForegroundColor Green
  Write-Host "Clean production." -ForegroundColor Green
  Write-Host "Server updated with: $activeHost" -ForegroundColor Green
} finally {
  if (Test-Path -LiteralPath $stageRoot) {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
  }
}

Write-Host "Google may keep showing the old result for a few days because of cache/indexing." -ForegroundColor Yellow
Write-Host "Open Google Search Console, inspect https://jvfoods.com.br/ and request indexing." -ForegroundColor Yellow
Write-Host "Also submit the sitemap: https://jvfoods.com.br/sitemap.xml" -ForegroundColor Yellow
