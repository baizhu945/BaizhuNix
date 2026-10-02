{ config, pkgs, lib, ... }:

let
  # Reuse the official CUDA 13 wheels already used by Qwen TTS. Keeping this
  # application on Python 3.13 also pins the ABI of those precompiled wheels.
  py = pkgs.python313;
  wheels = import ./tts/wheels.nix { inherit pkgs py; };
  inherit (wheels) torch tokenizersWheel safetensorsWheel hubWheel;

  torchvision = wheels.mkWheel {
    pname = "torchvision";
    version = "0.27.0"; # Matches torch 2.12.0 from wheels.nix.
    name = "torchvision-0.27.0+cu130-cp313-cp313-manylinux_2_28_x86_64.whl";
    url = "https://download.pytorch.org/whl/cu130/torchvision-0.27.0%2Bcu130-cp313-cp313-manylinux_2_28_x86_64.whl";
    sha256 = "afa4128f37066b83af9d426841a53147dd3c208efea893c93dc3eb6fa2af2287";
    dependencies = [ torch ] ++ (with py.pkgs; [ numpy pillow ]);
  };

  # pix2tex only needs the tokenizer API. Use the same precompiled dependency
  # versions as TTS rather than pulling another PyTorch stack through nixpkgs.
  tokenizers = tokenizersWheel;
  transformers = wheels.mkWheel {
    pname = "transformers";
    version = "4.57.3";
    name = "transformers-4.57.3-py3-none-any.whl";
    url = "https://files.pythonhosted.org/packages/6a/6b/2f416568b3c4c91c96e5a365d164f8a4a4a88030aa8ab4644181fdadce97/transformers-4.57.3-py3-none-any.whl";
    sha256 = "1x03f0gq8czk2iw8kqpnfwsish8knfn3cgb0j40qicai90x3azf7";
    dependencies = with py.pkgs; [
      filelock hubWheel jinja2 numpy packaging pyyaml regex requests
      safetensorsWheel tokenizersWheel tqdm
    ];
  };

  # Image preprocessing does not use OpenCV CUDA. The abi3 wheel avoids
  # rebuilding all of OpenCV with CUDA when the Python interpreter changes.
  opencv4 = py.pkgs.buildPythonPackage {
    pname = "opencv-python-headless";
    version = "4.13.0.92";
    format = "wheel";
    src = pkgs.fetchurl {
      name = "opencv_python_headless-4.13.0.92-cp37-abi3-manylinux_2_28_x86_64.whl";
      url = "https://files.pythonhosted.org/packages/4b/33/b5db29a6c00eb8f50708110d8d453747ca125c8b805bc437b289dbdcc057/opencv_python_headless-4.13.0.92-cp37-abi3-manylinux_2_28_x86_64.whl";
      sha256 = "0bd48544f77c68b2941392fcdf9bcd2b9cdf00e98cb8c29b2455d194763cf99e";
    };
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.zlib ];
    dependencies = [ py.pkgs.numpy ];
    doCheck = false;
    pythonImportsCheck = [ "cv2" ];
  };

  runtimeLibs = lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];

  inherit (py.pkgs)
    buildPythonPackage
    buildPythonApplication
    fetchPypi
    ;

  # entmax 1.3 — required by x-transformers
  entmax-1_3 = buildPythonPackage rec {
    pname = "entmax";
    version = "1.3";
    format = "wheel";

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/06/a0/71747f0d98e441d0670b06205afd24d832e88c0ee62129ca47ce88505304/entmax-1.3-py3-none-any.whl";
      hash = "sha256-Qbse29SXobU7Hw/IC+/VQ0mdxwS05UNt32xXKKLQBUY=";
    };

    propagatedBuildInputs = with py.pkgs; [
      torch
    ];

    doCheck = false;

    meta = with lib; {
      description = "Entmax activation functions (version pinned for x-transformers)";
      license = licenses.mit;
    };
  };

  # timm 0.5.4 — pix2tex pins this exact version
  timm-0_5_4 = buildPythonPackage rec {
    pname = "timm";
    version = "0.5.4";
    format = "setuptools";

    src = pkgs.fetchFromGitHub {
      owner = "huggingface";
      repo = "pytorch-image-models";
      rev = "v${version}";
      hash = "sha256-sI+WMHUmNWxTlpfDq1Q0yC1yZOR45qJ9LRAPKumuaVk=";
    };

    propagatedBuildInputs = with py.pkgs; [
      torch
      torchvision
    ];

    doCheck = false;

    meta = with lib; {
      description = "PyTorch image models (version pinned for pix2tex)";
      license = licenses.asl20;
    };
  };

  # x-transformers 0.15.0 — pix2tex pins this exact version
  x-transformers-0_15_0 = buildPythonPackage rec {
    pname = "x-transformers";
    version = "0.15.0";
    format = "pyproject";

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-loAhpd9AG0G2ymSaCgrOrdVvIyv62YgOoLGeFXHwsWg=";
    };

    nativeBuildInputs = with py.pkgs; [
      setuptools
    ];

    propagatedBuildInputs = with py.pkgs; [
      torch
      einops
    ] ++ [ entmax-1_3 ];

    pythonRelaxDeps = true;

    doCheck = false;

    meta = with lib; {
      description = "Lightweight transformers library (version pinned for pix2tex)";
      license = licenses.mit;
    };
  };

  # albucore 0.0.24 — dependency of albumentations, built from wheel
  albucore-0_0_24 = buildPythonPackage rec {
    pname = "albucore";
    version = "0.0.24";
    format = "wheel";

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/0a/e2/91f145e1f32428e9e1f21f46a7022ffe63d11f549ee55c3b9265ff5207fc/albucore-0.0.24-py3-none-any.whl";
      hash = "sha256-re9uQ05Q4iwu4Se3o+cfLjX6CIvPVEMeGJcLYtl9AAU=";
    };

    propagatedBuildInputs = with py.pkgs; [
      numpy
      opencv4
      simsimd
      stringzilla
    ];

    pythonRelaxDeps = true;
    pythonRemoveDeps = [ "opencv-python-headless" ];

    doCheck = false;

    meta = with lib; {
      description = "Core library for albumentations (version pinned)";
      license = licenses.mit;
    };
  };

  # albumentations 1.4.24 — pix2tex requires <=1.4.24
  albumentations-1_4_24 = buildPythonPackage rec {
    pname = "albumentations";
    version = "1.4.24";
    format = "wheel";

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/af/ae/904b7bf58281d2bc1f3d6d48813bbcee742d1f8e3f9c0e1c451b0f67eb5a/albumentations-1.4.24-py3-none-any.whl";
      hash = "sha256-L2OSV6EeaBBx9PfRD2pth0rnBbzOUnRodM2NfjF6Ftc=";
    };

    propagatedBuildInputs = with py.pkgs; [
      numpy
      opencv4
      pillow
      pyyaml
      scipy
      pydantic
    ] ++ [ albucore-0_0_24 ];

    pythonRemoveDeps = [ "opencv-python-headless" ];

    pythonRelaxDeps = true;

    doCheck = false;

    meta = with lib; {
      description = "Fast image augmentation library (version pinned for pix2tex)";
      license = licenses.mit;
    };
  };

  # antlr4-python3-runtime 4.7.2 — latex2sympy2 needs this exact version
  antlr4-python3-runtime-4_7_2 = buildPythonPackage rec {
    pname = "antlr4-python3-runtime";
    version = "4.7.2";
    format = "setuptools";

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/29/14/8ac135ec7cc9db3f768e2d032776718c6b23f74e63543f0974b4873500b2/antlr4-python3-runtime-4.7.2.tar.gz";
      hash = "sha256-Fozc7I+5FS6EqHym/SYbPVTI9jWPQqs7gTsUpxk7tQs=";
    };

    postPatch = ''
      substituteInPlace src/antlr4/Parser.py --replace-fail "from typing.io import TextIO" "from typing import TextIO"
      substituteInPlace src/antlr4/Lexer.py --replace-fail "from typing.io import TextIO" "from typing import TextIO"
    '';

    doCheck = false;

    meta = with lib; {
      description = "ANTLR 4.7.2 runtime for Python 3 (version pinned for latex2sympy2)";
      license = licenses.bsd3;
    };
  };

  # latex2sympy2 — required by pix2tex GUI, wheel-only on PyPI
  latex2sympy2 = buildPythonPackage rec {
    pname = "latex2sympy2";
    version = "1.9.1";
    format = "wheel";

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/0c/9e/4520682ab29a9219f1845643fdc75f1453bebf4b602c6e4421579de1f05d/latex2sympy2-1.9.1-py3-none-any.whl";
      hash = "sha256-RPJNJj0jUWSpEXMWejDUSfQ2Dj8KWSOc5rhDxQpBxgE=";
    };

    propagatedBuildInputs = with py.pkgs; [
      sympy
    ] ++ [ antlr4-python3-runtime-4_7_2 ];

    pythonRelaxDeps = true;

    doCheck = false;

    meta = with lib; {
      description = "Parse LaTeX math expressions and convert to SymPy";
      license = licenses.mit;
    };
  };

  # pix2tex — the main application (wheel-only on PyPI)
  pix2tex-unwrapped = buildPythonApplication rec {
    pname = "pix2tex";
    version = "0.1.4";
    format = "wheel";

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/12/b8/673667ace0a131169502420810aa9dfca69aad960d5af88da68ddd46c7f0/pix2tex-0.1.4-py3-none-any.whl";
      hash = "sha256-oCQwlQj8PopM5SQeCVJ2Ym0JjfU+YJQQAT8uw1pLdhI=";
    };

    nativeBuildInputs = with py.pkgs; [
      setuptools
    ];

    propagatedBuildInputs = with py.pkgs; [
      tqdm
      munch
      torch
      torchvision
      opencv4
      requests
      einops
      x-transformers-0_15_0
      transformers
      tokenizers
      numpy
      pillow
      pyyaml
      pandas
      timm-0_5_4
      albumentations-1_4_24
      
      # GUI dependencies
      pyqt6
      pyqt6-webengine
      pyside6
      pynput
      screeninfo
      latex2sympy2
    ];

    pythonRelaxDeps = true;
    pythonRemoveDeps = [ "opencv-python-headless" ];

    # Pre-download model weights so they don't need downloading at runtime
    weights = pkgs.fetchurl {
      url = "https://github.com/lukas-blecher/LaTeX-OCR/releases/download/v0.0.1/weights.pth";
      hash = "sha256-pj2RQcU9Jmy2gvtai9g71cvigxReDnjr3A+JUZWh36o=";
    };
    resizer = pkgs.fetchurl {
      url = "https://github.com/lukas-blecher/LaTeX-OCR/releases/download/v0.0.1/image_resizer.pth";
      hash = "sha256-HDggZZmFrRQrUmSQuyXCPZdxdqwgc1kbO92tppJxhFg=";
    };

    postInstall = let
      sitePackages = "${py.libPrefix}/site-packages";
    in ''
      dest="$out/lib/${sitePackages}/pix2tex/model/checkpoints"
      mkdir -p "$dest"
      cp ${weights} "$dest/weights.pth"
      cp ${resizer} "$dest/image_resizer.pth"

      # Upstream's no-argument Python API defaults to CPU even when CUDA is
      # available. Prefer CUDA there too; explicit --no-cuda remains supported.
      substituteInPlace "$out/lib/${sitePackages}/pix2tex/cli.py" \
        --replace-fail "'no_cuda': True" "'no_cuda': False"

      # Patch download_checkpoints to skip if weights already exist
      python3 -c "
import re
path = '$out/lib/${sitePackages}/pix2tex/model/checkpoints/get_latest_checkpoint.py'
with open(path) as f:
    content = f.read()
content = content.replace(
    'def download_checkpoints():',
    'def download_checkpoints():\n    path = os.path.dirname(__file__)\n    if os.path.exists(os.path.join(path, \"weights.pth\")) and os.path.exists(os.path.join(path, \"image_resizer.pth\")):\n        return'
)
with open(path, 'w') as f:
    f.write(content)
"
    '';

    doCheck = false;

    meta = with lib; {
      description = "pix2tex: Using a ViT to convert images of equations into LaTeX code";
      license = licenses.mit;
      mainProgram = "latexocr";
    };
  };

  # Runtime wrapper that detects desktop environment for screenshot tool
  pix2tex = let
    grimPath = "${pkgs.grim}/bin:${pkgs.slurp}/bin";
    spectaclePath = "${pkgs.kdePackages.spectacle}/bin";
  in pkgs.symlinkJoin {
    name = "pix2tex";
    paths = [ pix2tex-unwrapped ];
    postBuild = ''
      for exe in $out/bin/*; do
        mv "$exe" "$exe.unwrapped"
        cat > "$exe" <<'HEREDOC'
      ''
      + ''
      #!/usr/bin/env bash
      export QT_QPA_PLATFORM="wayland;xcb"
      export NO_ALBUMENTATIONS_UPDATE="1"
      export LD_LIBRARY_PATH="/run/opengl-driver/lib:${runtimeLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

      case "''${XDG_CURRENT_DESKTOP:-}" in
        *KDE*|*Plasma*|*plasma*)
          export SCREENSHOT_TOOL="spectacle"
          export PATH="${spectaclePath}:''${PATH}"
          ;;
        *)
          export SCREENSHOT_TOOL="grim"
          export PATH="${grimPath}:''${PATH}"
          ;;
      esac

      exec "$0.unwrapped" "$@"
      ''
      + ''
      HEREDOC
        chmod +x "$exe"
      done
    '';
  };

  latex-ocr-cli = pkgs.writeShellScriptBin "latex-ocr" ''
    exec ${pix2tex}/bin/latexocr "$@"
  '';

in
{
  home.packages = [
    pix2tex
    latex-ocr-cli
  ];

  home.file.".local/share/applications/latexocr.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=LaTeX OCR
    GenericName=Math Formula OCR
    Comment=Take a screenshot and convert math formulas to LaTeX code
    Exec=${pix2tex}/bin/latexocr
    Icon=accessories-calculator
    Terminal=false
    Categories=Education;
    StartupNotify=false
  '';
}
