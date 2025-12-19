# Generate RSA developer key for Connect IQ in DER format
# Uses .NET Framework compatible methods

$rsa = [System.Security.Cryptography.RSACryptoServiceProvider]::new(4096)

# Export to XML format first
$xmlKey = $rsa.ToXmlString($true)

# Export the private key in CSP blob format and convert to Base64 for PEM
$cspBlob = $rsa.ExportCspBlob($true)
$base64 = [Convert]::ToBase64String($cspBlob)

# Format as PEM with 64 char line width
$pemLines = @()
$pemLines += "-----BEGIN RSA PRIVATE KEY-----"
for ($i = 0; $i -lt $base64.Length; $i += 64) {
    $lineLength = [Math]::Min(64, $base64.Length - $i)
    $pemLines += $base64.Substring($i, $lineLength)
}
$pemLines += "-----END RSA PRIVATE KEY-----"

$pem = $pemLines -join "`n"

# Save to file
Set-Content -Path 'developer_key.pem' -Value $pem -Encoding ASCII

# Also save as DER (binary) which some versions prefer
[System.IO.File]::WriteAllBytes("developer_key.der", $cspBlob)

if (Test-Path 'developer_key.pem') {
    $size = (Get-Item 'developer_key.pem').Length
    Write-Host "Developer key generated: developer_key.pem ($size bytes)" -ForegroundColor Green
    Write-Host "Also created: developer_key.der" -ForegroundColor Green
} else {
    Write-Host "Failed to generate key" -ForegroundColor Red
}
