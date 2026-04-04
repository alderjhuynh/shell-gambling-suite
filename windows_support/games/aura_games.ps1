param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('blackjack', 'coinflip', 'rock_paper_scissors', 'scratchers', 'slots', 'video_poker')]
    [string]$Game
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:PassiveCreditAmount = 10
$script:PassiveCreditInterval = 300
$script:PassiveCreditCap = 100
$script:InstallRoot = Join-Path $env:LOCALAPPDATA 'AuraGamblingSuite'
$script:StatePath = Join-Path $script:InstallRoot 'state.json'
$script:RankMap = @{
    '2' = 2
    '3' = 3
    '4' = 4
    '5' = 5
    '6' = 6
    '7' = 7
    '8' = 8
    '9' = 9
    '10' = 10
    'J' = 11
    'Q' = 12
    'K' = 13
    'A' = 14
}
$script:SlotsSymbols = @('CH', 'LM', 'OR', 'GR', 'ST', 'DM', '77')
$script:ScratchTickets = @(
    [ordered]@{
        Id = '1'
        Name = 'Lucky Penny'
        Cost = 10
        Rows = 2
        Cols = 3
        Symbols = @('CL', 'MO', 'ST', 'DI', 'BE')
        Description = '6 cells  match 3=1.1x  match 2=0.6x'
        Paytable = [ordered]@{
            3 = 110
            2 = 60
        }
    },
    [ordered]@{
        Id = '2'
        Name = 'Gold Rush'
        Cost = 25
        Rows = 3
        Cols = 4
        Symbols = @('DM', 'TR', 'SL', 'ST', '7S', 'TG')
        Description = '12 cells  match 4=1.5x  3=1x  2=0.5x'
        Paytable = [ordered]@{
            4 = 150
            3 = 100
            2 = 50
        }
    },
    [ordered]@{
        Id = '3'
        Name = 'Midnight Jackpot'
        Cost = 50
        Rows = 3
        Cols = 5
        Symbols = @('DM', 'JK', 'FW', 'CR', 'MN', 'OM', 'BL')
        Description = '15 cells  match 5=2x  4=1.2x  3=0.6x  2=0.3x'
        Paytable = [ordered]@{
            5 = 200
            4 = 120
            3 = 60
            2 = 30
        }
    }
)

function New-DefaultState {
    @{
        credits = 100
        passive_earned = 0
        next_credit_time = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + $script:PassiveCreditInterval
    }
}

function Save-State {
    param([hashtable]$State)

    if (-not (Test-Path $script:InstallRoot)) {
        [void](New-Item -ItemType Directory -Path $script:InstallRoot -Force)
    }

    $payload = [ordered]@{
        credits = [int]$State.credits
        passive_earned = [int]$State.passive_earned
        next_credit_time = [long]$State.next_credit_time
    } | ConvertTo-Json

    Set-Content -Path $script:StatePath -Value $payload -Encoding ASCII
}

function Sync-PassiveCredits {
    param([hashtable]$State)

    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ([long]$State.next_credit_time -le 0) {
        $State.next_credit_time = $now + $script:PassiveCreditInterval
    }

    $bonus = 0
    if ([long]$State.next_credit_time -le $now) {
        $missed = [math]::Floor(($now - [long]$State.next_credit_time) / $script:PassiveCreditInterval) + 1
        $potential = [int]$missed * $script:PassiveCreditAmount
        $allowed = $script:PassiveCreditCap - [int]$State.passive_earned
        if ($allowed -lt 0) {
            $allowed = 0
        }

        $bonus = [math]::Min($potential, $allowed)
        if ($bonus -gt 0) {
            $State.credits = [int]$State.credits + $bonus
            $State.passive_earned = [int]$State.passive_earned + $bonus
        }

        $State.next_credit_time = $now + $script:PassiveCreditInterval
    }

    return [int]$bonus
}

function Load-State {
    $state = New-DefaultState

    if (Test-Path $script:StatePath) {
        try {
            $data = Get-Content -Path $script:StatePath -Raw | ConvertFrom-Json
            if ($null -ne $data.credits) { $state.credits = [int]$data.credits }
            if ($null -ne $data.passive_earned) { $state.passive_earned = [int]$data.passive_earned }
            if ($null -ne $data.next_credit_time) { $state.next_credit_time = [long]$data.next_credit_time }
        } catch {
            $state = New-DefaultState
        }
    }

    if ([int]$state.passive_earned -lt 0) { $state.passive_earned = 0 }
    if ([int]$state.passive_earned -gt $script:PassiveCreditCap) { $state.passive_earned = $script:PassiveCreditCap }

    [void](Sync-PassiveCredits -State $state)
    Save-State -State $state
    return $state
}

function Get-TimerText {
    param([hashtable]$State)

    $seconds = [long]$State.next_credit_time - [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($seconds -lt 0) {
        $seconds = 0
    }

    $minutes = [math]::Floor($seconds / 60)
    $remaining = $seconds % 60
    return '{0}m {1:00}s' -f $minutes, $remaining
}

function Read-Choice {
    param([string]$Prompt = '> ')

    $value = Read-Host $Prompt
    if ($null -eq $value) {
        return ''
    }

    return $value.Trim().ToLowerInvariant()
}

function Show-Bonus {
    param([int]$Bonus)

    if ($Bonus -gt 0) {
        Write-Host ''
        Write-Host ("+{0} FREE CREDITS!" -f $Bonus)
        Write-Host ''
    }
}

function Get-RepeatText {
    param(
        [string]$Character,
        [int]$Count
    )

    if ($Count -le 0) {
        return ''
    }

    return ([string]$Character[0]) * $Count
}

function Get-BoxInnerWidth {
    param([int]$Width)

    if ($Width -lt 4) {
        return 1
    }

    return $Width - 2
}

function Write-BoxLine {
    param(
        [string]$Text = '',
        [int]$Width = 44
    )

    $innerWidth = Get-BoxInnerWidth -Width $Width
    $content = if ($null -eq $Text) { '' } else { [string]$Text }
    if ($content.Length -gt $innerWidth) {
        $content = $content.Substring(0, $innerWidth)
    }

    Write-Host ('|{0}|' -f $content.PadRight($innerWidth))
}

function Write-BoxDivider {
    param([int]$Width = 44)
    Write-Host ('+{0}+' -f (Get-RepeatText -Character '-' -Count (Get-BoxInnerWidth -Width $Width)))
}

function Get-CenteredText {
    param(
        [string]$Text,
        [int]$Width
    )

    $content = if ($null -eq $Text) { '' } else { [string]$Text }
    $innerWidth = Get-BoxInnerWidth -Width $Width
    if ($content.Length -ge $innerWidth) {
        return $content.Substring(0, $innerWidth)
    }

    $leftPad = [math]::Floor(($innerWidth - $content.Length) / 2)
    return (' ' * $leftPad) + $content
}

function Show-GameBanner {
    param(
        [string]$Title,
        [hashtable]$State,
        [int]$Bet = 0,
        [int]$Width = 44
    )

    Clear-Host
    Write-Host ('+{0}+' -f (Get-RepeatText -Character '=' -Count (Get-BoxInnerWidth -Width $Width)))
    Write-BoxLine -Text (Get-CenteredText -Text $Title -Width $Width) -Width $Width
    Write-BoxLine -Text (Get-CenteredText -Text 'Aura Gambling Suite' -Width $Width) -Width $Width
    Write-BoxDivider -Width $Width

    if ($Bet -gt 0) {
        Write-BoxLine -Text ('  Credits: {0}   Bet: {1}   +{2} in {3}' -f $State.credits, $Bet, $script:PassiveCreditAmount, (Get-TimerText -State $State)) -Width $Width
    } else {
        Write-BoxLine -Text ('  Credits: {0}   +{1} in {2}' -f $State.credits, $script:PassiveCreditAmount, (Get-TimerText -State $State)) -Width $Width
    }

    Write-Host ('+{0}+' -f (Get-RepeatText -Character '=' -Count (Get-BoxInnerWidth -Width $Width)))
    Write-Host ''
}

function Read-Bet {
    param(
        [int]$CurrentBet,
        [int]$Credits,
        [int]$Minimum = 10,
        [int]$Maximum = 500
    )

    $maxBet = [math]::Min($Credits, $Maximum)
    if ($maxBet -lt $Minimum) {
        $maxBet = $Minimum
    }

    $raw = Read-Host ("Enter bet ({0}-{1})" -f $Minimum, $maxBet)
    $parsed = 0
    if ([int]::TryParse($raw, [ref]$parsed)) {
        if ($parsed -lt $Minimum) { $parsed = $Minimum }
        if ($parsed -gt $maxBet) { $parsed = $maxBet }
        return $parsed
    }

    return $CurrentBet
}

function New-ShuffledDeck {
    $cards = @()
    foreach ($suit in @('S', 'H', 'D', 'C')) {
        foreach ($rank in @('A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K')) {
            $cards += ('{0}|{1}' -f $rank, $suit)
        }
    }

    $shuffled = [System.Collections.ArrayList]::new()
    foreach ($card in (Get-Random -InputObject $cards -Count $cards.Count)) {
        [void]$shuffled.Add($card)
    }

    return $shuffled
}

function Draw-Card {
    param([System.Collections.ArrayList]$Deck)

    $card = $Deck[0]
    $Deck.RemoveAt(0)
    return $card
}

function Format-Card {
    param($Card)

    if ($null -eq $Card) {
        return '[??]'
    }

    $parts = ([string]$Card) -split '\|', 2
    if ($parts.Count -lt 2) {
        return '[??]'
    }

    return '[{0,-2}{1}]' -f $parts[0], $parts[1]
}

function Get-CardRank {
    param([string]$Card)

    if ([string]::IsNullOrWhiteSpace($Card)) {
        return ''
    }

    return ($Card -split '\|', 2)[0]
}

function Get-CardSuit {
    param([string]$Card)

    if ([string]::IsNullOrWhiteSpace($Card)) {
        return ''
    }

    $parts = $Card -split '\|', 2
    if ($parts.Count -lt 2) {
        return ''
    }

    return $parts[1]
}

function Get-SuitGlyph {
    param([string]$Suit)

    switch ($Suit) {
        'S' { return 'S' }
        'H' { return 'H' }
        'D' { return 'D' }
        'C' { return 'C' }
        default { return $Suit }
    }
}

function Get-CardLines {
    param(
        [string]$Card,
        [switch]$Hidden,
        [switch]$Held
    )

    if ($Hidden) {
        return @(
            '.-----.',
            '|#####|',
            '|#####|',
            '|#####|',
            '''-----'''
        )
    }

    $rank = Get-CardRank -Card $Card
    $glyph = Get-SuitGlyph -Suit (Get-CardSuit -Card $Card)
    $left = '{0,-2}' -f $rank
    $right = '{0,2}' -f $rank

    if ($Held) {
        return @(
            '.=====.',
            ('||{0}  ||' -f $left),
            ('|| {0}  ||' -f $glyph),
            ('||  {0}||' -f $right),
            '''====='''
        )
    }

    return @(
        '.-----.',
        ('|{0}   |' -f $left),
        ('|  {0}  |' -f $glyph),
        ('|   {0}|' -f $right),
        '''-----'''
    )
}

function Show-CardRow {
    param(
        [string[]]$Cards,
        [bool[]]$Held = @(),
        [switch]$HideSecond
    )

    if ($null -eq $Cards -or $Cards.Count -eq 0) {
        return
    }

    $rows = @('', '', '', '', '')
    for ($i = 0; $i -lt $Cards.Count; $i++) {
        $heldFlag = $false
        if ($Held.Count -gt $i) {
            $heldFlag = [bool]$Held[$i]
        }

        $lines = Get-CardLines -Card $Cards[$i] -Held:$heldFlag -Hidden:($HideSecond -and $i -eq 1)
        for ($row = 0; $row -lt $rows.Count; $row++) {
            if ($rows[$row]) {
                $rows[$row] += ' '
            }
            $rows[$row] += $lines[$row]
        }
    }

    foreach ($row in $rows) {
        Write-Host ('  {0}' -f $row)
    }
}

function Format-Hand {
    param(
        [object[]]$Hand,
        [switch]$HideSecond
    )

    $parts = @()
    for ($i = 0; $i -lt $Hand.Count; $i++) {
        if ($HideSecond -and $i -eq 1) {
            $parts += '[??]'
        } else {
            $parts += (Format-Card -Card $Hand[$i])
        }
    }

    return ($parts -join ' ')
}

function Get-HandInfo {
    param([object[]]$Hand)

    $total = 0
    $aces = 0
    foreach ($card in $Hand) {
        $rank = Get-CardRank -Card ([string]$card)
        switch ($rank) {
            'J' { $total += 10 }
            'Q' { $total += 10 }
            'K' { $total += 10 }
            'A' {
                $total += 11
                $aces += 1
            }
            default { $total += [int]$rank }
        }
    }

    while ($total -gt 21 -and $aces -gt 0) {
        $total -= 10
        $aces -= 1
    }

    return @{
        Total = $total
        Soft = ($aces -gt 0)
    }
}

function Get-HandTotal {
    param([object[]]$Hand)
    return (Get-HandInfo -Hand $Hand).Total
}

function Test-Blackjack {
    param([object[]]$Hand)
    return ($Hand.Count -eq 2 -and (Get-HandTotal -Hand $Hand) -eq 21)
}

function Get-DealerShouldHit {
    param([object[]]$Hand)

    $info = Get-HandInfo -Hand $Hand
    if ($info.Total -lt 17) {
        return $true
    }

    if ($info.Total -eq 17 -and $info.Soft) {
        return $true
    }

    return $false
}

function Show-BlackjackTable {
    param(
        [hashtable]$State,
        [int]$Bet,
        [object[]]$Player,
        [object[]]$Dealer,
        [string]$Message = '',
        [switch]$RevealDealer
    )

    Show-GameBanner -Title 'BLACKJACK' -State $State -Bet $Bet -Width 58

    if ($RevealDealer) {
        Write-Host ('Dealer [{0}]' -f (Get-HandTotal -Hand $Dealer))
        Show-CardRow -Cards @($Dealer)
    } else {
        Write-Host ('Dealer [{0} + ?]' -f (Get-HandTotal -Hand @($Dealer[0])))
        Show-CardRow -Cards @($Dealer) -HideSecond
    }

    Write-Host ''
    Write-Host ('You [{0}]' -f (Get-HandTotal -Hand $Player))
    Show-CardRow -Cards @($Player)
    Write-Host ''

    if ($Message) {
        Write-Host $Message
        Write-Host ''
    }
}

function Play-Blackjack {
    $state = Load-State
    $bet = 10

    while ($true) {
        $bonus = Sync-PassiveCredits -State $state
        if ($bonus -gt 0) {
            Save-State -State $state
            Show-Bonus -Bonus $bonus
        }

        Show-GameBanner -Title 'BLACKJACK' -State $state -Bet $bet -Width 58

        if ($state.credits -le 0) {
            Write-Host 'OUT OF CREDITS - wait for the next free bonus.'
            $answer = Read-Choice '[Enter] check again, [q] quit'
            if ($answer -eq 'q') { break }
            continue
        }

        Write-Host ('[Enter] deal   [b] change bet ({0})   [q] quit' -f $bet)
        $choice = Read-Choice
        if ($choice -eq 'q') {
            break
        }

        if ($choice -eq 'b') {
            $bet = Read-Bet -CurrentBet $bet -Credits $state.credits -Minimum 10 -Maximum 500
            continue
        }

        if ($bet -gt $state.credits) {
            Write-Host ''
            Write-Host 'Not enough credits.'
            Read-Host 'Press Enter'
            continue
        }

        $state.credits -= $bet
        $state.passive_earned = 0
        Save-State -State $state

        $deck = New-ShuffledDeck
        $player = [System.Collections.ArrayList]::new()
        $dealer = [System.Collections.ArrayList]::new()
        [void]$player.Add((Draw-Card -Deck $deck))
        [void]$dealer.Add((Draw-Card -Deck $deck))
        [void]$player.Add((Draw-Card -Deck $deck))
        [void]$dealer.Add((Draw-Card -Deck $deck))

        $payout = 0
        $message = ''

        if (Test-Blackjack -Hand $player) {
            Show-BlackjackTable -State $state -Bet $bet -Player $player -Dealer $dealer -Message 'Blackjack.' -RevealDealer
            if (Test-Blackjack -Hand $dealer) {
                $payout = $bet
                $message = 'Push. Both sides have blackjack.'
            } else {
                $payout = ($bet * 2) + [math]::Floor($bet / 2)
                $message = ('Blackjack pays 3:2. +{0}' -f ($payout - $bet))
            }
        } else {
            $roundQuit = $false
            while ($true) {
                $playerTotal = Get-HandTotal -Hand $player
                if ($playerTotal -gt 21) {
                    Show-BlackjackTable -State $state -Bet $bet -Player $player -Dealer $dealer -Message 'Bust.'
                    $payout = 0
                    $message = ('Bust. -{0}' -f $bet)
                    break
                }

                if ($playerTotal -eq 21) {
                    break
                }

                Show-BlackjackTable -State $state -Bet $bet -Player $player -Dealer $dealer -Message '[h] hit   [s] stand   [q] quit game'
                $turn = Read-Choice
                switch ($turn) {
                    'h' { [void]$player.Add((Draw-Card -Deck $deck)) }
                    'q' {
                        $roundQuit = $true
                        break
                    }
                    default { break }
                }

                if ($turn -ne 'h') {
                    break
                }
            }

            if ($roundQuit) {
                $state.credits += $bet
                Save-State -State $state
                break
            }

            if ((Get-HandTotal -Hand $player) -le 21 -and $message -eq '') {
                while (Get-DealerShouldHit -Hand $dealer) {
                    [void]$dealer.Add((Draw-Card -Deck $deck))
                }

                Show-BlackjackTable -State $state -Bet $bet -Player $player -Dealer $dealer -RevealDealer
                $playerTotal = Get-HandTotal -Hand $player
                $dealerTotal = Get-HandTotal -Hand $dealer

                if ($dealerTotal -gt 21 -or $playerTotal -gt $dealerTotal) {
                    $payout = $bet * 2
                    $message = ('You win. +{0}' -f $bet)
                } elseif ($playerTotal -eq $dealerTotal) {
                    $payout = $bet
                    $message = 'Push.'
                } else {
                    $payout = 0
                    $message = ('Dealer wins. -{0}' -f $bet)
                }
            }
        }

        $state.credits += $payout
        Save-State -State $state
        Write-Host ''
        Write-Host $message
        Read-Host 'Press Enter'
    }

    Save-State -State $state
}

function Play-CoinFlip {
    $state = Load-State
    $bet = 10

    while ($true) {
        $bonus = Sync-PassiveCredits -State $state
        if ($bonus -gt 0) {
            Save-State -State $state
            Show-Bonus -Bonus $bonus
        }

        Show-GameBanner -Title 'DOUBLE OR NOTHING' -State $state -Bet $bet

        if ($state.credits -le 0) {
            Write-Host 'OUT OF CREDITS - wait for the next free bonus.'
            $answer = Read-Choice '[Enter] check again, [q] quit'
            if ($answer -eq 'q') { break }
            continue
        }

        Write-Host ('[Enter] flip   [b] change bet ({0})   [q] quit' -f $bet)
        $choice = Read-Choice
        if ($choice -eq 'q') { break }
        if ($choice -eq 'b') {
            $bet = Read-Bet -CurrentBet $bet -Credits $state.credits -Minimum 10 -Maximum 500
            continue
        }

        if ($bet -gt $state.credits) {
            Write-Host ''
            Write-Host 'Not enough credits.'
            Read-Host 'Press Enter'
            continue
        }

        $state.credits -= $bet
        $state.passive_earned = 0
        Save-State -State $state
        $pot = $bet

        while ($true) {
            $result = if ((Get-Random -Minimum 0 -Maximum 2) -eq 0) { 'HEADS' } else { 'TAILS' }
            Show-GameBanner -Title 'DOUBLE OR NOTHING' -State $state -Bet $bet
            Write-Host ('Flip: {0}' -f $result)
            if ($result -eq 'HEADS') {
                $pot *= 2
                Write-Host ('Pot is now {0} credits.' -f $pot)
                $next = Read-Choice '[Enter] double again, [c] cash out'
                if ($next -eq 'c') {
                    $state.credits += $pot
                    Save-State -State $state
                    Write-Host ''
                    Write-Host ('Cashed out for {0} credits.' -f $pot)
                    Read-Host 'Press Enter'
                    break
                }
            } else {
                Save-State -State $state
                Write-Host ''
                Write-Host ('Lost the bet. -{0}' -f $bet)
                Read-Host 'Press Enter'
                break
            }
        }
    }

    Save-State -State $state
}

function Get-RpsMoveName {
    param([int]$Move)

    switch ($Move) {
        0 { return 'rock' }
        1 { return 'paper' }
        default { return 'scissors' }
    }
}

function Get-RpsPrediction {
    param(
        [int[]]$Transitions,
        [int]$LastMove
    )

    if ($LastMove -lt 0) {
        return (Get-Random -Minimum 0 -Maximum 3)
    }

    $offset = $LastMove * 3
    $weights = @($Transitions[$offset], $Transitions[$offset + 1], $Transitions[$offset + 2])
    $total = ($weights | Measure-Object -Sum).Sum
    if ($total -le 0) {
        return (Get-Random -Minimum 0 -Maximum 3)
    }

    $roll = Get-Random -Minimum 1 -Maximum ($total + 1)
    $running = 0
    for ($i = 0; $i -lt 3; $i++) {
        $running += $weights[$i]
        if ($roll -le $running) {
            return $i
        }
    }

    return 0
}

function Get-RpsCounter {
    param([int]$PredictedMove)

    switch ($PredictedMove) {
        0 { return 1 }
        1 { return 2 }
        default { return 0 }
    }
}

function Resolve-RpsRound {
    param(
        [int]$PlayerMove,
        [int]$BotMove
    )

    if ($PlayerMove -eq $BotMove) {
        return 'tie'
    }

    if (($PlayerMove -eq 0 -and $BotMove -eq 2) -or
        ($PlayerMove -eq 1 -and $BotMove -eq 0) -or
        ($PlayerMove -eq 2 -and $BotMove -eq 1)) {
        return 'win'
    }

    return 'loss'
}

function Play-RockPaperScissors {
    $state = Load-State
    $bet = 10
    $transitions = @(0, 0, 0, 0, 0, 0, 0, 0, 0)
    $lastMove = -1
    $lastSummary = ''

    while ($true) {
        $bonus = Sync-PassiveCredits -State $state
        if ($bonus -gt 0) {
            Save-State -State $state
            Show-Bonus -Bonus $bonus
        }

        Show-GameBanner -Title 'ROCK PAPER SCISSORS' -State $state -Bet $bet
        if ($lastSummary) {
            Write-Host $lastSummary
            Write-Host ''
        }

        if ($state.credits -le 0) {
            Write-Host 'OUT OF CREDITS - wait for the next free bonus.'
            $answer = Read-Choice '[Enter] check again, [q] quit'
            if ($answer -eq 'q') { break }
            continue
        }

        Write-Host ('[r] rock   [p] paper   [s] scissors   [b] change bet ({0})   [q] quit' -f $bet)
        $choice = Read-Choice
        if ($choice -eq 'q') { break }
        if ($choice -eq 'b') {
            $bet = Read-Bet -CurrentBet $bet -Credits $state.credits -Minimum 1 -Maximum $state.credits
            continue
        }

        $playerMove = switch ($choice) {
            'r' { 0 }
            'p' { 1 }
            's' { 2 }
            default { -1 }
        }
        if ($playerMove -lt 0) {
            continue
        }

        if ($bet -gt $state.credits) {
            Write-Host ''
            Write-Host 'Not enough credits.'
            Read-Host 'Press Enter'
            continue
        }

        $state.credits -= $bet
        $state.passive_earned = 0
        Save-State -State $state

        $prediction = Get-RpsPrediction -Transitions $transitions -LastMove $lastMove
        $botMove = Get-RpsCounter -PredictedMove $prediction
        $result = Resolve-RpsRound -PlayerMove $playerMove -BotMove $botMove

        $payout = 0
        switch ($result) {
            'win' { $payout = $bet * 2 }
            'tie' { $payout = $bet }
            default { $payout = 0 }
        }

        $state.credits += $payout
        Save-State -State $state

        if ($lastMove -ge 0) {
            $slot = ($lastMove * 3) + $playerMove
            $transitions[$slot] += 1
        }
        $lastMove = $playerMove

        $lastSummary = 'You: {0}   Raya: {1}   Result: {2}' -f (Get-RpsMoveName -Move $playerMove), (Get-RpsMoveName -Move $botMove), $result.ToUpperInvariant()
    }

    Save-State -State $state
}

function Get-SlotsPayout {
    param(
        [string[]]$Reels,
        [int]$Bet
    )

    $joined = $Reels -join ','
    switch ($joined) {
        'DM,DM,DM' { return @{ Label = 'DIAMOND JACKPOT'; Payout = $Bet * 100 } }
        'ST,ST,ST' { return @{ Label = 'STAR JACKPOT'; Payout = $Bet * 50 } }
        '77,77,77' { return @{ Label = 'LUCKY SEVENS'; Payout = $Bet * 40 } }
        'CH,CH,CH' { return @{ Label = 'CHERRY BONUS'; Payout = $Bet * 20 } }
        'GR,GR,GR' { return @{ Label = 'GRAPE BONUS'; Payout = $Bet * 15 } }
        'OR,OR,OR' { return @{ Label = 'ORANGE BONUS'; Payout = $Bet * 12 } }
        'LM,LM,LM' { return @{ Label = 'LEMON BONUS'; Payout = $Bet * 10 } }
    }

    if ($Reels[0] -eq $Reels[1] -or $Reels[0] -eq $Reels[2] -or $Reels[1] -eq $Reels[2]) {
        return @{ Label = 'TWO OF A KIND'; Payout = $Bet }
    }

    return @{ Label = 'NO WIN'; Payout = 0 }
}

function Play-Slots {
    $state = Load-State
    $bet = 10

    while ($true) {
        $bonus = Sync-PassiveCredits -State $state
        if ($bonus -gt 0) {
            Save-State -State $state
            Show-Bonus -Bonus $bonus
        }

        Show-GameBanner -Title 'SLOT MACHINE' -State $state -Bet $bet -Width 44

        if ($state.credits -le 0) {
            Write-Host 'OUT OF CREDITS - wait for the next free bonus.'
            $answer = Read-Choice '[Enter] check again, [q] quit'
            if ($answer -eq 'q') { break }
            continue
        }

        Write-Host ('[Enter] spin   [b] change bet ({0})   [q] quit' -f $bet)
        $choice = Read-Choice
        if ($choice -eq 'q') { break }
        if ($choice -eq 'b') {
            $bet = Read-Bet -CurrentBet $bet -Credits $state.credits -Minimum 10 -Maximum 100
            continue
        }

        if ($bet -gt $state.credits) {
            Write-Host ''
            Write-Host 'Not enough credits.'
            Read-Host 'Press Enter'
            continue
        }

        $state.credits -= $bet
        $state.passive_earned = 0
        Save-State -State $state

        $reels = @(
            $script:SlotsSymbols[(Get-Random -Minimum 0 -Maximum $script:SlotsSymbols.Count)],
            $script:SlotsSymbols[(Get-Random -Minimum 0 -Maximum $script:SlotsSymbols.Count)],
            $script:SlotsSymbols[(Get-Random -Minimum 0 -Maximum $script:SlotsSymbols.Count)]
        )
        $result = Get-SlotsPayout -Reels $reels -Bet $bet
        $state.credits += $result.Payout
        Save-State -State $state

        Show-GameBanner -Title 'SLOT MACHINE' -State $state -Bet $bet -Width 44
        Write-Host '+----------------------+'
        Write-Host '|     SLOT MACHINE     |'
        Write-Host '+----------------------+'
        Write-Host ('|   {0,-2}    {1,-2}    {2,-2}   |' -f $reels[0], $reels[1], $reels[2])
        Write-Host '+----------------------+'
        Write-Host ''
        if ($result.Payout -gt 0) {
            Write-Host ('{0}. +{1} credits.' -f $result.Label, $result.Payout)
        } else {
            Write-Host ('{0}. -{1} credits.' -f $result.Label, $bet)
        }
        Read-Host 'Press Enter'
    }

    Save-State -State $state
}

function Show-VideoPokerPaytable {
    param([int]$Bet)

    Clear-Host
    Write-Host '+--------------------------------------------------+'
    Write-Host '|               VIDEO POKER PAY TABLE             |'
    Write-Host '+--------------------------------------------------+'
    Write-Host ('|  Royal Flush       {0,8} credits               |' -f ($Bet * 250))
    Write-Host ('|  Straight Flush    {0,8} credits               |' -f ($Bet * 50))
    Write-Host ('|  Four of a Kind    {0,8} credits               |' -f ($Bet * 25))
    Write-Host ('|  Full House        {0,8} credits               |' -f ($Bet * 9))
    Write-Host ('|  Flush             {0,8} credits               |' -f ($Bet * 6))
    Write-Host ('|  Straight          {0,8} credits               |' -f ($Bet * 4))
    Write-Host ('|  Three of a Kind   {0,8} credits               |' -f ($Bet * 3))
    Write-Host ('|  Two Pair          {0,8} credits               |' -f ($Bet * 2))
    Write-Host ('|  Jacks or Better   {0,8} credits               |' -f $Bet)
    Write-Host ('|  Nothing           {0,8} credits               |' -f 0)
    Write-Host '+--------------------------------------------------+'
    Read-Host 'Press Enter'
}

function Show-VideoPokerHand {
    param(
        [hashtable]$State,
        [int]$Bet,
        [object[]]$Cards,
        [bool[]]$Held,
        [string]$Message = ''
    )

    Show-GameBanner -Title 'VIDEO POKER' -State $State -Bet $Bet -Width 66
    Show-CardRow -Cards @($Cards) -Held $Held

    $holdLabels = @()
    $indexes = @()
    for ($i = 0; $i -lt $Cards.Count; $i++) {
        if ($Held[$i]) {
            $holdLabels += ' HOLD   '
        } else {
            $holdLabels += '        '
        }
        $indexes += ('  [{0}]   ' -f ($i + 1))
    }
    Write-Host ('  {0}' -f ($holdLabels -join ' '))
    Write-Host ('  {0}' -f ($indexes -join ' '))
    Write-Host ''
    if ($Message) {
        Write-Host $Message
        Write-Host ''
    }
}

function Evaluate-VideoPokerHand {
    param(
        [object[]]$Cards,
        [int]$Bet
    )

    $ranks = @()
    $suits = @()
    foreach ($card in $Cards) {
        $ranks += (Get-CardRank -Card ([string]$card))
        $suits += (Get-CardSuit -Card ([string]$card))
    }

    $flush = (($suits | Select-Object -Unique).Count -eq 1)
    $values = @()
    foreach ($rank in $ranks) {
        $values += $script:RankMap[$rank]
    }
    $values = $values | Sort-Object

    $straight = $false
    if (($values | Select-Object -Unique).Count -eq 5) {
        $straight = $true
        for ($i = 1; $i -lt $values.Count; $i++) {
            if ($values[$i] -ne ($values[0] + $i)) {
                $straight = $false
                break
            }
        }

        if (-not $straight -and (($values -join ',') -eq '2,3,4,5,14')) {
            $straight = $true
        }
    }

    $counts = @{}
    foreach ($rank in $ranks) {
        if (-not $counts.ContainsKey($rank)) {
            $counts[$rank] = 0
        }
        $counts[$rank] += 1
    }

    $countValues = @($counts.Values | Sort-Object -Descending)
    $pairRanks = @($counts.Keys | Where-Object { $counts[$_] -eq 2 })
    $jacksOrBetter = $false
    foreach ($rank in $pairRanks) {
        if ($script:RankMap[$rank] -ge 11 -or $rank -eq 'A') {
            $jacksOrBetter = $true
        }
    }

    $royalValues = @(10, 11, 12, 13, 14)
    $royal = $flush
    foreach ($value in $royalValues) {
        if ($values -notcontains $value) {
            $royal = $false
            break
        }
    }

    if ($royal) { return @{ Name = 'Royal Flush'; Payout = $Bet * 250 } }
    if ($flush -and $straight) { return @{ Name = 'Straight Flush'; Payout = $Bet * 50 } }
    if ($countValues[0] -eq 4) { return @{ Name = 'Four of a Kind'; Payout = $Bet * 25 } }
    if ($countValues[0] -eq 3 -and $countValues[1] -eq 2) { return @{ Name = 'Full House'; Payout = $Bet * 9 } }
    if ($flush) { return @{ Name = 'Flush'; Payout = $Bet * 6 } }
    if ($straight) { return @{ Name = 'Straight'; Payout = $Bet * 4 } }
    if ($countValues[0] -eq 3) { return @{ Name = 'Three of a Kind'; Payout = $Bet * 3 } }
    if ($pairRanks.Count -eq 2) { return @{ Name = 'Two Pair'; Payout = $Bet * 2 } }
    if ($pairRanks.Count -eq 1 -and $jacksOrBetter) { return @{ Name = 'Jacks or Better'; Payout = $Bet } }

    return @{ Name = 'Nothing'; Payout = 0 }
}

function Play-VideoPoker {
    $state = Load-State
    $bet = 10

    while ($true) {
        $bonus = Sync-PassiveCredits -State $state
        if ($bonus -gt 0) {
            Save-State -State $state
            Show-Bonus -Bonus $bonus
        }

        Show-GameBanner -Title 'VIDEO POKER' -State $state -Bet $bet -Width 66

        if ($state.credits -le 0) {
            Write-Host 'OUT OF CREDITS - wait for the next free bonus.'
            $answer = Read-Choice '[Enter] check again, [q] quit'
            if ($answer -eq 'q') { break }
            continue
        }

        Write-Host ('[Enter] deal   [b] change bet ({0})   [p] pay table   [q] quit' -f $bet)
        $choice = Read-Choice
        if ($choice -eq 'q') { break }
        if ($choice -eq 'p') {
            Show-VideoPokerPaytable -Bet $bet
            continue
        }
        if ($choice -eq 'b') {
            $bet = Read-Bet -CurrentBet $bet -Credits $state.credits -Minimum 10 -Maximum 500
            continue
        }

        if ($bet -gt $state.credits) {
            Write-Host ''
            Write-Host 'Not enough credits.'
            Read-Host 'Press Enter'
            continue
        }

        $state.credits -= $bet
        $state.passive_earned = 0
        Save-State -State $state

        $deck = New-ShuffledDeck
        $hand = @(
            (Draw-Card -Deck $deck),
            (Draw-Card -Deck $deck),
            (Draw-Card -Deck $deck),
            (Draw-Card -Deck $deck),
            (Draw-Card -Deck $deck)
        )
        $held = @( $false, $false, $false, $false, $false )

        while ($true) {
            Show-VideoPokerHand -State $state -Bet $bet -Cards $hand -Held $held -Message '[1-5] toggle hold   [d] draw   [p] pay table   [q] quit game'
            $raw = Read-Choice
            if ($raw -eq 'q') {
                $state.credits += $bet
                Save-State -State $state
                return
            }
            if ($raw -eq 'p') {
                Show-VideoPokerPaytable -Bet $bet
                continue
            }
            if ($raw -eq 'd') {
                break
            }

            foreach ($token in ($raw -split '[,\s]+' | Where-Object { $_ })) {
                $index = 0
                if ([int]::TryParse($token, [ref]$index) -and $index -ge 1 -and $index -le 5) {
                    $held[$index - 1] = -not $held[$index - 1]
                }
            }
        }

        for ($i = 0; $i -lt $hand.Count; $i++) {
            if (-not $held[$i]) {
                $hand[$i] = Draw-Card -Deck $deck
            }
        }

        $result = Evaluate-VideoPokerHand -Cards $hand -Bet $bet
        $state.credits += $result.Payout
        Save-State -State $state

        Show-VideoPokerHand -State $state -Bet $bet -Cards $hand -Held @( $true, $true, $true, $true, $true ) -Message ('Result: {0}' -f $result.Name)
        if ($result.Payout -gt 0) {
            Write-Host ('+{0} credits.' -f $result.Payout)
        } else {
            Write-Host ('-{0} credits.' -f $bet)
        }

        $again = Read-Choice '[Enter] play again, [q] quit'
        if ($again -eq 'q') {
            break
        }
    }

    Save-State -State $state
}

function New-ScratcherGrid {
    param($Ticket)

    $total = $Ticket.Rows * $Ticket.Cols
    $cells = @()
    for ($i = 0; $i -lt $total; $i++) {
        $cells += $Ticket.Symbols[(Get-Random -Minimum 0 -Maximum $Ticket.Symbols.Count)]
    }

    $roll = Get-Random -Minimum 0 -Maximum 1000
    $winCount = 0
    if ($roll -lt 2) {
        $winCount = 5
    } elseif ($roll -lt 8) {
        $winCount = 4
    } elseif ($roll -lt 30) {
        $winCount = 3
    } elseif ($roll -lt 80) {
        $winCount = 2
    }

    if ($winCount -gt $total) {
        $winCount = $total
    }

    if ($winCount -ge 2) {
        $winningSymbol = $Ticket.Symbols[(Get-Random -Minimum 0 -Maximum $Ticket.Symbols.Count)]
        $positions = @(0..($total - 1) | Sort-Object { Get-Random } | Select-Object -First $winCount)
        $others = @($Ticket.Symbols | Where-Object { $_ -ne $winningSymbol })
        if ($others.Count -eq 0) {
            $others = @($Ticket.Symbols)
        }

        for ($i = 0; $i -lt $total; $i++) {
            if ($positions -contains $i) {
                $cells[$i] = $winningSymbol
            } else {
                $cells[$i] = $others[(Get-Random -Minimum 0 -Maximum $others.Count)]
            }
        }
    }

    return $cells
}

function Show-ScratcherGrid {
    param(
        $Ticket,
        [string[]]$Cells,
        [bool[]]$Revealed,
        [string]$Message = ''
    )

    Show-GameBanner -Title 'SCRATCHERS' -State $script:ScratchState -Bet 0 -Width 50
    Write-Host ('Ticket: {0}   Cost: {1}' -f $Ticket.Name, $Ticket.Cost)
    Write-Host ('Rules:  {0}' -f $Ticket.Description)
    Write-Host ''

    $index = 0
    $cellWidth = 4
    $rowWidth = ($Ticket.Cols * ($cellWidth + 1)) + 1
    Write-Host ('  +{0}+' -f (Get-RepeatText -Character '-' -Count ($rowWidth - 2)))
    for ($row = 0; $row -lt $Ticket.Rows; $row++) {
        $parts = @()
        for ($col = 0; $col -lt $Ticket.Cols; $col++) {
            if ($Revealed[$index]) {
                $parts += (' {0,-2} ' -f $Cells[$index])
            } else {
                $parts += (' {0:00} ' -f ($index + 1))
            }
            $index += 1
        }
        Write-Host ('  |{0}|' -f ($parts -join '|'))
    }
    Write-Host ('  +{0}+' -f (Get-RepeatText -Character '-' -Count ($rowWidth - 2)))

    Write-Host ''
    if ($Message) {
        Write-Host $Message
        Write-Host ''
    }
}

function Get-ScratcherResult {
    param(
        $Ticket,
        [string[]]$Cells
    )

    $counts = @{}
    foreach ($cell in $Cells) {
        if (-not $counts.ContainsKey($cell)) {
            $counts[$cell] = 0
        }
        $counts[$cell] += 1
    }

    $bestSymbol = ''
    $bestCount = 0
    foreach ($symbol in $counts.Keys) {
        if ($counts[$symbol] -gt $bestCount) {
            $bestCount = $counts[$symbol]
            $bestSymbol = $symbol
        }
    }

    foreach ($key in @($Ticket.Paytable.Keys | Sort-Object -Descending)) {
        if ($bestCount -ge [int]$key) {
            $winnings = [math]::Floor($Ticket.Cost * ([int]$Ticket.Paytable[$key]) / 100)
            return @{
                Winnings = $winnings
                Label = ('{0} x {1}' -f $bestCount, $bestSymbol)
            }
        }
    }

    return @{
        Winnings = 0
        Label = 'No match'
    }
}

function Play-Scratchers {
    $script:ScratchState = Load-State

    while ($true) {
        $bonus = Sync-PassiveCredits -State $script:ScratchState
        if ($bonus -gt 0) {
            Save-State -State $script:ScratchState
            Show-Bonus -Bonus $bonus
        }

        Show-GameBanner -Title 'SCRATCHERS' -State $script:ScratchState -Bet 0 -Width 50
        foreach ($ticket in $script:ScratchTickets) {
            Write-Host ('[{0}] {1} - {2} credits' -f $ticket.Id, $ticket.Name, $ticket.Cost)
            Write-Host ('    {0}' -f $ticket.Description)
        }
        Write-Host ''

        if ($script:ScratchState.credits -le 0) {
            Write-Host 'OUT OF CREDITS - wait for the next free bonus.'
            $answer = Read-Choice '[Enter] check again, [q] quit'
            if ($answer -eq 'q') { break }
            continue
        }

        $choice = Read-Choice '[1/2/3] buy ticket, [q] quit'
        if ($choice -eq 'q') { break }

        $ticket = $script:ScratchTickets | Where-Object { $_.Id -eq $choice } | Select-Object -First 1
        if ($null -eq $ticket) {
            continue
        }

        if ($ticket.Cost -gt $script:ScratchState.credits) {
            Write-Host ''
            Write-Host ('Not enough credits for {0}.' -f $ticket.Name)
            Read-Host 'Press Enter'
            continue
        }

        $script:ScratchState.credits -= $ticket.Cost
        $script:ScratchState.passive_earned = 0
        Save-State -State $script:ScratchState

        $cells = @([string[]](New-ScratcherGrid -Ticket $ticket))
        $revealed = @()
        for ($i = 0; $i -lt $cells.Count; $i++) {
            $revealed += $false
        }

        while ($revealed -contains $false) {
            Show-ScratcherGrid -Ticket $ticket -Cells $cells -Revealed $revealed -Message '[Enter] next cell   [a] all   [q] reveal all'
            $input = Read-Choice
            if ($input -eq 'a' -or $input -eq 'q') {
                for ($i = 0; $i -lt $revealed.Count; $i++) {
                    $revealed[$i] = $true
                }
                break
            }

            $picked = 0
            if ([int]::TryParse($input, [ref]$picked) -and $picked -ge 1 -and $picked -le $revealed.Count) {
                $revealed[$picked - 1] = $true
            } else {
                for ($i = 0; $i -lt $revealed.Count; $i++) {
                    if (-not $revealed[$i]) {
                        $revealed[$i] = $true
                        break
                    }
                }
            }
        }

        $result = Get-ScratcherResult -Ticket $ticket -Cells $cells
        $script:ScratchState.credits += $result.Winnings
        Save-State -State $script:ScratchState

        Show-ScratcherGrid -Ticket $ticket -Cells $cells -Revealed $revealed -Message ('Result: {0}' -f $result.Label)
        if ($result.Winnings -gt 0) {
            $net = $result.Winnings - $ticket.Cost
            Write-Host ('Winner. +{0} credits (net {1}).' -f $result.Winnings, $net)
        } else {
            Write-Host ('No match. -{0} credits.' -f $ticket.Cost)
        }
        Read-Host 'Press Enter'
    }

    Save-State -State $script:ScratchState
}

switch ($Game) {
    'blackjack' { Play-Blackjack }
    'coinflip' { Play-CoinFlip }
    'rock_paper_scissors' { Play-RockPaperScissors }
    'scratchers' { Play-Scratchers }
    'slots' { Play-Slots }
    'video_poker' { Play-VideoPoker }
}
