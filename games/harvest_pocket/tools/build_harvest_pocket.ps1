param(
    [Alias('RccPath')]
    [string]$Rcc = '',
    [string]$QmlLint = '',
    [switch]$SkipQmlLint,
    [switch]$VerboseQmlLint
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Set-Location $Root

function Fail {
    param([string]$Message, [int]$Code = 1)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    exit $Code
}

function Find-Python {
    # IMPORTANT: do not use -like 'py*' here.  "python.exe" also starts with
    # "py", which would incorrectly add the Windows py-launcher-only -3 flag.
    $candidates = @(
        @{ Name = 'python.exe'; Args = @() },
        @{ Name = 'python';     Args = @() },
        @{ Name = 'py.exe';    Args = @('-3') },
        @{ Name = 'py';        Args = @('-3') }
    )

    foreach ($candidate in $candidates) {
        $cmd = Get-Command ([string]$candidate.Name) -ErrorAction SilentlyContinue
        if ($null -eq $cmd -or [string]::IsNullOrWhiteSpace([string]$cmd.Source)) { continue }

        $exe = [string]$cmd.Source
        $prefix = @($candidate.Args)
        $probeArgs = @($prefix) + @('-c', 'import sys; raise SystemExit(0 if sys.version_info.major == 3 else 7)')

        try {
            $null = & $exe @probeArgs 2>&1
            $probeCode = $LASTEXITCODE
        } catch {
            $probeCode = 99
        }

        if ($probeCode -eq 0) {
            return @{ Exe = $exe; Args = $prefix; DisplayName = [string]$candidate.Name }
        }
    }

    Fail 'Python 3 is required. Install Python 3 or make python.exe/py.exe available on PATH.' 3
}

function Resolve-ExistingCommandOrPath {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    try {
        if (Test-Path -LiteralPath $Value -PathType Leaf) {
            return [IO.Path]::GetFullPath($Value)
        }
    } catch {}
    $cmd = Get-Command $Value -ErrorAction SilentlyContinue
    if ($null -ne $cmd -and -not [string]::IsNullOrWhiteSpace([string]$cmd.Source)) {
        return [IO.Path]::GetFullPath([string]$cmd.Source)
    }
    return ''
}

function Get-KitPriority {
    param([string]$Kit)
    switch -Regex ($Kit.ToLowerInvariant()) {
        '^llvm-mingw_64$' { return 0 }
        '^mingw_64$' { return 10 }
        '^msvc2022_64$' { return 20 }
        '^msvc.*_64$' { return 30 }
        default { return 100 }
    }
}

function Resolve-Rcc {
    param([string]$Explicit)

    # Explicit choice always wins.
    if (-not [string]::IsNullOrWhiteSpace($Explicit)) {
        $resolved = Resolve-ExistingCommandOrPath $Explicit
        if ([string]::IsNullOrWhiteSpace($resolved)) {
            Fail "Explicit Qt rcc was not found: $Explicit" 4
        }
        return $resolved
    }

    # Project/user overrides. The first valid override is authoritative.
    foreach ($value in @($env:LMG_RCC, $env:RCC, $env:QT_RCC)) {
        $resolved = Resolve-ExistingCommandOrPath $value
        if (-not [string]::IsNullOrWhiteSpace($resolved)) { return $resolved }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:QTDIR)) {
        $resolved = Resolve-ExistingCommandOrPath (Join-Path $env:QTDIR 'bin\rcc.exe')
        if (-not [string]::IsNullOrWhiteSpace($resolved)) { return $resolved }
    }

    # Respect an explicitly configured PATH before scanning installed Qt kits.
    foreach ($name in @('rcc.exe','rcc')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $cmd -and -not [string]::IsNullOrWhiteSpace([string]$cmd.Source)) {
            return [IO.Path]::GetFullPath([string]$cmd.Source)
        }
    }

    # Harvest Pocket is a single project: auto-pick one real Qt desktop kit instead
    # of failing merely because several Qt versions/toolchains are installed.
    $roots = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        $roots.Add((Join-Path $env:USERPROFILE 'Qt'))
    }
    $roots.Add('D:\Qt')
    $roots.Add('C:\Qt')

    $found = @()
    foreach ($base in @($roots | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $base -PathType Container)) { continue }
        $versionDirs = @(Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d+\.\d+(?:\.\d+)?$' })
        foreach ($versionDir in $versionDirs) {
            $versionObj = $null
            try { $versionObj = [Version]$versionDir.Name } catch { continue }
            $kitDirs = @(Get-ChildItem -LiteralPath $versionDir.FullName -Directory -ErrorAction SilentlyContinue)
            foreach ($kitDir in $kitDirs) {
                $candidate = Join-Path $kitDir.FullName 'bin\rcc.exe'
                if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
                $found += [PSCustomObject]@{
                    Path = [IO.Path]::GetFullPath($candidate)
                    Version = $versionObj
                    Kit = $kitDir.Name
                    KitPriority = (Get-KitPriority $kitDir.Name)
                }
            }
        }
    }

    $found = @($found | Sort-Object Path -Unique)
    if ($found.Count -eq 0) {
        Fail 'Qt rcc not found. Pass -Rcc, set LMG_RCC/RCC/QT_RCC/QTDIR, put rcc on PATH, or install a Qt desktop kit.' 4
    }

    $ranked = @($found | Sort-Object `
        @{Expression={$_.Version}; Descending=$true}, `
        @{Expression={$_.KitPriority}}, `
        @{Expression={$_.Path}})
    $selected = $ranked[0]

    if ($ranked.Count -gt 1) {
        Write-Host ("[INFO] Multiple Qt rcc installations found; selected Qt {0} / {1}:" -f $selected.Version, $selected.Kit) -ForegroundColor DarkYellow
        Write-Host ("       " + $selected.Path) -ForegroundColor DarkYellow
        Write-Host '[INFO] Override with build.bat -Rcc <path> or LMG_RCC if another kit is required.' -ForegroundColor DarkYellow
    }
    return [string]$selected.Path
}

function Resolve-QmlLint {
    param([string]$Explicit, [string]$RccPath)
    if (-not [string]::IsNullOrWhiteSpace($Explicit)) {
        $resolved = Resolve-ExistingCommandOrPath $Explicit
        if ([string]::IsNullOrWhiteSpace($resolved)) { Fail "Explicit qmllint was not found: $Explicit" 8 }
        return $resolved
    }
    $nearRcc = Join-Path (Split-Path $RccPath -Parent) 'qmllint.exe'
    if (Test-Path -LiteralPath $nearRcc -PathType Leaf) { return $nearRcc }
    foreach ($name in @('qmllint.exe','qmllint')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $cmd -and -not [string]::IsNullOrWhiteSpace([string]$cmd.Source)) { return [string]$cmd.Source }
    }
    return ''
}

function Invoke-PythonScript {
    param($Python, [string]$Script)
    $exe = [string]$Python.Exe
    $invokeArgs = @($Python.Args) + @($Script)
    & $exe @invokeArgs
    $code = $LASTEXITCODE
    if ($code -ne 0) { Fail "$Script failed with exit code $code." $code }
}

if (-not (Test-Path -LiteralPath 'manifest.json' -PathType Leaf)) { Fail 'manifest.json missing.' 2 }
if (-not (Test-Path -LiteralPath 'mod.qrc' -PathType Leaf)) { Fail 'mod.qrc missing.' 2 }
try { $Manifest = Get-Content -LiteralPath 'manifest.json' -Raw -Encoding UTF8 | ConvertFrom-Json }
catch { Fail ("manifest.json could not be parsed: " + $_.Exception.Message) 2 }
if ([string]$Manifest.id -ne 'harvest_pocket') { Fail 'Manifest id must be harvest_pocket.' 6 }
$Version = [string]$Manifest.version
if ($Version -notmatch '^\d+\.\d+\.\d+$') { Fail "Invalid SemVer: $Version" 6 }

$Python = Find-Python
$RccPath = Resolve-Rcc $Rcc
$QmlLintPath = Resolve-QmlLint $QmlLint $RccPath

Write-Host ''
Write-Host '==================================================' -ForegroundColor DarkYellow
Write-Host (" Harvest Pocket Build - v{0}" -f $Version) -ForegroundColor Yellow
Write-Host '==================================================' -ForegroundColor DarkYellow
Write-Host "Root : $Root"
$PythonDisplay = [string]$Python.Exe
if (@($Python.Args).Count -gt 0) { $PythonDisplay += ' ' + (@($Python.Args) -join ' ') }
Write-Host "Python: $PythonDisplay"
Write-Host "RCC  : $RccPath"
if (-not [string]::IsNullOrWhiteSpace($QmlLintPath)) { Write-Host "Lint : $QmlLintPath" }
Write-Host ''

function Invoke-NativeCaptured {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [string[]]$ArgumentList = @()
    )

    # Windows PowerShell 5.1 promotes native stderr records to NativeCommandError
    # when stderr is redirected through the PowerShell error stream. Qt's qmllint
    # writes ordinary warnings to stderr, so invoking it with `2>&1` can terminate
    # the build even when qmllint itself exits with code 0. Capture native stdout
    # and stderr at the process level instead, then trust the process exit code.
    $tempBase = Join-Path ([IO.Path]::GetTempPath()) ("harvest-native-{0}" -f [Guid]::NewGuid().ToString('N'))
    $stdoutPath = $tempBase + '.out.txt'
    $stderrPath = $tempBase + '.err.txt'

    try {
        $escapedArgs = @()
        foreach ($argValue in @($ArgumentList)) {
            $arg = [string]$argValue
            if ($arg -match '[\s"]') {
                $escapedArgs += ('"' + $arg.Replace('"', '\"') + '"')
            } else {
                $escapedArgs += $arg
            }
        }

        $process = Start-Process -FilePath $FilePath `
            -ArgumentList $escapedArgs `
            -Wait -PassThru -NoNewWindow `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath

        $output = @()
        if (Test-Path -LiteralPath $stdoutPath -PathType Leaf) {
            $output += @(Get-Content -LiteralPath $stdoutPath -ErrorAction SilentlyContinue)
        }
        if (Test-Path -LiteralPath $stderrPath -PathType Leaf) {
            $output += @(Get-Content -LiteralPath $stderrPath -ErrorAction SilentlyContinue)
        }

        return [pscustomobject]@{
            ExitCode = [int]$process.ExitCode
            Output = @($output)
        }
    } finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

if (-not $SkipQmlLint) {
    if (-not [string]::IsNullOrWhiteSpace($QmlLintPath)) {
        Write-Host '[QML] qmllint preflight'
        $qmlFiles = @(Get-ChildItem -LiteralPath $Root -Filter '*.qml' -File | Sort-Object Name)
        $qmlWarningCount = 0
        foreach ($qmlFile in $qmlFiles) {
            $lintResult = Invoke-NativeCaptured -FilePath $QmlLintPath -ArgumentList @('--max-warnings', '-1', $qmlFile.FullName)
            $lintOutput = @($lintResult.Output)
            $lintCode = [int]$lintResult.ExitCode

            if ($lintCode -ne 0) {
                Write-Host ("[QML] qmllint output for {0}:" -f $qmlFile.Name) -ForegroundColor Red
                $lintOutput | ForEach-Object { Write-Host ([string]$_) }
                Fail ("qmllint rejected {0} with exit code {1}." -f $qmlFile.Name, $lintCode) 9
            }

            $fileWarnings = @($lintOutput | Where-Object { ([string]$_) -match '^Warning:' }).Count
            $qmlWarningCount += $fileWarnings
            if ($VerboseQmlLint -and $lintOutput.Count -gt 0) {
                Write-Host ("[QML] {0}:" -f $qmlFile.Name) -ForegroundColor DarkGray
                $lintOutput | ForEach-Object { Write-Host ([string]$_) }
            }
        }
        if ($qmlWarningCount -gt 0) {
            Write-Host ("[QML] PASS: {0} files; {1} non-fatal warning lines suppressed. Use -VerboseQmlLint to print them." -f $qmlFiles.Count, $qmlWarningCount) -ForegroundColor DarkYellow
        } else {
            Write-Host ("[QML] PASS: {0} files; no warnings." -f $qmlFiles.Count) -ForegroundColor Green
        }
    } else {
        Write-Host '[WARN] qmllint not found; structural QML validation will still run.' -ForegroundColor Yellow
    }
}

Write-Host '[1/7] Manifest / source validation'
Invoke-PythonScript $Python 'tools\validate_package.py'
Write-Host '[2/7] Gameplay regression'
Invoke-PythonScript $Python 'tools\test_gameplay.py'
Write-Host '[3/7] Migration regression'
Invoke-PythonScript $Python 'tools\test_migration.py'
Write-Host '[4/7] Release-tree audit'
Invoke-PythonScript $Python 'tools\meta_audit.py'

$Dist = Join-Path $Root 'dist'
if (-not (Test-Path -LiteralPath $Dist -PathType Container)) { New-Item -ItemType Directory -Force -Path $Dist | Out-Null }
$Output = Join-Path $Dist ("harvest_pocket-{0}.rcc" -f $Version)
$HashFile = "$Output.sha256"
Get-ChildItem -LiteralPath $Dist -Filter 'harvest_pocket-*.rcc' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -ne $Output } | Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem -LiteralPath $Dist -Filter 'harvest_pocket-*.rcc.sha256' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -ne $HashFile } | Remove-Item -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $Output -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $HashFile -Force -ErrorAction SilentlyContinue

Write-Host '[5/7] RCC build'
$rccResult = Invoke-NativeCaptured -FilePath $RccPath -ArgumentList @('--binary', 'mod.qrc', '-o', $Output)
if ([int]$rccResult.ExitCode -ne 0) {
    @($rccResult.Output) | ForEach-Object { Write-Host ([string]$_) }
    Fail ("rcc failed with exit code {0}." -f [int]$rccResult.ExitCode) 20
}
if (-not (Test-Path -LiteralPath $Output -PathType Leaf)) { Fail "RCC output missing: $Output" 21 }
if ((Get-Item -LiteralPath $Output).Length -le 0) { Fail "RCC output is empty: $Output" 22 }

Write-Host '[6/7] SHA-256'
$hash = (Get-FileHash -LiteralPath $Output -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $HashFile -Value ("{0}  {1}" -f $hash, (Split-Path $Output -Leaf)) -Encoding ASCII

Write-Host '[7/7] Source release ZIP'
Invoke-PythonScript $Python 'tools\package_source.py'
Write-Host ''
Write-Host "[OK] $Output" -ForegroundColor Green
Write-Host "[OK] $HashFile" -ForegroundColor Green
exit 0
