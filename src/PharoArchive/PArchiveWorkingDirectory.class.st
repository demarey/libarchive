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
