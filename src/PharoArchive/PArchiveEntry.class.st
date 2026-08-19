Class {
	#name : 'PArchiveEntry',
	#superclass : 'Object',
	#instVars : [
		'pathname',
		'size',
		'mtime',
		'mode',
		'filetype',
		'symlink'
	],
	#pools : [
		'ArchiveConstants'
	],
	#category : 'PharoArchive',
	#package : 'PharoArchive'
}

{ #category : 'instance creation' }
PArchiveEntry class >> fromHandle: ffiArchiveEntry library: libArchive [

	^ self new
		initializeFromHandle: ffiArchiveEntry library: libArchive;
		yourself
]

{ #category : 'accessing' }
PArchiveEntry >> filetype [

	^ filetype
]

{ #category : 'initialization' }
PArchiveEntry >> initializeFromHandle: ffiArchiveEntry library: libArchive [

	| symlinkValue |
	pathname := libArchive entry_pathname: ffiArchiveEntry.
	symlinkValue := libArchive entry_symlink: ffiArchiveEntry.
	pathname := self normalizedPathname: pathname.
	size := libArchive entry_size: ffiArchiveEntry.
	mtime := libArchive entry_mtime: ffiArchiveEntry.
	mode := libArchive entry_mode: ffiArchiveEntry.
	filetype := libArchive entry_filetype: ffiArchiveEntry.
	symlink := (symlinkValue isNil or: [ symlinkValue isEmpty ])
		ifTrue: [ nil ]
		ifFalse: [ symlinkValue ]
]

{ #category : 'private' }
PArchiveEntry >> normalizedPathname: aPathname [

	aPathname isNil ifTrue: [ ^ aPathname ].
	aPathname isEmpty ifTrue: [ ^ aPathname ].
	^ aPathname last = $/
		ifTrue: [ aPathname allButLast ]
		ifFalse: [ aPathname ]
]

{ #category : 'testing' }
PArchiveEntry >> isDirectory [

	^ filetype = AE_IFDIR
]

{ #category : 'testing' }
PArchiveEntry >> isFile [

	^ filetype = AE_IFREG
]

{ #category : 'testing' }
PArchiveEntry >> isSymlink [

	^ filetype = AE_IFLNK
]

{ #category : 'accessing' }
PArchiveEntry >> mode [

	^ mode
]

{ #category : 'accessing' }
PArchiveEntry >> mtime [

	^ mtime
]

{ #category : 'accessing' }
PArchiveEntry >> pathname [

	^ pathname
]

{ #category : 'accessing' }
PArchiveEntry >> size [

	^ size
]

{ #category : 'accessing' }
PArchiveEntry >> symlink [

	^ symlink
]
