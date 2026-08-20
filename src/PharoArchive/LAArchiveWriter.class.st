"
LAArchiveWriter builds a new archive (zip or tar) through libarchive from files and
directories. Files can be added from arbitrary content, from real files on disk
(preserving their POSIX permissions and modification time), or by recursively walking
a whole directory. Handles are opened, flushed and freed for the caller.
"
Class {
	#name : 'LAArchiveWriter',
	#superclass : 'Object',
	#traits : 'LAFileMetadata + LAArchiveFFI',
	#classTraits : 'LAFileMetadata classTrait + LAArchiveFFI classTrait',
	#instVars : [
		'file',
		'lib',
		'archive',
		'stream'
	],
	#pools : [
		'ArchiveConstants'
	],
	#category : 'PharoArchive',
	#package : 'PharoArchive'
}

{ #category : 'instance creation' }
LAArchiveWriter class >> toFile: aFileReference format: aFormat [
	"aFormat is #zip or #tar."

	^ self new initializeToFile: aFileReference format: aFormat
]

{ #category : 'instance creation' }
LAArchiveWriter class >> toStream: aBinaryWriteStream format: aFormat [
	"Build the archive by streaming its bytes directly into aBinaryWriteStream through an
	FFI write callback (no temporary file involved)."

	^ self new initializeToStream: aBinaryWriteStream format: aFormat
]

{ #category : 'building' }
LAArchiveWriter >> addDirectory: aRelativePath [

	^ self addDirectory: aRelativePath mode: (AE_IFDIR bitOr: 8r755)
]

{ #category : 'building' }
LAArchiveWriter >> addDirectory: aRelativePath mode: aMode [

	| entry |
	entry := lib entry_new.
	lib entry_set_pathnameArg1: entry arg2: aRelativePath.
	lib entry_set_modeArg1: entry arg2: aMode.
	lib write_headerArg1: archive arg2: entry.
	lib write_finish_entry: archive.
	lib entry_free: entry.

	^ self
]

{ #category : 'building' }
LAArchiveWriter >> addEntriesFromDirectory: aDirectoryReference [

	| entries |
	entries := aDirectoryReference allChildren
		reject: [ :child | child resolve = aDirectoryReference resolve ]
		thenCollect: [ :child | child ].
	entries := entries asSortedCollection: [ :a :b | a pathString <= b pathString ].
	entries do: [ :child |
		| relative |
		relative := (child relativeTo: aDirectoryReference) pathString.
		child isDirectory
			ifTrue: [ self
					addDirectory: relative
					mode: (self modeFor: child ofType: AE_IFDIR) ]
			ifFalse: [ self addFileNamed: relative from: child ] ].

	^ self
]

{ #category : 'building' }
LAArchiveWriter >> addFileNamed: aRelativePath content: aByteArray [

	^ self
		addFileNamed: aRelativePath
		content: aByteArray
		mode: (AE_IFREG bitOr: 8r644)
		mtime: nil
]

{ #category : 'building' }
LAArchiveWriter >> addFileNamed: aRelativePath content: aByteArray mode: aMode mtime: aTimestamp [

	| entry |
	entry := lib entry_new.
	lib entry_set_pathnameArg1: entry arg2: aRelativePath.
	lib entry_set_modeArg1: entry arg2: aMode.
	lib entry_set_sizeArg1: entry arg2: aByteArray size.
	aTimestamp ifNotNil: [ :t | lib entry_set_mtimeArg1: entry arg2: t arg3: 0 ].
	lib write_headerArg1: archive arg2: entry.
	aByteArray size > 0
		ifTrue: [
			lib
				write_dataArg1: archive
				arg2: aByteArray
				size_t: aByteArray size ].
	lib write_finish_entry: archive.
	lib entry_free: entry.

	^ self
]

{ #category : 'building' }
LAArchiveWriter >> addFileNamed: aRelativePath from: aFileReference [
	"Stream the file content in chunks, reusing a single buffer. Uses the file's real
	permissions and modification time."

	| entry buffer n |
	entry := lib entry_new.
	lib entry_set_pathnameArg1: entry arg2: aRelativePath.
	lib entry_set_modeArg1: entry arg2: (self modeFor: aFileReference ofType: AE_IFREG).
	lib entry_set_sizeArg1: entry arg2: aFileReference size.
	(self mtimeOf: aFileReference) ifNotNil: [ :t |
		lib entry_set_mtimeArg1: entry arg2: t arg3: 0 ].
	lib write_headerArg1: archive arg2: entry.
	buffer := ByteArray new: 65536.
	aFileReference binaryReadStreamDo: [ :stream |
		[ (n := stream readInto: buffer startingAt: 1 count: buffer size) > 0 ]
			whileTrue: [ lib write_dataArg1: archive arg2: buffer size_t: n ] ].
	lib write_finish_entry: archive.
	lib entry_free: entry.

	^ self
]

{ #category : 'finalization' }
LAArchiveWriter >> finish [

	archive ifNil: [ ^ self ].
	lib write_close: archive.
	lib write_free: archive.
	archive := nil.
	lib := nil.
	^ self
]

{ #category : 'private' }
LAArchiveWriter >> initializeToStream: aBinaryWriteStream format: aFormat [
	"Open the archive writing through FFI callbacks that append libarchive's output
	buffer to aBinaryWriteStream, using proper Pharo streams instead of a temp file."

	| openCallback writeCallback closeCallback |
	stream := aBinaryWriteStream.
	lib := LibArchive uniqueInstance.
	archive := lib write_new.
	[ 
		aFormat = #zip
			ifTrue: [ lib write_set_format_zip: archive ]
			ifFalse: [ lib write_set_format_pax: archive ].
		openCallback := FFICallback
			signature: #(int (void* a, void* client_data))
			block: [ :a :clientData | 0 ].
		writeCallback := FFICallback
			signature: #(long (void* a, void* client_data, const void* buffer, size_t length))
			block: [ :a :clientData :buffer :length |
				stream
					nextPutAll: ((ExternalData fromHandle: buffer type: ExternalType unsignedByte)
							copyFrom: 1 to: length).
				length ].
		closeCallback := FFICallback
			signature: #(int (void* a, void* client_data))
			block: [ :a :clientData | 0 ].
		self
			assertOk: (lib
					write_openArg1: archive
					arg2: ExternalAddress null
					arg3: openCallback
					arg4: writeCallback
					arg5: closeCallback)
			lib: lib
			archive: archive
			reference: 'stream' ]
	on: Error
	do: [ :error |
		lib write_free: archive.
		archive := nil.
		error signal ]
]

{ #category : 'initialization' }
LAArchiveWriter >> initializeToFile: aFileReference format: aFormat [

	file := aFileReference.
	lib := LibArchive uniqueInstance.
	archive := lib write_new.
	[ 
		aFormat = #zip
			ifTrue: [ lib write_set_format_zip: archive ]
			ifFalse: [ lib write_set_format_pax: archive ].
		self
			assertOk: (lib write_open_filenameArg1: archive _file: aFileReference fullName)
			lib: lib
			archive: archive
			reference: aFileReference ]
	on: Error
	do: [ :error |
		lib write_free: archive.
		archive := nil.
		error signal ]
]
