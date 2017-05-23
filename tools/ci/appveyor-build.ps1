# Helper build script for AppVeyor environment.
#  Each AppVeyor job including the tests takes under 5 minutes; the upper limit is 60 minutes.
#  We can make all builds for a given generator (family) in a single entry.
#  On a high level, this script is invoked with a generator (env), it builds the project
#    - for each platform ("x86" and "x64") - Visual Studio only
#    - for each configuration ("Debug" and "Release")

function CMakeBuild() {
  param(
    [Parameter(Mandatory)] [string] $Generator,
    [string] $Platform = "unknown",
    [array] $BuildArgs
  )
  foreach ($config in "Debug","Release") {
    New-Item -Path "$Platform-$config" -ItemType Directory | Push-Location

    cmake -G "$Generator" -DCMAKE_BUILD_TYPE=$config $env:APPVEYOR_BUILD_FOLDER 2>&1 | %{ "$_" }
    if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode)  }

    cmake --build . --config $config -- $BuildArgs 2>&1 | %{ "$_" }
    if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode)  }

    Pop-Location
  }
}

New-Item -Path build -ItemType Directory -Force | Push-Location

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
  $env:PATH = $tmpPATH
}

Pop-Location
