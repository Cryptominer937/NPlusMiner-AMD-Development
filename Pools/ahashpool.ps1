if (!(IsLoaded(".\Include.ps1"))) {. .\Include.ps1;RegisterLoaded(".\Include.ps1")}

try {
    $ahashpool_Request = Invoke-WebRequest "https://www.ahashpool.com/api/status" -UseBasicParsing -Headers @{"Cache-Control" = "no-cache"} | ConvertFrom-Json 
    $ahashpoolCoins_Request = Invoke-RestMethod "http://www.ahashpool.com/api/currencies" -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
}
catch { return }

if (-not $ahashpool_Request) {return}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Location = "US"

$ahashpool_Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    $ahashpool_Host = "$_.mine.ahashpool.com"
    $ahashpool_Port = $ahashpool_Request.$_.port
    $ahashpool_Algorithm = Get-Algorithm $ahashpool_Request.$_.name
    $ahashpool_Coin = $ahashpool_Request.$_.coins
    $ahashpool_Coinname = $ahashpoolCoins_Request.$_.name

    $Divisor = 1000000
	
    switch ($ahashpool_Algorithm) {
        "sha256" {$Divisor *= 1000000}
        "sha256t" {$Divisor *= 1000000}
        "blake" {$Divisor *= 1000}
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "vanilla" {$Divisor *= 1000}
        "x11" {$Divisor *= 1000}
        "equihash" {$Divisor /= 1000}
        "yescrypt" {$Divisor /= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($ahashpool_Algorithm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($ahashpool_Algorithm)_Profit" -Value ([Double]$ahashpool_Request.$_.estimate_last24h / $Divisor * (1 - ($ahashpool_Request.$_.fees / 100)))}
    else {$Stat = Set-Stat -Name "$($Name)_$($ahashpool_Algorithm)_Profit" -Value ([Double]$ahashpool_Request.$_.estimate_current / $Divisor * (1 - ($ahashpool_Request.$_.fees / 100)))}

	$ConfName = if ($Config.PoolsConfig.$Name -ne $Null){$Name}else{"default"}
	
    if ($Config.PoolsConfig.default.Wallet) {
        [PSCustomObject]@{
            Algorithm     = $ahashpool_Algorithm
            Info          = "$ahashpool_Coin $ahashpool_Coinname"
            Price         = $Stat.Live*$Config.PoolsConfig.$ConfName.PricePenaltyFactor
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $ahashpool_Host
            Port          = $ahashpool_Port
            User          = $Config.PoolsConfig.$ConfName.Wallet
		    Pass          = "$($Config.PoolsConfig.$ConfName.WorkerName),c=$($Config.Passwordcurrency)"
            Location      = $Location
            SSL           = $false
        }
    }
}
