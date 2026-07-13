#!/usr/bin/env python3
import sys
import re
import os
import asyncio
import subprocess
import datetime
import tempfile
import edge_tts

VOICES = {
    "zh": "zh-CN-XiaoxiaoNeural",
    "ja": "ja-JP-NanamiNeural",
    "en": "en-US-JennyNeural",
}


def detect_lang(text):
    cjk = 0
    jp = 0
    latin = 0
    for c in text:
        cp = ord(c)
        if 0x4E00 <= cp <= 0x9FFF or 0x3400 <= cp <= 0x4DBF or 0xF900 <= cp <= 0xFAFF:
            cjk += 1
        elif 0x3040 <= cp <= 0x309F or 0x30A0 <= cp <= 0x30FF:
            jp += 1
        elif c.isascii() and c.isalpha():
            latin += 1
    if cjk >= jp and cjk >= latin and cjk > 0:
        return "zh"
    elif jp > cjk and jp > latin:
        return "ja"
    else:
        return "en"


def split_sentences(text):
    parts = re.split(r"(?<=[.!?。！？\u203C\u2047\u2048\u2049\n])\s*", text)
    return [p.strip() for p in parts if p.strip()]


def group_by_language(sentences):
    groups = []
    cur_lang = None
    cur_texts = []
    for sent in sentences:
        lang = detect_lang(sent)
        if cur_lang != lang and cur_texts:
            groups.append((cur_lang, " ".join(cur_texts)))
            cur_texts = []
        cur_lang = lang
        cur_texts.append(sent)
    if cur_texts:
        groups.append((cur_lang, " ".join(cur_texts)))
    return groups


def split_into_paragraphs(text, max_chars=3000):
    if len(text) <= max_chars:
        return [text]
    paragraphs = []
    current = ""
    for line in text.split("\n"):
        if len(current) + len(line) > max_chars and current:
            paragraphs.append(current.strip())
            current = line + "\n"
        else:
            current += line + "\n"
    if current.strip():
        paragraphs.append(current.strip())
    return paragraphs


async def synthesize_text(text, voice, output_mp3):
    comm = edge_tts.Communicate(text=text, voice=voice)
    await comm.save(output_mp3)


def concat_mp3s(mp3_files, output):
    concat_list = os.path.join(os.path.dirname(output), ".concat_list.txt")
    with open(concat_list, "w") as f:
        for mf in mp3_files:
            f.write(f"file '{mf}'\n")
    subprocess.run(
        ["ffmpeg", "-f", "concat", "-safe", "0", "-i", concat_list,
         "-c", "copy", output, "-y"],
        capture_output=True
    )
    os.remove(concat_list)


def synthesize_all(text, output_wav):
    output_dir = os.path.dirname(output_wav)
    paragraphs = split_into_paragraphs(text)

    all_mp3s = []
    tmpdir = tempfile.mkdtemp(prefix="tts_")

    try:
        for pi, para in enumerate(paragraphs):
            sentences = split_sentences(para)
            groups = group_by_language(sentences)

            para_mp3s = []
            for gi, (lang, group_text) in enumerate(groups):
                voice = VOICES.get(lang, VOICES["en"])
                mp3_path = os.path.join(tmpdir, f"p{pi}_g{gi}.mp3")
                asyncio.run(synthesize_text(group_text, voice, mp3_path))
                para_mp3s.append(mp3_path)

            if len(para_mp3s) == 1:
                all_mp3s.append(para_mp3s[0])
            else:
                combined = os.path.join(tmpdir, f"p{pi}_combined.mp3")
                concat_mp3s(para_mp3s, combined)
                for mf in para_mp3s:
                    os.remove(mf)
                all_mp3s.append(combined)

        if len(all_mp3s) == 1:
            subprocess.run(
                ["ffmpeg", "-i", all_mp3s[0], "-ar", "24000", "-ac", "1",
                 output_wav, "-y"],
                capture_output=True
            )
        else:
            final_mp3 = os.path.join(tmpdir, "final.mp3")
            concat_mp3s(all_mp3s, final_mp3)
            subprocess.run(
                ["ffmpeg", "-i", final_mp3, "-ar", "24000", "-ac", "1",
                 output_wav, "-y"],
                capture_output=True
            )
    finally:
        for f in os.listdir(tmpdir):
            os.remove(os.path.join(tmpdir, f))
        os.rmdir(tmpdir)


def main():
    text = sys.stdin.read()
    if not text.strip():
        sys.exit(0)

    output_dir = os.path.expanduser("~/Music/tts")
    os.makedirs(output_dir, exist_ok=True)
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    wav_path = os.path.join(output_dir, f"{timestamp}.wav")

    synthesize_all(text, wav_path)

    print(wav_path)
    subprocess.run(["aplay", wav_path])


if __name__ == "__main__":
    main()
