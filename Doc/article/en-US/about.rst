=====
About
=====

Visual Studio supports debugging with symbol files out of the box.  Resharper also supports debuging with symbol files.  However, the process of downloading the files has proven to be frustrating and unreliable.  There are at least 3 major issues we've identified when trying to download symbols and source files.


SymbolDownloader downloads .pdb files and all associated source files for a nuget package independently of Visual Studio.
