# cross-review

面向编码 agent 的评审工具箱:一个 skill,把「代码评审」从**模型给自己打分**变成
**换一个模型来审**。

[`cross-review`](skills/cross-review/SKILL.md) 写下改动的意图,把不同模型家系的独立
评审者作为并行 pane 派到同一个 Herdr tab,逐条裁决,修完只对增量复审。它要求评审者
遵守的 finding 契约 —— P0–P3 分级、`No findings.` 哨兵,以及禁止评审者编造证据的
那几条硬规矩 —— 就在它旁边:
[`references/finding-format.md`](skills/cross-review/references/finding-format.md)。

> **从 v2 升级。** 以前有第二个 skill `review-agent` 承载契约,现在已删除:重新安装
> 本仓库,并卸载你从本仓库装过的 `review-agent`。Codex 自己内置的那个 `review-agent`
> 是另一回事,不要动它。

## 为什么要跨模型

大部分「评审一下」的提示,都是用**写代码的同一个模型**去评审。这是现有评审里最弱的
一种:评审者和作者共享同一批盲区。干净的上下文解决不了 —— **换一个模型才可以**。

同一份 diff、同一个透镜、同一份任务包的实测:

| 位置 | Claude Code | Codex | 判定 |
|---|---|---|---|
| 取消守卫只拦住了四种「已出库」状态中的一种 | P1 | P1 | 一致,同一行 |
| 退款函数可能返回负数 | P3 | P2 | 一致,**级别不同** |
| 新增公开函数没有测试 | P2 | P2 | 一致 |
| 半分在二进制浮点上舍入不一致 | P2 | — | **Codex 漏了** |
| 项目自己的钱单位规则与它自己的价格函数矛盾 | P2 | — | **Codex 漏了** |
| 同一份 diff 里删掉了一个无关文件 | P2 | P2 | **两个都抓到了** |

**并集才是发现集,不是交集。** 单跑任何一个评审团都不是答案。

## 安装

装整个工具箱:

```bash
npx skills add https://github.com/laboberken/cross-review
```

或者手动装。Claude Code 原生读 `~/.claude/skills`;opencode 把它当兼容性源读;
**Codex 只读 `~/.codex/skills`**,所以共享目录需要镜像过去。

```bash
git clone https://github.com/laboberken/cross-review.git
cp -r cross-review/skills/* ~/.claude/skills/
sh ~/.claude/skills/cross-review/scripts/sync-codex-skills.sh
```

Windows PowerShell:

```powershell
git clone https://github.com/laboberken/cross-review.git
Copy-Item cross-review\skills\* "$env:USERPROFILE\.claude\skills\" -Recurse
pwsh -File "$env:USERPROFILE\.claude\skills\cross-review\scripts\sync-codex-skills.ps1"
```

再装 herdr-core 的评审者模板 —— **只读契约**和每个 agent 的**启动行**都在模板里:

```bash
sh ~/.claude/skills/cross-review/scripts/install-templates.sh
```

```powershell
pwsh -File "$env:USERPROFILE\.claude\skills\cross-review\scripts\install-templates.ps1"
```

可选:装斜杠命令。

```bash
mkdir -p ~/.config/opencode/commands
cp ~/.claude/skills/cross-review/commands/cross-review.md ~/.config/opencode/commands/
```

重启 agent,或执行 `/reload`。

## 使用

```bash
/cross-review                            # git diff HEAD
/cross-review the auth module
/cross-review HEAD~3..HEAD
```

或者直接说人话:「换个模型评审一下这个改动」「对登录修复做一次对抗式评审」。

### 评审团怎么跑

1. 主控写下**意图**和明确的**范围外**,并检查仓库自己的规则之间是否自相矛盾。
2. 按六层阶梯找 **spec 来源**:你说过的话、主控上下文里已有的、commit message、
   仓库自己的声明、约定扫描、最后问一次。找不到就跳过 Spec 轴并**明说跳过了**,
   绝不当作通过。
3. 给每个评审者分配**一个轴 + 一个透镜**的配对,并按**风险**而非行数决定面板规模:
   是否碰公共 API、金额与权限路径、是否伴随失败测试、你是否点名了这块区域。
4. 建一个 Herdr tab,**每个评审者一个 pane**,各自是通过 `hc` 启动的独立 agent 进程。
5. 每个评审者把发现写到 `<git-dir>/cross-review/round-<N>/`,文件开头带
   `AXIS`/`LENS` 头,再用 `hc send` 回报。
6. 主控**轴在外、透镜在内**地呈现报告,先按 `file:line` 去重,再对**每一条**发现
   单独裁决:接受、驳回或延后,都给出理由。
7. 接受的问题修掉,重新给工作区拍快照,下一轮**只审增量**。某一轮零接受就收敛结束;
   3 轮上限只是兜底,撞上了会**明说没收敛**。

**全程不产生 commit**:基线是借一个临时索引给工作区拍出来的树快照,所以脏工作区
也能审,`git log` 一动不动。发现写在 `.git/` 内部,不会出现在 `git status` 里。

### 轴与透镜

**轴**回答"拿什么当标准",**透镜**回答"怎么挑战"。每个评审者各拿一个。

| 轴 | 追问什么 |
|---|---|
| **正确性** | 改动是否做到它声称的事,且没弄坏别的? |
| **Spec 保真度** | 是否做全了 spec 要求的,且没多做? |
| **编码标准** | 是否遵守仓库文档化的标准与 smell 基线? |

| 透镜 | 挑战什么 |
|---|---|
| **Skeptic** | 正确性与完整性 —— 什么会崩、什么没处理、什么被当成了已证事实 |
| **Architect** | 结构适配性 —— 设计是否服务于目标、耦合点在哪、规模上来先坏哪 |
| **Minimalist** | 必要性与复杂度 —— 什么可以删、什么在解决还没遇到的问题、最简路径是什么 |

### 传输阶梯

协议在每一级都一样,变的只是评审进程怎么起。

| 级别 | 何时 | 是什么 |
|---|---|---|
| **L3** | 在 Herdr 里 | 可见的 pane —— 可中途 steer、事后可追问 |
| **L2** | 装了跨模型 CLI | print 模式(`codex exec`、`opencode run`、`claude -p`),便宜;结论用退出码 0/1/2 表达 |
| **L1** | 两者都没有 | 同 harness 的 subagent,并在报告里**声明这是同模型评审** |

**CI 明确不在范围内**。这是本地、有人参与的工具;L2 存在是因为它是便宜的本地路径。

### 支持的 agent

`skills/cross-review/references/agents.md` 是注册表:每个 agent 怎么启动、是否上报
状态、怎么接收提示词、启动期会弹什么框。Claude Code、Codex、opencode 是**已验证**
条目;`dsh-tui`、`dsh`、`pi` 是未验证条目。

每个 agent 需要自己的 herdr-core 模板,因为模板同时承载**只读契约**和该 agent 的
**启动行**。

## 安全阀

以下情况,skill 会停下来报告而不是继续派单:

- 仓库自己的规则**互相矛盾**。评审者读规则的方式和规则坏掉的方式是一样的,所以这是
  主控的活。
- 没有任何评审者跑在**与作者不同的模型家系**上。它会说明并记录,而不是静默继续。
- 仓库文档里的测试命令**跑不起来**。跑不了测试的评审者只会给出未经核实的断言。
- 评审报告里出现了**任何命令都没产生过的数字**。

skill **绝不**关闭、kill 或删除评审者的终端和 tab —— 留给你手动关。

## 仓库结构

```text
.
├── skills/
│   ├── cross-review/
│   │   ├── SKILL.md                 # name: cross-review
│   │   ├── references/
│   │   │   ├── lenses.md            # Skeptic / Architect / Minimalist
│   │   │   ├── agents.md            # agent 注册表
│   │   │   ├── task-packet.md       # 交给评审者的任务包
│   │   │   └── troubleshooting.md   # 实测踩坑集
│   │   ├── commands/cross-review.md  # 斜杠命令
│   │   ├── templates/               # herdr-core 评审者模板
│   │   ├── examples/                # 实测会话记录
│   │   └── scripts/                 # 安装与镜像脚本
├── .github/workflows/validate.yml
├── LICENSE
└── README.md
```

## 许可证

MIT。见 [LICENSE](LICENSE)。
