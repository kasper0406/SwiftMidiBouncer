//
//  main.swift
//  Sound Generator
//
//  Created by Kasper Nielsen on 04/01/2024.
//

import Foundation

// TODO: Piano Perfect mix volume can be ultra low

if CommandLine.arguments.count < 3 {
    print("This program must be used as ./sound_generator {generate_random, from_midi} <output_dir> ...")
    print("  if generate_random: ./sound_generator generate_random <output_dir> <partition_number> <samples_per_instrument>")
    print("  if from_midi: ./sound_generator from_midi <output_dir> <midi_file>")
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[2])

let cwd = FileManager.default.currentDirectoryPath
let pianoKeyRange = 21...108
let instruments = [
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/vibraphone_keys.exs"),
        keyRange: pianoKeyRange,
        category: "keys",
        sampleName: "vibraphone",
        maxComplexity: 4
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/different_phase_clav.exs"),
        keyRange: pianoKeyRange,
        category: "piano",
        sampleName: "different_phase_clav"
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/perfect_mix_piano.exs"),
        keyRange: pianoKeyRange,
        category: "piano",
        sampleName: "perfect_mix_piano"
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/learners_piano.exs"),
        keyRange: pianoKeyRange,
        category: "piano",
        sampleName: "learners_piano"
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/80_keyboard.exs"),
        keyRange: pianoKeyRange,
        category: "keys",
        sampleName: "80_keyboard",
        maxComplexity: 4
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/yamaha_grand.exs"),
        keyRange: pianoKeyRange,
        category: "piano",
        sampleName: "yamaha_grand"
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/yamaha_grand_cutoff_velocity.exs"),
        keyRange: pianoKeyRange,
        category: "piano",
        sampleName: "yamaha_grand_cutoff_velocity"
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/yamaha_grand_filter_pitch.exs"),
        keyRange: pianoKeyRange,
        category: "piano",
        sampleName: "yamaha_grand_filter_pitch"
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/yamaha_grand_tuned_up.exs"),
        keyRange: pianoKeyRange,
        category: "piano",
        sampleName: "yamaha_grand_tuned_up"
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/yamaha_grand_tuned_down.exs"),
        keyRange: pianoKeyRange,
        category: "piano",
        sampleName: "yamaha_grand_tuned_down"
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/yamaha_grand_like_steinway.exs"),
        keyRange: pianoKeyRange,
        category: "piano",
        sampleName: "yamaha_grand_like_steinway"
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/yamaha_grand_key_pitch.exs"),
        keyRange: pianoKeyRange,
        category: "piano",
        sampleName: "yamaha_grand_key_pitch"
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/grand_piano.exs"),
        keyRange: pianoKeyRange,
        category: "piano",
        sampleName: "grand_piano"
    ),
    InstrumentSpec(
        url: URL(fileURLWithPath: "\(cwd)/instruments/bosendorfer_grand.exs"),
        keyRange: pianoKeyRange,
        category: "piano",
        sampleName: "bosendorfer_grand",
        gainCorrection: -6.0
    )
]

switch CommandLine.arguments[1] {
case "generate_random":
    let partitionNumber = CommandLine.arguments[3]
    let samplesPerInstrument = Int(CommandLine.arguments[4])!
    try play_random(
        partitionNumber: partitionNumber,
        samplesPerInstrument: samplesPerInstrument,
        instruments: instruments,
        datasetDirectory: outputDirectory)

case "from_midi":
    let midiFile = URL(fileURLWithPath: CommandLine.arguments[3])
    try generate_from_midi(midiFile: midiFile, instruments: instruments, outputDirectory: outputDirectory)

default:
    print("Unknown option '\(CommandLine.arguments[1])'")
    exit(1)
}
