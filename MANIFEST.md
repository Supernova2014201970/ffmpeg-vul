# 交付件清单

核对日期：2026-11-17。此清单依据当前磁盘内容生成。`src/ffmpeg-readonly/` 单独汇总（普通文件，不含 `.git`），其余文件逐项记录字节数与 SHA256；`MANIFEST.md` 自身排除哈希以避免自引用。报告重新生成或其他文件改变后，需要同步更新本清单。

## 1. 当前交付内容

| 项目 | 数量 | 字节数 |
| --- | --- | --- |
| 源码副本 `src/ffmpeg-readonly/` | 6418 个文件 | 60021388 |
| 修复补丁 `payload/patches/` | 11 个文件 | 22406 |
| PoC 输入 `payload/pocs/` | 11 个文件 | 31610 |
| 验证报告 `reports/` | 3 个文件 | 2457 |
| 有效案例索引 `payload/cases.tsv` | 11 条 | 见下表 |

当前目录不提供镜像 tar 或其校验文件；镜像由 `image/Dockerfile` 构建，`src/` 不进构建上下文（镜像里的树取自基础镜像自带的上游历史）。源码身份、构建命令、脚本职责、结果判据与已知局限见 [README.md](README.md)。

## 2. 文件校验

下表覆盖源码目录之外的全部现有文件（文档、镜像定义、payload、脚本与报告）。

| 文件 | 字节 | SHA256 |
| --- | --- | --- |
| `MANIFEST.md` | — | 自引用不入表 |
| `README.md` | 24667 | `178c6f489f4a5f772f149ed4389bfe6e35dde5625cbfd754449c4c63f1692aae` |
| `SPECIFICATION.md` | 9788 | `6a9815099aad6bbc8f7d90e6dd51d4d5f7551c18a682c3f0a07197d3a77d9d38` |
| `image/Dockerfile` | 4532 | `c6f1a740f57b25bca0022c1b45c8acefdeadd483ac9555757dd6a664f7b2674c` |
| `payload/cases.tsv` | 2751 | `3175987296c1bd1a4fa0a0860e00d10c6346a6557ae9bb8c377ecc9441846dd1` |
| `payload/patch-index.json` | 4707 | `a25f69f2b09bcc4c5d0e7cbbe2283f64a20072cefecefe1efd39ef130398aa44` |
| `payload/vulnerabilities.json` | 19308 | `922ad2bbe23092419acc0b6c1996326f2f256e333e2a7c949cec21819b0cb6ed` |
| `payload/patches/0e87c07d87b474568e82364ae0d4a3928801e2b2.patch` | 6021 | `7f39cf74adafb40c1ae8cf1107ca8fb098a4828f075c7fad96cb84014cac7cdf` |
| `payload/patches/1cb4ef526dd1e5f547d0354efb0831d07e967919.patch` | 425 | `18651c16ead28d591cf78b0b893689f31e4aa1177973b18849036b22cecd4282` |
| `payload/patches/54e1b62ee28f1588ca35d26eeb2df1fb59040de3.patch` | 4205 | `762c74b6f83a165f00dd16a5ea3d3100bf28e44a3dc2655577f06b84f68c89bd` |
| `payload/patches/6b5d3fb26fb4be48e4966e4b1d97c2165538d4ef.patch` | 1043 | `767a7aeafdad748f46423173f5f2bd5e39ba22d971deaee823c2f72254c5f697` |
| `payload/patches/7ac5067146613997bb38442cb022d7f41321a706.patch` | 488 | `7bc7f45c522f5e6e710aab5d6cfb81ed8a9c6f288f128d3eeaccbca3eaeeeb0c` |
| `payload/patches/8a69f2602fea04b7ebae2db16f2581e8ff5ee0cd.patch` | 667 | `1161f3fa42107e609ed8e3437e79d53ada5e058121cdce61a86b4965f8953213` |
| `payload/patches/9351a156de724edb69ba6e1f05884fe806a13a21.patch` | 4449 | `01a4c93284403bfae486a9589ecc073ccf203822032c2dfa013ba40c0ff008dc` |
| `payload/patches/c55e637072b694a1db40e21948d218bfa2e744bb.patch` | 612 | `b1ba98f863933897d56a7f3f0c19559382d0d7866e1a076fa85bec570ad57d10` |
| `payload/patches/ca6776a993903dbcfef5ae8a18556c40ecf83e1c.patch` | 628 | `8a64546a8969f39e018fe81248d2361d80269f4f2ce4154e3f4548d29af77bd8` |
| `payload/patches/cb243972b121b1ae6b60a78ff55a0506c69f3879.patch` | 3290 | `6d4db370ef0720be4cbb6b887f74207b509f512e80f9eae9a8f8d822664de827` |
| `payload/patches/d9051f8f3e60768f68867c3e3116e980d855215a.patch` | 578 | `8cb54113261b94ece9795e7c0592180296408ac43f16c7f79e7dd5ea075fe07a` |
| `payload/pocs/42474806/poc` | 29032 | `2cb423103f28f64315826111e4c575671712d2620bed2758166fbab5a914794a` |
| `payload/pocs/42474895/poc` | 1 | `01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b` |
| `payload/pocs/42475161/poc` | 141 | `3558a0aa3c499f38ffedd084d13215d17f0b8bac508df9b751e6e13a2285fe7a` |
| `payload/pocs/42475183/poc` | 32 | `939300faa73de1de7a4a635040728872bbe8411ff14b9761c726f98406f4e793` |
| `payload/pocs/42475239/poc` | 24 | `9b04e98408cc49a809f12518905b2b590bb47c22192f5c55d3b75a594b6d49eb` |
| `payload/pocs/42475294/poc` | 1027 | `620858e132b186b5a7ed0c8093999f7978d95ce09dbb66b2cede7fe5544822f9` |
| `payload/pocs/42475684/poc` | 33 | `a34c60e6ba18eac1017f4311f3e27ac78f60bb87ad558327a280f1887abfa182` |
| `payload/pocs/42475961/poc` | 1150 | `9113f90faeb28552c749bd449ce7ab30d37d1391601265878fabcc9b9f31508d` |
| `payload/pocs/42476317/poc` | 16 | `0b72261bfac2c7a770d6864f5229e10b297f8d4a5b7a6c31649772c8636e6385` |
| `payload/pocs/42477083/poc` | 33 | `8221b9a23865d5ff0d9a1d9de93a4808fd1d6a74acb0d09e16ab1d8b49f709e8` |
| `payload/pocs/42483416/poc` | 121 | `b7117d6317ff3c517150da25f2464b81e4fde3846a3b4d17455d1a2fe4fc6c22` |
| `reports/verify-one-by-one.json` | 1500 | `d8597ed7e58790a7316819bfdce55825b58c6f2886eeb680fb467624b2fa5a42` |
| `reports/verify-one.json` | 107 | `22bea18227d44bf3544697e7ac93667d654629ead71368668725f5004800d963` |
| `reports/verify.json` | 850 | `25134bb8d7938b7441c4ee19cf901e1f0ed5896c884798aaeb34aeb14f0f4905` |
| `scripts/build.sh` | 1269 | `9846d482c02f66e4330d9f191227f75802d7a03dae992cfebcd37c094b3bbd28` |
| `scripts/hand_repro.c` | 1631 | `5c393318425b172e488de90bc569f151951630bf2b27cc15ec93f3c93b7dffd2` |
| `scripts/lib.sh` | 8575 | `44ee6d26877e801f5f3fdf56a9ace213706965f3e5a651853f217905c816ccb0` |
| `scripts/verify-one-by-one.sh` | 2206 | `d0028cbf71be5483eebc1142d2c337e2e250940f4d2c7c409a8b51c52e3f1fc2` |
| `scripts/verify-one.sh` | 3326 | `4d11bed5f599a0e47ee30954bd4e290b97685b810346dcd7d58c2b150ff498c5` |
| `scripts/verify.sh` | 2280 | `8f2fda5671b96ed88c8d5d6e1e64bb51de74bec8fec1570cc190b27bc0264527` |

## 3. 源码副本

`src/ffmpeg-readonly/` 是上游 `17f63d98e679e88a64f96e4aefba57b12ca29a0c`（2017-05-09，`n3.4-dev-874-g17f63d9`）的源码快照，目录名以 `-readonly` 结尾：不含 `.git`，作为普通文件随包提交，不用于构建，也不应在其上打补丁。它的源码身份由 `baseline.commit`、`baseline.describe` 和本节的文件数/字节数确定；镜像内 `/src/ffmpeg` 是基础镜像自带上游历史检出到同一提交的结果，其 git 树哈希是 `227b26daf8e6b9d02b973aefca8f6f47cd177f9d`。

两侧内容一致性用同一个命令核对（`6418` 个文件、聚合 SHA256 相同）：

```bash
find . -path ./.git -prune -o -type f -print0 | LC_ALL=C sort -z |
  xargs -0 sha256sum -t | sha256sum -t
# src/ffmpeg-readonly 与镜像内 /src/ffmpeg 都得到
# 24995eab93647ed6c077a45138bad086a63c34c23290ef87973ec3229bf95262
```

`tests/ref/fate/sub-scc` 在上游就是 CRLF，快照按仓库内容原样保留（不随 Windows 的行尾设置转换）。逐文件校验和上游 diff 由 `check_package.py` 的补丁 `git apply --check` 与 Dockerfile 里的 `HEAD`/`HEAD^{tree}` 断言覆盖，不在此逐条列出 6418 个文件。
