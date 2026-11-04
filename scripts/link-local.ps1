# Links every skill in skills/ into .claude/skills/ as a directory junction,
# so Claude Code in this repo runs the source copy you are editing.
$root = Split-Path -Parent $PSScriptRoot
foreach ($skill in Get-ChildItem -Directory "$root\skills") {
  $link = "$root\.claude\skills\$($skill.Name)"
  if (-not (Test-Path $link)) {
    New-Item -ItemType Junction -Path $link -Target $skill.FullName | Out-Null
    Write-Output "linked $($skill.Name)"
  }
}
