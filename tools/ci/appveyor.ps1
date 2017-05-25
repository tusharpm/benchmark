# Helper script for AppVeyor environment.
#  Each AppVeyor job including the tests takes under 5 minutes; the upper limit is 60 minutes.
#  We can make all builds for a given generator (family) in a single entry.
#  For build, this script is invoked with a generator (env), it builds the project
#    - for each platform (x86/x64) - Visual Studio only
#    - for each configuration (Debug/Release)
#  For test, it runs the built tests for the selected configurations (Debug/Release)
param (
  [Parameter(Position=1)] [string] $Action = "build",
  [array] $Configurations = @("Debug","Release")
)

if ($Action -notin "build","test") {
  Write-Output "Usage:
  .\appveyor.ps1 [[-Action] string] [-Configurations array]
  Action:
    build - CMake generate and build
    test - Run the built tests. Useful only after running build.
    Default: build
  Configurations:
    Specify (and limit) the configurations to perform the action for.
    Ex: `"Debug`" <- limits the action to Debug configuration only
    Default: `"Debug`",`"Release`""
  return
}

function CMakeBuild() {
  param (
    [Parameter(Mandatory)] [string] $Generator,
    [string] $Platform = "unknown",
    [array] $BuildArgs
  )
  foreach ($config in $Configurations) {
    New-Item -Path "$Platform-$config" -ItemType Directory | Push-Location

    cmake -G "$Generator" -DCMAKE_BUILD_TYPE=$config $env:APPVEYOR_BUILD_FOLDER 2>&1 | %{ "$_" }
    if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode)  }

    cmake --build . --config $config -- $BuildArgs 2>&1 | %{ "$_" }
    if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode)  }

    Pop-Location
  }
}

function RunTests() {
  foreach ($config in $Configurations) {
    Get-ChildItem -Directory -Filter "*$config" | ForEach-Object {
      $dirName = $_.Name
      Push-Location $dirName

      ctest -C $config --timeout 300 -T test --output-on-failure 2>&1 | %{ "$_" }
      if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode)  }

      (Get-ChildItem -Path CMakeFiles -File *.log) +
      (Get-ChildItem -Path Testing -File -Recurse *.xml) | ForEach-Object {
        Push-AppveyorArtifact $_.FullName -FileName ($dirName + "-" + $_.Name)
      }

      Pop-Location
    }
  }
}

New-Item -Path build -ItemType Directory -Force | Push-Location

if ($Action -eq "build") {
  if ($env:generator -match "Visual Studio") {
    $buildArgs = "/nologo","/m","/v:m","/logger:C:\Program Files\AppVeyor\BuildAgent\Appveyor.MSBuildLogger.dll"
    CMakeBuild -Generator $env:generator -Platform "x86" -BuildArgs $buildArgs
    CMakeBuild -Generator "$env:generator Win64" -Platform "x64" -BuildArgs $buildArgs
  }
  elseif ($env:generator -eq "MinGW Makefiles") {
    $tmpPATH = $env:PATH
    # git bash conflicts with MinGW makefiles
    $env:PATH = $tmpPATH.Replace("C:\Program Files\Git\usr\bin", "C:\mingw-w64\i686-5.3.0-posix-dwarf-rt_v4-rev0\mingw32\bin")
    CMakeBuild -Generator $env:generator -Platform "MinGW-w64" -BuildArgs "-j4"
  }
}
elseif ($Action -eq "test") {
  RunTests
}

Pop-Location
