"
LAArchiveWriter builds a new archive (zip, tar, 7zip, ...) through libarchive from files
and directories. Files can be added from arbitrary content, from real files on disk
(preserving their POSIX permissions and modification time), or by recursively walking a
whole directory. Handles are opened, flushed and freed for the caller; a during: wrapper
guarantees finish so a native handle can never leak.

The output format is described by an LAArchiveFormat value object (also accepted as a
Symbol such as #zip or #tar through the registry).
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
	"aFormat is an LAArchiveFormat or a Symbol such as #zip or #tar."

	^ self new initializeToFile: aFileReference format: aFormat
]

{ #category : 'instance creation' }
LAArchiveWriter class >> toStream: aBinaryWriteStream format: aFormat [
	"Build the archive by streaming its bytes directly into aBinaryWriteStream through an
	FFI write callback (no temporary file involved)."

	^ self new initializeToStream: aBinaryWriteStream format: aFormat
]

{ #category : 'instance creation' }
LAArchiveWriter class >> writeToFile: aFileReference format: aFormat during: aBlock [
	"Build an archive, evaluating aBlock with the writer, and guarantee finish even on error."

	| writer |
	writer := self toFile: aFileReference format: aFormat.
	[ aBlock value: writer ]
		ensure: [ writer finish ]
]

{ #category : 'instance creation' }
LAArchiveWriter class >> writeToStream: aBinaryWriteStream format: aFormat during: aBlock [
	"Build an archive into aBinaryWriteStream, evaluating aBlock with the writer, and
	guarantee finish even on error."

	| writer |
	writer := self toStream: aBinaryWriteStream format: aFormat.
	[ aBlock value: writer ]
		ensure: [ writer finish ]
]

{ #category : 'building' }
LAArchiveWriter >> addDirectory: aRelativePath [

	^ self addDirectory: aRelativePath mode: (AE_IFDIR bitOr: 8r755)
]

{ #category : 'building' }
LAArchiveWriter >> addDirectory: aRelativePath mode: aMode [

	^ self
		addEntryNamed: aRelativePath
		mode: aMode
		size: nil
		mtime: nil
		dataBlock: nil
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

{ #category : 'private' }
LAArchiveWriter >> addEntryNamed: aName mode: aMode size: aSizeOrNil mtime: aTimestampOrNil dataBlock: aDataBlockOrNil [
	"Shared choreography for adding one entry: create the FFI entry, set its header fields,
	write the header, write payload data (if any), then finish and free the entry."

	| entry |
	entry := lib entry_new.
	lib entry_set_pathnameArg1: entry arg2: aName.
	lib entry_set_modeArg1: entry arg2: aMode.
	aSizeOrNil ifNotNil: [ :s | lib entry_set_sizeArg1: entry arg2: s ].
	aTimestampOrNil ifNotNil: [ :t | lib entry_set_mtimeArg1: entry arg2: t arg3: 0 ].
	lib write_headerArg1: archive arg2: entry.
	aDataBlockOrNil ifNotNil: [ aDataBlockOrNil value ].
	lib write_finish_entry: archive.
	lib entry_free: entry.

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

	^ self
		addEntryNamed: aRelativePath
		mode: aMode
		size: aByteArray size
		mtime: aTimestamp
		dataBlock: [
			aByteArray size > 0
				ifTrue: [
					lib
						write_dataArg1: archive
						arg2: aByteArray
						size_t: aByteArray size ] ]
]

{ #category : 'building' }
LAArchiveWriter >> addFileNamed: aRelativePath from: aFileReference [
	"Stream the file content in chunks, reusing a single buffer. Uses the file's real
	permissions and modification time."

	| buffer n |
	buffer := ByteArray new: 65536.
	^ self
		addEntryNamed: aRelativePath
		mode: (self modeFor: aFileReference ofType: AE_IFREG)
		size: aFileReference size
		mtime: (self mtimeOf: aFileReference)
		dataBlock: [
			aFileReference binaryReadStreamDo: [ :stream |
				[ (n := stream readInto: buffer startingAt: 1 count: buffer size) > 0 ]
					whileTrue: [
						lib
							write_dataArg1: archive
							arg2: buffer
							size_t: n ] ] ]
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

{ #category : 'initialization' }
LAArchiveWriter >> initializeToFile: aFileReference format: aFormat [

	| format |
	file := aFileReference.
	lib := LibArchive uniqueInstance.
	archive := lib write_new.
	format := self resolvedFormat: aFormat.
	[ 
		self
			assertOk: (format configure: archive with: lib)
			lib: lib
			archive: archive
			reference: aFileReference.
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

{ #category : 'initialization' }
LAArchiveWriter >> initializeToStream: aBinaryWriteStream format: aFormat [
	"Open the archive writing through FFI callbacks that append libarchive's output
	buffer to aBinaryWriteStream, using proper Pharo streams instead of a temp file."

	| format openCallback writeCallback closeCallback |
	stream := aBinaryWriteStream.
	lib := LibArchive uniqueInstance.
	archive := lib write_new.
	format := self resolvedFormat: aFormat.
	[ 
		self
			assertOk: (format configure: archive with: lib)
			lib: lib
			archive: archive
			reference: 'stream'.
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

{ #category : 'private' }
LAArchiveWriter >> resolvedFormat: aFormatOrSymbol [

	^ aFormatOrSymbol isSymbol
		ifTrue: [ LAArchiveFormat named: aFormatOrSymbol ]
		ifFalse: [ aFormatOrSymbol ]
]
