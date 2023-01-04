$script:project_config = "Debug"

properties {
    $base_dir = resolve-path .
    $temp_tools_dir="$base_dir/temp-tools"
    $solution_file = "$base_dir\$solution_name.sln"
    $applicationPath = "$base_dir\src\$solution_name.Application"
    $app_project_file = "$applicationPath\$solution_name.Application.csproj"
    $date = Get-Date
    $dotnet_exe = get-dotnet
    $version = get_version
    $config_server_uri = "http://localhost:8888/"

    $release_id = "linux-x64"
    $target_frameworks = "net6.0"
    $app_publish_dir = "$base_dir\publish-artifacts\app\$release_id"
    $test_results_dir = "$base_dir\test-results"
    $test_coverage_threshold = 0 # normally set to 85 (85%), or some high threshold. turned to 0 since this is a legacy app with 0 coverage.
    # will fail the build if not met
    $registry = 'index.docker.io/<repo_name>'
    $imageName = 'configloader-sidecar-app'
    $containerName = 'configloader-sidecar-app'
    $imageTag = "$version"

    $fullImageName = "$($imageName):$($imageTag)"
    $fullImageTag = "$registry/$fullImageName"
}
#These are aliases for other build tasks. They typically are named after the camelcase letters (rd = Rebuild Databases)
task default -depends DevBuild
task dp -depends DevPublish
task cib -depends CiBuild
task cip -depends CiPublish
task ci -depends CreateImage
task pi -depends PushImage
task cpi -depends ci,pi
task ri -depends RunImage
task ? -depends help

task EmitProperties {
    Write-Host "base_dir=$base_dir"
    Write-Host "solution_file=$solution_file"
    Write-Host "app_project_file=$app_project_file"
    Write-Host "applicationPath=$applicationPath"
    Write-Host "date=$date"
    Write-Host "dotnet_exe=$dotnet_exe"
    Write-Host "version=$version"
    Write-Host "config_server_uri=$config_server_uri"
    Write-Host "release_id=$release_id"
    Write-Host "target_frameworks=$target_frameworks"
    Write-Host "project_config=$project_config"
    Write-Host "app_publish_dir=$app_publish_dir"
    Write-Host "test_results_dir=$test_results_dir"
    Write-Host "test_coverage_threshold=$test_coverage_threshold%"
    Write-Host "registry=$registry"
    Write-Host "imageName=$imageName"
    Write-Host "containerName=$containerName"
    Write-Host "imageTag=$imageTag"
    Write-Host "fullImageName=$fullImageName"
    Write-Host "fullImageTag=$fullImageTag"
}

task help {
    Write-Help-Header
    Write-Help-Section-Header "Comprehensive Building"
    Write-Help-For-Alias "(default)" "Intended for first build or when you want a fresh, clean local copy"
    Write-Help-For-Alias "dp" "Developer build and test with publishing"
    Write-Help-For-Alias "ci" "Continuous Integration build (long and thorough)"
    Write-Help-For-Alias "cp" "Continuous Integration build (long and thorough) with publishing"
    Write-Help-Footer
    exit 0
}
#These are the actual build tasks. They should be Pascal case by convention
task b -depends SetDebugBuild, EmitProperties, Restore, Clean, Build
task DevBuild -depends SetDebugBuild, EmitProperties, Restore, Clean, Build, UnitTests
task DevPublish -depends DevBuild, Publish
task CiBuild -depends SetReleaseBuild, EmitProperties, Restore, Clean, Build, UnitTests
task CiPublish -depends CiBuild, Publish

task SetDebugBuild {
    $script:project_config = "Debug"
}

task SetReleaseBuild {
    $script:project_config = "Release"
}

task Restore {
    Write-Host "******************* Now restoring the solution dependencies *********************"  -ForegroundColor Green
    exec {
        & $dotnet_exe msbuild /t:restore $solution_file /v:m /p:NuGetInteractive="true" /p:RuntimeIdentifier=$release_id
    }
}

task Clean {
    Write-Host "******************* Now cleaning the solution and artifacts *********************"  -ForegroundColor Green
    if (Test-Path $app_publish_dir)
    {
        delete_directory $app_publish_dir
    }
    exec {
        & $dotnet_exe msbuild /t:clean /v:m /p:Configuration=$project_config $solution_file
    }
}

task Build {
    Write-Host "******************* Now compiling the solution *********************"  -ForegroundColor Green
    exec {
        & $dotnet_exe msbuild /t:build /v:m /p:Configuration=$project_config /nologo /p:Platform="Any CPU" /nologo $solution_file
    }
}

task UnitTests {
    Write-Host "******************* Now running unit tests, generating and assessing code coverage results*********************"  -ForegroundColor Green
    if (Test-Path $test_results_dir)
    {
        delete_directory $test_results_dir
    }
    Push-Location $base_dir
    $test_projects = @((Get-ChildItem -Recurse -Filter "*UnitTests.csproj").FullName) -join '~'

    foreach($test_project in $test_projects.Split("~"))
    {
        Write-Host "Executing tests on: $test_project"
        exec {
            $test_project_name = (Get-Item $test_project).Directory.Name.TrimEnd("UnitTests").TrimEnd(".")
            & $dotnet_exe test /p:threshold=$test_coverage_threshold /p:ThresholdType=line /p:SkipAutoProps=true /p:Include="[$test_project_name]*" /p:CollectCoverage=true /p:CoverletOutput="$test_results_dir/$test_project_name/" /p:CoverletOutputFormat="cobertura" $test_project --no-restore --configuration $project_config --settings "$base_dir\test-run-settings" -- xunit.parallelizeTestCollections=true
        }
    }
    Pop-Location
}

task Publish {
    Write-Host "******************* Now publishing the application to $app_publish_dir *********************"  -ForegroundColor Green
    exec {
        & $dotnet_exe msbuild /t:restore $solution_file /v:m /p:NuGetInteractive="true" /p:RuntimeIdentifier=$release_id /p:TargetFrameworks=$target_frameworks
        & $dotnet_exe msbuild /t:publish /v:m /p:Platform=$platform /p:TargetFrameworks=$target_frameworks /p:RuntimeIdentifier=$release_id /p:PublishDir=$app_publish_dir /p:Configuration=$project_config /nologo $app_project_file
    }
}

task CreateImage {
    Write-Host "******************* Now creating image $fullImageTag using pack *********************"  -ForegroundColor Green
    exec {
        & pack build $imageName --tag $fullImageTag `
            --builder paketobuildpacks/builder:full `
            --buildpack paketo-buildpacks/dotnet-core `
            --env BP_EMBED_CERTS=true --env BP_DOTNET_PROJECT_PATH='./src/ConfigLoader.SideCar.Application'
    }
}

task PushImage {
    Write-Host "******************* Now pushing image $fullImageTag using pack *********************"  -ForegroundColor Green
    exec {
        & docker push $fullImageTag
    }
}

task RunImage {
    Write-Host "******************* Running image $fullImageTag *********************"  -ForegroundColor Green
    exec {
        docker run --env ASPNETCORE_ENVIRONMENT=development `
            --env APPLICATION_NAME=ui --env CONFIGSERVER_URI="$config_server_uri" `
            --env CONFIG_FOLDER_PATH="/dist/assets/config/" --env CONFIG_FILE_NAME="config.json" `
            --env ENABLE_DIAGNOSTICS_ENDPOINTS=true `
            --name $containerName -u 0 `
            -p 8089:8080 --rm -it `
            $fullImageTag
    }
}

# -------------------------------------------------------------------------------------------------------------
# generalized functions for Help Section
# --------------------------------------------------------------------------------------------------------------
function Write-Help-Header($description)
{
    Write-Host ""
    Write-Host "********************************" -foregroundcolor DarkGreen -nonewline;
    Write-Host " HELP " -foregroundcolor Green  -nonewline;
    Write-Host "********************************"  -foregroundcolor DarkGreen
    Write-Host ""
    Write-Host "This build script has the following common build " -nonewline;
    Write-Host "task " -foregroundcolor Green -nonewline;
    Write-Host "aliases set up:"
}

function Write-Help-Footer($description)
{
    Write-Host ""
    Write-Host " For a complete list of build tasks, view default.ps1."
    Write-Host ""
    Write-Host "**********************************************************************" -foregroundcolor DarkGreen
}

function Write-Help-Section-Header($description)
{
    Write-Host ""
    Write-Host " $description" -foregroundcolor DarkGreen
}

function Write-Help-For-Alias($alias,$description)
{
    Write-Host "  > " -nonewline;
    Write-Host "$alias" -foregroundcolor Green -nonewline;
    Write-Host " = " -nonewline;
    Write-Host "$description"
}

# -------------------------------------------------------------------------------------------------------------
# generalized functions
# --------------------------------------------------------------------------------------------------------------
function global:delete_file($file)
{
    if($file)
    { remove-item $file -force -ErrorAction SilentlyContinue | out-null 
    }
}

function global:delete_directory($directory_name)
{
    rd $directory_name -recurse -force  -ErrorAction SilentlyContinue | out-null
}

function global:get-dotnet()
{
    return (Get-Command dotnet).Path
}

function global:get_version()
{
    create_directory($temp_tools_dir)

    if ($IsMacOS)
    {
        Write-Host "Running in MacOS"  -ForegroundColor Blue
        $file="$temp_tools_dir/gitversion-osx.tar.gz"
        if(-Not(Test-Path $file))
        {
            Invoke-WebRequest -Uri "https://github.com/GitTools/GitVersion/releases/download/5.11.1/gitversion-osx-x64-5.11.1.tar.gz" -OutFile "$temp_tools_dir/gitversion-osx.tar.gz"
        }
        tar -xvzf $file -C "$temp_tools_dir"
        & chmod +x "$temp_tools_dir/gitversion"
        $gitversion = "$temp_tools_dir/gitversion"
    } 
    elseif ($IsLinux)
    {
        Write-Host "Running in Linux"  -ForegroundColor Blue
        $file="$temp_tools_dir/gitversion-linux.tar.gz"
        if(-Not(Test-Path $file))
        {
            Invoke-WebRequest -Uri "https://github.com/GitTools/GitVersion/releases/download/5.11.1/gitversion-linux-x64-5.11.1.tar.gz" -OutFile "$temp_tools_dir/gitversion-linux.tar.gz"
        }
        tar -xvzf "$file" -C "$temp_tools_dir"
        & chmod +x "$temp_tools_dir/gitversion"
        $gitversion = "$temp_tools_dir/gitversion"
    } 
    else
    {
        Write-Host "Running in Windows"  -ForegroundColor Blue
        $file="$base_dir/tools/gitversion/gitversion-win.zip"
        if(-Not(Test-Path $file))
        {
            Invoke-WebRequest -Uri "https://github.com/GitTools/GitVersion/releases/download/5.11.1/gitversion-win-x64-5.11.1.zip" -OutFile "$temp_tools_dir/gitversion-win.zip"
        }
        Expand-Archive -Path "$file" -DestinationPath "$temp_tools_dir/gitversion" -Force
        $gitversion = "$temp_tools_dir/gitversion/gitversion.exe"
    }
    
    return exec { & $gitversion /output json /showvariable FullSemVer }
}

function global:create_directory($directory_name)
{
    New-Item $directory_name -Force  -ItemType "directory" -ErrorAction SilentlyContinue | Out-Null
}