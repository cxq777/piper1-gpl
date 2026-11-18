
FROM python:3.12 AS builder

RUN apt-get update && \
    apt-get install --yes --no-install-recommends \
      build-essential cmake ninja-build git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY pyproject.toml setup.py CMakeLists.txt MANIFEST.in README.md COPYING ./
COPY licenses/ ./licenses/
COPY src/piper/ ./src/piper/
COPY script/setup script/dev_build script/package ./script/

# 安装编译和打包所需的开发依赖
RUN script/setup --dev

# 编译原生扩展并打包 wheel
RUN script/dev_build
RUN script/package

# -------------------------------------------------------------------
FROM python:3.12-slim

ENV PIP_BREAK_SYSTEM_PACKAGES=1

WORKDIR /app

COPY --from=builder /app/dist/ ./dist/

# 安装 Piper wheel、中文依赖和 HTTP 服务依赖
RUN pip install --no-cache-dir \
      ./dist/piper_tts-*.whl \
      'g2pW>=0.1.1,<1' \
      'transformers>=4,<6' \
      'sentence-stream>=1.2.1,<2' \
      'unicode-rbnf>=2.4.0,<3' \
      'requests>=2.31,<3' \
      'flask>=3,<4' \
    && rm -rf ./dist/

COPY docker/entrypoint.sh /

EXPOSE 5000


# 预下载 Piper 中文 G2PW 模型
RUN python - <<'PY'
import os
import tarfile
import urllib.request

url = (
    "https://huggingface.co/datasets/rhasspy/"
    "piper-checkpoints/resolve/main/zh/zh_CN/"
    "_resources/g2pw.tar.gz?download=true"
)

target = "/app/g2pW"
archive = "/tmp/g2pw.tar.gz"

os.makedirs(target, exist_ok=True)
print("Downloading G2PW model...")
urllib.request.urlretrieve(url, archive)

with tarfile.open(archive, "r:gz") as tar:
    tar.extractall(path=target, filter="data")

if not os.path.isfile(os.path.join(target, "g2pw.onnx")):
    raise RuntimeError(
        f"g2pw.onnx not found in {target}; "
        "check the archive's directory structure"
    )

os.remove(archive)
print("G2PW model downloaded successfully")
PY

ENTRYPOINT ["/entrypoint.sh"]

