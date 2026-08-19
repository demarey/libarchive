Class {
	#name : 'LAArchiveTest',
	#superclass : 'TestCase',
	#category : 'PharoArchive-Tests',
	#package : 'PharoArchive-Tests'
}

{ #category : 'helpers' }
LAArchiveTest >> baseTempDirectory [

	^ FileLocator temp / ('pharoArchiveTest-', UUID new asString)
]

{ #category : 'helpers' }
LAArchiveTest >> expectedEntries [

	^ #('docs' 'docs/notes.md' 'hello.txt' 'images' 'images/pixel.bin')
]

{ #category : 'helpers' }
LAArchiveTest >> memoryFilesystemFolder [

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
LAArchiveTest >> testEntriesRoundTripTar [

	self assert: (self readArchiveOfFormat: #tar) equals: self expectedEntries
]

{ #category : 'tests' }
LAArchiveTest >> testEntriesRoundTripZip [

	self assert: (self readArchiveOfFormat: #zip) equals: self expectedEntries
]

{ #category : 'tests' }
LAArchiveTest >> testDocumentModelRoundTrip [

	| archive base out extracted readBack |
	archive := LAArchive new.
	archive
		addDirectory: 'docs';
		addString: 'Hello document!' as: 'hello.txt';
		addString: ('# Title', String lf) as: 'docs/notes.md'.
	self assert: archive numberOfMembers equals: 3.
	base := self baseTempDirectory.
	base ensureCreateDirectory.
	out := base / 'doc.zip'.
	extracted := base / 'out'.
	[ 
		archive writeToFile: out.
		readBack := LAArchive new readFrom: out.
		self assert: (readBack memberNames asSortedCollection asArray)
			equals: #('docs' 'docs/notes.md' 'hello.txt').
		self assert: (readBack contentsOf: 'hello.txt') equals: 'Hello document!' asByteArray.
		readBack extractAllTo: extracted.
		self assert: (extracted / 'hello.txt') contents equals: 'Hello document!'.
		self assert: (extracted / 'docs') isDirectory ]
	ensure: [ base ensureDeleteAll ]
]

{ #category : 'tests' }
LAArchiveTest >> testContentsOfEntry [

	| folder base writer reader hello |
	folder := self memoryFilesystemFolder.
	base := self baseTempDirectory.
	base ensureCreateDirectory.
	[ 
		writer := LAArchiveWriter toFile: (base / 'x.zip') format: #zip.
		writer addEntriesFromDirectory: folder.
		writer finish.
		reader := LAArchiveReader onFile: (base / 'x.zip').
		hello := reader entries detect: [ :e | e pathname = 'hello.txt' ].
		self assert: (reader contentsOf: hello) equals: 'Hello from memory!' asByteArray.
		self assert: hello isFile.
		self assert: hello size equals: 'Hello from memory!' size ]
	ensure: [ base ensureDeleteAll ]
]

{ #category : 'tests' }
LAArchiveTest >> testExtractToDirectoryPreservesContentAndPermissions [

	| folder base writer extracted hello |
	folder := self memoryFilesystemFolder.
	base := self baseTempDirectory.
	base ensureCreateDirectory.
	extracted := base / 'out'.
	[ 
		writer := LAArchiveWriter toFile: (base / 'x.zip') format: #zip.
		writer addEntriesFromDirectory: folder.
		writer finish.
		(LAArchiveReader onFile: (base / 'x.zip')) extractTo: extracted.
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
LAArchiveTest >> testExtractUsesRealFilePermissions [

	| root folder writer extracted perms |
	root := self baseTempDirectory.
	root ensureCreateDirectory.
	folder := root / 'payload'.
	folder ensureCreateDirectory.
	(folder / 'secret.txt') writeStreamDo: [ :s | s nextPutAll: 'secret' ].
	(folder / 'secret.txt') permissions: (FileSystemPermission posixPermissions: 8r600).
	extracted := root / 'out'.
	[ 
		writer := LAArchiveWriter toFile: (root / 'x.tar') format: #tar.
		writer addEntriesFromDirectory: folder.
		writer finish.
		(LAArchiveReader onFile: (root / 'x.tar')) extractTo: extracted.
		perms := (extracted / 'secret.txt') permissions posixPermission.
		self assert: perms equals: 8r600.
		self assert: (extracted / 'secret.txt') contents equals: 'secret' ]
	ensure: [ root ensureDeleteAll ]
]

{ #category : 'helpers' }
LAArchiveTest >> readArchiveOfFormat: aFormat [

	| folder base writer reader |
	folder := self memoryFilesystemFolder.
	base := self baseTempDirectory.
	base ensureCreateDirectory.
	[ 
		writer := LAArchiveWriter
			toFile: (base / 'test.archive')
			format: aFormat.
		writer addEntriesFromDirectory: folder.
		writer finish.
		reader := LAArchiveReader onFile: (base / 'test.archive').
		^ (reader entries collect: [ :e | e pathname ]) asArray ]
	ensure: [ base ensureDeleteAll ]
]
