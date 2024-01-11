//
//  main.swift
//  Sound Generator
//
//  Created by Kasper Nielsen on 04/01/2024.
//

import Foundation

let pianoYamahaC7: URL = URL(fileURLWithPath: "/Volumes/git/ESX24/piano_YamahaC7/YamahaC7.exs")

// Create dataset directory
let datasetDirectory: URL = URL(fileURLWithPath: "/Volumes/git/ml/datasets/midi-to-sound/v0")

let generator = try SampleGenerator()
try generator.useInstrument(instrumentPack: pianoYamahaC7)

for key in 21..<108 {
    generator.clearTracks()

    for (index, velocity) in [10, 40, 80, 127].enumerated() {
        generator.stage(note: Note(time: Double(index), duration: Double(index + 1), key: UInt8(key), velocity: UInt8(velocity)))
    }

    let aacOutputFile = datasetDirectory.appending(path: "piano_\(key).aac")
    let csvOutputFile = datasetDirectory.appending(path: "piano_\(key).csv")

    let csvString = noteEventsToCsv(notes: try generator.getStagedEvents())
    try csvString.write(to: csvOutputFile, atomically: false, encoding: .utf8)
    try generator.generateAac(outputUrl: aacOutputFile)
}
