Extension { #name : 'LibC' }

{ #category : '*PharoArchive' }
LibC >> chdirPosix: aPathString [

	^ self ffiCall: #(int chdir(const char* aPathString))
]

{ #category : '*PharoArchive' }
LibC >> chdirSafe: aPathString [
	"Change the process working directory. Dispatches on the current platform because the
	symbol differs between POSIX (chdir) and Windows (_wchdir, wide-character)."

	^ OSPlatform current isWindows
		ifTrue: [ self wchdirUtf16: aPathString ]
		ifFalse: [ self chdirPosix: aPathString ]
]

{ #category : '*PharoArchive' }
LibC >> wchdirUtf16: aPathString [
	"Change the process working directory using the wide-character _wchdir. Pharo's FFI has no
	wchar_t external type, so the UTF-16LE (null-terminated) bytes are written into a ByteArray
	and passed as an int* pointer, which FFI resolves to the address of the buffer."

	| stream |
	stream := WriteStream on: (ByteArray new: (aPathString size * 2) + 2).
	aPathString do: [ :char |
		| code |
		code := char asInteger.
		code < 16r10000
			ifTrue: [ stream
				nextPut: (code bitAnd: 16rFF);
				nextPut: ((code bitShift: -8) bitAnd: 16rFF) ]
			ifFalse: [ | v |
				v := code - 16r10000.
				stream
					nextPut: ((16rD800 + (v bitShift: -10)) bitAnd: 16rFF);
					nextPut: (((16rD800 + (v bitShift: -10)) bitShift: -8) bitAnd: 16rFF);
					nextPut: ((16rDC00 + (v bitAnd: 16r3FF)) bitAnd: 16rFF);
					nextPut: (((16rDC00 + (v bitAnd: 16r3FF)) bitShift: -8) bitAnd: 16rFF) ] ].
	stream nextPut: 0; nextPut: 0.
	^ self ffiCall: #(int _wchdir(const int* aPathString)) with: stream contents
]
