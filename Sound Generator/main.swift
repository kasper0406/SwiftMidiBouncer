//
//  main.swift
//  Sound Generator
//
//  Created by Kasper Nielsen on 04/01/2024.
//

import Foundation

// Assuming you have a MIDI file URL
let midiFileURL: URL = URL(string: "/Users/knielsen/Desktop/test-midi.mid")!
// let pianoSounds: URL = URL(string: "/Users/knielsen/Downloads/YamahaC7/YamahaC7.exs")!
let pianoSounds: URL = URL(string: "/Volumes/git/ESX24/TestPianoSamples/TestPianoSamples.exs")!

// Create an audio file to write to
let aacOutputFileURL: URL = URL(string: "/Users/knielsen/Desktop/test-sequenced.aac")!
let wavOputFileURL: URL = URL(string: "/Users/knielsen/Desktop/test-sequenced.wav")!

let generator = try SampleGenerator()
try generator.useInstrument(instrumentPack: pianoSounds)

generator.stage(note: Note(time: 0.0, duration: 1.0, key: 44, velocity: 127))

print("Midi events: \(try generator.getStagedEvents())")
try generator.generateAac(outputUrl: aacOutputFileURL)
try generator.generateWav(outputUrl: wavOputFileURL)
