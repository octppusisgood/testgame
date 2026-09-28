$ErrorActionPreference = "SilentlyContinue"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$exe = "C:\Users\HUAWEI\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
$console = "C:\Users\HUAWEI\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"

while ($true) {
    Clear-Host
    Write-Host "=================================="
    Write-Host "             回响之城"
    Write-Host "=================================="
    Write-Host ""
    Write-Host "   [1] 开始游戏（单人 / 局域网联机）"
    Write-Host "   [2] 打开编辑器（改代码/地图）"
    Write-Host "   [3] 运行自动化测试"
    Write-Host "   [4] 打开游戏文件夹"
    Write-Host "   [5] 测试模式（强化点全满）"
    Write-Host "   [0] 退出"
    Write-Host ""
    $choice = Read-Host "输入数字后回车"
    switch ($choice) {
        "1" {
            Write-Host "正在启动游戏..."
            if (Test-Path $exe) {
                Start-Process -FilePath $exe -ArgumentList '--path', '.', 'res://scenes3d/menu3d.tscn' -WorkingDirectory $root
            } else {
                Start-Process godot -ArgumentList '--path', '.', 'res://scenes3d/menu3d.tscn' -WorkingDirectory $root
            }
            return
        }
        "2" {
            Write-Host "正在打开编辑器..."
            if (Test-Path $exe) {
                Start-Process -FilePath $exe -ArgumentList '-e', '--path', '.' -WorkingDirectory $root
            } else {
                Start-Process godot -ArgumentList '-e', '--path', '.' -WorkingDirectory $root
            }
            return
        }
        "3" {
            Write-Host "正在运行自动化测试..."
            if (Test-Path $console) {
                & $console --headless --path $root res://tests/test_flow.tscn
            } else {
                godot --headless --path $root res://tests/test_flow.tscn
            }
            Write-Host ""
            Read-Host "测试结束，按回车返回菜单"
        }
        "4" {
            Start-Process explorer.exe $root
        }
        "5" {
            Write-Host "正在启动测试模式..."
            if (Test-Path $exe) {
                Start-Process -FilePath $exe -ArgumentList '--path', '.', 'res://scenes3d/proto3d.tscn', '--', '--test' -WorkingDirectory $root
            } else {
                Start-Process godot -ArgumentList '--path', '.', 'res://scenes3d/proto3d.tscn', '--', '--test' -WorkingDirectory $root
            }
            return
        }
        "0" {
            return
        }
    }
}
