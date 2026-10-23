#!/usr/bin/env python3
"""CosyVoice3 native mixed-text inference; one CUDA model and one reference speaker per request."""
import argparse
import hashlib
import os
import queue
import re
import sys
import tempfile
import threading
import time
import wave

END = object()


def sentence_chunks(text):
    """Losslessly split at sentence endings; leave long punctuated sentences intact."""
    start = 0
    for i, ch in enumerate(text):
        if ch in "。！？!?；;\n":
            yield text[start:i + 1]
            start = i + 1
    if start < len(text):
        yield text[start:]


def _bounded(text, limit):
    start = 0
    breaks = "，,、；;:： \t"
    while start < len(text):
        remaining = len(text) - start
        if remaining <= limit:
            yield text[start:]
            return
        window = text[start:start + limit]
        cut = max((window.rfind(ch) + 1 for ch in breaks if ch in window), default=0)
        if cut < limit // 2:
            cut = limit
        yield text[start:start + cut]
        start += cut


def normalize_japanese(text, language="auto"):
    """Convert Japanese kana-context Han/kana runs to katakana, preserving other scripts.

    Han-only runs stay unchanged under auto/chinese because Chinese and Japanese share
    Han; --lang japanese explicitly resolves otherwise ambiguous Han as Japanese.
    This is text normalization only: the complete mixed text still goes to one TTS call.
    """
    import pyopenjtalk

    def is_cjk(ch):
        return ("\u3040" <= ch <= "\u30ff") or ("\u3400" <= ch <= "\u9fff") or ch in "ーゝゞヽヾ、"

    out = []
    i = 0
    while i < len(text):
        if not is_cjk(text[i]):
            out.append(text[i])
            i += 1
            continue
        j = i + 1
        while j < len(text) and is_cjk(text[j]):
            j += 1
        run = text[i:j]
        has_kana = any(("\u3040" <= ch <= "\u30ff") for ch in run)
        out.append(pyopenjtalk.g2p(run, kana=True) if language == "japanese" or has_kana else run)
        i = j
    return "".join(out)


def inference_chunks(text, language, debug=False, min_chars=90, max_chars=180):
    """Group natural sentences; hard-bound only an unpunctuated long input."""
    def emit(value):
        if debug: print(f"model_text={value}", file=sys.stderr, flush=True)
        return value
    if not any(ch in "。！？!?；;\n" for ch in text) and len(text) > max_chars:
        normalized = normalize_japanese(text, language)
        for chunk in _bounded(normalized, max_chars):
            yield emit(chunk)
        return
    pending = ""
    for sentence in sentence_chunks(text):
        normalized = normalize_japanese(sentence, language)
        if len(normalized) > max_chars:
            if pending:
                yield emit(pending)
                pending = ""
            yield emit(normalized)
            continue
        if pending and len(pending) + len(normalized) > max_chars:
            yield emit(pending)
            pending = ""
        pending += normalized
        if len(pending) >= min_chars:
            yield emit(pending)
            pending = ""
    if pending:
        yield emit(pending)


def main():
    process_start = time.monotonic()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lang", choices=["auto", "chinese", "english", "japanese"], default="auto",
                        help="Japanese kana-context normalization; Han-only defaults to Chinese")
    parser.add_argument("--reference-wav", help="override the pinned synthetic voice reference")
    parser.add_argument("--no-play", action="store_true")
    parser.add_argument("--play", action="store_true", help="play audio while also writing --output")
    parser.add_argument("--output", help="write to a WAV file, atomically replace on success")
    parser.add_argument("--debug-normalized", action="store_true", help="print transformed text chunks")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("text", nargs="*", help="text to synthesize; defaults to UTF-8 stdin")
    args = parser.parse_args()
    if args.list:
        print("languages: auto, chinese, english, japanese")
        print("speaker: cosyvoice-reference (single fixed prompt for every chunk/language)")
        return

    text = " ".join(args.text) if args.text else sys.stdin.read()
    if not text.strip():
        return
    play_audio = not args.no_play and (not args.output or args.play)
    model_dir = os.environ["COSYVOICE_MODEL_DIR"]
    if not os.path.isfile(os.path.join(model_dir, "cosyvoice3.yaml")):
        raise SystemExit(f"FATAL: pinned local CosyVoice3 model missing: {model_dir}")
    reference = args.reference_wav or os.environ.get("COSYVOICE_REFERENCE_WAV")
    if not reference or not os.path.isfile(reference):
        raise SystemExit("FATAL: a local speaker-reference WAV is required")

    import torch
    if not torch.cuda.is_available():
        raise SystemExit("FATAL: CUDA unavailable; CosyVoice3 refuses CPU fallback")
    capability = torch.cuda.get_device_capability()
    if capability != (12, 0):
        raise SystemExit(f"FATAL: expected RTX 5060 sm_120, got {capability}")
    print(f"torch={torch.__version__} cuda={torch.version.cuda} device={torch.cuda.get_device_name()} capability={capability}",
          file=sys.stderr, flush=True)

    from cosyvoice.cli.cosyvoice import CosyVoice3
    model_started = time.monotonic()
    cosy = CosyVoice3(model_dir=model_dir, load_trt=False, load_vllm=False, fp16=True)
    if cosy.model.device.type != "cuda":
        raise SystemExit(f"FATAL: CosyVoice3 loaded on {cosy.model.device}, expected CUDA")
    module_devices = {}
    for name in ("llm", "flow", "hift"):
        module = getattr(cosy.model, name)
        try:
            module_devices[name] = str(next(module.parameters()).device)
        except StopIteration:
            raise SystemExit(f"FATAL: CosyVoice3 {name} has no parameters")
        if not module_devices[name].startswith("cuda"):
            raise SystemExit(f"FATAL: CosyVoice3 {name} is not on CUDA: {module_devices[name]}")
    model_ready = time.monotonic()
    torch.cuda.reset_peak_memory_stats()
    reference_hash = hashlib.sha256(open(reference, "rb").read()).hexdigest()
    print(f"speaker_reference_sha256={reference_hash}", file=sys.stderr, flush=True)

    # Cache one voice condition, then reuse it for bounded natural-sentence groups.
    # Each input group can itself contain Chinese/English/Japanese; no language routing.
    reference_id = "cosyvoice-fixed-reference"
    target_prefix = "You are a helpful assistant.<|endofprompt|>"
    started = time.monotonic()
    reference_started = time.monotonic()
    # Cache only the acoustic speaker condition. Cross-lingual inference removes
    # prompt text/speech tokens from the LLM context, avoiding reference-text echo.
    cosy.add_zero_shot_spk("", reference, reference_id)
    reference_prepare = time.monotonic() - reference_started
    audio_queue = queue.Queue(maxsize=3)
    cancelled = threading.Event()
    errors = []
    first_audio = [None]
    sample_count = [0]
    audio_chunk_count = [0]
    model_call_count = [0]
    text_chunk_count = [0]
    end = object()

    def enqueue(item):
        while not cancelled.is_set():
            try:
                audio_queue.put(item, timeout=0.1)
                return True
            except queue.Full:
                continue
        return False

    def producer():
        try:
            for text_chunk in inference_chunks(text, args.lang, args.debug_normalized):
                if cancelled.is_set():
                    break
                text_chunk_count[0] += 1
                result = None
                try:
                    result = cosy.inference_cross_lingual(
                        tts_text=target_prefix + text_chunk,
                        prompt_wav=reference,
                        zero_shot_spk_id=reference_id,
                        stream=True,
                        speed=1.0,
                        text_frontend=False,
                    )
                    model_call_count[0] += 1
                    for packet in result:
                        if cancelled.is_set():
                            break
                        wave = packet["tts_speech"]
                        audio = wave.detach().float().cpu().numpy() if hasattr(wave, "detach") else wave
                        audio = audio.reshape(-1)
                        if not bool(torch.isfinite(torch.from_numpy(audio)).all()):
                            raise RuntimeError("CosyVoice emitted non-finite audio")
                        sample_count[0] += len(audio)
                        audio_chunk_count[0] += 1
                        if first_audio[0] is None:
                            first_audio[0] = time.monotonic() - process_start
                            print(f"first_audio_s={first_audio[0]:.3f}", file=sys.stderr, flush=True)
                        if not enqueue(audio):
                            break
                finally:
                    if result is not None and hasattr(result, "close"):
                        result.close()
            if not cancelled.is_set():
                print(f"generation_complete=true model_calls={model_call_count[0]}", file=sys.stderr, flush=True)
        except BaseException as exc:
            errors.append(exc)
        finally:
            enqueue(end)

    output_wave = None
    output_tmp = None
    if args.output:
        fd, output_tmp = tempfile.mkstemp(prefix=".cosyvoice-", suffix=".wav",
                                          dir=os.path.dirname(os.path.abspath(args.output)))
        os.close(fd)
        output_wave = wave.open(output_tmp, "wb")
        output_wave.setnchannels(1)
        output_wave.setsampwidth(2)
        output_wave.setframerate(cosy.sample_rate)

    worker = threading.Thread(target=producer, daemon=True)
    worker.start()
    first_consumed = False
    try:
        if play_audio:
            import sounddevice as sd
            stream = sd.OutputStream(samplerate=cosy.sample_rate, channels=1, dtype="float32")
            stream.start()
        while True:
            chunk = audio_queue.get()
            if chunk is end:
                break
            if not first_consumed:
                first_consumed = True
                print("first_chunk_consumed=true", file=sys.stderr, flush=True)
            if output_wave:
                pcm = (chunk * 32767).clip(-32768, 32767).astype("int16")
                output_wave.writeframesraw(pcm.tobytes())
            if play_audio:
                stream.write(chunk.reshape(-1, 1))
        worker.join()
        if "stream" in locals():
            stream.stop()
            stream.close()
        if errors:
            raise errors[0]
        if output_wave:
            output_wave.close()
            output_wave = None
            os.replace(output_tmp, args.output)
            output_tmp = None
            print(f"output_wav={args.output}", file=sys.stderr, flush=True)
    except BaseException:
        cancelled.set()
        if "stream" in locals():
            stream.abort()
            stream.close()
        if output_wave:
            output_wave.close()
            output_wave = None
        if output_tmp and os.path.exists(output_tmp):
            os.unlink(output_tmp)
        worker.join(timeout=2)
        raise

    duration = sample_count[0] / cosy.sample_rate
    elapsed = time.monotonic() - started
    peak = torch.cuda.max_memory_allocated() / (1024 ** 2)
    print(f"cold_model_load_s={model_ready-process_start:.3f} model_init_s={model_ready-model_started:.3f} "
          f"reference_prepare_s={reference_prepare:.3f} synthesis_consume_s={elapsed:.3f} audio_seconds={duration:.3f} "
          f"rtf={elapsed/duration if duration else 0:.4f} audio_chunks={audio_chunk_count[0]} "
          f"model_calls={model_call_count[0]} text_chunks={text_chunk_count[0]} peak_vram_mib={peak:.1f}", file=sys.stderr, flush=True)

if __name__ == "__main__":
    main()
