$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

$python = $null
$pythonVersion = $null

foreach ($venvName in @('.venv', '.venv-3.11', '.venv-3.12')) {
    $candidateVenvPython = Join-Path (Join-Path $scriptDir $venvName) 'Scripts\python.exe'
    if (Test-Path $candidateVenvPython) {
        try {
            $candidateVersion = (& $candidateVenvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null | Select-Object -First 1)
            if ($candidateVersion -in @('3.11', '3.12')) {
                $python = $candidateVenvPython
                $pythonVersion = $candidateVersion
                break
            }
        } catch {}
    }
}

if ([string]::IsNullOrWhiteSpace($python)) {
    $pythonLauncher = Get-Command py -ErrorAction SilentlyContinue
    foreach ($version in @('3.11', '3.12')) {
        if ($pythonLauncher) {
            try {
                $candidate = (& $pythonLauncher.Source "-$version" -c "import sys; print(sys.executable)" 2>$null | Select-Object -First 1)
                if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                    $python = $candidate
                    $pythonVersion = $version
                    break
                }
            } catch {}
        }
    }
}

if ([string]::IsNullOrWhiteSpace($python)) {
    throw "Python 3.11 or 3.12 is required. Install one of them and re-run this script."
}

$venvDir = Join-Path $scriptDir '.venv'
$venvPython = Join-Path $venvDir 'Scripts\python.exe'
if (Test-Path $venvPython) {
    $existingVersion = (& $venvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null | Select-Object -First 1)
    if ($LASTEXITCODE -ne 0 -or $existingVersion -ne $pythonVersion) {
        $venvDir = Join-Path $scriptDir ".venv-$pythonVersion"
        $venvPython = Join-Path $venvDir 'Scripts\python.exe'
    }
}

if (-not (Test-Path $venvPython)) {
    & $python -m venv $venvDir
}

if (-not (Test-Path $venvPython)) {
    throw "The virtual environment was not created correctly."
}

& $venvPython -m pip install --upgrade pip
& $venvPython -m pip install -r requirements.txt

$dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
if ($dockerCommand) {
    $docker = $dockerCommand.Source
} else {
    $docker = Join-Path $env:ProgramFiles 'Docker\Docker\resources\bin\docker.exe'
    if (-not (Test-Path $docker)) {
        throw "Docker Desktop is not installed. Install it, then re-run this script."
    }
}

$dockerBin = Split-Path -Parent $docker
$env:PATH = "$dockerBin;$env:PATH"

$dockerDesktop = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
function Test-DockerEngine {
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $docker info *> $null
        return ($LASTEXITCODE -eq 0)
    } finally {
        $ErrorActionPreference = $previousPreference
    }
}

if (-not (Test-DockerEngine)) {
    if (-not (Test-Path $dockerDesktop)) {
        throw "Docker Desktop is installed, but its engine is not running. Start Docker Desktop and re-run this script."
    }
    Start-Process $dockerDesktop

    $engineReady = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        Start-Sleep -Seconds 2
        if (Test-DockerEngine) {
            $engineReady = $true
            break
        }
    }
    if (-not $engineReady) {
        throw "Docker Desktop did not start its engine within 2 minutes. Open Docker Desktop, wait until it is running, then re-run this script."
    }
}

& $docker compose up -d
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose failed to start MinIO and Qdrant. Check Docker Desktop and the output above."
}

# Optional: load files from the local documents directory into MinIO.
# & $venvPython -m app.storage

& $venvPython -m uvicorn app.api:app --reload
