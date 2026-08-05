#!/usr/bin/env python3
"""Qwen3-TTS 本地 TTS 一次性合成 (替代 CosyVoice3): 加载模型 → 分句批量合成 → 保存/播放 → 退出释放显存

用法:
  tts-core [文本...]          # 传入文本或从 stdin 读取, 合成并播放
  tts-core -s ryan 文本       # 指定音色 (默认 vivian)
  tts-core -l japanese 文本   # 指定语言 (默认 auto: 自动识别, 支持中英混读)
  tts-core --no-play 文本     # 只生成文件不播放
  tts-core --list             # 列出可用音色/语言

音色 (9 个内置, 无需音色克隆):
  serena / vivian / uncle_fu / ryan / aiden / ono_anna(日语) / sohee(韩语) / eric(四川) / dylan(北京)
语言:
  auto / chinese / english / japanese / korean / german / french / russian / portuguese / spanish / italian
"""
import argparse
import datetime
import os
import re
import subprocess
import sys
import time
import wave

import numpy as np

SPEAKERS = ["serena", "vivian", "uncle_fu", "ryan", "aiden", "ono_anna", "sohee", "eric", "dylan"]
LANGUAGES = ["auto", "chinese", "english", "japanese", "korean", "german",
             "french", "russian", "portuguese", "spanish", "italian"]

OUTPUT_DIR = os.path.expanduser(os.environ.get("TTS_OUTPUT_DIR", "~/Music/tts"))
# 每 chunk 最大字符数; 批次大小 (显存不够可设 QWEN_TTS_BATCH=1)
MAX_CHARS = int(os.environ.get("QWEN_TTS_MAX_CHARS", "200"))
BATCH_SIZE = int(os.environ.get("QWEN_TTS_BATCH", "4"))
MAX_NEW_TOKENS = int(os.environ.get("QWEN_TTS_MAX_TOKENS", "4096"))


def split_chunks(text: str, max_chars: int = MAX_CHARS) -> list[str]:
    """按句末标点分句, 再合并为 <= max_chars 的 chunk (长文本流畅的关键)"""
    sentences = re.split(r"(?<=[。．！？!?；;…\n])", text)
    chunks: list[str] = []
    cur = ""
    for s in sentences:
        if not s.strip():
            continue
        if cur and len(cur) + len(s) > max_chars:
            chunks.append(cur)
            cur = s
        else:
            cur += s
        # 超长无标点句子硬切
        while len(cur) > max_chars:
            chunks.append(cur[:max_chars])
            cur = cur[max_chars:]
    if cur.strip():
        chunks.append(cur)
    return [c.strip() for c in chunks if c.strip()]


def write_wav(path: str, audio: np.ndarray, sample_rate: int) -> None:
    pcm = np.clip(audio * 32767, -32768, 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        w.writeframes(pcm.tobytes())


def main():
    parser = argparse.ArgumentParser(description="Qwen3-TTS local TTS (one-shot)")
    parser.add_argument("-s", "--speaker", default="vivian",
                        help="音色: " + "/".join(SPEAKERS))
    parser.add_argument("-l", "--lang", default="auto",
                        help="语言: " + "/".join(LANGUAGES) + " (auto 自动混读)")
    parser.add_argument("--no-play", action="store_true",
                        help="只生成 wav 不播放")
    parser.add_argument("--list", action="store_true",
                        help="列出音色和语言后退出")
    parser.add_argument("text", nargs="*", help="要合成的文本 (缺省读 stdin)")
    args = parser.parse_args()

    if args.list:
        print("音色:", ", ".join(SPEAKERS))
        print("语言:", ", ".join(LANGUAGES))
        sys.exit(0)

    speaker = args.speaker.lower()
    lang = args.lang.lower()
    if speaker not in SPEAKERS:
        print(f"error: 未知音色 '{args.speaker}', 可用: {', '.join(SPEAKERS)}", file=sys.stderr)
        sys.exit(1)
    if lang not in LANGUAGES:
        print(f"error: 未知语言 '{args.lang}', 可用: {', '.join(LANGUAGES)}", file=sys.stderr)
        sys.exit(1)

    text = " ".join(args.text) if args.text else sys.stdin.read()
    if not text.strip():
        sys.exit(0)

    model_dir = os.environ.get("QWEN_TTS_MODEL_DIR")
    if not model_dir or not os.path.isdir(model_dir):
        print(f"error: QWEN_TTS_MODEL_DIR not set or invalid: {model_dir}", file=sys.stderr)
        sys.exit(1)

    chunks = split_chunks(text)
    print(f"分句: {len(chunks)} 段", file=sys.stderr, flush=True)

    # 延迟导入 (尽量缩短启动时间)
    t0 = time.time()
    print("加载模型...", file=sys.stderr, flush=True)
    import torch  # noqa: E402
    from qwen_tts import Qwen3TTSModel  # noqa: E402

    # attn_implementation=sdpa: 避免 flash-attn (需编译); 0.6B 模型默认 sdpa 即可
    tts = Qwen3TTSModel.from_pretrained(
        model_dir,
        device_map="cuda:0",
        dtype=torch.bfloat16,
        local_files_only=True,
        attn_implementation="sdpa",
    )
    print(f"模型加载完成 ({time.time()-t0:.1f}s), 合成中...", file=sys.stderr, flush=True)

    try:
        all_wavs: list[np.ndarray] = []
        for i in range(0, len(chunks), BATCH_SIZE):
            group = chunks[i:i + BATCH_SIZE]
            t1 = time.time()
            wavs, sr = tts.generate_custom_voice(
                text=group,
                speaker=speaker,
                language=lang,
                non_streaming_mode=True,
                max_new_tokens=MAX_NEW_TOKENS,
            )
            all_wavs.extend(wavs)
            print(f"  第 {i // BATCH_SIZE + 1} 批 ({len(group)} 段) 完成 ({time.time()-t1:.1f}s)",
                  file=sys.stderr, flush=True)
    except Exception as e:  # noqa: BLE001
        print(f"error: 合成失败: {e}", file=sys.stderr)
        sys.exit(1)

    if not all_wavs:
        print("error: 未生成音频", file=sys.stderr)
        sys.exit(1)
    audio = np.concatenate([np.asarray(w, dtype=np.float32) for w in all_wavs])

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    wav_path = os.path.join(OUTPUT_DIR, f"{ts}.wav")
    write_wav(wav_path, audio, sr)

    print(wav_path)
    if not args.no_play:
        subprocess.run(["aplay", "-q", wav_path])


if __name__ == "__main__":
    main()
