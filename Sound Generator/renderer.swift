//
//  generator.swift
//  Sound Generator
//
//  Created by Kasper Nielsen on 11/01/2024.
//

import Foundation

import CoreAudio
import AudioToolbox
import AVFoundation

/*
 * `key` is in the range 0 -> 127
 * `velocity` is in the range 0 -> 127
 */
struct Note {
    // TODO(knielsen): For now we take the time and duration to be position in seconds.
    //                 Consider if this should be the position in beats instead
    let time: Double
    let duration: Double

    let key: UInt8
    let velocity: UInt8
}

/**
  Given a description of midi events generate a rendered audio file
 */
class SampleRenderer {

    // General audio and capacity settings
    let sampleRate = 44100.0
    let format: AVAudioFormat
    let maxFrames: AVAudioFrameCount = 4096

    // File export settings
    let wavSettings: [String: Any]
    let aacSettings: [String: Any]

    // Audio library instances
    let engine: AVAudioEngine
    let sampler: AVAudioUnitSampler
    let sequencer: AVAudioSequencer

    init() throws {
        // Set up formats and export settings
        format = AVAudioFormat(
            commonFormat: AVAudioCommonFormat.pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 2,
            interleaved: false)!
        wavSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: sampleRate
        ]
        aacSettings = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 2
        ]

        engine = AVAudioEngine()
        sampler = AVAudioUnitSampler()

        // Setup the engine
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: maxFrames)
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: format)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)
        try engine.start()

        // Setup the sequencer
        sequencer = AVAudioSequencer(audioEngine: engine)
    }

    func useInstrument(instrumentPack: URL) throws {
        try sampler.loadInstrument(at: instrumentPack)
    }

    func stage(note: Note) {
        if sequencer.tracks.isEmpty {
            sequencer.createAndAppendTrack()
        }
        let track = sequencer.tracks[0]

        // TODO(knielsen): Consider a better option here.
        //                 For now hard-code the tempo to 60 bpm, to make the note time in second line up with
        //                 the generated audio.
        sequencer.tempoTrack.addEvent(AVExtendedTempoEvent(tempo: 60.0), at: 0.0)

        let noteMidiEvent = AVMIDINoteEvent(
            channel: 0,
            key: UInt32(note.key),
            velocity: UInt32(note.velocity),
            duration: note.duration)
        track.addEvent(noteMidiEvent, at: note.time)
    }

    func loadFromMidiFile(midiFileURL: URL) throws {
        try sequencer.load(from: midiFileURL)
    }

    /**
     Returns all the staged nodes ordered by the time they start playing
     */
    func getStagedEvents() throws -> [Note] {
        if sequencer.tracks.isEmpty {
            return []
        }
        let track = sequencer.tracks[0]

        var events: [Note] = []
        var encounteredUnknownEvent = false
        track.enumerateEvents(in: AVBeatRange(start: 0.0, length: 999999999999.0), using: { event, timestamp, _ in
            if let midiEvent = event as?AVMIDINoteEvent {
                events.append(Note(
                    time: timestamp.pointee,
                    duration: midiEvent.duration,
                    key: UInt8(midiEvent.key),
                    velocity: UInt8(midiEvent.velocity)
                ))
            } else {
                // We can not throw in this closure so we keep a flag
                encounteredUnknownEvent = true
            }
        })

        if encounteredUnknownEvent {
            throw NSError(domain: "SampleGenerator", code: 1, userInfo: nil)
        }

        return events.sorted { (event1, event2) -> Bool in
            if event1.time == event2.time {
                return event1.key < event2.key
            }
            return event1.time < event2.time
        }
    }

    func clearTracks() {
        sequencer.tracks.forEach { track in sequencer.removeTrack(track) }
    }

    func generateWav(outputUrl: URL) throws {
        let outputFile = try AVAudioFile(
            forWriting: outputUrl,
            settings: wavSettings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false)
        return try generate(outputFile: outputFile)
    }

    func generateAac(outputUrl: URL) throws {
        let outputFile = try AVAudioFile(
            forWriting: outputUrl,
            settings: aacSettings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false)
        return try generate(outputFile: outputFile)
    }

    private func generate(outputFile: AVAudioFile) throws {
        let buffer = AVAudioPCMBuffer(
            pcmFormat: engine.manualRenderingFormat,
            frameCapacity: engine.manualRenderingMaximumFrameCount)!

        sequencer.currentPositionInSeconds = 0
        var maxTrackLengthInSeconds = 0.0
        sequencer.tracks.forEach { track in
            track.destinationAudioUnit = sampler
            maxTrackLengthInSeconds = max(maxTrackLengthInSeconds, track.lengthInSeconds)
        }

        try sequencer.start()
        while sequencer.isPlaying && sequencer.currentPositionInSeconds < maxTrackLengthInSeconds {
            let framesToRender = min(buffer.frameCapacity, engine.manualRenderingMaximumFrameCount)
            let status = try engine.renderOffline(framesToRender, to: buffer)

            switch status {
            case .success:
                // Write the rendered audio to the file
                try outputFile.write(from: buffer)
            case .insufficientDataFromInputNode:
                // More data is needed to continue rendering
                break
            case .cannotDoInCurrentContext, .error:
                // An error occurred. Handle it here.
                throw NSError(domain: "SampleGenerator", code: 0, userInfo: nil)
            default:
                // Handle other cases
                break
            }
        }

        sequencer.stop()
    }

    deinit {
        engine.stop()
    }
}
