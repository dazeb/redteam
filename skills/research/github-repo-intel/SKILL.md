---
name: github-repo-intel
description: "Comprehensive GitHub repo investigation: extract the repo page, check releases, then search for recent news/analysis/discussion. When someone shares a repo URL, the README is just the starting point — the real value is current context."
trigger: "User shares a GitHub repository URL (or any project URL). The README is never sufficient alone — always layer in current news/coverage."
category: research
---

# GitHub Repo Intel

## The Core Principle

When someone drops a project URL — especially Darren — **the README content is the baseline, not the answer**. The user already read the README (or decided to share it). Your job is to find **what's being said *about* the project right now**.

There are three layers to every repo investigation:

```
Layer 1: EXTRACT    → What the project says about itself (README, releases)
Layer 2: SEARCH     → What the internet says about it right now
Layer 3: SYNTHESIZE → What matters to the user, in their context
```

## Layer 1: Extract the Project Page

- `web_extract` the URL (GitHub renders fine as text)
- Key things to grab: description, stars/forks, latest release/tag, license, language breakdown, install commands, architecture overview
- If it's a GitHub release page: check the releases page too (`/releases`) — release notes often contain more detail than the README

## Layer 2: Search for Current Context ⚠️ (the critical step)

**Do not stop at Layer 1.** Immediately search for:

```
web_search "REPO_NAME" + "latest news" OR "release" OR "2026"
web_search "REPO_NAME" + "analysis" OR "review" OR "coverage"
```

Target sources in priority order:
1. **News coverage** — Help Net Security, The Register, Ars Technica, TechCrunch, The Verge
2. **Industry analysis** — vendor blogs, PipeLab-style project sites, security research shops
3. **Social discussion** — Reddit (r/programming, r/netsec, r/MachineLearning), Hacker News, X/Twitter
4. **Comparison/context articles** — "best X tools 2026" roundups that position the project against alternatives

**Pitfall: Don't re-present stale Layer 1 data as "news."** If the user says "that's old," the web_extract gave you old data — you skipped the search step and need to go back and do it.

## Layer 3: Synthesize

Structure the response as:

1. **Current status** — latest version, star count trend, freshness
2. **Recent coverage** — what was published, when, by whom
3. **Key signal** — the one thing that matters (new feature, security finding, positioning against alternatives)
4. **Your take** — where it fits / what to flag for later

### Example structure (from corrected behavior):

```
## ProjectName — Brief Description

**Stars:** X → Y | **Latest:** vX.Y.Z (Date)

### Latest Coverage
- [Source](url) — Date — what it says, key quotes
- [Source](url) — Date — what it says

### Landscape Context
- How it compares to alternatives
- What gap it fills
- Notable criticism or limitations
```

## Common Pitfalls

- **Pitfall: Treating web_extract as sufficient.** The README is the project's marketing to itself — what you actually need is external validation/criticism/coverage. Always Layer 2.
- **Pitfall: Presenting release dates as news.** "v2.3.0 released April 25" is not a news update if today is May 6. The news is the coverage *about* the release, not the release itself.
- **Pitfall: Not checking dates.** If the GitHub page says "last commit 3 months ago" but you find an article from 2 days ago, the article is the fresher signal. Lead with recency.
- **Pitfall: Over-extracting.** Don't dump the full README or full article. Darren wants the high-signal summary — key facts, key quotes, key positioning. 3-5 bullets max per layer.

## Verification

Before delivering: is what I'm calling "news" actually new? Check dates. If the most recent article is >2 weeks old, say so explicitly.