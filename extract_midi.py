import mido
import csv
import argparse
from pathlib import Path

def adjust_note_to_range(note: int):
    # Ensure the note is in a range we understand
    adjusted_note = note
    while adjusted_note < 21:
        adjusted_note += 12
    while adjusted_note > 108:
        adjusted_note -= 12
    return adjusted_note

def convert_midi_file(input_midi: Path, output_file: Path):
    midi_file = mido.MidiFile(input_midi)
    ticks_per_beat = midi_file.ticks_per_beat
    tempo = None

    # Iterate over all messages in the MIDI file
    name = None
    notes = []
    active_notes = {}
    current_time = 0
    for i, track in enumerate(midi_file.tracks):
        for msg in track:
            # print(msg)
            # print(current_time)
            
            if isinstance(msg, mido.MetaMessage):
                if msg.type == "set_tempo":
                    tempo = msg.tempo
                elif msg.type == 'instrument_name':
                    name = msg.name
                # else:
                #     print(f"Skipping message: {msg}")
                continue
            
            current_time += msg.time
            if msg.type == 'note_on':
                if msg.velocity == 0:
                    continue
                adjusted_note = adjust_note_to_range(msg.note)
                if adjusted_note in active_notes:
                    # raise f"The note {msg.note} is already active!"
                    continue
                start_time = mido.tick2second(current_time, ticks_per_beat, tempo)
                active_notes[adjusted_note] = { 'velocity': msg.velocity, 'start_time': start_time }
            if msg.type == 'note_off':
                adjusted_note = adjust_note_to_range(msg.note)
                if adjusted_note not in active_notes:
                    # raise f"The note {adjusted_note} is not active!"
                    continue
                attack = active_notes.pop(adjusted_note)
                start_time = attack['start_time']
                end_time = mido.tick2second(current_time, ticks_per_beat, tempo)
                duration = end_time - attack['start_time']
                note = adjusted_note
                velocity = float(attack['velocity']) / 128.0
                notes.append([ start_time, duration, note, velocity ])

    notes.sort(key=lambda x: (x[0], x[2], x[1]))

    if len(notes) > 0:
        print(f"Writing file {output_file}")
        with open(output_file, "w") as file:
            writer = csv.writer(file)
            for event in notes:
                # print(event)
                writer.writerow(event)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Extracts midi events from a midi file and convert them into a csv description')
    parser.add_argument('dir', help='The input directory containing midi files')
    args = parser.parse_args()

    dir = Path(args.dir)

    for file in dir.glob("*.mid"):
        print(f"Extracting events from {file}")
        output_name = f"{file.stem}.csv"
        convert_midi_file(file, dir / output_name)
