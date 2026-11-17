# FFmpeg ARVO 漏洞数据集

本项目提供一套 FFmpeg 漏洞基线、11 个 PoC 和 11 个独立修复补丁，用于源码构建、漏洞复现和单补丁验证。基线是上游真实提交 `17f63d98e679e88a64f96e4aefba57b12ca29a0c`（2017-05-09，`n3.4-dev-874-g17f63d9`）。镜像保留该检出的完整 `.git` 历史；修复版在验证时复制源码、应用指定补丁后生成，不常驻第二棵源码树。

本文于 2026-11-17 按当前目录和脚本实现更新，报告数字来自本次在镜像内的实际运行。文件大小与 SHA256 见 [MANIFEST.md](MANIFEST.md)。可复用的仓库命名、目录、数据格式与验收要求见 [漏洞数据仓库规约](SPECIFICATION.md)。

## 1. 目录结构

```text
ffmpeg-vul/
├── README.md
├── MANIFEST.md
├── SPECIFICATION.md           通用规约（与 imagemagick-vul 同源）
├── .dockerignore              构建上下文只放 payload/、scripts/、reports/
├── image/Dockerfile           镜像构建定义
├── src/ffmpeg-readonly/       基线源码副本：普通文件，不含 .git，只读使用
├── payload/
│   ├── cases.tsv              案例索引：11 条、8 列
│   ├── vulnerabilities.json   漏洞信息、源码片段和补丁路径
│   ├── patch-index.json       补丁与案例、文件、上游标题的对应关系
│   ├── patches/*.patch        11 份独立补丁
│   └── pocs/<localId>/poc     11 个输入文件
├── scripts/                   构建、复现与报告入口
└── reports/                   本次基线、单案例及逐补丁验证报告
```

不提供镜像 tar。镜像由 Dockerfile 构建。`src/ffmpeg-readonly/` 是随包快照（源码身份由 `baseline.commit`、`baseline.describe` 和 MANIFEST 统计确定），**不进构建上下文**：镜像里的 `/src/ffmpeg` 取自基础镜像自带的同一条上游历史，检出到同一个提交，两侧的 tree 哈希都是 `227b26da`。

## 2. 构建与运行

需要启动支持 Linux 容器的 Docker，并能拉取指定基础镜像。以下命令在 `ffmpeg-vul/` 目录执行（PowerShell 和 Bash 均可逐行运行）：

```bash
docker pull n132/arvo:42474806-vul@sha256:95cd4fadae89976811235d6b70b4d750c42a380845f7df27dc644333fef05052
docker build -f image/Dockerfile -t ffmpeg-vul:17f63d98 .
docker run -dit --name ffvul ffmpeg-vul:17f63d98
docker exec ffvul ffdt build
docker exec ffvul ffdt verify --report /tmp/report
docker exec ffvul ffdt verify-one 42474806 --report /tmp/report
docker exec ffvul ffdt verify-one 42474806 --patched --report /tmp/report
docker exec ffvul /opt/ffdt/verify-one-by-one.sh --report /tmp/report
```

`/opt/ffdt/reports/` 是镜像内自带的随包报告目录，容器的默认工作目录是 `/opt/ffdt`，所以不加 `--report` 时报告会直接覆盖它；要保留随包报告就显式指定目录（如上例的 `/tmp/report`），或挂载一个目录，例如 `-v ${PWD}/reports:/reports` 后写 `/reports`。

镜像内的工具链来自 2017 年时期的 ARVO / OSS-Fuzz 环境（Ubuntu 16.04、clang 6.0.0 trunk 321529、gcc 5.4、yasm/nasm、libFuzzer 源码）。构建阶段已经跑过一次 `ffdt verify`，所以镜像里 `/out` 直接带有 9 个基线插桩复现程序（覆盖 11 条案例），`/reports/verify.json` 也是构建时写的；随包 `reports/` 存的是同一批脚本在本机重跑的结果。

## 3. Dockerfile 做什么

1. 使用 digest 固定的 `n132/arvo:42474806-vul` 基础镜像，工具链与上游历史都在镜像里。
2. 复制 `payload/` 到 `/payload`、`scripts/` 到 `/opt/ffdt`、`reports/` 到 `/opt/ffdt/reports`，并给脚本加执行位。
3. 把基础镜像自带的 `/src/fdk-aac` 编译安装到 `/usr/local`（`--disable-shared --enable-static`；案例 42474895 的修复在 FFmpeg 的封装层，解码器本身不插桩也足够让 ASan 报出越界），随后删掉 `/src` 下除 `ffmpeg` 以外的全部内容，以及 `/out`、`/work` 里的旧产物。
4. 在 `/src/ffmpeg` 上 `git checkout -f --detach 17f63d98`、`reset --hard`、`clean -xffdq`，断言 `HEAD`、`HEAD^{tree}`、提交时间与 `git status --porcelain`，再对 `payload/patches/*.patch` 逐个 `git apply --check`：11 份补丁必须都能落在这棵树上。
5. 运行 `ffdt verify --report /reports`：编译 ASan、UBSan 两份基线插桩库和 9 个复现程序（11 条案例，`h264` 与 `ac3` 各两条共用同一解码器 + 检测器的可执行文件），逐个运行 PoC，写 `/reports/verify.json`。基线仍然带 bug，所以这一步要求“每条都崩”，构建期就能发现基线、PoC 或补丁被换掉；随后清空 `/work`，让 `verify-one.sh` 仍做真实构建。
6. 断言交付布局：`/src` 只有 `ffmpeg`、`.git` 存在且在 `17f63d98`、工作区干净、`/payload` 有 11 份补丁/11 个 PoC/11 行案例、`/out` 有 9 个复现程序、`/work` 为空。默认工作目录 `/opt/ffdt`，默认启动 `/bin/bash`。

```text
/src/ffmpeg      基线源码与完整 .git（detached 于 17f63d98）
/payload         案例、PoC、补丁、漏洞信息
/opt/ffdt        ffdt、lib.sh、build.sh、verify*.sh、hand_repro.c、reports/
/out             repro-<源码指纹>-<sanitizer>-<decoder>
/work            运行时的源码副本与插桩构建目录，初始为空
```

基础镜像自身是按 FFmpeg 案例 `42474806` 建的，其 `/src/ffmpeg` 停在上游 `3624d45`（2017-05-01），因此第 4 步把它切到本数据集的基线，而不是复制随包快照。

## 4. scripts/ 的分工

| 文件 | 职责与产物 |
| --- | --- |
| `ffdt` | 命令分发：`build`、`verify`、`verify-one`，参数原样转给对应脚本 |
| `build.sh` | 普通编译指定目录，生成 `<DIR>/ffmpeg`，不加 sanitizer，不运行 PoC |
| `lib.sh` | 共用路径、sanitizer 配置、源码指纹、插桩编译 `ensure_libs`/`ensure_repro`、单次执行 `run_poc` |
| `verify-one.sh` | 查找一个案例，选择原始源码或补丁副本，编译/复用复现程序，运行 PoC，写单案例报告 |
| `verify.sh` | 遍历案例，调用不带 `--patched` 的 `verify-one.sh`（`--tree` 透传），汇总基线报告 |
| `verify-one-by-one.sh` | 遍历案例，每次调用 `verify-one.sh --patched`（`--tree` 透传），汇总各自补丁的验证报告 |
| `hand_repro.c` | C 驱动：读取 PoC，调用 `LLVMFuzzerTestOneInput` 一次，代替 libFuzzer 运行时 |

```text
ffdt build → build.sh → configure + make（普通编译）
ffdt verify → verify.sh → verify-one.sh --tree DIR
verify-one-by-one.sh → verify-one.sh --patched --tree DIR
verify-one.sh → lib.sh / ensure_repro → 插桩静态库 + hand_repro.c
              → lib.sh / run_poc → 执行、判定
```

### 4.1 普通编译

```bash
ffdt build [DIR]
```

默认目录 `/src/ffmpeg`。没有 `ffbuild/config.mak` 才运行配置，然后执行 `make -j$(nproc)`。配置参数为 `--cc=clang --cxx=clang++ --ld=clang++ --disable-doc --disable-stripping`，不执行 `make install`。日志为 `/tmp/plain-configure.log` 和 `/tmp/plain-make.log`。

重复执行是增量编译；已有配置时沿用现有配置，不重新检查配置参数。此过程会在源码目录留下构建文件，但源码指纹只看已跟踪内容的 `git diff`，未跟踪产物不会影响缓存。

### 4.2 lib.sh：插桩编译与运行

`TREE` 默认 `/src/ffmpeg`，可用环境变量 `FFDT_TREE` 或三个验证脚本的 `--tree DIR` 覆盖；`PAYLOAD`、`OUT`、`WORK` 分别默认 `/payload`、`/out`、`/work`。`--tree` 指向的目录只被读取和复制，脚本不会在其中构建或打补丁。

`ensure_libs <srcdir> <address|undefined>` 复制源码（排除 `.git`）到 `/work/build-<fp>-<san>/src`，配置并 `make` 出静态库：

```text
--cc=clang --cxx=clang++ --ld=clang++
--extra-cflags/-cxxflags/-ldflags="-O1 -gline-tables-only -fno-omit-frame-pointer
  -DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION -fsanitize=address|undefined ..."
--disable-shared --enable-static --disable-doc --disable-programs --disable-network
--disable-avdevice --disable-postproc --disable-avfilter --disable-stripping
[--enable-libfdk-aac]      仅当 /usr/local/include/fdk-aac 存在时
```

`ensure_repro <srcdir> <san> <decoder>` 链接 `tools/target_dec_fuzzer.c`（OSS-Fuzz 用的就是这份文件）与 `hand_repro.c`，用 `-DFFMPEG_DECODER=<decoder>` 在**链接期**钉住解码器，等价于 OSS-Fuzz 的 `ffmpeg_AV_CODEC_ID_<X>_fuzzer` 目标名。`EXTRALIBS` 从 `ffbuild/config.mak` 读取。最后用 `nm` 检查二进制里确实有 `__asan_` / `__ubsan_` 符号。

指纹是 `<提交前8位>-<sha256(git diff)前8位>`；镜像里的干净基线为 `17f63d98-e3b0c442`。目录不是 git 工作区时（例如直接拿 `src/ffmpeg-readonly` 或任意未初始化的 `--tree` 来测）改用内容指纹 `tree-<sha256>`，此时缓存键只随文件内容变化。指纹不包含未跟踪文件、驱动内容或工具链配置；对 git 树做自定义修改时应确保改动体现在普通 `git diff` 中。

ASan 与 UBSan 分开编译，缓存按源码指纹和 sanitizer 区分，绝不合并（同一份代码同时插两者会让无关 UB 干扰判断）。2017 年的工具链没有插桩 libc，MSan 在本环境不可行，因此只提供 `address` 与 `undefined` 两种。

UBSan 这一档的编译参数是 `-fsanitize=undefined -fno-sanitize=alignment -fno-sanitize-recover=undefined`。关掉 alignment 检查是有意的：FFmpeg 在 x86 上按 64 位一次性读码流指针（`AV_RB64`/`av_alias64`，例如 `libavcodec/h2645_parse.c` 的 `ff_h2645_extract_rbsp`）属于设计行为，打开这项检查时三个 h264/hevc 案例都在到达目标缺陷之前就停在 `member access within misaligned address`，把真正的 `index -1 out of bounds` 挡住。索引与溢出检查保持开启；`-fno-sanitize-recover=undefined` 让第一次报告即终止进程，`run_poc` 因此只需匹配 `SUMMARY:` 行。

`run_poc` 设置对应运行时选项，调用 `<binary> <poc>`，依据第 5 节判定结果。

### 4.3 单案例验证

```bash
verify-one.sh <pocId> [--patched] [--report DIR] [--keep] [--tree DIR]
ffdt verify-one <pocId> [--patched] [--report DIR] [--keep] [--tree DIR]
```

从 `cases.tsv` 读取解码器、sanitizer、PoC 和补丁路径。默认测试 `$TREE`；`--tree DIR` 换成别的源码树，`--patched` 则复制该树到 `/work/one-<ID>`，通过 `git apply --check` 后应用该案例的单个补丁，再编译和测试。脚本不会重置或修改 `--tree`/`$TREE` 指向的目录，因此做基线验证前应保证它内容符合预期。补丁文件始终只有一个、只应用一次：即使某条记录在上游需要两个连续修复才清得掉（第 6 节的 `0e87c07d`），随包文件本身已经包含那两处改动。

补丁测试默认清理源码副本及对应构建目录，`--keep` 保留它们；`/out` 中的程序缓存仍保留。报告默认写到相对当前工作目录的 `reports/verify-one.json`，后续运行会覆盖。

### 4.4 两种批量验证

```bash
verify.sh [--report DIR] [--tree DIR]
verify-one-by-one.sh [--report DIR] [--tree DIR]
ffdt verify [--report DIR] [--tree DIR]
```

前者测试所有基线案例，后者每次从原始源码重新复制、只应用当前案例对应补丁，再运行当前 PoC。补丁不累计，也不对每个补丁运行其他全部 PoC。因此逐补丁报告不能证明“其他漏洞全部仍然存在”或补丁没有回归影响。

11 个案例对应 11 个补丁，逐补丁验证需要 11 次插桩编译（每个补丁一棵源码副本、一个构建目录）；缓存复用以 `(源码指纹, sanitizer)` 为单位，重复运行同一补丁会命中缓存。

### 4.5 手写驱动

`hand_repro.c` 只负责把文件读入内存、回调 `LLVMFuzzerTestOneInput` 一次然后退出：没有 libFuzzer 运行时、没有语料、没有变异，回放的就是记录下来的那一个输入。解码器在链接期固定，输入无法改变走哪个解码器。文件读取或内存分配失败返回 2。

`tools/target_dec_fuzzer.c` 会把输入的最后 1024 字节当作 `ctx->width/height/bit_rate/...` 的初值（输入大于 1024 字节时），并跳过它们；这是 OSS-Fuzz 目标本身的行为，随包 PoC 也是按这个约定生成的，驱动不做任何额外处理。

## 5. 结果、报告和退出码

`run_poc` 的原始分类如下：

| 分类 | 判据 |
| --- | --- |
| `CRASH` | 输出存在 `SUMMARY: <X>Sanitizer: ...` 行，或旧运行时的 `==NN==ERROR: <X>Sanitizer: ...` 头部 |
| `CLEAN` | 没有上述报告，且退出码为 0 |
| `ERROR` | 没有报告、非零退出 |

报告内每条记录的 `pass=true` 表示 CLEAN，即**该 PoC 没能让被测树崩溃**。三份报告顶层固定为 `pass`、`fail`、`results`，没有 `error` 计数，条目也没有 `status` 字段：`ERROR` 一律并入 `pass=false`（计入 `fail`/`crash`），所以无法从报告里区分“真的崩了”和“运行本身没跑成”。`alert` 来自案例表，是 ARVO 记录的报告标题，不与本次运行的摘要逐字比对；报告 JSON 不保存真实 sanitizer 摘要，摘要只出现在 `verify-one.sh` 的终端输出里。

| 报告 | 生成者 | 条目字段 | 正常基线上的预期统计 | 退出条件 |
| --- | --- | --- | --- | --- |
| `verify.json` | `verify.sh` | `poc`、`pass`、`alert` | `pass: 0, fail: 11`；终端 `clean=0 crash=11` | `clean == 0` |
| `verify-one.json` | `verify-one.sh` | `poc`、`pass`、`alert` | 基线 `pass: 0, fail: 1`；`--patched` 时 `pass: 1, fail: 0` | 基线要求条目 `pass=false`，`--patched` 要求 `pass=true` |
| `verify-one-by-one.json` | `verify-one-by-one.sh` | `poc`、`patch`、`pass`、`alert` | `pass: 11, fail: 0` | `fail == 0` |

`patch` 只记录补丁文件名（`<fix_commit>.patch`），不带 `patches/` 前缀。单案例的两种模式写同一个 `verify-one.json`，后跑的那次覆盖前一次；随包文件来自 `--patched`（`pass: 1`）。

前置步骤失败（配置失败、构建失败、补丁不适用）也会导致脚本非零退出，并在 stderr 给出原因。基线模式成功退出表示符合“漏洞仍在”的预期，不表示漏洞被修复。

判定局限：

- 两个批量脚本忽略子脚本退出码：拿不到 `RESULT` 行时按 `pass=false` 计入 `fail`/`crash`，所以 `clean=0` 或 `fail=0` 本身不能证明每条都确实产生了 sanitizer 报告；验收时仍应同时核对案例数、运行日志和报告条数。
- `verify-one.sh` 把 `ERROR` 也显示成 CRASH，因此基线单案例可能把一次没跑成当成“符合预期”。
- `CLEAN` 只说明当前 PoC 在当前条件下没有产生 sanitizer 报告、退出码为 0，不证明目标代码没有其他漏洞，也不表示输入被完整解码。
- ASan 的 `SEGV` 类报告不含 `SUMMARY:` 行时会落到 `ERROR`，按 `pass=false` 计入。本数据集的 11 条案例都是带摘要的报告，不受此影响。

## 6. 数据与已有报告

`cases.tsv` 的列为 `localId decoder sanitizer alert expect_frame poc patch fix_commit`，11 个案例对应 11 个唯一补丁（一对一）。补丁按 fix commit 命名，内容可能经过适配（例如 ARVO 对 `d9051f8f` 的选取与 `arvo.db` 的 `fix_commit` 不同、`0e87c07d` 叠加了它前一个修复，见下），因此上游 `git show` 不能代替随包补丁文件。`cases.tsv` 与 `hand_repro.c` 是本包针对 FFmpeg 的实现，不属于通用规约要求。

`vulnerabilities.json` 包含 project、repo、baseline（`commit`/`describe`/`date`/`note`）、paths 和 vulnerabilities；各漏洞提供 id、type、location、code_snippet、description 和 patch 路径。`code_snippet.before` 取自 `src/ffmpeg-readonly` 中的基线文件、`code_snippet.after` 取自把该补丁应用到临时副本后的同一文件，生成时逐条校验（`make_vulns.py`，不随包）；`location.line` 与 `code_snippet.line` 都是基线中的行号。

`patch-index.json` 记录每个补丁的上游标题、日期、改动文件和对应案例，并标出两份**未随包**的提交：

| 提交 | 与数据集的关系 |
| --- | --- |
| `1795dccde0ad` | `arvo.db` 把它列为 42475183 的 `fix_commit`，但它改的是 Android MediaCodec 封装，与 `libavcodec/mimic.c` 的崩溃无关；随包的是真正修复它的 `d9051f8f3e60` |
| `4705edbbb96e` | 对应 ARVO 案例 42482171（mxpeg），该 PoC 在本基线上不崩溃，案例未随包；PoC、补丁与证据留在数据集外的 `runs/ffmpeg-baseline/excluded/` |

唯一一个叠加了两处上游修复的补丁是 `0e87c07d`（42477083）。单独应用它（`run_vlc[6]` → `run_vlc[6+1]`）不会让该 PoC 停下：在未改动的基线上 UBSan 先报 `libavcodec/h264_cavlc.c:579`（`(total_zeros_vlc-1)[total_coeff]`，`VLC [15]`），先打上前一个修复 `54e1b62e` 才轮到 `:620`（`(run_vlc-1)[zeros_left]`，`VLC [6]`）。因此随包文件是 `54e1b62e` 与 `0e87c07d` 对 `libavcodec/h264_cavlc.c` 的合并，应用后与上游打完 `0e87c07d` 的该文件一致；`patch-index.json` 里这条记为 `"adapted": true`、`"predecessor": "54e1b62ee28f1588ca35d26eeb2df1fb59040de3"`。

本次在镜像内跑出的随包报告：

| 文件 | 顶层 pass | 顶层 fail | 结果数 |
| --- | --- | --- | --- |
| `reports/verify.json` | 0 | 11 | 11 |
| `reports/verify-one.json` | 1 | 0 | 1 |
| `reports/verify-one-by-one.json` | 11 | 0 | 11 |

11 个案例在基线上都产生了 sanitizer 报告：ASan 3 例 `Heap-buffer-overflow WRITE`、1 例 `Stack-buffer-overflow WRITE`；UBSan 7 例 `runtime error: index ... out of bounds`。逐补丁报告里，每个案例应用自己的补丁后都不再产生报告。

`reports/` 只保存 JSON 汇总，不含运行日期、镜像 ID 和实际摘要；需要摘要时重跑 `ffdt verify-one <id>`，它会把命中的 `ERROR: <X>Sanitizer: ...` 行打到终端。

Windows 上本地源码副本的可执行权限可能与 Linux 有差异，但内容一致：按 MANIFEST 第 3 节的命令，`src/ffmpeg-readonly` 与镜像内 `/src/ffmpeg` 的 6418 个文件聚合 SHA256 都是 `24995eab`。构建和验证都走镜像内的 git 检出，不依赖本地副本。文件清单描述当前磁盘内容。

## 7. 漏洞分布

统计依据为 `payload/vulnerabilities.json`、`payload/cases.tsv` 和 `payload/patch-index.json`，基线范围是 `17f63d98` 这一个节点，统计单位是案例 ID（`localId`），默认按案例去重：每个案例在每个维度只计入一个主分类。占比分母均为 11 个案例，四舍五入到一位小数；各维度独立统计，不能跨维度相加。

### 7.1 总体规模

| 项目 | 数量 |
| --- | --- |
| 案例 | 11 |
| PoC | 11 |
| 唯一补丁 | 11 |
| 随包之外的候选案例 | 2（`1795dccd` 与崩溃无关、`4705edbb` 在基线上不复现） |

案例数不等于独立漏洞根因数：本数据集是 1 案例 : 1 补丁，但同一个补丁在上游可能同时修掉多个用例；反过来，`libavcodec/h264_cavlc.c` 的两个案例虽然在同一函数、都报在 `decode_residual`，触发的却是两张不同的 VLC 表，各自对应一个上游修复，不能合并。

### 7.2 按 CWE 类型

每个案例按元数据中的主 CWE 计一次。11 个案例的 CWE 都已知，因此没有“未知类型”行；若后续案例的主 CWE 无法确认，按规约单列并记为 `null`，不猜测填充。

| CWE | 类型 | 案例数 | 占比 |
| --- | --- | --- | --- |
| CWE-129 | Improper Validation of Array Index | 7 | 63.6% |
| CWE-787 | Out-of-bounds Write | 3 | 27.3% |
| CWE-121 | Stack-based Buffer Overflow | 1 | 9.1% |
| 合计 | — | 11 | 100.0% |

7 个 CWE-129 全部是“用码流里的计数/索引直接查表或写数组”这一类：`decode_residual` 用 `total_coeff`/`zeros_left` 查 VLC 表、`vlc_decode_block` 用 `num_bits` 查二维表、`dvbsub_parse_clut_segment` 用 `entry_id` 写色表、`decode_audio_block` 用 `2-ch` 算声道号、`add_candidate_ref` 用 `nb_refs` 写引用列表。UBSan 报的形式都是 `index N out of bounds for type '...'`。

### 7.3 按检测方式

按案例表的 `sanitizer` 字段统计，与 CWE 是两个维度，不能相加。

| 检测器 | 案例数 | 占比 |
| --- | --- | --- |
| `undefined` | 7 | 63.6% |
| `address` | 4 | 27.3% |
| 合计 | 11 | 100.0% |
| （未提供）`memory` | 0 | — |

`address` 的 4 例是 42474806（webp）、42474895（libfdk_aac）、42475161（xpm）、42475294（scpr），都是越界写；`undefined` 的 7 例都是越界下标。MSan 不可行：2017 年的基础镜像没有插桩 libc/libc++，用 MSan 编译整棵 FFmpeg 会立刻在 libc 边界报未初始化值。

### 7.4 按源码模块

按 `location.file` 的首级目录统计（路径已经是相对源码根目录的形式，无需规范化 `./` 前缀或大小写）。这是 ARVO 记录的**报告位置**，不等于补丁修改文件或根因位置。

| 模块 | 案例数 | 占比 |
| --- | --- | --- |
| `libavcodec` | 11 | 100.0% |
| 合计 | 11 | 100.0% |

按文件细分：`libavcodec/h264_cavlc.c` 2 例；`vp8.c`、`libfdk-aacdec.c`、`xpmdec.c`、`mimic.c`、`dvbsubdec.c`、`scpr.c`、`eac3dec.c`、`ac3dec.c`、`hevc_refs.c` 各 1 例。其中两例的报告位置与修复位置不在同一个文件：42474806 报在 `libavcodec/vp8.c:1677`（`intra_predict`），补丁改的是 `libavcodec/webp.c`（`vp8_lossy_decode_frame`，未重设 `pix_fmt`）；42475961 报在 `libavcodec/eac3dec.c:114`（`ff_eac3_apply_spectral_extension`），补丁改的是 `libavcodec/ac3dec.c`（`decode_band_structure` 跨块保持频带结构）。

### 7.5 按输入类别

按案例表的 `decoder` 字段（即 OSS-Fuzz 目标名 `ffmpeg_AV_CODEC_ID_<X>_fuzzer` 里钉住的解码器）统计，不合并视频/音频。

| 解码器 | 输入格式 | 案例数 |
| --- | --- | --- |
| `h264` | H.264 码流 | 2 |
| `ac3` | AC-3 / E-AC-3 码流 | 2 |
| `webp` | WebP（含内嵌 VP8） | 1 |
| `libfdk_aac` | AAC（经 libfdk-aac 封装） | 1 |
| `xpm` | XPM 图像 | 1 |
| `mimic` | Mimic 视频 | 1 |
| `dvbsub` | DVB 字幕 | 1 |
| `scpr` | ScreenPressor 视频 | 1 |
| `hevc` | HEVC 码流 | 1 |
| 合计 | — | 11 |

两个 `ac3` 案例分别发生在声道号折算（`decode_audio_block`）与频带结构（`ac3dec.c`），两个 `h264` 案例都在 `decode_residual` 的不同表（`total_zeros` 与 `run_vlc`）；42477083 的 PoC 会依次命中这两处（基线先停在 `total_zeros`，修掉它才轮到 `run_vlc`），它的补丁因此叠加了两个上游修复。

### 7.6 案例与补丁对应分布

| 每个补丁对应的案例数 | 补丁数 | 覆盖案例数 |
| --- | --- | --- |
| 1 | 11 | 11 |
| 合计 | 11 | 11 |

没有共享补丁，因此逐补丁验证的 11 次编译与 11 个案例一一对应。补丁提交前缀：

```text
6b5d3fb2  ca6776a9  cb243972  d9051f8f  8a69f260  7ac50671
54e1b62e  9351a156  c55e6370  0e87c07d  1cb4ef52
```

其中有 4 个补丁的形式值得区分（`fix_summary` 字段也按此写法）：

- `6b5d3fb2`（vp8/webp）把 `pix_fmt` 的赋值移出初始化分支，并加 `av_assert0` 约束格式——是“状态没跟着码流更新”这类根因，不是边界检查缺失。
- `9351a156`（ac3dec）改的是跨块状态的保存方式：把频带结构存进解码上下文、每帧首块用默认表初始化，`av_assert0` 只是入口自检。
- `d9051f8f`（mimic）把二维下标改成对行首指针的扁平索引，读的是同一片表数据，消除的是“内层数组越界”这一 UB 形式，而不是越界写。
- `0e87c07d`（h264_cavlc）是四张 total_zeros/run VLC 表“数组前移一项”写法的第二个修复；随包文件额外并入前一个修复 `54e1b62e`，否则该 PoC 仍会在 `total_zeros` 那处停下（见第 6 节）。

ARVO 记录的 `fix_commit` 对 42475183 写的是 `1795dccd`（Android MediaCodec 封装），与崩溃点无关；随包补丁换成真正修复 `libavcodec/mimic.c` 的 `d9051f8f`，两者都记在 `patch-index.json`。
