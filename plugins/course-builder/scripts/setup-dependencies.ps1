# Windows bootstrap: chạy được trước khi máy có Git Bash.
# Không cài WSL nếu chưa có; mặc định chuẩn bị Git Bash để chạy plugin.
param([switch]$Check, [switch]$Help)
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host 'Cách dùng: powershell -NoProfile -ExecutionPolicy Bypass -File setup-dependencies.ps1 [-Check]'
    Write-Host 'Kiểm tra/cài Git Bash, curl, jq, OpenSSL và Node.js (kèm npx) bằng WinGet.'
    exit 0
}

function Refresh-ToolPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $extraPaths = @(
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links",
        "$env:ProgramFiles\Git\bin",
        "$env:ProgramFiles\OpenSSL-Win64\bin",
        "${env:ProgramFiles(x86)}\OpenSSL-Win32\bin"
    )
    $env:Path = (@($machinePath, $userPath, $env:Path) + $extraPaths) -join ';'
}

function Find-GitBash {
    $gitRoots = @("$env:ProgramFiles\Git", "${env:ProgramFiles(x86)}\Git", "$env:LOCALAPPDATA\Programs\Git")
    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($git) { $gitRoots += Split-Path (Split-Path $git.Source -Parent) -Parent }
    foreach ($root in $gitRoots) {
        $candidate = Join-Path $root 'bin\bash.exe'
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

function Install-Tool([string]$PackageId) {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw 'Không có WinGet. Cài/cập nhật App Installer từ Microsoft Store rồi chạy lại script.'
    }
    Write-Host "Đang cài $PackageId..."
    & winget.exe install --id $PackageId --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "WinGet không cài được $PackageId (mã $LASTEXITCODE). Xem thông báo phía trên rồi chạy lại." }
    Refresh-ToolPath
}

function Save-ToolPath {
    # OpenSSL/Git không phải bản cài nào cũng tự thêm PATH. Chỉ thêm thư mục
    # thực sự tồn tại, không đưa Git usr/bin vào PATH chung của Windows.
    $entries = @([Environment]::GetEnvironmentVariable('Path', 'User') -split ';' | Where-Object { $_ })
    $candidates = @(
        (Split-Path $script:gitBash -Parent),
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links",
        "$env:ProgramFiles\OpenSSL-Win64\bin",
        "${env:ProgramFiles(x86)}\OpenSSL-Win32\bin"
    )
    foreach ($candidate in $candidates) {
        if ((Test-Path $candidate) -and ($entries -notcontains $candidate)) { $entries += $candidate }
    }
    [Environment]::SetEnvironmentVariable('Path', ($entries -join ';'), 'User')
}

function Has-BashTool([string]$Name) {
    # Chỉ nhận tên cố định từ danh sách bên dưới, không nhận lệnh từ người dùng.
    & $script:gitBash --noprofile --norc -c "command -v $Name >/dev/null 2>&1"
    return ($LASTEXITCODE -eq 0)
}

try {
    Refresh-ToolPath
    $script:gitBash = Find-GitBash
    if (-not $script:gitBash) {
        Write-Host 'THIẾU  Git Bash'
        if ($Check) { exit 1 }
        Install-Tool 'Git.Git'
        $script:gitBash = Find-GitBash
        if (-not $script:gitBash) { throw 'Chưa tìm thấy Git Bash sau cài đặt. Khởi động lại máy rồi chạy lại script.' }
    }

    $packages = [ordered]@{
        bash = 'Git.Git'
        curl = 'cURL.cURL'
        jq = 'jqlang.jq'
        openssl = 'ShiningLight.OpenSSL.Light'
        node = 'OpenJS.NodeJS.LTS'
        npx = 'OpenJS.NodeJS.LTS'
    }
    $missing = @()
    foreach ($tool in $packages.Keys) {
        if (Has-BashTool $tool) { Write-Host "OK     $tool" }
        else { Write-Host "THIẾU  $tool"; $missing += $tool }
    }
    if ($missing.Count -gt 0 -and $Check) { exit 1 }
    $installed = @()
    foreach ($tool in $missing) {
        $packageId = $packages[$tool]
        if ($installed -notcontains $packageId) {
            Install-Tool $packageId
            $installed += $packageId
        }
    }
    foreach ($tool in $packages.Keys) {
        if (-not (Has-BashTool $tool)) {
            throw "Đã cài nhưng Git Bash chưa tìm thấy $tool. Đóng/mở lại ứng dụng rồi chạy lại kiểm tra."
        }
    }
    if (-not $Check) { Save-ToolPath }
    Write-Host 'ĐÃ SẴN SÀNG. Đóng và mở lại Codex/Claude Code để nhận công cụ mới.'
    exit 0
} catch {
    Write-Host "LỖI: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
