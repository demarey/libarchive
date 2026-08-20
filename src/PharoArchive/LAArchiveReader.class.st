"
LAArchiveReader opens an existing archive (zip, tar, ...) through libarchive and offers
high-level reading operations: enumerating its entries, reading the raw bytes of an
entry, and extracting all entries natively to a target directory (while preserving
permissions and timestamps). It takes care of opening, closing and freeing the
underlying libarchive handle in all circumstances.
"
Class {
	#name : 'LAArchiveReader',
	#superclass : 'Object',
	#traits : 'LAArchiveFFI',
	#classTraits : 'LAArchiveFFI classTrait',
	#instVars : [
		'file',
		'bytes'
	],
	#pools : [
		'ArchiveConstants'
	],
	#category : 'PharoArchive',
	#package : 'PharoArchive'
}

{ #category : 'defaults' }
LAArchiveReader class >> defaultExtractFlags [

	^ ARCHIVE_EXTRACT_PERM bitOr: (ARCHIVE_EXTRACT_TIME
		bitOr: (ARCHIVE_EXTRACT_SECURE_NODOTDOT
			bitOr: ARCHIVE_EXTRACT_SECURE_NOABSOLUTEPATHS))
]

{ #category : 'instance creation' }
LAArchiveReader class >> onBytes: aByteArray [

	^ self new initializeBytes: aByteArray
]

{ #category : 'instance creation' }
LAArchiveReader class >> onFile: aFileReference [

	^ self new initializeFile: aFileReference
]

{ #category : 'instance creation' }
LAArchiveReader class >> onStream: aReadStream [
	"Read the archive from an already-open read stream by materializing its bytes."

	^ self onBytes: aReadStream contents
]

{ #category : 'reading' }
LAArchiveReader >> contentsOf: aLAArchiveMember [

	| result |
	result := nil.
	self withOpenArchive: [ :lib :archive |
		| holder found size buffer offset n |
		found := false.
		result := ByteArray new: 0.
		holder := ArchiveEntry newValueHolder.
		[ (lib read_next_headerArg1: archive arg2: holder) = ARCHIVE_OK ] whileTrue: [
			(lib entry_pathname: holder value) = aLAArchiveMember pathname
				ifTrue: [
					found := true.
					size := aLAArchiveMember size.
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
LAArchiveReader >> entries [

	| result |
	result := nil.
	self withOpenArchive: [ :lib :archive |
		| holder entries |
		entries := OrderedCollection new.
		holder := ArchiveEntry newValueHolder.
		[ (lib read_next_headerArg1: archive arg2: holder) = ARCHIVE_OK ] whileTrue: [
			entries add: (LAArchiveMember fromHandle: holder value library: lib) ].
		result := entries ].
	^ result
]

{ #category : 'extracting' }
LAArchiveReader >> extractTo: aDirectoryReference [

	self extractTo: aDirectoryReference flags: self class defaultExtractFlags
]

{ #category : 'extracting' }
LAArchiveReader >> extractTo: aDirectoryReference flags: flags [
	"Extract all entries into aDirectoryReference using libarchive's native extractor.
	The process working directory is temporarily switched to aDirectoryReference
	(because archive_read_extract writes relative to it), then restored."

	aDirectoryReference ensureCreateDirectory.
	LAArchiveWorkingDirectory in: aDirectoryReference during: [
		self withOpenArchive: [ :lib :archive |
			| holder |
			holder := ArchiveEntry newValueHolder.
			[ (lib read_next_headerArg1: archive arg2: holder) = ARCHIVE_OK ] whileTrue: [
				self
					assertExtractOk: (lib read_extractArg1: archive arg2: holder value flags: flags)
					lib: lib
					archive: archive
					reference: file ] ] ]
]

{ #category : 'initialization' }
LAArchiveReader >> initializeBytes: aByteArray [

	bytes := aByteArray
]

{ #category : 'initialization' }
LAArchiveReader >> initializeFile: aFileReference [

	file := aFileReference
]

{ #category : 'private' }
LAArchiveReader >> withOpenArchive: aBlock [

	| lib archive |
	lib := LibArchive uniqueInstance.
	archive := lib read_new.
	[ 
		lib read_support_filter_all: archive.
		lib read_support_format_all: archive.
		bytes isNil
			ifTrue: [
				self
					assertOk: (lib
							read_open_filenameArg1: archive
							_filename: file fullName
							_block_size: 10240)
					lib: lib
					archive: archive
					reference: file ]
			ifFalse: [
				self
					assertOk: (lib
							read_open_memoryArg1: archive
							buff: bytes
							size: bytes size)
					lib: lib
					archive: archive
					reference: 'archive bytes' ].
		aBlock value: lib value: archive ]
	ensure: [
		lib read_close: archive.
		lib read_free: archive ]
]
