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
 * TODOs:
 *   1. Investigate delay in the beginning causing slight shift in audio timing
 *   2. Generate more samples without a bunch of effects
 *   3. Generate faster and more complicated sections
 */

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

enum EffectSettingsDescription {
    case Eq(String)
    case Compressor(String)
    case Reverb(String)
    case TimePitch(String)
}

enum Message {
    case Tempo(Double)
    case TimeSignature(TimeSignature)
    case EffectSettings(EffectSettingsDescription)

    func order() -> Int {
        switch self {
        case .Tempo:
            return 0
        case .TimeSignature:
            return 1
        case .EffectSettings:
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

    var generate_cutoff: Double? // If set, do not generate more than x seconds of audio

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
    let timePitch: AVAudioUnitTimePitch

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
        timePitch = AVAudioUnitTimePitch()

        // Setup the engine
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: maxFrames)
        engine.attach(sampler)
        engine.attach(timePitch)
        engine.attach(eq)
        engine.attach(compressor)
        engine.attach(reverb)

        engine.connect(sampler, to: timePitch, format: format)
        engine.connect(timePitch, to: eq, format: format)
        engine.connect(eq, to: compressor, format: format)
        engine.connect(compressor, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)

        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)

        try engine.start()

        // Setup the sequencer
        sequencer = AVAudioSequencer(audioEngine: engine)
    }

    func setCutoff(_ cutoff: Double) {
        self.generate_cutoff = cutoff
    }

    func pickRandomEffectPreset() {
        // Eq
        eq.bypass = Double.random(in: 0.0...1.0) < 0.5 // Bypass 50% of the time
        let a = Double.random(in: 0.5...1)
        let b = Double.random(in: 0.5...1)
        let numBands: Double = Double(eq.bands.endIndex + 1)
        for (i, band) in eq.bands.enumerated() {
            let fraction: Double = 4 * Double.pi
            let wave1: Double = sin((a * numBands * Double(i)) / fraction)
            let wave2: Double = sin((b * 2 * numBands * Double(i)) / fraction)
            band.gain = Float(2 * (wave1 + wave2))
        }

        // Compressor
        compressor.bypass = Double.random(in: 0.0...1.0) < 0.5 // Bypass 50% of the time
        // Global, dB, -40->20, -20
        let thresholdParameter = compressor.auAudioUnit.parameterTree!.parameter(withAddress: AUParameterAddress(kDynamicsProcessorParam_Threshold))!
        thresholdParameter.setValue(Float.random(in: -25...5), originator: nil)

        // Global, dB, 0.1->40.0, 5
        let headRoomParameter = compressor.auAudioUnit.parameterTree!.parameter(withAddress: AUParameterAddress(kDynamicsProcessorParam_HeadRoom))!
        headRoomParameter.setValue(Float.random(in: 5.0...20), originator: nil)

        // Global, rate, 1->50.0, 2
        let expansionRatioParameter = compressor.auAudioUnit.parameterTree!.parameter(withAddress: AUParameterAddress(kDynamicsProcessorParam_ExpansionRatio))!
        expansionRatioParameter.setValue(Float.random(in: 2.0...20.0), originator: nil)

        // Global, secs, 0.0001->0.2, 0.001
        let attackTimeParameter = compressor.auAudioUnit.parameterTree!.parameter(withAddress: AUParameterAddress(kDynamicsProcessorParam_AttackTime))!
        attackTimeParameter.setValue(Float.random(in: 0.0005...0.1), originator: nil)

        // Global, secs, 0.01->3, 0.05
        let releaseTimeParameter = compressor.auAudioUnit.parameterTree!.parameter(withAddress: AUParameterAddress(kDynamicsProcessorParam_ReleaseTime))!
        releaseTimeParameter.setValue(Float.random(in: 0.1...0.3), originator: nil)

        // Reverb
        reverb.bypass = Double.random(in: 0.0...1.0) < 0.3 // Bypass 30% of the time
        reverb.loadFactoryPreset(.init(rawValue: (0...12).randomElement()!)!)
        reverb.wetDryMix = Float.random(in: 0...100)

        // Time pitch
        timePitch.bypass = Double.random(in: 0.0...1.0) < 0.7 // Bypass 70% of the time
        timePitch.pitch = Float(Int.random(in: 0...40))
    }

    private func getEffectSettingsEvents() -> [Message] {
        // Eq
        var eqSettings = "bypass=\(eq.bypass)"
        eqSettings += ",bands="
        for (i, band) in eq.bands.enumerated() {
            eqSettings += String(format: "%.2f", band.gain)
            if i != eq.bands.count - 1 {
                eqSettings += ","
            }
        }
        let eqEvent = Message.EffectSettings(EffectSettingsDescription.Eq(eqSettings))

        // Compressor
        var compressorSettings = "bypass=\(compressor.bypass)"
        let thresholdParameter = compressor.auAudioUnit.parameterTree!.parameter(withAddress: AUParameterAddress(kDynamicsProcessorParam_Threshold))!
        compressorSettings += ",threshold=" + String(format: "%.2f", thresholdParameter.value)
        let headRoomParameter = compressor.auAudioUnit.parameterTree!.parameter(withAddress: AUParameterAddress(kDynamicsProcessorParam_HeadRoom))!
        compressorSettings += ",headroom=" + String(format: "%.2f", headRoomParameter.value)
        let expansionRatioParameter = compressor.auAudioUnit.parameterTree!.parameter(withAddress: AUParameterAddress(kDynamicsProcessorParam_ExpansionRatio))!
        compressorSettings += ",expansion_rate=" + String(format: "%.2f", expansionRatioParameter.value)
        let attackTimeParameter = compressor.auAudioUnit.parameterTree!.parameter(withAddress: AUParameterAddress(kDynamicsProcessorParam_AttackTime))!
        compressorSettings += ",attack_time=" + String(format: "%.2f", attackTimeParameter.value)
        let releaseTimeParameter = compressor.auAudioUnit.parameterTree!.parameter(withAddress: AUParameterAddress(kDynamicsProcessorParam_ReleaseTime))!
        compressorSettings += ",release_time=" + String(format: "%.2f", releaseTimeParameter.value)
        let compressorEvent = Message.EffectSettings(EffectSettingsDescription.Compressor(compressorSettings))

        // Reverb
        var reverbSettings = "bypass=\(reverb.bypass)"
        reverbSettings += ",preset=\(reverb.auAudioUnit.currentPreset!.name)"
        reverbSettings += ",wet_dry_mix=" + String(format: "%.2f", reverb.wetDryMix)
        let reverbEvent = Message.EffectSettings(EffectSettingsDescription.Reverb(reverbSettings))

        // Time pitch
        var timePitchSettings = "bypass=\(timePitch.bypass)"
        timePitchSettings += ",pitch=" + String(format: "%.2f", timePitch.pitch)
        let timePitchEvent = Message.EffectSettings(EffectSettingsDescription.TimePitch(timePitchSettings))

        return [eqEvent, compressorEvent, reverbEvent, timePitchEvent]
    }

    func useInstrument(instrumentPack: URL, _ gainCorrection: Float?) throws {
        try sampler.loadInstrument(at: instrumentPack)
        // print("Loaded instrument at \(instrumentPack)")
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

        // Ensure that the note is not already being played in the desired time interval
        // If it is, we will just ignore this staged event
        var noteAlreadyPlaying = false
        track.enumerateEvents(in: AVBeatRange(start: note.time, length: note.duration), using: { event, _, _ in
            if let existingEvent = event as?AVMIDINoteEvent {
                if existingEvent.key == note.key {
                    noteAlreadyPlaying = true
                    return
                }
            }
        })
        if noteAlreadyPlaying {
            return
        }

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

    func writeMidiFile(midiFileURL: URL) throws {
        try sequencer.write(to: midiFileURL, smpteResolution: 0, replaceExisting: true)
    }

    func transpose(trackSelect: Int, amount: Int) {
        let track = sequencer.tracks[trackSelect]
        track.enumerateEvents(in: AVBeatRange(start: 0.0, length: 999999999999.0), using: { event, _, _ in
            if let midiEvent = event as?AVMIDINoteEvent {
                midiEvent.key = UInt32(Int(midiEvent.key) + amount)
            }
        })
    }

    /**
     Returns all the staged nodes ordered by the time they start playing
     */
    func getStagedEvents(trackSelect: Int = 0) throws -> [MidiEvent] {
        if sequencer.tracks.isEmpty {
            return []
        }
        let track = sequencer.tracks[trackSelect]

        var events: [MidiEvent] = []
        var encounteredUnknownEvent = false
        var foundNoteEvents = false
        track.enumerateEvents(in: AVBeatRange(start: 0.0, length: 999999999999.0), using: { event, timestamp, _ in
            if let midiEvent = event as?AVMIDINoteEvent {
                foundNoteEvents = true
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

        if !foundNoteEvents {
            return []
        }

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

        events.append(contentsOf: getEffectSettingsEvents().map({ message in MidiEvent.MessageEvent(0.0, message) }))

        if encounteredUnknownEvent {
            print("Warning: Encountered unknown event")
            // throw NSError(domain: "SampleGenerator", code: 1, userInfo: nil)
        }

        return events.sorted()
    }

    func getTrackCount() -> Int {
        return sequencer.tracks.count
    }

    func soloTrack(trackSelect: Int? = nil) {
        for (i, track) in sequencer.tracks.enumerated() {
            track.isSoloed = trackSelect == i
        }
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
            if track.isMuted {
                track.destinationAudioUnit = nil
            } else {
                track.destinationAudioUnit = sampler
                maxTrackLengthInSeconds = max(maxTrackLengthInSeconds, track.lengthInSeconds)
            }
        }
        if let cutoff = self.generate_cutoff {
            maxTrackLengthInSeconds = min(cutoff, maxTrackLengthInSeconds)
        }

        sequencer.prepareToPlay()
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
        engine.reset()
    }

    /**
     Normalizes the apliitude of the audio file, and cuts away any leading silence.
     The number of silence seconds trimmed away is returned, so the CSV file can be adjusted.
     */
    static func normalizeAudioFile(audioFileUrl: URL) throws -> Double {
        // Open the source audio file
        var inputFile: AVAudioFile? = try AVAudioFile(forReading: audioFileUrl)

        // Create a format for processing
        let processingFormat = inputFile!.processingFormat
        let frameCount = UInt32(inputFile!.length)
        let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: frameCount)!

        // Read the entire file into the buffer
        try inputFile!.read(into: buffer, frameCount: frameCount)

        let epsilon: Float = 0.001

        // Find the peak level
        let channelData = buffer.floatChannelData!
        var maxAmplitude: Float = 0.0

        // Count the number of leading frames with 0 values
        var skipFrames = 0
        var audioStarted = false

        for frame in 0..<Int(frameCount) {
            var frameMax: Float = 0.0
            for channel in 0..<Int(buffer.format.channelCount) {
                let absAmplitude = abs(channelData[channel][frame])
                maxAmplitude = max(maxAmplitude, absAmplitude)
                frameMax = max(frameMax, absAmplitude)
            }

            if frameMax > epsilon {
                audioStarted = true
            }
            if !audioStarted && frameMax < epsilon {
                skipFrames += 1
            }
        }

        // Calculate gain
        let gain = maxAmplitude > epsilon ? 1.0 / maxAmplitude : 0.0

        // Apply gain to each sample
        for frame in 0..<Int(frameCount) {
            for channel in 0..<Int(buffer.format.channelCount) {
                if frame + skipFrames >= frameCount {
                    channelData[channel][frame] = 0
                } else {
                    channelData[channel][frame] = channelData[channel][frame + skipFrames] * gain
                }
            }
        }
        let settings = inputFile!.fileFormat.settings
        inputFile = nil // Make sure we do not use the file anymore

        // Write the normalized buffer to a new audio file
        let outputFile = try AVAudioFile(forWriting: audioFileUrl, settings: settings)
        try outputFile.write(from: buffer)

        return Double(skipFrames) / buffer.format.sampleRate
    }

    deinit {
        engine.stop()
    }
}
