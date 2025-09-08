# Enregistre une vidéo de démonstration MP4 de l'application
param(
    [int]$DurationSeconds = 90
)

$ErrorActionPreference = 'Stop'

# Paths
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$promoDir = Join-Path $root 'Promo'
$ffmpegDir = Join-Path $promoDir 'ffmpeg'
$ffmpegExe = Join-Path $ffmpegDir 'ffmpeg.exe'
$outVideo = Join-Path $promoDir 'Presentation.mp4'
$appExe = Join-Path $root 'Publish\EFEKAN_KAPMAZ.exe'

if(!(Test-Path $promoDir)){ New-Item -ItemType Directory -Path $promoDir | Out-Null }

# Télécharger ffmpeg si absent (build Windows static)
if(!(Test-Path $ffmpegExe)){
    # Essayer d'abord ffmpeg dans le PATH
    $ffCmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if($ffCmd){
        Copy-Item $ffCmd.Source $ffmpegExe -Force
    } else {
        Write-Host 'Téléchargement de ffmpeg (.zip)...'
        $zipPath = Join-Path $promoDir 'ffmpeg.zip'
        $urls = @(
            'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip',
            'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
        )
        $downloaded = $false
        foreach($u in $urls){
            try{
                Write-Host ("-> Tentative: {0}" -f $u)
                Invoke-WebRequest -Uri $u -OutFile $zipPath -UseBasicParsing
                $downloaded = $true
                break
            } catch {
                Write-Host ("Échec: {0}" -f $u)
            }
        }
        if(-not $downloaded){ throw 'Impossible de télécharger ffmpeg depuis les miroirs.' }

        Write-Host 'Extraction de ffmpeg...'
        Expand-Archive -Path $zipPath -DestinationPath $ffmpegDir -Force
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        $ffmpegFound = Get-ChildItem -Path $ffmpegDir -Recurse -Filter ffmpeg.exe | Select-Object -First 1
        if($ffmpegFound){ Copy-Item $ffmpegFound.FullName $ffmpegExe -Force } else { throw 'ffmpeg.exe introuvable après extraction.' }
    }
}

# Lancer l'application si présente
if(Test-Path $appExe){
    Start-Process -FilePath $appExe | Out-Null
    Start-Sleep -Seconds 5
} else {
    Write-Host 'Attention: EFEKAN_KAPMAZ.exe non trouvé dans Publish/. La capture va démarrer quand même.'
}

# Déterminer la résolution de l'écran principal
Add-Type -AssemblyName System.Windows.Forms
$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$w = $bounds.Width
$h = $bounds.Height

Write-Host ("Enregistrement {0}s en {1}x{2}..." -f $DurationSeconds,$w,$h)

# Capture de l'écran (gdigrab) en MP4 H.264
$ffArgs = @(
    '-y',
    '-f','gdigrab',
    '-framerate','30',
    '-offset_x','0','-offset_y','0',
    '-video_size',("{0}x{1}" -f $w,$h),
    '-i','desktop',
    '-c:v','libx264','-preset','veryfast','-pix_fmt','yuv420p',
    '-t',"$DurationSeconds",
    $outVideo
)

& $ffmpegExe $ffArgs

Write-Host "Vidéo générée: $outVideo"
