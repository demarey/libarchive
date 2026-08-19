Class {
	#name : 'PArchiveCoreTest',
	#superclass : 'TestCase',
	#category : 'PharoArchive-Tests',
	#package : 'PharoArchive-Tests'
}

{ #category : 'helpers' }
PArchiveCoreTest >> baseTempDirectory [

	^ FileLocator temp / ('pharoArchiveTest-', UUID new asString)
]

{ #category : 'helpers' }
PArchiveCoreTest >> expectedEntries [

	^ #('docs' 'docs/notes.md' 'hello.txt' 'images' 'images/pixel.bin')
]

{ #category : 'helpers' }
PArchiveCoreTest >> memoryFilesystemFolder [

	| filesystem root |
	filesystem := FileSystem memory.
	root := filesystem / 'payload'.
	root ensureCreateDirectory.
	(root / 'docs') ensureCreateDirectory.
	(root / 'images') ensureCreateDirectory.
	(root / 'hello.txt') writeStreamDo: [ :stream | stream nextPutAll: 'Hello from memory!' ].
	(root / 'docs' / 'notes.md') writeStreamDo: [ :stream | stream nextPutAll: '# Title', String lf ].
	(root / 'images' / 'pixel.bin') binaryWriteStreamDo: [ :stream |
		stream nextPutAll: (ByteArray with: 0 with: 1 with: 2 with: 255) ].
	^ root
]

{ #category : 'tests' }
PArchiveCoreTest >> testEntriesRoundTripTar [

	self assert: (self readArchiveOfFormat: #tar) equals: self expectedEntries
]

{ #category : 'tests' }
PArchiveCoreTest >> testEntriesRoundTripZip [

	self assert: (self readArchiveOfFormat: #zip) equals: self expectedEntries
]

{ #category : 'tests' }
PArchiveCoreTest >> testContentsOfEntry [

	| folder base writer reader hello |
	folder := self memoryFilesystemFolder.
	base := self baseTempDirectory.
	base ensureCreateDirectory.
	[ 
		writer := PArchiveWriter toFile: (base / 'x.zip') format: #zip.
		writer addEntriesFromDirectory: folder.
		writer finish.
		reader := PArchiveReader onFile: (base / 'x.zip').
		hello := reader entries detect: [ :e | e pathname = 'hello.txt' ].
		self assert: (reader contentsOf: hello) equals: 'Hello from memory!' asByteArray.
		self assert: hello isFile.
		self assert: hello size equals: 'Hello from memory!' size ]
	ensure: [ base ensureDeleteAll ]
]

{ #category : 'tests' }
PArchiveCoreTest >> testExtractToDirectoryPreservesContentAndPermissions [

	| folder base writer extracted hello |
	folder := self memoryFilesystemFolder.
	base := self baseTempDirectory.
	base ensureCreateDirectory.
	extracted := base / 'out'.
	[ 
		writer := PArchiveWriter toFile: (base / 'x.zip') format: #zip.
		writer addEntriesFromDirectory: folder.
		writer finish.
		(PArchiveReader onFile: (base / 'x.zip')) extractTo: extracted.
		hello := extracted / 'hello.txt'.
		self assert: hello exists.
		self assert: hello contents equals: 'Hello from memory!'.
		self assert: (extracted / 'docs') isDirectory.
		self assert: (extracted / 'docs' / 'notes.md') contents equals: '# Title', String lf.
		self assert: (hello permissions posixPermission) equals: 8r644.
		self assert: ((extracted / 'docs') permissions posixPermission) equals: 8r755 ]
	ensure: [ base ensureDeleteAll ]
]

{ #category : 'tests' }
PArchiveCoreTest >> testExtractUsesRealFilePermissions [

	| root folder writer extracted perms |
	root := self baseTempDirectory.
	root ensureCreateDirectory.
	folder := root / 'payload'.
	folder ensureCreateDirectory.
	(folder / 'secret.txt') writeStreamDo: [ :s | s nextPutAll: 'secret' ].
	(folder / 'secret.txt') permissions: (FileSystemPermission posixPermissions: 8r600).
	extracted := root / 'out'.
	[ 
		writer := PArchiveWriter toFile: (root / 'x.tar') format: #tar.
		writer addEntriesFromDirectory: folder.
		writer finish.
		(PArchiveReader onFile: (root / 'x.tar')) extractTo: extracted.
		perms := (extracted / 'secret.txt') permissions posixPermission.
		self assert: perms equals: 8r600.
		self assert: (extracted / 'secret.txt') contents equals: 'secret' ]
	ensure: [ root ensureDeleteAll ]
]

{ #category : 'helpers' }
PArchiveCoreTest >> readArchiveOfFormat: aFormat [

	| folder base writer reader |
	folder := self memoryFilesystemFolder.
	base := self baseTempDirectory.
	base ensureCreateDirectory.
	[ 
		writer := PArchiveWriter
			toFile: (base / 'test.archive')
			format: aFormat.
		writer addEntriesFromDirectory: folder.
		writer finish.
		reader := PArchiveReader onFile: (base / 'test.archive').
		^ (reader entries collect: [ :e | e pathname ]) asArray ]
	ensure: [ base ensureDeleteAll ]
]
