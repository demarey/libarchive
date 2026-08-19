Class {
	#name : 'PArchiveReader',
	#superclass : 'Object',
	#instVars : [
		'file'
	],
	#pools : [
		'ArchiveConstants'
	],
	#category : 'PharoArchive',
	#package : 'PharoArchive'
}

{ #category : 'defaults' }
PArchiveReader class >> defaultExtractFlags [

	^ ARCHIVE_EXTRACT_PERM bitOr: (ARCHIVE_EXTRACT_TIME
		bitOr: (ARCHIVE_EXTRACT_SECURE_NODOTDOT
			bitOr: ARCHIVE_EXTRACT_SECURE_NOABSOLUTEPATHS))
]

{ #category : 'instance creation' }
PArchiveReader class >> onFile: aFileReference [

	^ self new initializeFile: aFileReference
]

{ #category : 'private' }
PArchiveReader >> assertExtractOk: aResult lib: lib archive: archive [

	aResult >= ARCHIVE_OK ifFalse: [
		PArchiveError signalOn: file errorString: (lib error_string: archive) ]
]

{ #category : 'private' }
PArchiveReader >> assertOk: aResult lib: lib archive: archive [

	aResult = ARCHIVE_OK ifFalse: [
		PArchiveError signalOn: file errorString: (lib error_string: archive) ]
]

{ #category : 'reading' }
PArchiveReader >> contentsOf: aPArchiveEntry [

	| result |
	result := nil.
	self withOpenArchive: [ :lib :archive |
		| holder found size buffer offset n |
		found := false.
		result := ByteArray new: 0.
		holder := ArchiveEntry newValueHolder.
		[ (lib read_next_headerArg1: archive arg2: holder) = ARCHIVE_OK ] whileTrue: [
			(lib entry_pathname: holder value) = aPArchiveEntry pathname
				ifTrue: [
					found := true.
					size := aPArchiveEntry size.
					result := ByteArray new: size.
					buffer := ByteArray new: 65536.
					offset := 1.
					[ (n := lib read_dataArg1: archive arg2: buffer size_t: buffer size) > 0 ]
						whileTrue: [
							result replaceFrom: offset to: offset + n - 1 with: buffer startingAt: 1.
							offset := offset + n ] ] ].
		self assert: found ].
	^ result
]

{ #category : 'reading' }
PArchiveReader >> entries [

	| result |
	result := nil.
	self withOpenArchive: [ :lib :archive |
		| holder entries |
		entries := OrderedCollection new.
		holder := ArchiveEntry newValueHolder.
		[ (lib read_next_headerArg1: archive arg2: holder) = ARCHIVE_OK ] whileTrue: [
			entries add: (PArchiveEntry fromHandle: holder value library: lib) ].
		result := entries ].
	^ result
]

{ #category : 'extracting' }
PArchiveReader >> extractTo: aDirectoryReference [

	self extractTo: aDirectoryReference flags: self class defaultExtractFlags
]

{ #category : 'extracting' }
PArchiveReader >> extractTo: aDirectoryReference flags: flags [
	"Extract all entries into aDirectoryReference using libarchive's native extractor.
	The process working directory is temporarily switched to aDirectoryReference
	(because archive_read_extract writes relative to it), then restored."

	aDirectoryReference ensureCreateDirectory.
	PArchiveWorkingDirectory in: aDirectoryReference during: [
		self withOpenArchive: [ :lib :archive |
			| holder |
			holder := ArchiveEntry newValueHolder.
			[ (lib read_next_headerArg1: archive arg2: holder) = ARCHIVE_OK ] whileTrue: [
				self assertExtractOk: (lib read_extractArg1: archive arg2: holder value flags: flags)
					lib: lib
					archive: archive ] ] ]
]

{ #category : 'initialization' }
PArchiveReader >> initializeFile: aFileReference [

	file := aFileReference
]

{ #category : 'private' }
PArchiveReader >> withOpenArchive: aBlock [

	| lib archive |
	lib := LibArchive uniqueInstance.
	archive := lib read_new.
	[ 
		lib read_support_filter_all: archive.
		lib read_support_format_all: archive.
		self assertOk: (lib
				read_open_filenameArg1: archive
				_filename: file fullName
				_block_size: 10240)
			lib: lib
			archive: archive.
		aBlock value: lib value: archive ]
	ensure: [
		lib read_close: archive.
		lib read_free: archive ]
]
