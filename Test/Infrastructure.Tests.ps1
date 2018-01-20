$source = "$(Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent)\source"
$test   = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$source\Infrastructure.ps1"

Describe "Get-Config" {
    It "Should have configured sourceFolder" {
        (Get-Config).symbolFolder | Should not be $null
    }

    It "Should have configured nugetServers" {
        (Get-Config).nugetServers.Count | Should BeGreaterThan 0 
    }

    It "Should have configured symbolsServers" {
        (Get-Config).symbolServers.Count | Should BeGreaterThan 0 
    }
}

Describe "Join-Parts" {
    It "Should add missing /" {
        Join-Parts "a","b" | Should Be "a/b"
    }

    It "Should not duplicate / from left" {
        Join-Parts "a/","b" | Should Be "a/b"
    }

    It "Should not duplicate / from right" {
        Join-Parts "a","/b" | Should Be "a/b"
    }

    It "Should not duplicate / from both" {
        Join-Parts "a/","/b" | Should Be "a/b"
    }

    It "Should specify specific seperator" {
        Join-Parts "a","b" "," | Should Be "a,b"
    }

    It "should not duplicate specific seperator" {
        Join-Parts "a,",",b" "," | Should Be "a,b"
    }
}

Describe "Unzip" {
    
    BeforeEach {
        $path = "$Test\_temp"
        if(Test-Path $path){
            Remove-Item -Force -Recurse $path
        }
    }
    
    It "Should unzip file" {
        Unzip "$Test\Miruken.zip" "$Test\_temp\Miruken"
        Test-Path "$Test\_temp\Miruken\Miruken.nuspec" | Should Be $true
    }
}

Describe "Create-Directory" {
    
    BeforeEach {
        $path = "$Test\_temp"
        if(Test-Path $path){
            Remove-Item -Force -Recurse $path
        }
    }
    
    It "Should create nested directory" {
        $path = "$test\_temp\foo\bar\baz"
        Create-Directory $path
        Test-Path $path | Should Be $true
    }
}

#Rethink this test now that I am writing the binary file stream
Describe "Download-File" {
    
    BeforeEach {
        $path = "$Test\_temp"
        if(Test-Path $path){
            Remove-Item -Force -Recurse $path
        }
    }
    
    #It "Should return false when file does not exist" {
    #    $uri  = "http://build.miruken.com/doesNotExist"
    #    $path = "$test/_temp/file.txt"
    #    Download-File $uri $path | Should Be $false
    #}

    #It "Should return true when file does exist" {
    #    $uri  = "https://raw.githubusercontent.com/Miruken-DotNet/SymbolDownloader/master/README.rst"
    #    $path = "$test/_temp/README.rst"
    #    Download-File $uri $path | Should Be $true
    #    Test-Path $path | Should Be $true
    #}
}