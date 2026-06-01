# Render Quarto site, working around a bug in the bundled quarto.cmd that
# breaks when the install path contains spaces (Program Files).
#
# Usage:
#   .\render.ps1                       # render full site
#   .\render.ps1 services.qmd          # render a single file
#   .\render.ps1 countries/Botswana.qmd
#
# The wrapper references %QUARTO_DENO% unquoted; cmd then word-splits the
# "C:\Program Files\..." path. We pre-set QUARTO_DENO to its 8.3 short path
# and invoke quarto.cmd through its short path too.
#
# Also kills leftover deno/quarto/Rscript/pandoc processes from interrupted
# prior runs, which otherwise hold ~GB of virtual memory each and OOM the
# next render. Interactive R sessions (Rterm/Rgui) are NOT touched.

$ErrorActionPreference = 'Stop'

# Reap leftover render processes (Rscript is the non-interactive one;
# Rterm/Rgui are user sessions and intentionally left alone).
$stuck = Get-Process -Name deno, quarto, Rscript, pandoc -ErrorAction SilentlyContinue
if ($stuck) {
  Write-Host ("Killing {0} stuck render process(es): {1}" -f $stuck.Count, (($stuck | ForEach-Object { "$($_.ProcessName)($($_.Id))" }) -join ', ')) -ForegroundColor Yellow
  $stuck | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Milliseconds 500
}

$quartoCandidates = @(
  "C:\Program Files\Positron\resources\app\quarto\bin\quarto.cmd",
  "C:\Program Files\RStudio\resources\app\bin\quarto\bin\quarto.cmd",
  "$env:LOCALAPPDATA\Programs\Quarto\bin\quarto.cmd",
  "C:\Program Files\Quarto\bin\quarto.cmd"
)
$quartoLong = $quartoCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $quartoLong) { throw "No quarto.cmd found in known locations." }

$rscriptCandidates = @(
  "C:\Program Files\R\R-4.6.0\bin\Rscript.exe",
  "C:\Program Files\R\R-4.5.3\bin\Rscript.exe"
)
$rscript = $rscriptCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($rscript) {
  $env:PATH = "$(Split-Path $rscript);$env:PATH"
}

# Resolve 8.3 short paths to dodge the space-in-path bug
$fso = New-Object -ComObject Scripting.FileSystemObject
$quartoShort = $fso.GetFile($quartoLong).ShortPath
$denoLong = Join-Path (Split-Path $quartoLong) "tools\x86_64\deno.exe"
if (-not (Test-Path $denoLong)) { throw "Bundled deno.exe not found at $denoLong" }
$env:QUARTO_DENO = $fso.GetFile($denoLong).ShortPath

Write-Host "Using quarto at $quartoLong" -ForegroundColor Cyan
& $quartoShort render @args
exit $LASTEXITCODE
