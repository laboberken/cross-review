# cross-review

面向 OpenCode、Claude Code 和 Codex 的**跨模型对抗式代码评审** skill,基于
[herdr-core](https://github.com/herdrdev/herdr-core) 编排。它先写下这次改动的
**意图**,再把不同模型家系的独立评审者作为**并行 pane** 派到同一个 Herdr tab
里,逐条裁决评审结果,最后修掉问题并**只对增量做复审**。

## 为什么还要又一个 review skill?

大部分「评审一下」的提示,都是**用写代码的同一个模型去评审**。这是现有评审里最弱的
一种:评审者和作者共享同一批盲区。干净的上下文解决不了这个问题 —— **换一个模型
才可以**。

这个 skill 只保留经得起验证的部分:

- **跨模型,而不只是跨进程** —— 评审者跑在与作者不同的模型家系上。隔离换来干净的
  上下文,换模型才换来不同的假设。
- **用评审团,而不是一个评审者** —— 在同一份 diff 上,两个盲区不同的评审者找到了
  **各自不同**的缺陷。**并集才是发现集**;单评审者的盲区不是真相。
- **意图优先** —— 评审者挑战的是「这份工作**是否达成了既定意图**」,而不是「意图
  本身对不对」。没有意图,评审只能查规则,而查规则产出的是伪装成缺陷的样式问题。
- **角色,而非维度** —— Skeptic / Architect / Minimalist 是三种**行为立场**,会找到
  不同的东西。「Standards」和「Spec」是同一个改动的两条轴;透镜是三个不同的评审者。
- **位置是发现,级别只是意见** —— 同一个缺陷、同一行,一个模型给 P3,另一个给 P2。
- **每个数字都要重新推导** —— 评审者会编造看似合理的例子。作者不核对就会继承它。
- **轮次上限 3** —— 再往下跑,产出的只有样式噪音。

## 安装

三个 agent 都能装:

```bash
npx skills add https://github.com/laboberken/cross-review
```

或者克隆:

```bash
git clone https://github.com/laboberken/cross-review.git
cd cross-review
```

Claude Code 原生读 `~/.claude/skills`;opencode 把它当兼容性源读;**Codex 只读
`~/.codex/skills`**,所以共享的 skill 仓库需要镜像过去:

```bash
# Claude Code 和 opencode
mkdir -p ~/.claude/skills/cross-review
cp -r SKILL.md references ~/.claude/skills/cross-review/

# Codex(镜像)
sh scripts/sync-codex-skills.sh
```

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills\cross-review"
Copy-Item SKILL.md "$env:USERPROFILE\.claude\skills\cross-review\SKILL.md"
Copy-Item references "$env:USERPROFILE\.claude\skills\cross-review\" -Recurse

pwsh -File scripts\sync-codex-skills.ps1
```

再装 herdr-core 的评审者模板 —— **只读契约**和每个 agent 的**启动行**都在模板里:

```bash
sh scripts/install-templates.sh
```

```powershell
pwsh -File scripts\install-templates.ps1
```

可选:装斜杠命令。

```bash
mkdir -p ~/.config/opencode/commands
cp commands/cross-review.md ~/.config/opencode/commands/cross-review.md
```

`review-agent` —— 让两个厂商可以机器比对的那份统一 finding 格式 —— 是独立仓库:

```bash
git clone https://github.com/laboberken/review-agent.git
cp -r review-agent/SKILL.md ~/.claude/skills/review-agent/SKILL.md
```

重启 agent,或执行 `/reload`。

## 使用

```bash
/cross-review                            # git diff HEAD
/cross-review the auth module
/cross-review HEAD~3..HEAD
```

或者直接说人话:「换个模型评审一下这个改动」「对登录修复做一次对抗式评审」。

### 工作流程

1. 主控写下**意图**和明确的**范围外**,并检查仓库自己的规则之间是否自相矛盾。
2. 按改动规模挑**透镜**:50 行以内 1 个评审者,200 行以内或 5 个文件以内 2 个,
   更大则 3 个。
3. 建一个 Herdr tab,**每个评审者一个 pane**,各自是通过 `hc` 启动的独立 agent 进程。
4. 每个评审者把发现写到 `.review/round-<N>/<lens>.md`,再用 `hc send` 回报。
5. 主控把每份报告**分节原样呈现** —— 不合并不跨透镜重排 —— 并对**每一条**发现
   单独裁决:接受、驳回或延后,都给出理由。
6. 接受的问题修掉,落一个新的基线 commit,下一轮**只审增量**。

### 三种透镜

| 透镜 | 挑战什么 |
|---|---|
| **Skeptic** | 正确性与完整性 —— 什么会崩、什么没处理、什么被当成了已证事实 |
| **Architect** | 结构适配性 —— 设计是否服务于目标、耦合点在哪、规模上来先坏哪 |
| **Minimalist** | 必要性与复杂度 —— 什么可以删、什么在解决还没遇到的问题、最简路径是什么 |

### 支持的 agent

`references/agents.md` 是注册表:每个 agent 怎么启动、是否上报状态、怎么接收提示词、
启动期会弹什么框。Claude Code、Codex、opencode 是**已验证**条目;`dsh-tui`、`dsh`、
`pi` 是未验证条目。

每个 agent 需要自己的 herdr-core 模板,因为模板同时承载**只读契约**和该 agent 的
**启动行**。`templates/` 里带了 Claude Code 和 Codex 两份。

## 安全阀

以下情况,skill 会停下来报告而不是继续派单:

- 仓库自己的规则**互相矛盾**。评审者读规则的方式和规则坏掉的方式是一样的,所以这
  是主控的活。
- 没有任何评审者跑在**与作者不同的模型家系**上。这时它会说明并记录,而不是静默继续。
- 仓库文档里的测试命令**跑不起来**。跑不了测试的评审者只会给出未经核实的断言。
- 评审报告里出现了**任何命令都没产生过的数字**。

skill **绝不**关闭、kill 或删除评审者的终端和 tab —— 留给你手动关,好让你能翻过程。

## 仓库结构

```text
.
├── SKILL.md                     # skill 定义(name: cross-review)
├── commands/
│   └── cross-review.md          # 斜杠命令
├── references/
│   ├── lenses.md                # 三种透镜定义
│   ├── agents.md                # agent 注册表:启动行、状态、对话框
│   ├── task-packet.md           # 交给评审者的任务包
│   └── troubleshooting.md       # 实测踩坑集与解法
├── templates/
│   ├── reviewer.md              # Claude Code 的 herdr-core 模板
│   └── reviewer-codex.md        # Codex 的 herdr-core 模板
├── examples/
│   ├── panel-two-models.md      # 两个评审者、两个模型家系、一份 diff
│   ├── incremental-rereview.md  # 三轮复审,以及决定性的那一轮
│   └── agent-behaviour-matrix.md
├── scripts/
│   ├── install-templates.ps1
│   ├── install-templates.sh
│   ├── sync-codex-skills.ps1
│   └── sync-codex-skills.sh
├── .github/workflows/
│   └── validate.yml
├── LICENSE
└── README.md
```

## 许可证

MIT。见 [LICENSE](LICENSE)。
