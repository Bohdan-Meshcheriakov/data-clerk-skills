# Screenshots for Human Touch tasks

Reviewers only see what you attach. A screenshot shows layout, space and context, so they catch wording that is correct alone but wrong in place, or a button that overlaps. Attach one for anything visual: UI texts, pages, emails, documents, designs.

## Which tool to use

Use the first one you have:

1. **Playwright MCP** (`browser_navigate`, `browser_resize`, `browser_take_screenshot`). Set the window with `browser_resize` to 1280×800, then take the screenshot with a `filename`, so it is saved to a file and not returned into your context. Pass an element to capture one part, or `fullPage: true` for the whole page.
2. **Playwright CLI** (needs Node):
   ```bash
   npx -y playwright install chromium
   npx -y playwright screenshot --viewport-size="1280,800" --wait-for-timeout=1000 https://example.com shot.png
   npx -y playwright screenshot --full-page --viewport-size="1280,800" https://example.com page.png
   npx -y playwright screenshot --device="iPhone 13" https://example.com mobile.png
   ```
   If Chrome is already installed, add `--channel chrome` and skip the `install` step. Use `--wait-for-selector ".loaded"` to wait for content, and `--color-scheme dark` or `--lang de-DE` for variants.
3. **Headless Chrome**, no install:
   ```bash
   google-chrome --headless=new --hide-scrollbars --window-size=1280,800 --screenshot=shot.png https://example.com
   ```
   On macOS the binary is `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"`.
4. **Other tools**:
   - `uvx shot-scraper https://example.com -o shot.png --width 1280 --selector ".checkout"`
   - Puppeteer, or your own browser automation.
   - Native and mobile apps: `xcrun simctl io booted screenshot shot.png` (iOS simulator), `adb exec-out screencap -p > shot.png` (Android).
   - Desktop: `screencapture -x shot.png` (macOS), `grim shot.png` or `gnome-screenshot -f shot.png` (Linux).
5. **Nothing works**: ask your human to attach screenshots, or send the task without them and say so in `context`.

For a local app, start it first and screenshot `http://localhost:…`.

For screens behind a login, use a test account and never put real credentials in a command:
1. Log in once with `npx -y playwright codegen --save-storage=auth.json https://example.com/login`.
2. Add `--load-storage=auth.json` to every screenshot command.
3. Delete `auth.json` when you are done.

## Take them efficiently

- **Width 1280, scale 1.** Images are stored at most 1600 px wide, so retina (2×) screenshots only make the upload bigger.
- **Only what matters.** Capture the element or the screen in question. Use a full page only when the whole page is reviewed. Pages are cut at 16 000 px tall.
- **PNG for UI and text**, JPEG or WebP (quality about 80) for photos. Up to 10 MB each.
- **Wait for the real state.** Let fonts and data load, close cookie banners and pop-ups, and show the state you ask about (error, empty cart, step 2).
- **One screenshot, many items.** Put shared screenshots in the top-level `images` of the request; every item sees them. For translations, one screenshot of the source-language screen serves every language.
- **Upload without base64.** Call `upload_image` with no arguments and run the `curl` command it returns with your file (`--data-binary @shot.png`). Never paste base64 into your context; it costs many tokens.
- **Caption every image**: where it is and what state it shows, for example `Checkout, step 2, card declined`.
- Limits: 10 images per item, 50 per request.

## Privacy

Screenshots are **not** redacted. Only text fields get personal data replaced with placeholders. Before you take a screenshot:

- Use test accounts and fake data.
- Hide or crop out emails, names, phone numbers, addresses, tokens, API keys and other notifications on the screen.
- With Playwright you can black out parts of the page: in code, `page.screenshot({ path: "shot.png", mask: [page.locator(".email")] })`.
