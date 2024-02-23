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
let samplesPerInstrument = 50000
let totalSamples = instruments.count * samplesPerInstrument

let renderer = try SampleRenderer()
let generator = EventGenerator()

func updateLine(with newText: String) {
    let clearLineSequence = "\r" + String(repeating: " ", count: 80) + "\r"
    print(clearLineSequence, terminator: "")
    print(newText, terminator: "")
    fflush(stdout) // Ensure the output is immediately displayed
}

updateLine(with: "Generating samples...")
var count = 0
for instrument in instruments {
    try renderer.useInstrument(instrumentPack: instrument.url)

    for i in 0..<samplesPerInstrument {
        renderer.clearTracks()

        for midiEvent in generator.generate(instrumentSpec: instrument) {
            renderer.stage(note: midiEvent)
        }

        let instrumentName = "\(instrument.category)_\(instrument.sampleName)"
        let fileName = "\(instrumentName)_\(i)"
        // Maximum of 5000 files in one directory
        let datasetPartition = datasetDirectory.appending(path: "\(instrumentName)_\(i / 5000)")
        if !FileManager.default.fileExists(atPath: datasetPartition.path) {
            try FileManager.default.createDirectory(at: datasetPartition, withIntermediateDirectories: false)
        }
        let aacOutputFile = datasetPartition.appending(path: "\(fileName).aac")
        let csvOutputFile = datasetPartition.appending(path: "\(fileName).csv")

        let csvString = noteEventsToCsv(notes: try renderer.getStagedEvents())
        try csvString.write(to: csvOutputFile, atomically: false, encoding: .utf8)
        try renderer.generateAac(outputUrl: aacOutputFile)

        count += 1
        let completionPercent = (Double(count) / Double(totalSamples)) * 100
        updateLine(with: "\(String(format: "%.3f", completionPercent))% complete")
    }
}
