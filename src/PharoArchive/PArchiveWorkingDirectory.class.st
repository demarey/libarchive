"
PArchiveWorkingDirectory temporarily changes the process working directory for the
duration of a block and faithfully restores it afterwards. The underlying chdir call
is dispatched according to the platform (POSIX chdir on Linux/macOS, wide-character
_wchdir on Windows), since libarchive's native extraction writes relative to the
current working directory.
"
Class {
	#name : 'PArchiveWorkingDirectory',
	#superclass : 'Object',
	#category : 'PharoArchive',
	#package : 'PharoArchive'
}

{ #category : 'private' }
PArchiveWorkingDirectory class >> chdirTo: aPathString [

	((LibC uniqueInstance) chdirSafe: aPathString) = 0
		ifFalse: [ PArchiveError signal: 'chdir failed for: ', aPathString ]
]

{ #category : 'accessing' }
PArchiveWorkingDirectory class >> currentWorkingDirectory [

	^ OSPlatform current currentWorkingDirectoryPath
]

{ #category : 'convenience' }
PArchiveWorkingDirectory class >> in: aDirectoryReference during: aBlock [
	"Change the process working directory to aDirectoryReference for the duration of aBlock,
	then restore it. Raises PArchiveError if the directory change fails."

	| previous |
	previous := self currentWorkingDirectory.
	[ self chdirTo: aDirectoryReference fullName.
	  aBlock value ]
	ensure: [ self chdirTo: previous ]
]
