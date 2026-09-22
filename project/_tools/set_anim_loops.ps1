# Sets "settings/loop_mode": 1 for continuous animations in the Rig_Medium
# GLB import files (idle/walk/run/aim/etc). Rerun godot --import afterwards.
$ErrorActionPreference = 'Stop'
$dir = Join-Path $PSScriptRoot "..\_not_exported\animations"

$loops = @{
  "Rig_Medium_General"          = @("Idle_A","Idle_B")
  "Rig_Medium_MovementBasic"    = @("Walking_A","Walking_B","Walking_C","Running_A","Running_B","Jump_Idle")
  "Rig_Medium_MovementAdvanced" = @("Crawling","Crouching","Sneaking","Walking_Backwards","Running_HoldingBow","Running_HoldingRifle","Running_Strafe_Left","Running_Strafe_Right")
  "Rig_Medium_CombatMelee"      = @("Melee_2H_Idle","Melee_Blocking","Melee_Unarmed_Idle")
  "Rig_Medium_CombatRanged"     = @("Ranged_1H_Aiming","Ranged_2H_Aiming","Ranged_1H_Shooting","Ranged_2H_Shooting","Ranged_Bow_Aiming_Idle","Ranged_Bow_Idle","Ranged_Magic_Spellcasting")
  "Rig_Medium_Simulation"       = @("Lie_Idle","Sit_Chair_Idle","Sit_Floor_Idle","Cheering","Push_Ups","Sit_Ups","Waving")
}

foreach ($glb in $loops.Keys | Sort-Object) {
    $file = Join-Path $dir "$glb.glb.import"
    $text = [System.IO.File]::ReadAllText($file)
    $count = 0
    foreach ($anim in $loops[$glb]) {
        $pattern = '("' + [regex]::Escape($anim) + '": \{[^}]*?"settings/loop_mode": )0'
        $new = [regex]::Replace($text, $pattern, '${1}1')
        if ($new -ne $text) { $count++; $text = $new }
    }
    [System.IO.File]::WriteAllText($file, $text, (New-Object System.Text.UTF8Encoding($false)))
    "{0}: {1}/{2} animations tagged looping" -f $glb, $count, $loops[$glb].Count
}
