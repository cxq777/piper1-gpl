# Piper TTS 中文镜像构建

在本仓库根目录执行以下命令。需要安装 Docker CLI，并配置能连接远程 Docker Engine 的 `dev2` context。命令会在 `dev2` 上构建并保存镜像。

```bash
docker --context dev2 build --progress=plain -t piper-tts:1.8.0-zh .
docker --context dev2 image inspect piper-tts:1.8.0-zh \
  --format '{{.Id}} {{.Architecture}}'
docker --context dev2 tag piper-tts:1.8.0-zh \
  cxq.cr.ccxxqq.cn:9000/piper-tts:1.8.0-zh
docker --context dev2 push cxq.cr.ccxxqq.cn:9000/piper-tts:1.8.0-zh
```

构建使用根目录的 `Dockerfile` 和 `.dockerignore`。编译阶段生成 Piper wheel，运行阶段安装 wheel、中文音素转换依赖（包括 `unicode-rbnf`）和 Flask，并预下载 G2PW 模型到 `/app/g2pW`。首次构建需要访问 Docker Hub、系统和 Python 软件包源，以及 Hugging Face。网络较慢时，可通过 `--progress=plain` 查看各步骤的进度。

## 验证中文音素转换

```bash
docker --context dev2 run --rm --network none \
  -e HF_HUB_OFFLINE=1 --entrypoint python piper-tts:1.8.0-zh \
  -c 'from pathlib import Path; from piper.phonemize_chinese import ChinesePhonemizer; print(ChinesePhonemizer(Path("/app/g2pW")).phonemize("警告，变压器温度95度。"))'
```

预期输出为中文音素列表。`HF_HUB_OFFLINE=1` 避免 tokenizer 在启动时尝试访问 Hugging Face。这一步验证中文音素转换。合成 WAV 还需要另行准备语音模型文件及其配套的 `.onnx.json` 配置。

## 测试 HTTP 语音合成

部署完成后，向 `/synthesize` 发送中文告警文本，并将响应保存为 `test1.wav`。

```bash
curl -X POST 'https://piper-tts.app.cn:9000/synthesize' \
  -H 'Content-Type: application/json' \
  -d '{"text":"警告，变压器诶温度95度。"}' \
  --output test1.wav
```
