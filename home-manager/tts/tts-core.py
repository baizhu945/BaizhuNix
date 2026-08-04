#!/usr/bin/env python3
"""CosyVoice3 本地 TTS 一次性合成: 加载模型 → 合成 → 保存/播放 → 立即退出释放显存

用法:
  tts-core [文本...]           # 传入文本或从 stdin 读取, 合成并播放
  tts-core -i happy 文本       # 情感指令
  tts-core -l ja 文本          # 指定语言
  tts-core -s 1.2 文本         # 语速 1.2x
  tts-core --no-play 文本      # 只生成文件不播放

常用情感指令 -i:
  happy/sad/angry/fast/slow/loud/soft/peppa/robot
  或任意中文指令, 如 "请用四川话表达" "请用温柔的语气说一句话"
"""
import argparse
import datetime
import os
import subprocess
import sys
import time
import wave

import numpy as np

EMOTION_KEYS = {
    "happy": "请非常开心地说一句话。",
    "sad": "请非常伤心地说一句话。",
    "angry": "请非常生气地说一句话。",
    "fast": "请用尽可能快地语速说一句话。",
    "slow": "请用尽可能慢地语速说一句话。",
    "loud": "Please say a sentence as loudly as possible.",
    "soft": "Please say a sentence in a very soft voice.",
    "peppa": "我想体验一下小猪佩奇风格，可以吗？",
    "robot": "你可以尝试用机器人的方式解答吗？",
}

LANG_NAMES = {
    "zh": "中文",
    "en": "英文",
    "ja": "日语",
    "ko": "韩语",
    "de": "德语",
    "es": "西班牙语",
    "fr": "法语",
    "it": "意大利语",
    "ru": "俄语",
}

# CosyVoice3 要求文本中含 <|endofprompt|> (无 instruct 时使用 cross_lingual 模式)
PROMPT_PREFIX = "You are a helpful assistant.<|endofprompt|>"

OUTPUT_DIR = os.path.expanduser(os.environ.get("TTS_OUTPUT_DIR", "~/Music/tts"))


def build_instruct(instruct: str, lang: str) -> str:
    """拼装 CosyVoice3 的 instruct prompt: 'You are a helpful assistant. <指令><|endofprompt|>'"""
    parts = []
    if instruct and instruct.strip():
        parts.append(instruct.strip())
    if lang and lang in LANG_NAMES:
        parts.append(f"请用{LANG_NAMES[lang]}表达。")
    if not parts:
        return ""
    s = "，".join(parts)
    if not s.endswith("。"):
        s += "。"
    if "<|endofprompt|>" not in s:
        s += "<|endofprompt|>"
    if not s.startswith("You are a helpful assistant."):
        s = "You are a helpful assistant. " + s
    return s


def write_wav(path: str, audio: np.ndarray, sample_rate: int) -> None:
    pcm = np.clip(audio * 32767, -32768, 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        w.writeframes(pcm.tobytes())


def main():
    parser = argparse.ArgumentParser(description="CosyVoice3 local TTS (one-shot)")
    parser.add_argument("-i", "--instruct", default="",
                        help="情感/方言/语速指令 (happy/sad/angry/fast/slow/loud/soft/peppa/robot 或任意中文指令)")
    parser.add_argument("-l", "--lang", default="",
                        help="语言: zh/en/ja/ko/de/es/fr/it/ru")
    parser.add_argument("-s", "--speed", type=float, default=1.0,
                        help="语速倍率 (0.5-2.0)")
    parser.add_argument("--no-play", action="store_true",
                        help="只生成 wav 不播放")
    parser.add_argument("text", nargs="*", help="要合成的文本 (缺省读 stdin)")
    args = parser.parse_args()

    text = " ".join(args.text) if args.text else sys.stdin.read()
    if not text.strip():
        sys.exit(0)

    instruct = EMOTION_KEYS.get(args.instruct, args.instruct)
    instruct_text = build_instruct(instruct, args.lang)
    if not (0.5 <= args.speed <= 2.0):
        print("error: speed must be in [0.5, 2.0]", file=sys.stderr)
        sys.exit(1)

    model_dir = os.environ.get("COSYVOICE_MODEL_DIR")
    prompt_wav = os.environ.get("COSYVOICE_PROMPT_WAV")
    if not model_dir or not os.path.isdir(model_dir):
        print(f"error: COSYVOICE_MODEL_DIR not set or invalid: {model_dir}", file=sys.stderr)
        sys.exit(1)
    if not prompt_wav or not os.path.isfile(prompt_wav):
        print(f"error: COSYVOICE_PROMPT_WAV not set or invalid: {prompt_wav}", file=sys.stderr)
        sys.exit(1)

    # 延迟导入 (尽量缩短启动时间)
    t0 = time.time()
    print(f"加载模型...", file=sys.stderr, flush=True)
    from cosyvoice.cli.cosyvoice import AutoModel  # noqa: E402

    model = AutoModel(model_dir=model_dir, fp16=True)
    print(f"模型加载完成 ({time.time()-t0:.1f}s), 合成中...", file=sys.stderr, flush=True)

    try:
        if instruct_text:
            gen = model.inference_instruct2(text, instruct_text, prompt_wav,
                                            stream=False, speed=args.speed)
        else:
            # cross_lingual 模式: 文本需自带 <|endofprompt|>
            tts_text = text if "<|endofprompt|>" in text else PROMPT_PREFIX + text
            gen = model.inference_cross_lingual(tts_text, prompt_wav,
                                                stream=False, speed=args.speed)
        chunks = [o["tts_speech"].cpu().numpy() for o in gen]
    except Exception as e:  # noqa: BLE001
        print(f"error: 合成失败: {e}", file=sys.stderr)
        sys.exit(1)

    if not chunks:
        print("error: 未生成音频", file=sys.stderr)
        sys.exit(1)
    audio = np.concatenate(chunks)

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    wav_path = os.path.join(OUTPUT_DIR, f"{ts}.wav")
    write_wav(wav_path, audio, model.sample_rate)

    print(wav_path)
    if not args.no_play:
        subprocess.run(["aplay", "-q", wav_path])


if __name__ == "__main__":
    main()
