"
Tests for the libarchive-backed archive library (LAArchive, LAArchiveReader,
LAArchiveWriter, LAArchiveMember). Covers the document model, streaming read/write,
extraction (content, permissions, timestamps), directory-tree packing, and behavior
originally present in Compression-Tests/ZipArchiveTest.
"
Class {
	#name : 'LAArchiveTest',
	#superclass : 'TestCase',
	#instVars : [
		'fs',
		'subdir',
		'contentFile'
	],
	#category : 'PharoArchive-Tests',
	#package : 'PharoArchive-Tests'
}

{ #category : 'running' }
LAArchiveTest >> setUp [

	super setUp.
	fs := FileSystem memory.
	subdir := fs / 'test-zip-dir'.
	subdir ensureCreateDirectory.
	contentFile := subdir / 'file.txt'.
	contentFile writeStreamDo: [ :stream | stream nextPutAll: 'file contents' ]
]

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

{ #category : 'tests' }
LAArchiveTest >> testReadBackAndExtractAll [

	| archive out extracted readBack base |
	archive := LAArchive new.
	archive
		addDirectory: 'docs';
		addString: 'content one' as: 'docs/a.txt';
		addString: 'content two' as: 'root.txt'.
	base := self baseTempDirectory.
	base ensureCreateDirectory.
	out := base / 'doc.zip'.
	extracted := base / 'extracted'.
	[ 
		archive writeToFile: out.
		readBack := LAArchive new readFrom: out.
		readBack extractAllTo: extracted.
		self assert: (extracted / 'docs' / 'a.txt') contents equals: 'content one'.
		self assert: (extracted / 'root.txt') contents equals: 'content two' ]
	ensure: [ base ensureDeleteAll ]
]

{ #category : 'helpers' }
LAArchiveTest >> readFilePathsOfFormat: aFormat [

	| folder base writer reader filePaths |
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
		filePaths := reader entries
			reject: #isDirectory
			thenCollect: [ :e | e pathname ] ]
	ensure: [ base ensureDeleteAll ].
	^ filePaths asSet
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

{ #category : 'tests' }
LAArchiveTest >> testAddNonExistentFileRaises [

	self should: [ LAArchive new addFile: (self baseTempDirectory / 'missing-file.txt') ]
		raise: FileDoesNotExistException
]

{ #category : 'tests' }
LAArchiveTest >> testAddTreeWithContentShouldSucceed [

	| base out writer extracted |
	base := self baseTempDirectory.
	base ensureCreateDirectory.
	out := base / 'out.zip'.
	writer := LAArchiveWriter toFile: out format: #zip.
	writer addEntriesFromDirectory: subdir parent.
	writer finish.
	extracted := base / 'extracted'.
	[ 
		(LAArchiveReader onFile: out) extractTo: extracted.
		self assert: (extracted / 'test-zip-dir' / 'file.txt') exists.
		self assert: (extracted / 'test-zip-dir' / 'file.txt') contents equals: 'file contents' ]
	ensure: [ base ensureDeleteAll ]
]

{ #category : 'tests' }
LAArchiveTest >> testAddTreeWithSubDirectoriesShouldSucceed [

	| base out writer extracted subSubDir |
	subSubDir := subdir / 'subSubDir'.
	subSubDir ensureCreateDirectory.
	(subSubDir / 'fileInSubSubDir') ensureCreateFile.
	base := self baseTempDirectory.
	base ensureCreateDirectory.
	out := base / 'out.zip'.
	writer := LAArchiveWriter toFile: out format: #zip.
	writer addEntriesFromDirectory: subdir parent.
	writer finish.
	extracted := base / 'extracted'.
	[ 
		(LAArchiveReader onFile: out) extractTo: extracted.
		self assert: (extracted / 'test-zip-dir' / 'subSubDir') isDirectory.
		self assert: (extracted / 'test-zip-dir' / 'subSubDir' / 'fileInSubSubDir') isFile.
		self deny: (extracted / 'subSubDir') isDirectory ]
	ensure: [ base ensureDeleteAll ]
]

{ #category : 'tests' }
LAArchiveTest >> testManyFilesSmoke [

	| base out writer reader count |
	base := self baseTempDirectory.
	base ensureCreateDirectory.
	out := base / 'many.zip'.
	[ 
		writer := LAArchiveWriter toFile: out format: #zip.
		1 to: 500 do: [ :i |
			writer
				addFileNamed: ('file-', i asString)
				content: ('content ', i asString) asByteArray ].
		writer finish.
		reader := LAArchiveReader onFile: out.
		count := reader entries size.
		self assert: count equals: 500 ]
	ensure: [ base ensureDeleteAll ]
]

{ #category : 'tests' }
LAArchiveTest >> testCanUnzipFromStream [

	| base stream writer bytes reader extracted |
	stream := (ByteArray new: 0) writeStream.
	writer := LAArchiveWriter toStream: stream format: #zip.
	writer addFileNamed: 'hello.txt' content: 'file contents' asByteArray.
	writer addDirectory: 'docs'.
	writer finish.
	bytes := stream contents.
	reader := LAArchiveReader onBytes: bytes.
	base := self baseTempDirectory.
	base ensureCreateDirectory.
	extracted := base / 'extracted'.
	[ 
		reader extractTo: extracted.
		self assert: (extracted / 'hello.txt') exists.
		self assert: (extracted / 'hello.txt') contents equals: 'file contents'.
		self assert: (extracted / 'docs') isDirectory ]
	ensure: [ base ensureDeleteAll ]
]

{ #category : 'tests' }
LAArchiveTest >> testFilePermissionsFromRealFile [

	| base realFile archive member |
	base := self baseTempDirectory.
	base ensureCreateDirectory.
	realFile := base / 'secret.txt'.
	realFile writeStreamDo: [ :stream | stream nextPutAll: 'secret' ].
	realFile permissions: (FileSystemPermission posixPermissions: 8r600).
	archive := LAArchive new.
	archive addFile: realFile as: 'secret.txt'.
	member := archive memberNamed: 'secret.txt'.
	[ self assert: (member mode bitAnd: 8r7777) equals: 8r600 ]
	ensure: [ base ensureDeleteAll ]
]

{ #category : 'tests' }
LAArchiveTest >> testWriteRoundTripFormats [
	"Round-trip general formats. Directory encoding differs per format (7zip reorders,
	cpio omits dir entries), so we compare the set of file pathnames."

	self assert: (self readFilePathsOfFormat: #sevenzip)
		equals: #('docs/notes.md' 'hello.txt' 'images/pixel.bin') asSet.
	self assert: (self readFilePathsOfFormat: #cpio)
		equals: #('docs/notes.md' 'hello.txt' 'images/pixel.bin') asSet
]

{ #category : 'tests' }
LAArchiveTest >> testWriteToFileDuring [

	| base out |
	base := self baseTempDirectory.
	base ensureCreateDirectory.
	out := base / 'x.zip'.
	[ 
		LAArchiveWriter writeToFile: out format: #zip during: [ :writer |
			writer addFileNamed: 'a.txt' content: 'hi' asByteArray ].
		self assert: out exists.
		self assert: (LAArchiveReader onFile: out) entries size equals: 1 ]
	ensure: [ base ensureDeleteAll ]
]

{ #category : 'tests' }
LAArchiveTest >> testWriteToStreamDuring [

	| stream reader |
	stream := (ByteArray new: 0) writeStream.
	LAArchiveWriter writeToStream: stream format: #zip during: [ :writer |
		writer addFileNamed: 'a.txt' content: 'hi' asByteArray ].
	reader := LAArchiveReader onBytes: stream contents.
	self assert: reader entries size equals: 1
]

{ #category : 'tests' }
LAArchiveTest >> testDuringEnsuresFinishOnException [

	| base out |
	base := self baseTempDirectory.
	base ensureCreateDirectory.
	out := base / 'x.zip'.
	[ 
		self should: [
			LAArchiveWriter writeToFile: out format: #zip during: [ :writer |
				writer addFileNamed: 'a.txt' content: 'hi' asByteArray.
				self error: 'boom' ] ]
			raise: Error.
		self assert: out exists.
		self assert: (LAArchiveReader onFile: out) entries size equals: 1 ]
	ensure: [ base ensureDeleteAll ]
]

{ #category : 'tests' }
LAArchiveTest >> testUnknownFormatRaises [

	self should: [ LAArchiveFormat named: #doesNotExist ] raise: LAArchiveError.
	self assert: LAArchiveFormat zip libarchiveName equals: 'zip'.
	self assert: LAArchiveFormat tar libarchiveName equals: 'pax'
]
