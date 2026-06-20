# CLAUDE.md — Knowledge Vault

This file tells any AI agent (Claude Code, OpenClaw, or any runtime that reads project CLAUDE.md) how to maintain this vault across sessions. Edit freely to match your own workflow and topic structure.

## Vault Structure

```
.
├── notes/           ← kf-cli captured notes land here (YYYY-MM-DD-*.md)
├── raw/             ← inbox: unprocessed source material (PDFs, dumps)
├── wiki/            ← synthesized knowledge, organized by topic
│   ├── _master-index.md     ← entry point — lists every topic folder
│   └── [topic]/
│       └── [topic].md       ← topic index listing articles in that topic
├── output/          ← query results and generated reports
├── images/          ← images referenced by notes
└── Templates/       ← Obsidian Templater templates (optional)
```

## Knowledge Base Rules

- This is an LLM-maintained knowledge base. The agent is the librarian.
- `wiki/` is the agent's domain — synthesize and maintain content there.
- `raw/` is the inbox; process those files into the wiki during a "compile" step.
- `wiki/_master-index.md` is the entry point — keep it current.
- Each topic gets its own subfolder (`wiki/[topic]/`) with a topic file (`wiki/[topic]/[topic].md`) listing all articles in that topic.
- Topics follow a Wikipedia-style model — start broad, branch into subtopics, cross-link related concepts.
- Use Obsidian wikilink syntax `[[path/to/note|Display Name]]` for cross-references.
- Include a `## Key Takeaways` section in every wiki article.
- Keep articles concise — bullets over paragraphs.

## Capture → Wiki Rule

After every note saved via `/kf-cli:*` capture commands:

1. Read the note's `tags` and `title` from frontmatter.
2. Determine which wiki topic(s) it belongs to using the Tag → Topic mapping below.
3. Add a one-line entry `[[notes/filename|Title]] — short description` in the matching `wiki/[topic]/[topic].md`.
   - If the topic folder doesn't exist yet, create `wiki/[topic]/[topic].md`.
4. If the note also matches a subtopic, add an entry there too.
5. Update `wiki/_master-index.md` if a new top-level topic was created.

## Tag → Topic Mapping

Starter mapping covering kf-cli's default tag taxonomy. Extend it as your vault grows — add rows for your own topics and tags.

| Tag(s) | Wiki file |
|--------|-----------|
| AI, ai, ai-agents, agents, LLM, prompt-engineering, RAG, machine-learning, tools | wiki/ai/ai.md |
| development, coding, programming, web-development, data-science, automation | wiki/development/development.md |
| productivity, workflow, knowledge-management, PKM | wiki/productivity/productivity.md |
| research, learning, study, writing | wiki/research/research.md |
| business, finance, personal-growth | wiki/life/life.md |
| design, UI-UX | wiki/design/design.md |

## Tag Taxonomy (kf-cli default)

Apply these when tagging new captures. Add your own as needed.

**Content Types:** video, idea, article, study-guide, repository, reference, project

**Topics:** AI, productivity, knowledge-management, development, learning, research, writing, tools, business, design, automation, data-science, web-development, personal-growth, finance

**Status:** inbox, processing, evergreen, published, archived, needs-review

**Metadata:** high-priority, quick-read, deep-dive, technical, conceptual, actionable, tutorial, inspiration

## Common operations

- **Capture** new content → `/kf-cli:capture <url-or-text>` (routes to watch / youtube-note / gitingest / article / idea / study-guide)
- **Compile** raw material → process files in `raw/`, synthesize into `wiki/`, cross-link
- **Audit** → review `wiki/` for broken links, inconsistencies, gaps; propose fixes
- **Answer questions** → read `wiki/_master-index.md` first, drill into the relevant topic, then specific articles
