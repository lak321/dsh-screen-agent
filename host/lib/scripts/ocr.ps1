param([string]$Image, [string]$Lang)
# Windows built-in OCR: output each line as cx|cy|text (center pixel coords,
# same coordinate space as the capture PNG -> directly usable for mouse clicks)
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($WinRtTask, $ResultType) {
    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
    $netTask = $asTask.Invoke($null, @($WinRtTask))
    $netTask.Wait(-1) | Out-Null
    $netTask.Result
}
[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation, ContentType=WindowsRuntime] | Out-Null
[Windows.Storage.StorageFile, Windows.Foundation, ContentType=WindowsRuntime] | Out-Null
$file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($Image)) ([Windows.Storage.StorageFile])
$stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
$decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
$bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
$engine = $null
if ($Lang) {
    try { $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage([Windows.Globalization.Language]::new($Lang)) } catch { $engine = $null }
}
if (-not $engine) { $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages() }
if (-not $engine) { Write-Output "no-ocr-engine"; exit 1 }
$result = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
foreach ($line in $result.Lines) {
    if (-not $line.Words) { continue }
    # Indexing WinRT IVectorView with [] is unreliable in PS 5.1;
    # iterate with foreach instead to capture first/last word.
    $first = $null
    $last = $null
    foreach ($w in $line.Words) {
        if ($null -eq $first) { $first = $w }
        $last = $w
    }
    if ($null -eq $first) { continue }
    # Step-by-step double casts avoid WinRT property arrays breaking conversion
    $x1 = [double]$first.BoundingRect.X
    $y1 = [double]$first.BoundingRect.Y
    $h = [double]$first.BoundingRect.Height
    $x2 = [double]$last.BoundingRect.X
    $w2 = [double]$last.BoundingRect.Width
    # Line-center coordinate (more accurate for clicks)
    $cx = [int](($x1 + $x2 + $w2) / 2.0)
    $cy = [int]($y1 + $h / 2.0)
    Write-Output ("{0}|{1}|{2}" -f $cx, $cy, $line.Text)
}
