Extension { #name : 'LibC' }

{ #category : '*PharoArchive' }
LibC >> chdirSafe: aPathString [
	"Change the process working directory. Dispatches on the current platform because the
	symbol differs between POSIX (chdir) and Windows (_wchdir, wide-character)."

	^ OSPlatform current isWindows
		ifTrue: [ self wchdirUtf16: aPathString ]
		ifFalse: [ self chdirPosix: aPathString ]
]

{ #category : '*PharoArchive' }
LibC >> chdirPosix: aPathString [

	^ self ffiCall: #(int chdir(const char* aPathString))
]

{ #category : '*PharoArchive' }
LibC >> wchdirUtf16: aPathString [

	^ self ffiCall: #(int _wchdir(const wchar_t* aPathString))
]
