param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Add-Type -AssemblyName System.Drawing

$sourceDir = Join-Path $ProjectRoot 'art/pixel/enemies_px/source/drowned'
$outDir = Join-Path $ProjectRoot 'art/pixel/enemies_px'
$frameWidth = 112
$bodyHeight = 168
$fxTop = 48
$fxHeight = $bodyHeight + $fxTop
$poses = @('idle', 'idle', 'idle', 'early', 'mid', 'cast', 'cast', 'mid', 'early', 'idle')
$images = @{}

try {
    foreach ($pose in @('idle', 'early', 'mid', 'cast')) {
        $images[$pose] = [System.Drawing.Bitmap]::FromFile((Join-Path $sourceDir "$pose.png"))
    }

    $body = [System.Drawing.Bitmap]::new($frameWidth * $poses.Count, $bodyHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($body)
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighSpeed
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        for ($frame = 0; $frame -lt $poses.Count; $frame++) {
            $source = $images[$poses[$frame]]
            $bob = if ($frame -eq 1) { -1 } else { 0 }
            $destination = [System.Drawing.Rectangle]::new($frame * $frameWidth, $bob, $frameWidth, $bodyHeight)
            $sourceBounds = [System.Drawing.Rectangle]::new(0, 0, $source.Width, $source.Height)
            $graphics.DrawImage($source, $destination, $sourceBounds, [System.Drawing.GraphicsUnit]::Pixel)

        }
        $body.Save((Join-Path $outDir 'drowned_body_1.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $body.Dispose()
    }

    $fx = [System.Drawing.Bitmap]::new($frameWidth * $poses.Count, $fxHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($fx)
    $fanaticFx = [System.Drawing.Bitmap]::FromFile((Join-Path $outDir 'fanatic_fx_1.png'))
    $priestFx = [System.Drawing.Bitmap]::FromFile((Join-Path $outDir 'priest_fx_1.png'))
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver

        # Reuse the gold-and-teal card pixels and dispersal from the established sprites.
        $sparkSource = [System.Drawing.Rectangle]::new(2 * 91, 0, 91, 210)
        $sparkDest = [System.Drawing.Rectangle]::new(5 * $frameWidth + 10, 18, 91, 210)
        $graphics.DrawImage($priestFx, $sparkDest, $sparkSource, [System.Drawing.GraphicsUnit]::Pixel)
        foreach ($cel in @(@(6, 6, 30), @(7, 7, 10), @(8, 8, 20), @(9, 9, 1))) {
            $targetFrame = $cel[0]
            $sourceFrame = $cel[1]
            $verticalOffset = $cel[2]
            $sourceRect = [System.Drawing.Rectangle]::new($sourceFrame * 96, 0, 96, 204)
            $destRect = [System.Drawing.Rectangle]::new($targetFrame * $frameWidth + 8, $verticalOffset, 96, 204)
            $graphics.DrawImage($fanaticFx, $destRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
        }
        $fx.Save((Join-Path $outDir 'drowned_fx_1.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $fx.Dispose()
        $fanaticFx.Dispose()
        $priestFx.Dispose()
    }
} finally {
    foreach ($image in $images.Values) { $image.Dispose() }
}

python (Join-Path $PSScriptRoot 'quantize_drowned.py')
if ($LASTEXITCODE -ne 0) { throw 'Drowned palette finalization failed.' }
