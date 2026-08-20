---
name: agent-skill-advisor
description: "Recommends which agent skills to install to reach a goal — cut token cost, add a capability (web/social research, humanized writing, 1000+ tool connections, agentic video), or add multi-agent verification. Use when the user wants to make their agent cheaper or more capable, or asks which agent skill to install for a task. Catalog snapshot (Aug 2026, from Sharbel A.'s '10 Hermes Agent Skills'); always verify each repo before installing."
---

# Agent Skill Advisor

Recommends **which agent skills to install** to reach a goal, grounded in a tested catalog of 12
skills. This is a *decision guide*, not an installer — it maps a goal to the right skill(s), the
install order, the repo, and the caveats.

> **Snapshot:** Aug 2026, distilled from Sharbel A., *"10 Hermes Agent Skills You NEED To Install
> Today"*. Skill catalogs churn monthly — **treat repos as leads, verify each before installing**
> (read the skill, check what it puts in context, confirm the repo still exists).

## How to use this skill

1. Identify the user's goal and match it in **Decision Guide** below.
2. Recommend the specific skill(s), the **order**, and the one-line reason.
3. Give the repo link and any **caveat** (platform vs skill-file, big-file discipline, API needs).
4. If the goal is just "make my agent better", default to the **Top 3 tonight**.

## Decision Guide (goal → skill)

| If the user wants to… | Recommend | Why / order |
|---|---|---|
| **Cut token cost** (agent is expensive) | **Defuddle → Caveman → Codebase-Memory** | Attack the 3 sinks: inbound page reading, outbound writing, codebase exploration. Install in this order. |
| Stop wasting tokens on **web pages / research** | **Defuddle** | Strips pages to clean reader-mode markdown before the agent reads. Pays for itself on page 1. |
| Cut **output** cost / verbose answers | **Caveman** | Ultra-compressed output mode (~65% fewer output tokens — the expensive, re-sent side). |
| Stop re-reading files in a **codebase** | **Codebase-Memory** (MCP) | Indexes the repo to a graph once; agent queries the map (~95–99% fewer exploration tokens). |
| **Research X / Reddit / GitHub** without paid APIs | **Agent Reach** | No-fee social research with automatic failover when a platform blocks a path. |
| Make AI writing **sound human** / avoid "tells" | **Humanizer** | Rewrites out AI tells (built from the Wikipedia page, auto-updates). Big file — invoke **late, once**, ideally in a fresh session. |
| Add **marketing/sales judgment** | **Marketing Skills** | 49-skill pack (SEO, ads, conversion, copy, buyer psychology). Judgment, not tools. |
| **Connect real tools** (Gmail, Slack, Notion, CRM) | **Composio** | 1000+ tools in one install, no OAuth juggling. Platform, not a skill file. |
| Produce **video** agentically | **OpenMontage** | Proposes concepts + tool path + cost estimate before generating; you approve first. |
| Add a **verification / quality gate** before shipping | **Oh My Claude Code** | Turns one session into a decomposing, specialist-assigning, **self-verifying** team. Use for irreversible work. |
| A full **methodology / "OS" for the agent** | **Superpowers** | Skills framework with a real methodology. Budget an afternoon to learn it. |

## Top 3 to install tonight

1. **Defuddle** — trims inbound page tokens (biggest easy win).
2. **Caveman** — trims outbound tokens (the expensive, re-billed side).
3. **Codebase-Memory** — kills repeated file-reads during code work.

## Full catalog (repos)

| # | Skill | Bucket | Repo | Note |
|---|-------|--------|------|------|
| 01 | Defuddle | 💸 cheaper | https://github.com/kepano/obsidian-skills | reader-mode markdown before read |
| 02 | Caveman | 💸 cheaper | https://github.com/juliusbrussee/caveman | ~65% fewer output tokens |
| 03 | Codebase-Memory | 💸 cheaper | https://github.com/DeusData/codebase-memory-mcp | MCP server; ~95–99% fewer exploration tokens |
| 04 | Humanizer | ✨ ability | https://github.com/blader/humanizer | 29.6 KB; invoke late/once |
| 05 | Agent Reach | ✨ ability | https://github.com/Panniantong/Agent-Reach | no-fee social research + failover |
| 06 | Marketing Skills | ✨ ability | https://github.com/coreyhaines31/marketingskills | 49 skills in one pack |
| 07 | Composio | ✨ ability | https://github.com/composiohq/composio | platform; 1000+ tool connectors |
| 08 | OpenMontage | ✨ ability | https://github.com/calesthio/OpenMontage | agentic video; approve-before-spend |
| 09 | Oh My Claude Code | 👥 team | https://github.com/Yeachan-Heo/oh-my-claudecode | decompose + verify |
| 10 | Superpowers | 👥 team | https://github.com/obra/superpowers | skills framework / OS |
| — | Mission Control | 🎁 bonus | https://github.com/sharbelxyz/hermes-agent-mission-control | Hermes fleet dashboard |
| — | Nova | 🎁 bonus | https://github.com/sharbelxyz/nova-youtube-agent | YouTube agent |

## Caveats & anti-patterns

- **Verify before install** — read the skill, check what it loads into context; confirm the repo is live.
- **Platform vs skill-file** — Codebase-Memory (MCP) and Composio (platform) aren't markdown skills; the *effect* is the same but setup differs (accounts/servers).
- **Big files cost context all session** — Humanizer (29.6 KB) and Superpowers are heavy; invoke big writing passes late/once, ideally in a fresh session.
- **Curate, don't hoard** — the real cost is burying good skills under 40 you never use. Install a few high-value ones.
- **Snapshot risk** — this catalog is Aug 2026; recommend the user re-check for newer/replacement skills.

## Reference

- Full source catalog: `references/catalog.md`
- Original transcript: `references/transcript.md`
