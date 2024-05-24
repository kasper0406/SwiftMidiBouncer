//
//  generator.swift
//  Sound Generator
//
//  Created by Kasper Nielsen on 21/02/2024.
//

import Foundation

enum Chord: CaseIterable {
    case major
    case minor
    case diminished
    case augmented
    case random
    case single

    func intervals() -> [Int] {
        var intervals = switch self {
        case .major:
            [0, 4, 7, 12]
        case .minor:
            [0, 3, 7, 12]
        case .diminished:
            [0, 3, 6, 12]
        case .augmented:
            [0, 4, 8, 12]
        case .random:
            [ Int.random(in: 0...12), Int.random(in: 0...12), Int.random(in: 0...12), Int.random(in: 0...12) ]
        case .single:
            [0]
        }
        intervals = TransformTo7thChord.allCases.randomElement()!.apply(intervals: intervals)
        intervals = SuspendChord.allCases.randomElement()!.apply(intervals: intervals)
        return intervals
    }
}

enum Scale: CaseIterable {
    case diatonic
    case wholeTone
    case pentatonicMajor
    case pentatnoicBlues
    case random

    func intervals() -> [Int] {
        let intervals = switch self {
        case .diatonic:
            [0, 2, 4, 5, 7, 9, 11, 12]
        case .wholeTone:
            [0, 2, 4, 6, 8, 10, 12]
        case .pentatonicMajor:
            [0, 2, 4, 7, 9]
        case .pentatnoicBlues:
            [0, 2, 5, 7, 9]
        case .random:
            [Int.random(in: 0...12), Int.random(in: 0...12), Int.random(in: 0...12), Int.random(in: 0...12)]
        }
        return ModeScaleTransform().apply(intervals: intervals)
    }
}

enum PlayType: CaseIterable {
    case appegioChord
    case harmonicChord
    case scale

    func generateIntervals() -> [Int] {
        let invertionsTransform = InvertionsTransformer()
        let transformations: [IntervalTransformation] = [
            IntervalDupOrDrop(),
            IntervalReverser(),
            IntervalSwapper(),
            IntervalRandomInserter()
        ]

        var intervals = switch self {
        case .appegioChord:
            Chord.allCases.randomElement()!.intervals()
        case .harmonicChord:
            Chord.allCases.randomElement()!.intervals()
        case .scale:
            Scale.allCases.randomElement()!.intervals()
        }

        // Apply a bunch of transforms
        while intervals.count < 10 || Double.random(in: 0..<1) < 0.95 {
            let transform = transformations.randomElement()!
            intervals = transform.apply(intervals: intervals)
        }
        // Always apply the invertions transformer to use all of the available keys
        intervals = invertionsTransform.apply(intervals: intervals)
        return intervals
    }
}

func addInterval(interval: Int, intervals: [Int]) -> [Int] {
    var newList: [Int] = intervals
    newList.append(interval)
    return newList.sorted()
}

protocol IntervalTransformation {
    func apply(intervals: [Int]) -> [Int]
}

enum TransformTo7thChord: CaseIterable, IntervalTransformation {
    case none
    case major7
    case minor7

    func apply(intervals: [Int]) -> [Int] {
        switch self {
        case .none:
            return intervals
        case .major7:
            return addInterval(interval: 11, intervals: intervals)
        case .minor7:
            return addInterval(interval: 10, intervals: intervals)
        }
    }
}

enum SuspendChord: CaseIterable, IntervalTransformation {
    case none
    case sus2
    case sus4

    func apply(intervals: [Int]) -> [Int] {
        var transformed: [Int] = []
        for interval in intervals {
            if interval != 4 {
                transformed.append(interval)
            } else {
                switch self {
                case .none:
                    transformed.append(interval)
                case .sus2:
                    transformed.append(2)
                case .sus4:
                    transformed.append(5)
                }
            }
        }
        return transformed
    }
}

class IntervalDupOrDrop: IntervalTransformation {
    func apply(intervals: [Int]) -> [Int] {
        var transformed: [Int] = []
        for interval in intervals {
            while Double.random(in: 0..<1) < 0.3 {
                // Duplicate the interval
                transformed.append(interval)
            }
            // Drop the event with 20% probability
            if Double.random(in: 0..<1) < 0.2 {
                transformed.append(interval)
            }

        }
        return transformed
    }
}

class IntervalRandomInserter: IntervalTransformation {
    func apply(intervals: [Int]) -> [Int] {
        var transformed: [Int] = []
        if Double.random(in: 0..<1) < 0.2 {
            transformed.append(Int.random(in: 0...12))
        }
        for interval in intervals {
            transformed.append(interval)
            // Insert a random interval with 20% probability
            if Double.random(in: 0..<1) < 0.2 {
                transformed.append(Int.random(in: 0...12))
            }
        }
        return transformed
    }
}

class IntervalReverser: IntervalTransformation {
    func apply(intervals: [Int]) -> [Int] {
        return intervals.reversed()
    }
}

class IntervalSwapper: IntervalTransformation {
    func apply(intervals: [Int]) -> [Int] {
        var shuffled = intervals
        for i in 0..<max(0, (shuffled.count - 1)) {
            if Double.random(in: 0..<1.0) < 0.3 {
                // Flip if we throw a 30% dice, otherwise do nothing
                let tmp = shuffled[i]
                shuffled[i] = shuffled[i + 1]
                shuffled[i + 1] = tmp
            }
        }

        return shuffled
    }
}

func generateGaussianRandom(mean: Double, standardDeviation: Double) -> Double {
    let u1 = Double.random(in: Double.ulpOfOne...1)
    let u2 = Double.random(in: Double.ulpOfOne...1)

    let z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
    return z0 * standardDeviation + mean
}

class InvertionsTransformer: IntervalTransformation {
    func apply(intervals: [Int]) -> [Int] {
        // The interval is always relative to the middel octave.
        // On a piano we have ~4 octaves on either side to use
        // We pick an integer around 0 according to a normal distribution (favoring playing in the middle registers),
        // and then re-sample the intervals
        var newInterval: [Int] = []
        for interval in intervals {
            let shift = Int(round(generateGaussianRandom(mean: 0.0, standardDeviation: 1.5)))
            newInterval.append(12 * shift + interval)
        }
        return newInterval
    }
}

enum Mode: CaseIterable {
    case ionian
    case dorian
    case phrygian
    case lydian
    case mixolydian
    case aeolian
    case locrian

    func replacements() -> [Int: Int] {
        switch self {
        case .ionian:
            return [:]
        case .dorian:
            return [ 4: 3, 11: 10 ] // Flatten E and B
        case .phrygian:
            return [ 2: 1, 4: 3, 9: 8, 11: 10 ] // Flatten A, B, D, E
        case .lydian:
            return [ 5: 6 ] // Sharpen F
        case .mixolydian:
            return [ 11: 10 ] // Flatten B
        case .aeolian:
            return [ 5: 4, 11: 10, 9: 8 ] // Flatten E, B, A
        case .locrian:
            return [ 2: 1, 4: 3, 7: 6, 9: 8, 11: 10 ] // Flatten G, A, B, D, E
        }
    }
}

class ModeScaleTransform: IntervalTransformation {
    func apply(intervals: [Int]) -> [Int] {
        let replacements = Mode.allCases.randomElement()!.replacements()

        var newInterval: [Int] = []
        for interval in intervals {
            if let replacement = replacements[interval] {
                newInterval.append(replacement)
            } else {
                newInterval.append(interval)
            }
        }
        return newInterval
    }
}

func convertToInstrumentKeys(startingKey: Int, middleKey: Int, instrumentSpec: InstrumentSpec, intervals: [Int]) -> [Int] {
    var keys: [Int] = []

    let scaleOffset = 12 / 2
    for interval in intervals {
        let key = middleKey + startingKey + interval - scaleOffset
        if key < instrumentSpec.keyRange.lowerBound {
        } else if key > instrumentSpec.keyRange.upperBound {
        } else {
            keys.append(key)
        }
    }

    return keys
}

func makeIntervalsUnique(intervals: [Int]) -> [Int] {
    var unique: [Int] = []
    var seen: Set<Int> = Set()

    for interval in intervals {
        if !seen.contains(interval) {
            seen.insert(interval)
            unique.append(interval)
        }
    }

    return unique
}

struct TimeSignature {
    var notesPerBar: Int
    var noteValue: Int
}

func randomSampleByElementWeight(values: [Double]) -> Double? {
    let transformedWeights = values.map { 1 / $0 }
    // Calculate the total sum of the transformed weights
    let totalWeightSum = transformedWeights.reduce(0, +)

    // Generate a random number in the range [0, totalWeightSum)
    let randomNumber = Double.random(in: 0..<totalWeightSum)

    // Iterate over the values to find where the random number fits using transformed weights
    var runningSum = 0.0
    for (index, weight) in transformedWeights.enumerated() {
        runningSum += weight
        if randomNumber < runningSum {
            return values[index]
        }
    }
    return nil
}

func selectElement<T>(from elements: [T], basedOn probabilities: [Double]) -> T? {
    // Check if the number of elements matches the number of probabilities
    guard elements.count == probabilities.count else { return nil }

    // Generate a random number between 0 and 1
    let randomNumber = Double.random(in: 0...1)

    // Iterate through the probabilities
    var cumulativeProbability = 0.0
    for (index, probability) in probabilities.enumerated() {
        cumulativeProbability += probability

        // Check if the random number falls within the current cumulative probability
        if randomNumber <= cumulativeProbability {
            return elements[index]
        }
    }

    // In case no element is selected (should not happen if probabilities sum to 1)
    return nil
}

func beatsFromNoteValue(noteValue: Double, timeSignature: TimeSignature) -> Double {
    return noteValue * Double(timeSignature.noteValue)
}

func goToNextMeasure(currentTime: Double, timeSignature: TimeSignature, tempo: Double) -> Double {
    let measureDuration = Double(timeSignature.notesPerBar)
    let rest = measureDuration - currentTime.truncatingRemainder(dividingBy: measureDuration)
    return currentTime + rest
}

func measureFromTime(_ time: Double, _ timeSignature: TimeSignature) -> Int {
    return Int(floor(time / Double(timeSignature.notesPerBar)))
}

func humanizeEvents(_ events: [Note], tempo: Double) -> [Note] {
    let stdDivInSeconds = sqrt(Double.random(in: 0.0..<0.3))
    let stdDiv = stdDivInSeconds / (tempo / 60.0)

    var humanized: [Note] = []
    for event in events {
        // This can lead to a note being played again that has not been released!
        // The release event may happen after the maximum time (probably not an issue)
        humanized.append(Note(
            time: max(0.0, generateGaussianRandom(mean: event.time, standardDeviation: stdDiv)),
            duration: max(0.1, generateGaussianRandom(mean: event.duration, standardDeviation: stdDiv)),
            key: event.key,
            velocity: event.velocity
        ))
    }

    return humanized
}

func sampleTimeSignature() -> TimeSignature {
    let possibilities: [TimeSignature] = [
        TimeSignature(notesPerBar: 4, noteValue: 4),
        TimeSignature(notesPerBar: 3, noteValue: 4),
        TimeSignature(notesPerBar: 2, noteValue: 4),
        TimeSignature(notesPerBar: 2, noteValue: 2),
        TimeSignature(notesPerBar: 3, noteValue: 8),
        TimeSignature(notesPerBar: 6, noteValue: 8),
        TimeSignature(notesPerBar: 9, noteValue: 8),
        TimeSignature(notesPerBar: 12, noteValue: 8),
        TimeSignature(notesPerBar: 5, noteValue: 4),
        TimeSignature(notesPerBar: 6, noteValue: 4)
    ]

    return possibilities.randomElement()!
}

class EventGenerator {

    let noteValues = [ 1.0/32.0, 1.0/16.0, 1.0/8.0, 1.0/4.0, 1.0/2.0, 1.0, 2.0 ]

    func generate(instrumentSpec: InstrumentSpec, renderer: SampleRenderer, maxDuration: Double = 5.9) {
        let timeSignature = sampleTimeSignature()
        let tempo = min(max(40, round(generateGaussianRandom(mean: 100, standardDeviation: 35))), 200)

        let events = generate(
            timeSignature: timeSignature,
            tempo: tempo,
            instrumentSpec: instrumentSpec,
            maxDuration: maxDuration)

        renderer.setTempoAndTimeSignature(tempo: tempo, timeSignature: timeSignature)
        for event in events {
            renderer.stage(note: event)
        }
    }

    func generate(timeSignature: TimeSignature, tempo: Double, instrumentSpec: InstrumentSpec, maxDuration: Double = 4.9) -> [Note] {
        let maxDurationInBeats = (tempo / 60.0) * maxDuration // Beats per second * seconds = beats
        var events: [Note] = []

        var time = 0.0

        while time < maxDurationInBeats && (events.isEmpty || Double.random(in: 0..<1) < 0.999) {
            let startMeasure = measureFromTime(time, timeSignature)

            let middle = (instrumentSpec.keyRange.lowerBound + instrumentSpec.keyRange.upperBound) / 2
            let range = instrumentSpec.keyRange.upperBound - instrumentSpec.keyRange.lowerBound

            let startingKey = Int.random(in: -6..<6)

            let playBothHands = Double.random(in: 0...1.0) < 0.95
            if playBothHands {
                let leftMiddle = middle - range / 4
                let rightMiddle = middle + range / 4

                // Allow between 1 and 6 notes per hand playing at the same time
                let leftHandComplexity = UInt8.random(in: 1...6)
                let rightHandComplexity = UInt8.random(in: 1...6)

                let leftHandValueDist = noteValueProbDist()
                let rightHandValueDist = noteValueProbDist()

                let leftHand = generateHandForMeasure(time, startingKey, leftMiddle, leftHandComplexity, leftHandValueDist, maxDurationInBeats, instrumentSpec, timeSignature)
                let rightHand = generateHandForMeasure(time, startingKey, rightMiddle, rightHandComplexity, rightHandValueDist, maxDurationInBeats, instrumentSpec, timeSignature)

                events.append(contentsOf: leftHand)
                events.append(contentsOf: rightHand)
            } else {
                let complexity = UInt8.random(in: 1...6)
                let noteValueDist = noteValueProbDist()
                let hand = generateHandForMeasure(time, startingKey, middle, complexity, noteValueDist, maxDurationInBeats, instrumentSpec, timeSignature)
                events.append(contentsOf: hand)
            }

            if measureFromTime(time, timeSignature) <= startMeasure {
                time = goToNextMeasure(currentTime: time, timeSignature: timeSignature, tempo: tempo)
            }
        }

        if events.isEmpty {
            // What a hack, but I don't bother fixing it in a nicer way...
            // This should happen quite very rarely to not be a perf or stack concern
            return generate(timeSignature: timeSignature, tempo: tempo, instrumentSpec: instrumentSpec)
        }

        return humanizeEvents(events, tempo: tempo)
    }

    func generateHandForMeasure(_ startTime: Double, _ startingKey: Int, _ middleKey: Int, _ handNoteComplexity: UInt8, _ noteValueDist: [Double], _ maxDurationInBeats: Double, _ instrumentSpec: InstrumentSpec, _ timeSignature: TimeSignature) -> [Note] {
        var events: [Note] = []

        let playType = PlayType.allCases.randomElement()!
        let intervals = playType.generateIntervals()
        let keys = convertToInstrumentKeys(startingKey: startingKey, middleKey: middleKey, instrumentSpec: instrumentSpec, intervals: intervals)

        let startMeasure = measureFromTime(startTime, timeSignature)
        var time = startTime

        // Introduce a possible rest before starting to play in the measure
        if Double.random(in: 0..<1.0) < 0.15 {
            let waitTime = selectElement(from: noteValues,
                                         basedOn: noteValueDist)!
            time += beatsFromNoteValue(noteValue: waitTime, timeSignature: timeSignature)
        }

        // Map from key playing until end duration in seconds to access the complexity
        var currentlyPlayingKeys: [ Int: Double ] = [:]
        let repeatedKeys = (0..<10).flatMap { _ in keys } // Repeat the keys to not run out
        for key in repeatedKeys {
            if time >= maxDurationInBeats {
                break
            }
            if measureFromTime(time, timeSignature) > startMeasure {
                // We will generate a new set of beats for the next measure
                break
            }
            if currentlyPlayingKeys.count < handNoteComplexity {
                // If more than `handNoteComplexity` notes are playing we don't want to play more...
                let velocity = UInt8.random(in: 30..<128)
                let noteValue = selectElement(from: noteValues,
                                              basedOn: noteValueDist)!

                let durationInBeats = beatsFromNoteValue(noteValue: noteValue, timeSignature: timeSignature)
                if currentlyPlayingKeys[key] != nil {
                    // Skip this key as it is already playing
                    continue
                }
                currentlyPlayingKeys[key] = time + durationInBeats

                events.append(Note(time: time, duration: durationInBeats, key: UInt8(key), velocity: velocity))
            } else if playType == PlayType.harmonicChord {
                break
            }

            if playType != PlayType.harmonicChord {
                // In 30% the cases increment the time by some amount
                if Double.random(in: 0..<1.0) < 0.3 {
                    let waitTime = selectElement(from: noteValues,
                                                 basedOn: noteValueDist)!
                    time += beatsFromNoteValue(noteValue: waitTime, timeSignature: timeSignature)
                }
            }

            // Clean up the currently playing keys
            let keysToRemove = currentlyPlayingKeys.filter { $0.value < time }.map { $0.key }
            keysToRemove.forEach { currentlyPlayingKeys.removeValue(forKey: $0) }
        }

        return events
    }

    private func noteValueProbDist() -> [Double] {
        let mean = min(noteValues.last!, max(noteValues.first!, generateGaussianRandom(mean: 0.5, standardDeviation: 0.6)))
        let variance = 0.35 * mean

        let expectation = noteValues.map({ value in -0.5 * pow((value - mean) / variance, 2) })
            .map({ value in max(value, -10.0) }) // Below values of -10 we will assume the exponential will give 0
            .map(exp)
        let sum = expectation.reduce(0.0, +)

        return expectation.map({ value in value / sum })
    }
}
