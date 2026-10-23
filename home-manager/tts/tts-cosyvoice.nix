{ config, pkgs, lib, ... }:

let
  py = pkgs.python313;
  wheels = import ./wheels.nix { inherit pkgs py; };
  inherit (wheels) mkWheel torch torchaudio triton hubWheel safetensorsWheel;

  # Pin both upstream source trees; Matcha-TTS is a git submodule in CosyVoice.
  cosyvoiceSource = pkgs.fetchFromGitHub {
    owner = "FunAudioLLM";
    repo = "CosyVoice";
    rev = "074ca6dc9e80a2f424f1f74b48bdd7d3fea531cc";
    sha256 = "075s4vslhl4dm6szxcq0a9iykjd369f46v3cixz1lzx31jdq541n";
  };
  matchaSource = pkgs.fetchFromGitHub {
    owner = "shivammehta25";
    repo = "Matcha-TTS";
    rev = "dd9105b34bf2be2230f4aa1e4769fb586a3c824e";
    sha256 = "0visb1xwsmfz16sm587b36hdg5hvyd825h6khy7xygbdawam3rcs";
  };
  cosyvoiceRuntime = pkgs.runCommand "cosyvoice-source-offline" { nativeBuildInputs = [ py ]; } ''
    mkdir -p $out
    cp -r ${cosyvoiceSource}/. $out/
    chmod -R u+w $out
    COSYVOICE_OUT=$out ${py}/bin/python - <<'PY'
from pathlib import Path
import os, re
root = Path(os.environ["COSYVOICE_OUT"])
cli = root / "cosyvoice/cli/cosyvoice.py"
s = cli.read_text()
old = "from modelscope import snapshot_download"
new = """def snapshot_download(model_id):
    raise RuntimeError('CosyVoice is offline-only; expected pinned local model files')"""
if s.count(old) != 1:
    raise SystemExit(f"expected one ModelScope downloader import, found {s.count(old)}")
cli.write_text(s.replace(old, new))
frontend = root / "cosyvoice/cli/frontend.py"
s = frontend.read_text()
start = s.find('providers=["CUDAExecutionProvider" if torch.cuda.is_available() else')
end = s.find('"CPUExecutionProvider"])', start)
if start < 0 or end < 0:
    raise SystemExit('expected one speech-tokenizer ONNX provider selector')
end += len('"CPUExecutionProvider"])')
s = s[:start] + 'providers=["CPUExecutionProvider"])' + s[end:]
frontend.write_text(s)
dataset = root / "cosyvoice/dataset/processor.py"
s = dataset.read_text()
for optional_training_import in ("import pyarrow.parquet as pq\n", "import pyworld as pw\n"):
    if s.count(optional_training_import) != 1:
        raise SystemExit(f"expected one optional dataset import: {optional_training_import!r}")
    s = s.replace(optional_training_import, "")
dataset.write_text(s)
file_utils = root / "cosyvoice/utils/file_utils.py"
s = file_utils.read_text()
s = s.replace("import torchaudio\n", "import torchaudio\nimport soundfile\n")
old = "speech, sample_rate = torchaudio.load(wav, backend='soundfile')"
new = "audio, sample_rate = soundfile.read(wav, dtype='float32', always_2d=True)\n    speech = torch.from_numpy(audio.T.copy())"
if s.count(old) != 1:
    raise SystemExit(f"expected one torchaudio.load call, found {s.count(old)}")
file_utils.write_text(s.replace(old, new))
PY
  '';

  matchaRuntime = pkgs.runCommand "matcha-inference-source" { nativeBuildInputs = [ py ]; } ''
    mkdir -p $out
    cp -r ${matchaSource}/. $out/
    chmod -R u+w $out
    cat > $out/matcha/utils/__init__.py <<'PY'
from matcha.utils.pylogger import get_pylogger
PY
    cat > $out/matcha/utils/pylogger.py <<'PY'
import logging

def get_pylogger(name=__name__):
    return logging.getLogger(name)
PY
  '';

  # Official Fun-CosyVoice3-0.5B-2512 snapshot, pinned to one immutable HF revision.
  modelRevision = "29e01c4e8d000f4bcd70751be16fa94bf3d85a18";
  modelBase = "https://huggingface.co/FunAudioLLM/Fun-CosyVoice3-0.5B-2512/resolve/${modelRevision}";
  fetchModel = { name, file, sha256 }: pkgs.fetchurl {
    inherit name sha256;
    url = "${modelBase}/${file}";
  };
  modelFiles = {
    yaml = fetchModel { name = "cosyvoice3.yaml"; file = "cosyvoice3.yaml"; sha256 = "f5a6b2c6f05139d0f18861a1fe506f751e787026b77c05f7e8fef9f8a4405965"; };
    llm = fetchModel { name = "cosyvoice3-llm.pt"; file = "llm.pt"; sha256 = "69f43bd545131c30e98947fb360ea8b4dc9916d8e83dded7757c7ea4f5a24970"; };
    flow = fetchModel { name = "cosyvoice3-flow.pt"; file = "flow.pt"; sha256 = "a6fab32a7825e5b0bc855ddd948f8db9370b0a786fbc249caa4595e95b608e4b"; };
    hift = fetchModel { name = "cosyvoice3-hift.pt"; file = "hift.pt"; sha256 = "b279d7641eb97ae55b3b540cfba4f953c26492a2df758328a89a4d007ab87a65"; };
    campplus = fetchModel { name = "cosyvoice3-campplus.onnx"; file = "campplus.onnx"; sha256 = "a6ac6a63997761ae2997373e2ee1c47040854b4b759ea41ec48e4e42df0f4d73"; };
    speechTokenizer = fetchModel { name = "cosyvoice3-speech-tokenizer.onnx"; file = "speech_tokenizer_v3.onnx"; sha256 = "23236a74175dbdda47afc66dbadd5bcb41303c467a57c261cb8539ad9db9208d"; };
    blankConfig = fetchModel { name = "cosyvoice-blanken-config.json"; file = "CosyVoice-BlankEN/config.json"; sha256 = "168aa1bd401abc3bc262ba15ba4e499627a8b4e006e9d050b47c22de20660185"; };
    blankGeneration = fetchModel { name = "cosyvoice-blanken-generation-config.json"; file = "CosyVoice-BlankEN/generation_config.json"; sha256 = "e558847a8b4402616f1273797b015104dc266fe4b520056fca88823ba8f8ebe6"; };
    blankMerges = fetchModel { name = "cosyvoice-blanken-merges.txt"; file = "CosyVoice-BlankEN/merges.txt"; sha256 = "ac8ff86a72bee70828fbc1119bc4398c6f3a9a6e490d7b0dbe917be025478bd0"; };
    blankModel = fetchModel { name = "cosyvoice-blanken-model.safetensors"; file = "CosyVoice-BlankEN/model.safetensors"; sha256 = "130282af0dfa9fe5840737cc49a0d339d06075f83c5a315c3372c9a0740d0b96"; };
    blankTokenizer = fetchModel { name = "cosyvoice-blanken-tokenizer-config.json"; file = "CosyVoice-BlankEN/tokenizer_config.json"; sha256 = "482bd979881423375ca5414e4e0d94cd7c5349dbb17fffd46b4d36d71e62a1bc"; };
    blankVocab = fetchModel { name = "cosyvoice-blanken-vocab.json"; file = "CosyVoice-BlankEN/vocab.json"; sha256 = "ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910"; };
  };
  modelDir = pkgs.runCommand "fun-cosyvoice3-0.5b-2512" { } ''
    mkdir -p $out/CosyVoice-BlankEN
    ln -s ${modelFiles.yaml} $out/cosyvoice3.yaml
    ln -s ${modelFiles.llm} $out/llm.pt
    ln -s ${modelFiles.flow} $out/flow.pt
    ln -s ${modelFiles.hift} $out/hift.pt
    ln -s ${modelFiles.campplus} $out/campplus.onnx
    ln -s ${modelFiles.speechTokenizer} $out/speech_tokenizer_v3.onnx
    ln -s ${modelFiles.blankConfig} $out/CosyVoice-BlankEN/config.json
    ln -s ${modelFiles.blankGeneration} $out/CosyVoice-BlankEN/generation_config.json
    ln -s ${modelFiles.blankMerges} $out/CosyVoice-BlankEN/merges.txt
    ln -s ${modelFiles.blankModel} $out/CosyVoice-BlankEN/model.safetensors
    ln -s ${modelFiles.blankTokenizer} $out/CosyVoice-BlankEN/tokenizer_config.json
    ln -s ${modelFiles.blankVocab} $out/CosyVoice-BlankEN/vocab.json
  '';

  # Match the official CosyVoice transformers API while keeping the existing CUDA 13 wheel stack.
  tokenizersWheel = mkWheel {
    pname = "tokenizers"; version = "0.21.2";
    name = "tokenizers-0.21.2-cp39-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
    url = "https://files.pythonhosted.org/packages/c5/74/f41a432a0733f61f3d21b288de6dfa78f7acff309c6f0f323b2833e9189f/tokenizers-0.21.2-cp39-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
    sha256 = "fed9a4d51c395103ad24f8e7eb976811c57fbec2af9f133df471afcd922e5020";
    dependencies = [ hubWheel ];
  };
  transformersWheel = mkWheel {
    pname = "transformers"; version = "4.51.3";
    name = "transformers-4.51.3-py3-none-any.whl";
    url = "https://files.pythonhosted.org/packages/a9/b6/5257d04ae327b44db31f15cce39e6020cc986333c715660b1315a9724d82/transformers-4.51.3-py3-none-any.whl";
    sha256 = "fd3279633ceb2b777013234bbf0b4f5c2d23c4626b05497691f00cfda55e8a83";
    dependencies = with py.pkgs; [ filelock hubWheel jinja2 numpy packaging pyyaml regex requests tokenizersWheel safetensorsWheel tqdm ];
  };
  diffusersWheel = mkWheel {
    pname = "diffusers"; version = "0.38.0";
    name = "diffusers-0.38.0-py3-none-any.whl";
    url = "https://files.pythonhosted.org/packages/42/c0/3237566ea6e3a542f3c0669a253d62fe75f27b84b3d7bd4fb3b5ee89d73c/diffusers-0.38.0-py3-none-any.whl";
    sha256 = "18e53f9e539096320470f62c6360a6fd5727ff28cffda566265316e13fcdb612";
    dependencies = with py.pkgs; [ importlib-metadata filelock httpx hubWheel numpy pillow regex requests safetensorsWheel ];
  };
  xTransformersWheel = mkWheel {
    pname = "x-transformers"; version = "2.11.24";
    name = "x_transformers-2.11.24-py3-none-any.whl";
    url = "https://files.pythonhosted.org/packages/4a/ec/55d258e0b63c9269a72d535d7972c2524e173e3eac9f1627a9fd741f34bf/x_transformers-2.11.24-py3-none-any.whl";
    sha256 = "319d644d1bd4c6f2ada3a87c1367cf54013088d92b921b03e12c6ba03e97b81f";
    dependencies = [ py.pkgs.einops py.pkgs.einx py.pkgs.loguru py.pkgs.packaging torch ];
  };
  whisper = py.pkgs.buildPythonPackage {
    pname = "openai-whisper"; version = "20250625"; format = "pyproject";
    nativeBuildInputs = with py.pkgs; [ setuptools wheel ];
    src = pkgs.fetchurl {
      name = "openai-whisper-20250625.tar.gz";
      url = "https://files.pythonhosted.org/packages/35/8e/d36f8880bcf18ec026a55807d02fe4c7357da9f25aebd92f85178000c0dc/openai_whisper-20250625.tar.gz";
      sha256 = "37a91a3921809d9f44748ffc73c0a55c9f366c85a3ef5c2ae0cc09540432eb96";
    };
    propagatedBuildInputs = [ py.pkgs.more-itertools py.pkgs.numba py.pkgs.numpy py.pkgs.tiktoken py.pkgs.tqdm torch triton ];
    doCheck = false;
    dontCheckRuntimeDeps = true;
  };
  onnxRuntime = py.pkgs.buildPythonPackage {
    pname = "onnxruntime"; version = "1.30.0"; format = "wheel";
    src = pkgs.fetchurl {
      name = "onnxruntime-1.30.0-cp313-cp313-manylinux_2_28_x86_64.whl";
      url = "https://files.pythonhosted.org/packages/f1/a1/ede48ab5dc54907a2999362777f541e132639fb06628ded1932058aa8a36/onnxruntime-1.30.0-cp313-cp313-manylinux_2_28_x86_64.whl";
      hash = "sha256-hvlAr8gB6paBpNqK+E++leHZ6n2AkDlSzBv61U+q048=";
    };
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    dependencies = with py.pkgs; [ flatbuffers numpy packaging protobuf ];
    doCheck = false;
    pythonImportsCheck = [ ];
    dontCheckRuntimeDeps = true;
  };
  jtalkArchive = pkgs.fetchurl {
    name = "open_jtalk_dic_utf_8-1.11.tar.gz";
    url = "https://github.com/r9y9/open_jtalk/releases/download/v1.11.1/open_jtalk_dic_utf_8-1.11.tar.gz";
    sha256 = "fe6ba0e43542cef98339abdffd903e062008ea170b04e7e2a35da805902f382a";
  };
  jtalkDictionary = pkgs.runCommand "open-jtalk-dictionary-1.11" { nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ]; } ''
    mkdir -p $out
    tar -xzf ${jtalkArchive} --strip-components=1 -C $out
  '';
  conformerWheel = mkWheel {
    pname = "conformer"; version = "0.3.2"; name = "conformer-0.3.2-py3-none-any.whl";
    url = "https://files.pythonhosted.org/packages/3f/7d/714601ab8d790d77d4158af743895fb999216cb02fc6283ab8e54911a887/conformer-0.3.2-py3-none-any.whl";
    sha256 = "b957faa683e9e75061257f77407318428f2ad0fb5262bfc2e9b55fc2fffdfa03";
    dependencies = [ py.pkgs.einops torch ];
  };
  pythonEnv = py.withPackages (ps: [
    torch torchaudio triton transformersWheel xTransformersWheel diffusersWheel whisper onnxRuntime conformerWheel
    ps.hyperpyyaml ps.inflect ps.librosa ps.matplotlib ps.numpy ps.omegaconf ps.pyopenjtalk ps.scipy ps.soundfile ps.tiktoken
    ps.numba ps.more-itertools ps.einops ps.einx ps.loguru ps.packaging ps.requests ps.pyyaml ps.regex
    ps.filelock ps.jinja2 ps.tqdm ps.fsspec ps.sounddevice
  ]);
  referenceWav = ./cosyvoice-reference.wav;
  outputDir = "${config.home.homeDirectory}/Music/tts";
  runtimeLibs = lib.concatStringsSep ":" [ "/run/opengl-driver/lib" "${pkgs.stdenv.cc.cc.lib}/lib" ];
  runner = pkgs.writeShellScriptBin "tts-cosyvoice-core" ''
    output_dir=${lib.escapeShellArg outputDir}
    has_output=0
    skip_default_output=0
    auto_play=1
    for arg in "$@"; do
      case "$arg" in
        --output|--output=*) has_output=1 ;;
        --help|-h|--list) skip_default_output=1 ;;
        --no-play) auto_play=0 ;;
      esac
    done
    if [ "$has_output" -eq 0 ] && [ "$skip_default_output" -eq 0 ]; then
      ${pkgs.coreutils}/bin/mkdir -p "$output_dir"
      timestamp=$(${pkgs.coreutils}/bin/date +'%Y%m%d-%H%M%S-%N')
      output_path="$output_dir/$timestamp.wav"
      suffix=1
      while [ -e "$output_path" ]; do
        output_path="$output_dir/$timestamp-$suffix.wav"
        suffix=$((suffix + 1))
      done
      set -- --output "$output_path" "$@"
      if [ "$auto_play" -eq 1 ]; then
        set -- --play "$@"
      fi
    fi
    export LD_LIBRARY_PATH=${runtimeLibs}:$(${pkgs.findutils}/bin/find -L ${pythonEnv}/lib/python3.13/site-packages/nvidia -type d -name lib -print 2>/dev/null | ${pkgs.coreutils}/bin/paste -sd: -)''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
    export HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1
    export COSYVOICE_ONNX_PROVIDER=CPUExecutionProvider
    export COSYVOICE_MODEL_DIR=${modelDir}
    export COSYVOICE_REFERENCE_WAV=${referenceWav}
    export OPEN_JTALK_DICT_DIR=${jtalkDictionary}
    export PYTHONPATH=${cosyvoiceRuntime}:${matchaRuntime}''${PYTHONPATH:+:$PYTHONPATH}
    exec ${pythonEnv}/bin/python ${./tts-cosyvoice-core.py} "$@"
  '';
  ttsCore = pkgs.writeShellScriptBin "tts-core" ''exec ${runner}/bin/tts-cosyvoice-core "$@"'';
  speak = pkgs.writeShellScriptBin "speak" ''exec ${runner}/bin/tts-cosyvoice-core "$@"'';
  speakFile = pkgs.writeShellScriptBin "speak-file" ''
    if [ "$#" -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
      echo "Usage: speak-file <file> [TTS options]"; exit 0
    fi
    input=$1; shift
    if [ ! -f "$input" ]; then echo "File not found: $input" >&2; exit 1; fi
    exec ${runner}/bin/tts-cosyvoice-core "$@" < "$input"
  '';
  speakClip = pkgs.writeShellScriptBin "speak-clip" ''
    if [ "$#" -gt 0 ] && { [ "$1" = "-h" ] || [ "$1" = "--help" ]; }; then
      echo "Usage: speak-clip [TTS options]"; exit 0
    fi
    if ! command -v wl-paste >/dev/null 2>&1; then echo "wl-paste not found" >&2; exit 1; fi
    text=$(wl-paste --no-newline 2>/dev/null) || exit 1
    [ -n "$text" ] || { echo "Clipboard empty" >&2; exit 1; }
    printf '%s' "$text" | ${runner}/bin/tts-cosyvoice-core "$@"
  '';
in {
  home.packages = [ runner ttsCore speak speakFile speakClip ];
}
