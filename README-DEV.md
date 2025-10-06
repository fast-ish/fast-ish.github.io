# fastish Documentation Development

Local development guide for the fastish documentation site.

## Quick Start

### Option 1: Bash Script (Recommended)

The easiest way to run the docs locally:

```bash
./serve.sh
```

This will start a local server at `http://localhost:3000`

**Custom port/host:**
```bash
./serve.sh 8080              # Run on port 8080
./serve.sh 8080 0.0.0.0      # Run on port 8080, accessible from network
```

The script automatically detects and uses the best available HTTP server:
- Python 3 (preferred)
- Python 2
- Node.js http-server
- PHP built-in server

### Option 2: docsify-cli (Best for Development)

Install docsify-cli globally:
```bash
npm install -g docsify-cli
```

Then run:
```bash
npm run dev
# or
npm start
```

This provides:
- Live reload on file changes
- Better error messages
- Faster development workflow

### Option 3: Node.js http-server

```bash
npx http-server -p 3000 -o
```

### Option 4: Python

**Python 3:**
```bash
python3 -m http.server 3000
```

**Python 2:**
```bash
python -m SimpleHTTPServer 3000
```

### Option 5: PHP

```bash
php -S localhost:3000
```

## Development Workflow

1. **Start the server** using any method above
2. **Open browser** to `http://localhost:3000`
3. **Edit markdown files** in the repository
4. **Refresh browser** to see changes (or use live reload with docsify-cli)

## Project Structure

```
fast-ish.github.io/
├── index.html              # Main docsify config
├── theme.css               # Custom theme (portal UI aligned)
├── README.md               # Home page
├── _sidebar.md             # Sidebar navigation
├── _navbar.md              # Top navigation
├── _coverpage.md           # Cover page
├── getting-started/        # Getting started docs
├── webapp/                 # Webapp architecture docs
├── druid/                  # Druid architecture docs
├── faq/                    # FAQ docs
└── workflow/               # Workflow docs
```

## Theme Customization

The theme is in `theme.css` and matches the portal UI:

**Key Variables:**
- `--heading-font-family`: Chelsea Market (brand font)
- `--base-font-family`: System fonts (Inter fallback)
- `--code-font-family`: SF Mono, JetBrains Mono
- Colors match portal's dark theme

**To modify:**
1. Edit `theme.css`
2. Refresh browser to see changes
3. Dark mode is default, light mode available via toggle button

## Adding New Pages

1. Create markdown file: `docs/new-section/page.md`
2. Add to `_sidebar.md`:
   ```markdown
   * New Section
     * [Page Title](/new-section/page.md)
   ```
3. The page will automatically appear in navigation

## Tips

- **Live Reload**: Use `docsify-cli` for the best development experience
- **Fast Testing**: Use the bash script for quick checks
- **Network Testing**: Use `0.0.0.0` host to test on mobile devices
- **Theme Toggle**: Bottom-right floating button switches light/dark modes
- **Search**: Works out of the box, indexes all markdown files

## Deployment

Docs are automatically deployed to GitHub Pages when pushed to main branch.

**Manual GitHub Pages setup:**
1. Go to repository Settings > Pages
2. Source: Deploy from a branch
3. Branch: `main` / `root`
4. Save

The site will be live at: `https://fast-ish.github.io`

## Troubleshooting

### Port already in use
```bash
./serve.sh 8080  # Try a different port
```

### Permission denied on serve.sh
```bash
chmod +x serve.sh
```

### docsify-cli not found
```bash
npm install -g docsify-cli
```

### Theme not loading
- Clear browser cache
- Check browser console for errors
- Verify `theme.css` file exists

## Additional Resources

- [Docsify Documentation](https://docsify.js.org/)
- [Docsify Themeable](https://jhildenbiddle.github.io/docsify-themeable/)
- [GitHub Pages Docs](https://docs.github.com/en/pages)
