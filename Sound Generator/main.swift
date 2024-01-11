//
//  main.swift
//  Sound Generator
//
//  Created by Kasper Nielsen on 04/01/2024.
//

import Foundation

// Create dataset directory
let datasetDirectory: URL = URL(fileURLWithPath: "/Volumes/git/ml/datasets/midi-to-sound/v0")

let instruments = [
    InstrumentSpec(
        url: URL(fileURLWithPath: "/Volumes/git/ESX24/piano_YamahaC7/YamahaC7.exs"),
        lowKey: 21,
        highKey: 108,
        category: "piano",
        sampleName: "YamahaC7"
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "/Volumes/git/ESX24/piano_BechsteinFelt/piano_BechsteinFelt.exs"),
        lowKey: 21,
        highKey: 108,
        category: "piano",
        sampleName: "BechsteinFelt"
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "/Volumes/git/ESX24/violin_candp/violin_candp.exs"),
        lowKey: 55,
        highKey: 105,
        category: "violin",
        sampleName: "candp"
    )
]

let generator = try SampleGenerator()

for instrument in instruments {
    try generator.useInstrument(instrumentPack: instrument.url)

    for key in instrument.lowKey...instrument.highKey {
        generator.clearTracks()

        for (index, velocity) in [10, 40, 80, 127].enumerated() {
            generator.stage(note: Note(time: Double(index), duration: Double(index + 1), key: UInt8(key), velocity: UInt8(velocity)))
        }

        let fileName = "\(instrument.category)_\(instrument.sampleName)_\(key)"
        let aacOutputFile = datasetDirectory.appending(path: "\(fileName).aac")
        let csvOutputFile = datasetDirectory.appending(path: "\(fileName).csv")

        let csvString = noteEventsToCsv(notes: try generator.getStagedEvents())
        try csvString.write(to: csvOutputFile, atomically: false, encoding: .utf8)
        try generator.generateAac(outputUrl: aacOutputFile)
    }
}
