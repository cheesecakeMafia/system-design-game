#
# setup.ps1 — System Design Mastery course setup (Windows)
#
# Clones external dependencies into deps/:
#   - System Design Primer (textbook)
#   - Server Survival (browser game)
#
# Safe to run multiple times. Does not require admin privileges.

$ErrorActionPreference = "Stop"

$DepsDir = "deps"
$PrimerRepo = "https://github.com/donnemartin/system-design-primer.git"
$PrimerDir = Join-Path $DepsDir "system-design-primer"
$GameRepo = "https://github.com/pshenok/server-survival.git"
$GameDir = Join-Path $DepsDir "server-survival"

# --- Check prerequisites ---

try {
    git --version | Out-Null
} catch {
    Write-Error "git is not installed. Install git from https://git-scm.com/downloads and try again."
    exit 1
}

# --- Create deps directory ---

if (-not (Test-Path $DepsDir)) {
    New-Item -ItemType Directory -Path $DepsDir | Out-Null
}

# --- Clone System Design Primer ---

if (Test-Path $PrimerDir) {
    Write-Host "System Design Primer already exists at $PrimerDir — skipping."
} else {
    Write-Host "Cloning System Design Primer..."
    git clone $PrimerRepo $PrimerDir
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to clone System Design Primer. Check your internet connection and try again."
        exit 1
    }
    Write-Host "System Design Primer cloned successfully."
}

# --- Clone Server Survival ---

if (Test-Path $GameDir) {
    Write-Host "Server Survival already exists at $GameDir — skipping."
} else {
    Write-Host "Cloning Server Survival..."
    git clone $GameRepo $GameDir
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to clone Server Survival. Check your internet connection and try again."
        exit 1
    }
    Write-Host "Server Survival cloned successfully."
}

# --- Done ---

Write-Host ""
Write-Host "Setup complete!"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Open course/START-HERE.md to start the course"
Write-Host "  2. Play Server Survival: open deps/server-survival/index.html in your browser"
Write-Host "  3. Read the textbook: open deps/system-design-primer/README.md"
