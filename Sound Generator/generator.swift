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
        let baseIntervals = switch self {
        case .major:
            [0, 4, 7, 12]
        case .minor:
            [0, 3, 7, 12]
        case .diminished:
            [0, 3, 6, 12]
        case .augmented:
            [0, 4, 8, 12]
        case .random:
            // TODO(knielsen): Consider making this have a dynamic number of intervals
            [Int.random(in: 0...12), Int.random(in: 0...12), Int.random(in: 0...12), Int.random(in: 0...12)]
        case .single:
            [0]
        }
        return TransformTo7thChord.allCases.randomElement()!.apply(intervals: baseIntervals)
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
            [Int.random(in: 0...12), Int.random(in: 0...12), Int.random(in: 0...12), Int.random(in: 0...12), Int.random(in: 0...12), Int.random(in: 0...12)]
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
        var transformations: [IntervalTransformation] = [IntervalDupOrDrop(), IntervalReverser(), IntervalSwapper()]

        var intervals = switch self {
        case .appegioChord:
            Chord.allCases.randomElement()!.intervals()
        case .harmonicChord:
            Chord.allCases.randomElement()!.intervals()
        case .scale:
            Scale.allCases.randomElement()!.intervals()
        }

        // Apply transformations at random until we either have 10 intervals to play or we throw a 20% dice
        let maxIntervalLength = 10
        while intervals.count < maxIntervalLength && Double.random(in: 0..<1) < 0.8 {
            let transform = transformations.randomElement()!
            intervals = transform.apply(intervals: intervals)
            intervals = Array(intervals.prefix(upTo: min(intervals.count, maxIntervalLength + 1)))
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

class IntervalDupOrDrop: IntervalTransformation {
    func apply(intervals: [Int]) -> [Int] {
        var transformed: [Int] = []
        for interval in intervals {
            while Double.random(in: 0..<1) < 0.2 {
                // Duplicate the interval
                transformed.append(interval)
            }
            // Drop the event with 20% probability
            if Double.random(in: 0..<1) < 0.8 {
                transformed.append(interval)
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

class InvertionsTransformer: IntervalTransformation {
    func generateGaussianRandom(mean: Double, standardDeviation: Double) -> Double {
        let u1 = Double.random(in: 0..<1)
        let u2 = Double.random(in: 0..<1)

        let z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
        return z0 * standardDeviation + mean
    }

    func apply(intervals: [Int]) -> [Int] {
        // The interval is always relative to middle C.
        // On a piano we have ~4 octaves on either side to use
        // We pick an integer around 0 according to a normal distribution (favoring playing in the middle registers),
        // and then re-sample the intervals
        var newInterval: [Int] = []
        for interval in intervals {
            let shift = Int(round(generateGaussianRandom(mean: 0.0, standardDeviation: 2.5)))
            newInterval.append(shift * 12 + interval)
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

func convertToInstrumentKeys(instrumentSpec: InstrumentSpec, intervals: [Int]) -> [Int] {
    var keys: [Int] = []

    let middleKey = (instrumentSpec.lowKey + instrumentSpec.highKey) / 2
    let startingKey = Int.random(in: 0..<12)

    for interval in intervals {
        let key = middleKey + startingKey + interval
        if key < instrumentSpec.lowKey {
            let offset = ceil((Double(instrumentSpec.lowKey) - Double(key)) / 12.0) * 12
            keys.append(key + Int(offset))
        } else if key > instrumentSpec.highKey {
            let offset = ceil((Double(key) - Double(instrumentSpec.highKey)) / 12.0) * 12
            keys.append(key - Int(offset))
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

func durationFromNoteValue(noteValue: Double, timeSignature: TimeSignature, tempo: Double) -> Double {
    let durationForFullNote = (60.0 / tempo) * Double(timeSignature.noteValue)
    return durationForFullNote * noteValue
}

func goToNextBar(currentTime: Double, timeSignature: TimeSignature, tempo: Double) -> Double {
    let durationOfBar = (60.0 / tempo) * Double(timeSignature.notesPerBar)
    let rest = currentTime.truncatingRemainder(dividingBy: durationOfBar)
    return currentTime + rest
}

class EventGenerator {

    func generate(instrumentSpec: InstrumentSpec, maxDuration: Double = 4.9) -> [Note] {
        let timeSignature = TimeSignature(
            notesPerBar: Int.random(in: 2...12),
            noteValue: [2, 4, 8].randomElement()!)
        let tempo = Double.random(in: 60.0...160.0)
        return generate(timeSignature: timeSignature, tempo: tempo, instrumentSpec: instrumentSpec, maxDuration: maxDuration)
    }

    func generate(timeSignature: TimeSignature, tempo: Double, instrumentSpec: InstrumentSpec, maxDuration: Double = 4.5) -> [Note] {
        var events: [Note] = []

        var time = 0.0
        var currentlyPlayingKeys: [ Int: Double ] = [:] // Map from key playing until end duration in seconds
        while time < maxDuration && (events.isEmpty || Double.random(in: 0..<1) < 0.95) {
            let playType = PlayType.allCases.randomElement()!
            let intervals = playType.generateIntervals()

            let keys = convertToInstrumentKeys(instrumentSpec: instrumentSpec, intervals: intervals)

            for key in keys {
                if time >= maxDuration {
                    break
                }
                let velocity = UInt8.random(in: 10..<128)
                let noteValue = selectElement(from: [ 1.0/32.0, 1.0/16.0, 1.0/8.0, 1.0/4.0, 1.0/2.0, 1.0, 2.0 ],
                                              basedOn: [ 0.15, 0.2, 0.2, 0.3, 0.075, 0.05, 0.025 ])!

                var durationInSeconds = durationFromNoteValue(noteValue: noteValue, timeSignature: timeSignature, tempo: tempo)
                if let _currentEndTiem = currentlyPlayingKeys[key] {
                    // Skip this key as it is already playing
                    continue
                }
                currentlyPlayingKeys[key] = time + durationInSeconds
                if time + durationInSeconds > maxDuration {
                    durationInSeconds = maxDuration - time
                }

                events.append(Note(time: time, duration: durationInSeconds, key: UInt8(key), velocity: velocity))
                if playType != PlayType.harmonicChord {
                    // In 80% the cases increment the time by some amount
                    if Double.random(in: 0..<1.0) < 0.8 {
                        let waitTime = selectElement(from: [ 1.0/32.0, 1.0/16.0, 1.0/8.0, 1.0/4.0, 1.0/2.0, 1.0, 2.0 ],
                                                      basedOn: [ 0.15, 0.2, 0.2, 0.3, 0.075, 0.05, 0.025 ])!
                        time += waitTime
                    }
                }

                // Clean up the currently playing keys
                let keysToRemove = currentlyPlayingKeys.filter { $0.value < time }.map { $0.key }
                keysToRemove.forEach { currentlyPlayingKeys.removeValue(forKey: $0) }
            }
            time = goToNextBar(currentTime: time, timeSignature: timeSignature, tempo: tempo)
            // Clean up the currently playing keys
            let keysToRemove = currentlyPlayingKeys.filter { $0.value < time }.map { $0.key }
            keysToRemove.forEach { currentlyPlayingKeys.removeValue(forKey: $0) }
        }

        return events
    }
}
