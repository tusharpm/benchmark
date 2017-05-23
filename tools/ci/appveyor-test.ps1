# Companion script to appveyor-build.ps1 - runs the tests built there

Push-Location build
Get-ChildItem -Directory | ForEach-Object {
  $dirName = $_.Name
  Push-Location $dirName

  # HACK - getting config from name is risky. Change to something more stable.
  $config = $_.Name.Split('-')[-1]
  ctest -C $config --timeout 300 -T test --output-on-failure 2>&1 | %{ "$_" }
  if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode)  }

  (Get-ChildItem -Path CMakeFiles -File *.log) +
  (Get-ChildItem -Path Testing -File -Recurse *.xml) | ForEach-Object {
    Push-AppveyorArtifact $_.FullName -FileName ($dirName + "-" + $_.Name)
  }

  Pop-Location
}
Pop-Location
