# Windows bootstrap: chạy được trước khi máy có Git Bash.
# Không cài WSL nếu chưa có; mặc định chuẩn bị Git Bash để chạy plugin.
param([switch]$Check, [switch]$Help)
$ErrorActionPreference = 'Stop'
# Codex/Claude Code đọc stdout qua pipe dạng UTF-8. Windows PowerShell 5.1 mặc
# định ghi bằng code page OEM nên tiếng Việt thành '?' trong kết quả agent đọc.
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch {}

# Gọi lệnh ngoài (winget, bash) với ErrorActionPreference = Continue. Khi agent
# chuyển hướng stderr, PowerShell 5.1 biến từng dòng stderr của lệnh ngoài thành
# ErrorRecord; để 'Stop' là script chết ngay ở dòng cảnh báo đầu tiên. Kết quả
# chỉ đọc qua exit code.
function Invoke-Native([scriptblock]$Block) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $Block; return $LASTEXITCODE } finally { $ErrorActionPreference = $prev }
}

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
    $code = Invoke-Native {
        & winget.exe install --id $PackageId --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Host
    }
    # 0x8A15002B: đã cài bản mới nhất. 0x8A150061: gói đã cài. Không phải lỗi;
    # bước kiểm tra cuối mới quyết định công cụ có dùng được hay không.
    if ($code -ne 0 -and $code -ne -1978335189 -and $code -ne -1978335135) {
        throw "WinGet không cài được $PackageId (mã $code). Xem thông báo phía trên rồi chạy lại."
    }
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
    $code = Invoke-Native { & $script:gitBash --noprofile --norc -c "command -v $Name >/dev/null 2>&1" | Out-Null }
    return ($code -eq 0)
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
    # 'bash' trần trong PowerShell/cmd thường trỏ vào C:\Windows\System32\bash.exe
    # (trình khởi chạy WSL) vì System32 đứng trước PATH người dùng. Chạy script
    # plugin phải dùng đúng đường dẫn Git Bash này.
    Write-Host "GIT BASH: $($script:gitBash)"
    Write-Host 'ĐÃ SẴN SÀNG. Đóng và mở lại Codex/Claude Code để nhận công cụ mới.'
    exit 0
} catch {
    Write-Host "LỖI: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
