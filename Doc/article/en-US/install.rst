=======
Install
=======

Powershell modules are installed by copying the files into a known directory that is on the PSModulePath environment variable.  Make sure that the following folder is in the PSModulePath variable.

Install the module straight from git by:

	cd c:\Program Files\WindowsPowerShell\Modules
	git clone https://github.com/Miruken-DotNet/SymbolDownloader.git	

SymbolDownloader is a powershell module.  First import the module into the current session:

	Import-Module .\SymbolDownloader.psm1