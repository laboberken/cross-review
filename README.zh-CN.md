# cross-review

面向编码 agent 的**评审工具箱**:两个 skill,把「代码评审」从**模型给自己打分**变成
**换一个模型来审**。

| Skill | 作用 |
|---|---|
| [`cross-review`](skills/cross-review/SKILL.md) | **编排层**。写下改动的意图,把不同模型家系的独立评审者作为并行 pane 派到同一个 Herdr tab,逐条裁决,修完只对增量复审。 |
| [`review-agent`](skills/review-agent/SKILL.md) | **契约层**。只读、缺陷优先的 finding 格式 —— P0–P3 分级、`No findings.` 哨兵,以及禁止评审者编造证据的那几条硬规矩。 |

两者是组合关系:`cross-review` 跑评审团,`review-agent` 给评审团一套**共同语言**,
让两个厂商的报告能逐行比对。

## 为什么拆成两个 skill

因为它们回答的是不同的问题,而且各自独立有用。

`cross-review` 需要 herdr-core、一个 git 仓库、以及至少一个别的 agent CLI。
`review-agent` 什么都不需要 —— 它只是一份评审契约,没有评审团也能改善任何一次评审。
**Codex 本身就内置了它。**

如果合成一个,`review-agent` 就永远无法单独安装,而「共享契约」这个想法会退化成
「某个 skill 的内部细节」。

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

按名字只装一个:

```bash
npx skills add https://github.com/laboberken/cross-review@cross-review
npx skills add https://github.com/laboberken/cross-review@review-agent
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
2. 按改动规模挑**透镜**:50 行以内 1 个,200 行以内或 5 个文件以内 2 个,更大 3 个。
3. 建一个 Herdr tab,**每个评审者一个 pane**,各自是通过 `hc` 启动的独立 agent 进程。
4. 每个评审者把发现写到 `.review/round-<N>/<lens>.md`,再用 `hc send` 回报。
5. 主控把每份报告**分节原样呈现** —— 不合并不跨透镜重排 —— 并对**每一条**发现单独
   裁决:接受、驳回或延后,都给出理由。
6. 接受的问题修掉,落新基线 commit,下一轮**只审增量**。上限 3 轮。

### 三种透镜

| 透镜 | 挑战什么 |
|---|---|
| **Skeptic** | 正确性与完整性 —— 什么会崩、什么没处理、什么被当成了已证事实 |
| **Architect** | 结构适配性 —— 设计是否服务于目标、耦合点在哪、规模上来先坏哪 |
| **Minimalist** | 必要性与复杂度 —— 什么可以删、什么在解决还没遇到的问题、最简路径是什么 |

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
│   └── review-agent/
│       └── SKILL.md                 # name: review-agent
├── .github/workflows/validate.yml
├── LICENSE
└── README.md
```

## 许可证

MIT。见 [LICENSE](LICENSE)。
