//
//  main.swift
//  Sound Generator
//
//  Created by Kasper Nielsen on 04/01/2024.
//

import Foundation

if CommandLine.arguments.count != 4 {
    print("This program must be used as ./sound_generator <dataset_dir> <partition_number> <samples_per_instrument>")
    exit(1)
}
let datasetDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
let partitionNumber = CommandLine.arguments[2]
let samplesPerInstrument = Int(CommandLine.arguments[3])!

let cwd = FileManager.default.currentDirectoryPath
let instruments = [
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/mellow_vibe_piano.exs"),
        // lowKey: 21,
        // highKey: 108,
        lowKey: 53,
        highKey: 84,
        category: "keys",
        sampleName: "mellow_vibe_piano"
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/80_keyboard.exs"),
        // lowKey: 21,
        // highKey: 108,
        lowKey: 53,
        highKey: 84,
        category: "keys",
        sampleName: "80_keyboard"
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/yamaha_grand.exs"),
        // lowKey: 21,
        // highKey: 108,
        lowKey: 53,
        highKey: 84,
        category: "piano",
        sampleName: "yamaha_grand",
        gainCorrection: 6.0
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/yamaha_grand_cutoff_velocity.exs"),
        // lowKey: 21,
        // highKey: 108,
        lowKey: 53,
        highKey: 84,
        category: "piano",
        sampleName: "yamaha_grand_cutoff_velocity",
        gainCorrection: 6.0
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/yamaha_grand_filter_pitch.exs"),
        // lowKey: 21,
        // highKey: 108,
        lowKey: 53,
        highKey: 84,
        category: "piano",
        sampleName: "yamaha_grand_filter_pitch",
        gainCorrection: 6.0
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/yamaha_grand_tuned_up.exs"),
        // lowKey: 21,
        // highKey: 108,
        lowKey: 53,
        highKey: 84,
        category: "piano",
        sampleName: "yamaha_grand_tuned_up",
        gainCorrection: 6.0
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/yamaha_grand_tuned_down.exs"),
        // lowKey: 21,
        // highKey: 108,
        lowKey: 53,
        highKey: 84,
        category: "piano",
        sampleName: "yamaha_grand_tuned_down",
        gainCorrection: 6.0
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/yamaha_grand_like_steinway.exs"),
        // lowKey: 21,
        // highKey: 108,
        lowKey: 53,
        highKey: 84,
        category: "piano",
        sampleName: "yamaha_grand_like_steinway",
        gainCorrection: 6.0
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/yamaha_grand_key_pitch.exs"),
        // lowKey: 21,
        // highKey: 108,
        lowKey: 53,
        highKey: 84,
        category: "piano",
        sampleName: "yamaha_grand_key_pitch",
        gainCorrection: 6.0
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/grand_piano.exs"),
        // lowKey: 21,
        // highKey: 108,
        lowKey: 53,
        highKey: 84,
        category: "piano",
        sampleName: "grand_piano"
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/bosendorfer_grand.exs"),
        // lowKey: 21,
        // highKey: 108,
        lowKey: 53,
        highKey: 84,
        category: "piano",
        sampleName: "bosendorfer_grand",
        gainCorrection: -14.0
    )
]
let totalSamples = instruments.count * samplesPerInstrument

// print("Generating a total of \(totalSamples) samples for partition \(partitionNumber)")

let renderer = try SampleRenderer()
renderer.setCutoff(5.0) // Do not generate more than 5 seconds of audio

let generator = EventGenerator()

func updateLine(with newText: String) {
    let clearLineSequence = "\r" + String(repeating: " ", count: 80) + "\r"
    print(clearLineSequence, terminator: "")
    print(newText, terminator: "")
    fflush(stdout) // Ensure the output is immediately displayed
}

// updateLine(with: "Generating samples...")
var count = 0
for instrument in instruments {
    let instrumentCopy = try createTemporaryCopyOfFile(originalFilePath: instrument.url)
    try renderer.useInstrument(instrumentPack: instrumentCopy, instrument.gainCorrection)

    for i in 0..<samplesPerInstrument {
        renderer.clearTracks()
        renderer.pickRandomEffectPreset()

        generator.generate(instrumentSpec: instrument, renderer: renderer)

        let instrumentName = "\(instrument.category)_\(instrument.sampleName)"
        let fileName = "\(instrumentName)_\(i)"

        let datasetPartition = datasetDirectory.appending(path: "\(instrumentName)_\(partitionNumber)")
        if !FileManager.default.fileExists(atPath: datasetPartition.path) {
            try FileManager.default.createDirectory(at: datasetPartition, withIntermediateDirectories: false)
        }
        let aacOutputFile = datasetPartition.appending(path: "\(fileName).aac")
        let csvOutputFile = datasetPartition.appending(path: "\(fileName).csv")
        let midiOutputFile = datasetPartition.appending(path: "\(fileName).mid")

        let csvString = noteEventsToCsv(events: try renderer.getStagedEvents())
        try csvString.write(to: csvOutputFile, atomically: false, encoding: .utf8)
        try renderer.generateAac(outputUrl: aacOutputFile)
        try renderer.writeMidiFile(midiFileURL: midiOutputFile)

        count += 1
        let completionPercent = (Double(count) / Double(totalSamples)) * 100
        updateLine(with: "\(String(format: "%.3f", completionPercent))% complete")
    }

    try FileManager.default.removeItem(at: instrumentCopy)
}
