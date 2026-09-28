$root = 'C:\Users\joanr\Desktop\katali-surgery'
$exe = Join-Path $root 'katali-lab.exe'
$model = Join-Path $root 'katali-tenary\models\bonsai-1.7b\Bonsai-1.7B-Q1_0.gguf'
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe
$psi.Arguments = ('generate "{0}" "What is the capital of France?" --max 32 --threads 12' -f $model)
$psi.WorkingDirectory = $root
$psi.UseShellExecute = $false
$psi.EnvironmentVariables['KATALI_BONSAI_Q8'] = '1'
$p = New-Object System.Diagnostics.Process
$p.StartInfo = $psi
[void]$p.Start()
$p.ProcessorAffinity = [IntPtr]0xFFF
$p.WaitForExit()
if ($p.ExitCode -ne 0) { throw "benchmark failed: $($p.ExitCode)" }
