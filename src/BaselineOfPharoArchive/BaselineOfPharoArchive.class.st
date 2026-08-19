Class {
	#name : 'BaselineOfPharoArchive',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfPharoArchive',
	#package : 'BaselineOfPharoArchive'
}

{ #category : 'baselines' }
BaselineOfPharoArchive >> baseline: spec [
	<baseline>

	spec for: #common do: [
		spec
			baseline: 'Archive'
			with: [ spec repository: 'tonel://../pharo-archive/src' ].
		spec
			package: 'PharoArchive'
			with: [ spec requires: #('Archive') ].
		spec
			package: 'PharoArchive-Tests'
			with: [ spec requires: #('PharoArchive') ].

		spec group: 'default' with: #('PharoArchive' 'PharoArchive-Tests').
		spec group: 'Tests' with: #('PharoArchive-Tests') ]
]
