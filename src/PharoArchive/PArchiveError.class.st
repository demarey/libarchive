Class {
	#name : 'PArchiveError',
	#superclass : 'Error',
	#category : 'PharoArchive',
	#package : 'PharoArchive'
}

{ #category : 'instance creation' }
PArchiveError class >> signalOn: aReference errorString: aString [

	^ self
		signal: 'Libarchive error while handling ', aReference printString,
			': ', aString
]
