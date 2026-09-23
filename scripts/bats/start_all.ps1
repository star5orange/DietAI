# =============================================================================
#  DietAI 一键启动脚本（PRD 5.1）
#
#  流程：
#    1. 设置 NO_PROXY / no_proxy，避免代理劫持本地依赖
#    2. 依次检查 PostgreSQL(5432) / Redis(6379) / MinIO(9000) 的 TCP 可用性
#       不可用时：优先用 docker compose 拉起，其次尝试本地启动脚本，最后给出人工指引
#    3. 以「无 --reload」方式启动后端：uv run uvicorn main:app --host 0.0.0.0 --port 8000
#       并显式设置 DIETAI_DEBUG=false（否则 main.py 的 reload=settings.debug 会开启热重载）
#    4. 轮询 http://127.0.0.1:8000/health 直到 200 或超时，并给出结论
#
#  说明：脚本不硬编码任何私有绝对路径，全部基于脚本自身位置推导项目根目录。
# =============================================================================

#Requires -Version 5.1

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
try { $OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

# ----------------------------- 基础路径与常量 --------------------------------
# $PSScriptRoot = <项目根>\scripts\bats
$ProjectRoot    = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ComposeFile    = Join-Path $ProjectRoot 'docker-compose.yml'
$LocalPgBat     = Join-Path $PSScriptRoot 'postgresql_start.bat'
$LocalMinioBat  = Join-Path $PSScriptRoot 'minio_start.bat'
$BackendPort    = 8000
$HealthUrl      = 'http://127.0.0.1:8000/health'

# ------------------------------- 输出辅助 ------------------------------------
function Write-Step { param([string]$Message) Write-Host ""; Write-Host "[DietAI] $Message" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Message) Write-Host "        [OK] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "        [!]  $Message" -ForegroundColor Yellow }
function Write-Err  { param([string]$Message) Write-Host "        [X]  $Message" -ForegroundColor Red }
function Write-Hint { param([string]$Message) Write-Host "             $Message" -ForegroundColor DarkGray }

# ----------------------------- TCP 端口探测 ----------------------------------
function Test-TcpPort {
    param(
        [string]$TargetHost,
        [int]$Port,
        [int]$TimeoutMs = 1500
    )
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect($TargetHost, $Port, $null, $null)
        if ($async.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
            $client.EndConnect($async)
            return $true
        }
        return $false
    } catch {
        return $false
    } finally {
        try { $client.Close() } catch { }
    }
}

function Wait-TcpPort {
    param(
        [string]$TargetHost,
        [int]$Port,
        [int]$TimeoutSeconds = 60
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-TcpPort -TargetHost $TargetHost -Port $Port) { return $true }
        Start-Sleep -Seconds 2
    }
    return (Test-TcpPort -TargetHost $TargetHost -Port $Port)
}

# ----------------------------- docker compose 探测 ---------------------------
$script:ComposeBase = $null   # 例如 @('docker','compose') 或 @('docker-compose')

function Initialize-ComposeCommand {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { return }
    if (-not (Test-Path $ComposeFile)) { return }

    & docker compose version *> $null
    if ($LASTEXITCODE -eq 0) { $script:ComposeBase = @('docker', 'compose'); return }

    if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
        & docker-compose version *> $null
        if ($LASTEXITCODE -eq 0) { $script:ComposeBase = @('docker-compose'); return }
    }
}

function Invoke-ComposeUp {
    param([string[]]$Services)
    if (-not $script:ComposeBase) { return $false }
    $exe  = $script:ComposeBase[0]
    $pre  = @()
    if ($script:ComposeBase.Count -gt 1) {
        $pre = $script:ComposeBase[1..($script:ComposeBase.Count - 1)]
    }
    $arguments = $pre + @('-f', $ComposeFile, 'up', '-d') + $Services
    & $exe @arguments 2>&1 | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkGray }
    return ($LASTEXITCODE -eq 0)
}

# --------------------------- 单个依赖服务的保障 -------------------------------
function Ensure-DependencyService {
    param(
        [string]$DisplayName,
        [string]$TargetHost,
        [int]$Port,
        [string]$ComposeService,
        [string]$LocalBat,
        [int]$WaitSeconds = 60
    )

    Write-Step "检查依赖服务：$DisplayName (${TargetHost}:${Port})"
    if (Test-TcpPort -TargetHost $TargetHost -Port $Port) {
        Write-Ok "$DisplayName 已在运行，端口可达"
        return $true
    }
    Write-Warn "$DisplayName 未就绪，尝试自动启动 ..."

    # 方案一：docker compose（推荐，跨机器通用）
    if ($script:ComposeBase) {
        Write-Hint "执行: $($script:ComposeBase -join ' ') -f docker-compose.yml up -d $ComposeService"
        [void](Invoke-ComposeUp -Services @($ComposeService))
        if (Wait-TcpPort -TargetHost $TargetHost -Port $Port -TimeoutSeconds $WaitSeconds) {
            Write-Ok "$DisplayName 已通过 docker compose 启动"
            return $true
        }
        Write-Warn "docker compose 启动后端口仍不可达"
    } else {
        Write-Warn "未检测到可用的 docker / docker-compose，跳过容器启动"
    }

    # 方案二：本机已有启动脚本（仅 PostgreSQL / MinIO 提供）
    if ($LocalBat -and (Test-Path $LocalBat)) {
        Write-Hint "尝试本地启动脚本: $LocalBat"
        try {
            Start-Process -FilePath $LocalBat -WorkingDirectory (Split-Path -Parent $LocalBat) -WindowStyle Minimized | Out-Null
        } catch {
            Write-Warn "调用本地启动脚本失败: $($_.Exception.Message)"
        }
        if (Wait-TcpPort -TargetHost $TargetHost -Port $Port -TimeoutSeconds $WaitSeconds) {
            Write-Ok "$DisplayName 已通过本地脚本启动"
            return $true
        }
        Write-Warn "本地脚本启动后端口仍不可达"
    }

    # 方案三：给出可操作的人工指引
    Write-Err "$DisplayName 仍不可用，请手动处理后再运行本脚本"
    Write-Hint "推荐：在项目根目录执行  docker compose up -d postgres redis minio"
    if ($LocalBat) { Write-Hint "或双击运行：$LocalBat" }
    switch ($Port) {
        5432 { Write-Hint "请确认本机 PostgreSQL 已启动，且数据库连接串(DIETAI_DATABASE_URL)中的主机/端口正确" }
        6379 { Write-Hint "请确认本机 Redis 已启动（默认 6379），并检查 DIETAI_REDIS_PASSWORD 是否正确" }
        9000 { Write-Hint "请确认本机 MinIO 已启动（API 端口 9000），并检查 DIETAI_MINIO_* 配置" }
    }
    return $false
}

# ------------------------------- 后端健康检查 --------------------------------
function Wait-BackendHealth {
    param(
        [string]$Url,
        [int]$TimeoutSeconds = 90
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $lastError = '尚未收到响应'
    while ((Get-Date) -lt $deadline) {
        try {
            $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
            if ($resp.StatusCode -eq 200) {
                return @{ Ok = $true; Body = $resp.Content; Error = '' }
            }
            $lastError = "HTTP $($resp.StatusCode)"
        } catch {
            $lastError = $_.Exception.Message
        }
        Start-Sleep -Seconds 2
    }
    return @{ Ok = $false; Body = ''; Error = $lastError }
}

# ================================== 主流程 ====================================

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Magenta
Write-Host "          DietAI 一键启动脚本（PRD 5.1 工程底座）" -ForegroundColor Magenta
Write-Host "==============================================================" -ForegroundColor Magenta
Write-Hint "项目根目录: $ProjectRoot"

# --- 步骤 1：本地代理白名单 ---
Write-Step "步骤 1/4：设置 NO_PROXY，避免代理劫持本地依赖"
$env:NO_PROXY = 'localhost,127.0.0.1,::1'
$env:no_proxy = 'localhost,127.0.0.1,::1'
Write-Ok "NO_PROXY=$env:NO_PROXY"

# --- 步骤 2：依赖服务健康检查 ---
Write-Step "步骤 2/4：检查依赖服务（PostgreSQL / Redis / MinIO）"
Initialize-ComposeCommand
if ($script:ComposeBase) {
    Write-Hint "已检测到容器编排命令: $($script:ComposeBase -join ' ')"
} else {
    Write-Warn "未检测到 docker compose（将只尝试本机已安装的服务）"
}

$allReady = $true
if (-not (Ensure-DependencyService -DisplayName 'PostgreSQL' -TargetHost '127.0.0.1' -Port 5432 -ComposeService 'postgres' -LocalBat $LocalPgBat)) { $allReady = $false }
if (-not (Ensure-DependencyService -DisplayName 'Redis'      -TargetHost '127.0.0.1' -Port 6379 -ComposeService 'redis'    -LocalBat $null))        { $allReady = $false }
if (-not (Ensure-DependencyService -DisplayName 'MinIO'      -TargetHost '127.0.0.1' -Port 9000 -ComposeService 'minio'    -LocalBat $LocalMinioBat)) { $allReady = $false }

if (-not $allReady) {
    Write-Host ""
    Write-Err "依赖服务未全部就绪，已中止启动（避免后端启动后大量报错）。"
    Write-Hint "处理完成后请重新运行: scripts\bats\start_all.bat"
    exit 1
}
Write-Ok "三个依赖服务全部就绪"

# --- 步骤 3：启动后端（无 --reload） ---
Write-Step "步骤 3/4：启动后端服务（uvicorn，无 --reload）"

if (Test-TcpPort -TargetHost '127.0.0.1' -Port $BackendPort) {
    Write-Warn "端口 $BackendPort 已被占用，可能后端已在运行"
    $probe = Wait-BackendHealth -Url $HealthUrl -TimeoutSeconds 5
    if ($probe.Ok) {
        Write-Ok "后端已在运行且健康检查通过，无需重复启动"
        Write-Hint "接口文档: http://127.0.0.1:${BackendPort}/docs"
        exit 0
    }
    Write-Err "端口被占用但 $HealthUrl 不可用，请先结束占用进程后重试"
    Write-Hint "排查: netstat -ano | findstr :$BackendPort"
    exit 1
}

# 显式关闭 debug，防止 main.py 的 reload=settings.debug 打开热重载
$env:DIETAI_DEBUG = 'false'
Write-Ok "已设置 DIETAI_DEBUG=false（确保不启用热重载，避免子进程残留占端口）"

$uvicornArgs = @('run', 'uvicorn', 'main:app', '--host', '0.0.0.0', '--port', '8000')
$launchExe   = $null
$launchArgs  = $null

if (Get-Command uv -ErrorAction SilentlyContinue) {
    $launchExe  = 'uv'
    $launchArgs = $uvicornArgs
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $launchExe  = 'python'
    $launchArgs = @('-m', 'uvicorn', 'main:app', '--host', '0.0.0.0', '--port', '8000')
    Write-Warn "未找到 uv，已回退为 python -m uvicorn"
} else {
    Write-Err "未找到 uv 或 python，无法启动后端"
    Write-Hint "请安装 uv: https://docs.astral.sh/uv/"
    exit 1
}

Write-Hint "命令: $launchExe $($launchArgs -join ' ')"
Write-Hint "工作目录: $ProjectRoot"
try {
    Start-Process -FilePath $launchExe -ArgumentList $launchArgs -WorkingDirectory $ProjectRoot | Out-Null
} catch {
    Write-Err "启动后端进程失败: $($_.Exception.Message)"
    exit 1
}
Write-Ok "后端进程已在新窗口启动（日志在该窗口输出）"

# --- 步骤 4：轮询健康检查 ---
Write-Step "步骤 4/4：等待后端健康检查通过（$HealthUrl）"
$health = Wait-BackendHealth -Url $HealthUrl -TimeoutSeconds 90

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Magenta
if ($health.Ok) {
    Write-Ok "启动完成，健康检查返回 200"
    Write-Hint "响应: $($health.Body)"
    Write-Hint "接口文档: http://127.0.0.1:${BackendPort}/docs"
    Write-Hint "停止后端: 在后端日志窗口按 Ctrl+C"
    exit 0
} else {
    Write-Err "健康检查超时未通过，原因: $($health.Error)"
    Write-Hint "请查看后端日志窗口的报错信息（常见原因：数据库连接串/密码错误、端口冲突）"
    Write-Hint "排查: netstat -ano | findstr :$BackendPort"
    Write-Hint "确认依赖: docker compose ps"
    exit 1
}
