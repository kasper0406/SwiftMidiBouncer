//
//  main.swift
//  Sound Generator
//
//  Created by Kasper Nielsen on 04/01/2024.
//

import Foundation

// Create dataset directory
let datasetDirectory: URL = URL(fileURLWithPath: "/Volumes/git/ml/datasets/midi-to-sound/v1")

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

let renderer = try SampleRenderer()
let generator = EventGenerator()

for instrument in instruments {
    try renderer.useInstrument(instrumentPack: instrument.url)

    for i in 0..<100 {
        renderer.clearTracks()

        for midiEvent in generator.generate(instrumentSpec: instrument) {
            renderer.stage(note: midiEvent)
        }

        let fileName = "\(instrument.category)_\(instrument.sampleName)_\(i)"
        let aacOutputFile = datasetDirectory.appending(path: "\(fileName).aac")
        let csvOutputFile = datasetDirectory.appending(path: "\(fileName).csv")

        let csvString = noteEventsToCsv(notes: try renderer.getStagedEvents())
        try csvString.write(to: csvOutputFile, atomically: false, encoding: .utf8)
        try renderer.generateAac(outputUrl: aacOutputFile)
    }
}
