# Publishing to dennysentinel.com

The blog is an Astro static site at `github.com/dazeb/dennysentinel.com`, auto-deployed via Cloudflare Pages on push to `main`.

## Workflow

```bash
# 1. Clone (if not already local)
git clone git@github.com:dazeb/dennysentinel.com.git
cd dennysentinel.com

# 2. Create post in src/content/blog/
# Frontmatter format:
# ---
# title: "Title Here"
# description: "One-line summary"
# pubDate: "Mon DD YYYY"
# ---

# 3. Commit and push
git add src/content/blog/my-post.md
git commit -m "post: descriptive commit message"
git push origin main

# Cloudflare Pages auto-builds and deploys within ~30 seconds
# Verify: curl -s -o /dev/null -w "%{http_code}" https://dennysentinel.com/blog/my-post/
```

## Astro Build (if manual deploy needed)

```bash
pnpm install
pnpm approve-builds esbuild sharp  # pnpm v10+ requires this once
pnpm build                           # Output in dist/
npx wrangler pages deploy dist       # Requires CLOUDFLARE_API_TOKEN
```

## Content Format Notes

- Uses standard Astro markdown with frontmatter
- Code blocks use triple backticks with language hint
- Tables, lists, headings, blockquotes all work
- RSS feed auto-generated from `pubDate` field
- No need for manual deployment — git push is sufficient
