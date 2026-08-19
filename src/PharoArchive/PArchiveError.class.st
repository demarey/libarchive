"
A PArchiveError is raised whenever libarchive reports a failure. It carries the
underlying error message coming from archive_error_string(), so callers get a
meaningful description instead of a raw return code.
"
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
