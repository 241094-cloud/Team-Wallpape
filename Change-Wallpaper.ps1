# Change-Wallpaper.ps1
# Downloads an image from a URL and sets it as the Windows desktop wallpaper.

$ErrorActionPreference = "Stop"

# You can paste the online image URL here, or leave it blank to be prompted.
$imageUrl = "https://images.unsplash.com/photo-1519681393784-d120267933ba?w=1920"

if ([string]::IsNullOrWhiteSpace($imageUrl)) {
    $imageUrl = Read-Host "Enter the direct URL of the wallpaper image (JPG, PNG, or BMP)"
}

if ($imageUrl -notmatch '^https?://') {
    Write-Host "Please enter a valid URL starting with http:// or https://" -ForegroundColor Red
    exit 1
}

try {
    $wallpaperFolder = Join-Path $env:LOCALAPPDATA "TeamWallpaper"
    if (-not (Test-Path $wallpaperFolder)) {
        New-Item -ItemType Directory -Path $wallpaperFolder -Force | Out-Null
    }

    $extension = [System.IO.Path]::GetExtension(([Uri]$imageUrl).AbsolutePath)
    if ($extension -notin @(".jpg", ".jpeg", ".png", ".bmp")) {
        $extension = ".jpg"
    }

    $wallpaperPath = Join-Path $wallpaperFolder ("wallpaper" + $extension)

    Write-Host "Downloading wallpaper..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $imageUrl -OutFile $wallpaperPath -UseBasicParsing

    if (-not (Test-Path $wallpaperPath) -or (Get-Item $wallpaperPath).Length -eq 0) {
        throw "The downloaded file is empty or was not created."
    }

    # Confirm that Windows can decode the downloaded image.
    Add-Type -AssemblyName System.Drawing
    $image = [System.Drawing.Image]::FromFile($wallpaperPath)
    $image.Dispose()

    # Set wallpaper for the current Windows user.
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $wallpaperPath
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -Value "10"
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper -Value "0"

    if (-not ("Wallpaper.NativeMethods" -as [type])) {
        Add-Type @"
using System;
using System.Runtime.InteropServices;
namespace Wallpaper {
    public class NativeMethods {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern bool SystemParametersInfo(
            int uAction, int uParam, string lpvParam, int fuWinIni);
    }
}
"@
    }

    $SPI_SETDESKWALLPAPER = 0x0014
    $SPIF_UPDATEINIFILE = 0x01
    $SPIF_SENDCHANGE = 0x02

    $result = [Wallpaper.NativeMethods]::SystemParametersInfo(
        $SPI_SETDESKWALLPAPER, 0, $wallpaperPath,
        ($SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE)
    )

    if (-not $result) {
        throw "Windows did not apply the wallpaper. Try running the script in your normal user session."
    }

    Write-Host "Wallpaper changed successfully!" -ForegroundColor Green
    Write-Host "Saved image: $wallpaperPath"
}
catch {
    Write-Host "Could not change wallpaper: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Make sure the URL points directly to an image file and that you have internet access."
    exit 1
}
