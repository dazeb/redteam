# Codester Profile Completion Workflow

Session date: 2026-05-08. Account: dazebdotdev. Site: codester.com.

## Full Flow

### 1. Cloudflare → Login

1. `browser_navigate` to `https://www.codester.com`
2. Click the Cloudflare "Verify you are human" checkbox in the iframe
3. `browser_navigate` to `https://www.codester.com/login` (direct navigation skips redirect wait)
4. `browser_type` username (ref=e7) and password (ref=e8)
5. `browser_click` "Log in" (ref=e5)

### 2. Upload Avatar & Background

Settings URL: `https://www.codester.com/edit/` (dropdown → Settings)

1. Click "Avatar & profile background" tab
2. Download placeholder images to `/tmp/`:
   - Avatar: `curl -sL "https://ui-avatars.com/api/?name=Darren+Bennett&size=256&background=1a73e8&color=fff&bold=true&format=png" -o /tmp/codester-avatar.png`
   - Background: `curl -sL "https://picsum.photos/seed/codester/1200/400" -o /tmp/codester-bg.jpg`
3. `browser_type` file paths into both "Choose File" inputs
4. Click "Upload & save"
5. Success message: "You have successfully changed your avatar and profile photo"

### 3. Profile Heading & Text

These fields are in the DOM but NOT visible in any settings tab. They belong to the "Website & Social profiles" section but are rendered elsewhere.

**Field IDs (discovered via browser_console):**
- Heading: `id="by_line"`, name="profile_title", label="Profile heading"
- Text: `id="profile_desc"`, name="profile_desc", label="Profile text"

**Process:**
1. Set values via `browser_console`:
```javascript
document.getElementById('by_line').value = 'DevOps Engineer & Security Researcher | 20+ Years Building Reliable Infrastructure';
document.getElementById('profile_desc').value = 'Experienced DevOps engineer...';
```
2. Find and click save button:
```javascript
Array.from(document.querySelectorAll('button')).find(b => /save/i.test(b.textContent)).click();
```
3. Verify: "Your personal data has been successfully saved"

### 4. Verification

Navigate to `https://www.codester.com/user/dazebdotdev` — heading should appear under the name.

**Note:** The profile text (profile_desc) uses a Redactor rich-text editor. Plain text set via JavaScript may not persist in the WYSIWYG. Manual paste may be required.

## Site Structure

- Login: `/login`
- Settings/Edit: `/edit/` (tabbed interface)
- Profile: `/user/dazebdotdev`
- Settings tabs: Personal information, Password, Avatar & profile background, 2FA, Website & Social profiles, Featured item, Licenses

## Keys/Secrets
- Username: dazebdotdev
- Password: Y0ufuckingtwat!
- Email: daz@dazeb.dev
