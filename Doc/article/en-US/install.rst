=======
Install
=======

Powershell modules are installed by copying the powershell files into a known directory that is on the PSModulePath environment variable.  I like to use:

	C:\Users\<USER_NAME>\Documents\WindowsPowerShell\Modules

Make sure that folder is in the PSModulePath variable.

Install the module straight from git by:

	cd C:\Users\Michael\Documents\WindowsPowerShell\Modules
	git clone https://github.com/Miruken-DotNet/SymbolDownloader.git	

Now open a powershell window in a solution or project directory. Then import the SymbolDownloader module:

	Import-Module SymbolDownloader
	
SymbolDownloader is now ready to use.	
