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
struct Note: Comparable {
    // Time and duration measured in beats!
    let time: Double
    let duration: Double

    let key: UInt8
    let velocity: UInt8

    static func <(_ note1: Note, _ note2: Note) -> Bool {
        if note1.time == note2.time {
            return note1.key == note2.key
        }
        return note1.time < note2.time
    }

    static func ==(_ note1: Note, _ note2: Note) -> Bool {
        return note1.time == note2.time && note1.key == note2.key
    }
}

enum Message {
    case Tempo(Double)
    case TimeSignature(TimeSignature)

    func order() -> Int {
        switch self {
        case .Tempo:
            return 0
        case .TimeSignature:
            return 2
        }
    }
}

enum MidiEvent: Comparable {
    case NoteEvent(Double, Note)
    case MessageEvent(Double, Message)

    func getTimestamp() -> Double {
        switch self {
        case .NoteEvent(let timestamp, _):
            return timestamp
        case .MessageEvent(let timestamp, _):
            return timestamp
        }
    }

    static func <(_ event1: MidiEvent, _ event2: MidiEvent) -> Bool {
        let time1 = event1.getTimestamp()
        let time2 = event2.getTimestamp()

        if time1 == time2 {
            switch (event1, event2) {
            case let (.NoteEvent(_, note1), .NoteEvent(_, note2)):
                return note1 < note2
            case let (.MessageEvent(_, msg1), .MessageEvent(_, msg2)):
                return msg1.order() < msg2.order()
            case (.NoteEvent(_, _), .MessageEvent(_, _)):
                return false // `MessageEvent` goes first
            case (.MessageEvent(_, _), .NoteEvent(_, _)):
                return true // `MessageEvent` goes first
            }
        }
        return time1 <= time2
    }

    static func ==(_ event1: MidiEvent, _ event2: MidiEvent) -> Bool {
        switch (event1, event2) {
        case let (.NoteEvent(_, note1), .NoteEvent(_, note2)):
            return note1 == note2
        case let (.MessageEvent(ts1, msg1), .MessageEvent(ts2, msg2)):
            return ts1 == ts2 && msg1.order() == msg2.order()
        default:
            return false
        }
    }
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

    let eq: AVAudioUnitEQ
    let compressor: AVAudioUnitEffect
    let reverb: AVAudioUnitReverb

    var timeSignature = TimeSignature(notesPerBar: 4, noteValue: 4)

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

        eq = AVAudioUnitEQ(numberOfBands: 10)
        compressor = AVAudioUnitEffect(
            audioComponentDescription: AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: kAudioUnitSubType_DynamicsProcessor,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0))
        reverb = AVAudioUnitReverb()

        // Setup the engine
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: maxFrames)
        engine.attach(sampler)
        engine.attach(eq)
        engine.attach(compressor)
        engine.attach(reverb)

        engine.connect(sampler, to: eq, format: format)
        engine.connect(eq, to: compressor, format: format)
        engine.connect(compressor, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)
        try engine.start()

        // Setup the sequencer
        sequencer = AVAudioSequencer(audioEngine: engine)
    }

    func pickRandomEffectPreset() {
        // Eq
        let a = Double.random(in: 0.5...1)
        let b = Double.random(in: 0.5...1)
        let numBands: Double = Double(eq.bands.endIndex + 1)
        for (i, band) in eq.bands.enumerated() {
            let fraction: Double = 4 * Double.pi
            let wave1: Double = sin((a * numBands * Double(i)) / fraction)
            let wave2: Double = sin((b * 2 * numBands * Double(i)) / fraction)
            band.gain = Float(3 * (wave1 + wave2))
        }

        // Compressor
        // Global, dB, -40->20, -20
        let thresholdParameter = compressor.auAudioUnit.parameterTree!.parameter(withAddress: AUParameterAddress(kDynamicsProcessorParam_Threshold))!
        thresholdParameter.setValue(Float.random(in: -30...10), originator: nil)

        // Global, dB, 0.1->40.0, 5
        let headRoomParameter = compressor.auAudioUnit.parameterTree!.parameter(withAddress: AUParameterAddress(kDynamicsProcessorParam_HeadRoom))!
        headRoomParameter.setValue(Float.random(in: 0.5...20), originator: nil)

        // Global, rate, 1->50.0, 2
        let expansionRatioParameter = compressor.auAudioUnit.parameterTree!.parameter(withAddress: AUParameterAddress(kDynamicsProcessorParam_ExpansionRatio))!
        expansionRatioParameter.setValue(Float.random(in: 1.0...30.0), originator: nil)

        // Global, secs, 0.0001->0.2, 0.001
        let attackTimeParameter = compressor.auAudioUnit.parameterTree!.parameter(withAddress: AUParameterAddress(kDynamicsProcessorParam_AttackTime))!
        attackTimeParameter.setValue(Float.random(in: 0.0005...0.01), originator: nil)

        // Global, secs, 0.01->3, 0.05
        let releaseTimeParameter = compressor.auAudioUnit.parameterTree!.parameter(withAddress: AUParameterAddress(kDynamicsProcessorParam_ReleaseTime))!
        releaseTimeParameter.setValue(Float.random(in: 0.01...1.0), originator: nil)

        // Reverb
        reverb.loadFactoryPreset(.init(rawValue: (0...12).randomElement()!)!)
        reverb.wetDryMix = Float.random(in: 0...100)
    }

    func useInstrument(instrumentPack: URL, _ gainCorrection: Float?) throws {
        try sampler.loadInstrument(at: instrumentPack)
        sampler.overallGain = 0.0
        if let gain = gainCorrection {
            sampler.overallGain = gain
        }
    }

    func setTempoAndTimeSignature(tempo: Double, timeSignature: TimeSignature) {
        sequencer.tempoTrack.addEvent(AVExtendedTempoEvent(tempo: tempo), at: 0.0)

        let timeSignatureData = Data([ UInt8(timeSignature.notesPerBar), UInt8(timeSignature.noteValue) ])
        sequencer.tempoTrack.addEvent(AVMIDIMetaEvent(
            type: AVMIDIMetaEvent.EventType.timeSignature,
            data: timeSignatureData),
                                      at: 0.0)
        self.timeSignature = timeSignature
    }

    func stage(note: Note) {
        if sequencer.tracks.isEmpty {
            sequencer.createAndAppendTrack()
        }
        let track = sequencer.tracks[0]
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
    func getStagedEvents() throws -> [MidiEvent] {
        if sequencer.tracks.isEmpty {
            return []
        }
        let track = sequencer.tracks[0]

        var events: [MidiEvent] = []
        var encounteredUnknownEvent = false
        track.enumerateEvents(in: AVBeatRange(start: 0.0, length: 999999999999.0), using: { event, timestamp, _ in
            if let midiEvent = event as?AVMIDINoteEvent {
                events.append(MidiEvent.NoteEvent(timestamp.pointee, Note(
                    time: timestamp.pointee,
                    duration: midiEvent.duration,
                    key: UInt8(midiEvent.key),
                    velocity: UInt8(midiEvent.velocity)
                )))
            } else {
                // We can not throw in this closure so we keep a flag
                encounteredUnknownEvent = true
            }
        })

        sequencer.tempoTrack.enumerateEvents(in: AVBeatRange(start: 0.0, length: 999999999999.0), using: { event, timestamp, _ in
            if let tempoEvent = event as?AVExtendedTempoEvent {
                events.append(MidiEvent.MessageEvent(timestamp.pointee, Message.Tempo(tempoEvent.tempo)))
            } else if let metadataEvent = event as?AVMIDIMetaEvent {
                switch metadataEvent.type {
                case .timeSignature:
                    // HACK: This is a big big hack, and only works because we pick one single time signature per sample generated.
                    //       The API does not seem to support getting back the MIDI data ¯\_(ツ)_/¯
                    events.append(MidiEvent.MessageEvent(timestamp.pointee, Message.TimeSignature(self.timeSignature)))
                default:
                    // We can not throw in this closure so we keep a flag
                    encounteredUnknownEvent = true
                }
            } else {
                // We can not throw in this closure so we keep a flag
                encounteredUnknownEvent = true
            }
        })

        if encounteredUnknownEvent {
            throw NSError(domain: "SampleGenerator", code: 1, userInfo: nil)
        }

        return events.sorted()
    }

    func clearTracks() {
        // HACK: If we clear events on an empty tempo track it errors, so I just add a garbage event before clearing
        sequencer.tempoTrack.addEvent(AVExtendedTempoEvent(tempo: 60.0), at: 0.1)
        sequencer.tempoTrack.clearEvents(in: AVBeatRange(start: 0.0, length: 999999999999.0))

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
