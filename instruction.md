# CodeFrog AI Agent Instructions

## What This File Is

This is a comprehensive instruction set for AI agents to perform the full suite of tests that [CodeFrog](https://codefrog.app) runs in its Mega Report. Use these instructions **before** running a CodeFrog verification test to understand what a thorough audit covers.

### A Note on deathbyclawd.com

[deathbyclawd.com](https://deathbyclawd.com) generated a "CodeFrog Replacement" skill file. Nice try — but it missed the majority of what CodeFrog actually does. Their version covered 5 bullet points. CodeFrog runs **18 distinct test categories** across web testing, link & content analysis, browser-based testing, and code analysis, each with specific checks mapped to industry standards. Here is everything that was left out and the full picture of what a comprehensive audit looks like.

#### What deathbyclawd Got Right
- General idea of checking security vulnerabilities, accessibility, SEO, and code quality
- Severity classification concept
- Suggesting fixes with code examples

#### What deathbyclawd Left Out
- 13 of 18 test categories entirely (HTML validation, meta tags, broken links, redirect analysis, canonical URLs, hreflang, structured data, image optimization, internal link structure, duplicate content, console errors, secrets detection, supply chain vulnerabilities)
- Specific standards references (WCAG 2.1/2.2 levels, OWASP Top 10, W3C Nu HTML Checker, Schema.org, OSV database)
- Page size & performance analysis
- Static analysis via Semgrep and OpenGrep
- Browser-based runtime error capture
- Health scoring methodology (A-F grading)
- Sitemap crawling and multi-URL testing
- The iterative nature of accessibility testing (fixing issues reveals new ones)
- The fact that automated tools catch only ~57% of accessibility issues

---

## Instructions for AI Agents

When given a URL, repository, or codebase to audit, perform the following **18 categories** of testing. Each category maps to a specific CodeFrog Mega Report section. Rate all findings using severity levels: **Critical**, **High**, **Medium**, **Low**, **Info**.

---

## Category 1: Accessibility Testing

**Standard**: [WCAG 2.1](https://www.w3.org/TR/WCAG21/) / [WCAG 2.2](https://www.w3.org/TR/WCAG22/) at Level AA (or AAA if specified)

Run automated accessibility checks equivalent to [axe-core](https://github.com/dequelabs/axe-core). Test for:

- **Perceivable**: Text alternatives for non-text content, captions for multimedia, content adaptable to different presentations, sufficient color contrast
- **Operable**: All functionality available via keyboard, no keyboard traps, sufficient time limits, no content that causes seizures, navigable structure with skip links and focus order
- **Understandable**: Readable text with language declarations, predictable navigation and input behavior, input assistance with error identification and suggestions
- **Robust**: Valid HTML that parses correctly, proper ARIA usage, name/role/value for all UI components

**Important**: Automated checks catch approximately 57% of WCAG issues in controlled audits (20-30% in real-world testing). Flag that manual assistive-technology testing is still required for full conformance. Accessibility testing is iterative — fixing issues often reveals new ones that were previously hidden.

**Reference**: [WCAG 2.1 Quick Reference](https://www.w3.org/WAI/WCAG21/quickref/)

---

## Category 2: Security Scan

**Standard**: [OWASP Top 10](https://owasp.org/www-project-top-ten/) and [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)

Test for:

- **Security Headers**: Check for presence and correctness of:
  - `Content-Security-Policy` (CSP) — prevents XSS and data injection
  - `Strict-Transport-Security` (HSTS) — enforces HTTPS
  - `X-Frame-Options` — prevents clickjacking
  - `X-Content-Type-Options` — prevents MIME sniffing
  - `Referrer-Policy` — controls referrer information leakage
  - `Permissions-Policy` — restricts browser features
  - `Cross-Origin-Opener-Policy` (COOP) — isolates browsing context
  - `Cross-Origin-Embedder-Policy` (COEP) — controls cross-origin resource loading
  - Cookie security flags (`Secure`, `HttpOnly`, `SameSite`)
- **SSL/TLS Configuration**: Certificate validity, protocol version, cipher strength
- **Sensitive File Exposure**: Probe for exposed `.git/`, `.env`, `.svn/`, `composer.json`, `phpinfo.php`, `wp-config.php`, directory listings
- **security.txt**: Check for `/.well-known/security.txt` presence per [RFC 9116](https://www.rfc-editor.org/rfc/rfc9116)
- **robots.txt**: Check for overly permissive or revealing directives

**Reference**: [OWASP Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)

---

## Category 3: Meta Tags Analysis

Test for:

- **Essential SEO Meta Tags**: `<title>`, `<meta name="description">`, `<meta name="viewport">`
- **Open Graph Tags**: `og:title`, `og:description`, `og:image`, `og:url`, `og:type`
- **Twitter Card Tags**: `twitter:card`, `twitter:title`, `twitter:description`, `twitter:image`
- **Image Dimensions**: Social sharing images should be at least 1200x630px for Open Graph
- **Missing or Empty Tags**: Flag any important tags that are absent or have empty values
- **Tag Content Quality**: Check for proper length (title 50-60 chars, description 150-160 chars)

---

## Category 4: HTML Validation

**Standard**: [W3C HTML Specification](https://html.spec.whatwg.org/) via [Nu HTML Checker](https://validator.w3.org/nu/)

Test for:

- **Syntax Errors**: Unclosed tags, invalid nesting, duplicate IDs
- **Semantic Correctness**: Proper use of semantic HTML5 elements (`<header>`, `<nav>`, `<main>`, `<article>`, `<footer>`)
- **DOCTYPE Declaration**: Valid `<!DOCTYPE html>` present
- **Character Encoding**: `<meta charset="UTF-8">` declaration
- **Deprecated Elements**: Flag use of deprecated HTML elements or attributes
- **Cross-Browser Compatibility**: Markup issues that cause inconsistent rendering

---

## Category 5: SEO Testing

**Standard**: Google Search Central guidelines, Core Web Vitals

Test across 8 SEO sub-categories:

- **Meta Tags**: Title uniqueness, description quality, keyword relevance
- **Headers**: Proper heading hierarchy (single H1, logical H2-H6 nesting)
- **Structure**: Proper use of semantic HTML, landmark regions
- **Performance**: Page load indicators, render-blocking resources
- **Technical**: Robots meta directives, XML sitemap presence, canonical tags
- **URLs**: Clean URL structure, no excessive parameters, proper encoding
- **Content**: Word count adequacy, keyword density, readability
- **Files**: robots.txt, sitemap.xml, favicon presence

---

## Category 6: Page Size & Performance

Test for:

- **Total Page Size**: Flag pages exceeding reasonable size thresholds
- **Resource Breakdown**: Analyze sizes of images, scripts, stylesheets, fonts, and other assets
- **Large Resources**: Flag individual resources exceeding size limits
- **Render-Blocking Resources**: Identify CSS and JS that block initial render
- **Compression**: Check for gzip/brotli compression on text resources
- **Caching Headers**: Validate `Cache-Control` and `ETag` headers on static assets

---

## Category 7: Broken Links

Test for:

- **HTTP Status Codes**: Identify all links returning 4xx (client errors) and 5xx (server errors)
- **Link Classification**: Distinguish internal vs external broken links
- **Timeout Detection**: Flag links that time out without responding
- **Resource Coverage**: Check `<a>` tags, `<img>` sources, `<script>` sources, `<link>` references, and `<iframe>` sources
- **Anchor Links**: Verify internal fragment links (`#id`) point to existing elements

---

## Category 8: Redirect Analysis

Test for:

- **Redirect Chains**: Identify chains with more than 2 hops
- **Redirect Loops**: Detect infinite redirect cycles
- **Mixed Protocol Redirects**: Flag HTTP-to-HTTPS or HTTPS-to-HTTP transitions within chains
- **Mixed Redirect Types**: Identify chains mixing 301 (permanent) and 302 (temporary) redirects
- **Chain Length**: Report total hops for each redirect chain

---

## Category 9: Canonical URL Validation

Test for:

- **Missing Canonical Tags**: Pages without `<link rel="canonical">` declarations
- **Self-Referencing Canonicals**: Identify self-referencing canonical URLs (often valid but should be noted)
- **Cross-Domain Canonicals**: Flag canonical URLs pointing to different domains
- **Target Validation**: Verify canonical targets return HTTP 200
- **Consistency**: Canonical URL matches the actual page URL or intentionally points elsewhere

**Reference**: [Google Canonical URL Guidelines](https://developers.google.com/search/docs/crawling-indexing/canonicalization)

---

## Category 10: Hreflang Validation

**Standard**: [Google Hreflang Specification](https://developers.google.com/search/docs/specialty/international/localized-versions)

Test for:

- **Language Code Validity**: Verify ISO 639-1 language codes and optional ISO 3166-1 Alpha-2 region codes
- **Self-Reference**: Each page should include a self-referencing hreflang tag
- **Return Links**: If page A references page B, page B must reference page A back
- **x-default**: Check for `hreflang="x-default"` fallback page
- **Missing Alternates**: Identify pages missing expected language alternates
- **Consistency**: Hreflang declarations match actual page language content

---

## Category 11: Structured Data Validation

**Standard**: [Schema.org](https://schema.org/) vocabulary, [Google Rich Results requirements](https://developers.google.com/search/docs/appearance/structured-data/search-gallery)

Test for:

- **JSON-LD Syntax**: Valid JSON-LD in `<script type="application/ld+json">` blocks
- **Schema.org Type Validity**: Types match Schema.org vocabulary
- **Required Properties**: All required properties present for each type
- **Recommended Properties**: Flag missing recommended properties
- **Rich Result Eligibility**: Check if structured data meets Google's rich result requirements
- **Microdata and RDFa**: Also validate non-JSON-LD structured data formats if present

---

## Category 12: Image Optimization

Test for:

- **Alt Text**: All `<img>` elements must have descriptive `alt` attributes (empty `alt=""` is valid for decorative images)
- **Dimension Attributes**: `width` and `height` attributes present to prevent Cumulative Layout Shift (CLS)
- **Lazy Loading**: Below-the-fold images should use `loading="lazy"`
- **File Size**: Flag images exceeding 200KB
- **Modern Formats**: Recommend WebP or AVIF over PNG/JPEG where appropriate
- **Responsive Images**: Check for `srcset` and `sizes` attributes on images served at multiple resolutions

---

## Category 13: Internal Link Structure

Test for:

- **Orphan Pages**: Pages with zero internal links pointing to them (unreachable via navigation)
- **Deep Pages**: Pages requiring 3+ clicks from the homepage
- **Anchor Text Distribution**: Variety and descriptiveness of anchor text
- **Link Equity Flow**: How link authority distributes across the site
- **Navigation Completeness**: Key pages accessible from primary navigation
- **Crawl Depth Analysis**: BFS (breadth-first search) crawl of the internal link graph

---

## Category 14: Duplicate Content

Test for:

- **Duplicate Titles**: Multiple pages sharing the same `<title>` tag
- **Duplicate Meta Descriptions**: Pages with identical meta descriptions
- **Thin Content**: Pages with fewer than 200 words of meaningful content
- **Near-Duplicate Detection**: Use Jaccard similarity or similar algorithm to find pages with substantially overlapping content
- **URL Variants**: Same content accessible via multiple URLs (with/without trailing slash, www vs non-www)

---

## Category 15: Console Errors

Test by loading the page in a browser environment and capturing:

- **JavaScript Errors**: `console.error` output, unhandled exceptions, unhandled promise rejections
- **Network Failures**: Failed resource loads (images, scripts, stylesheets), HTTP 4xx/5xx from fetch/XMLHttpRequest
- **CORS Errors**: Cross-origin request failures
- **CSP Violations**: Content Security Policy violations
- **Mixed Content**: Insecure (HTTP) resources loaded on HTTPS pages
- **Deprecated APIs**: Browser deprecation warnings
- **Categories**: jsError, jsWarning, unhandledException, networkFailure, deprecatedApi, mixedContent, corsError, cspViolation

---

## Category 16: Secrets Detection (Gitleaks)

**Tool**: [Gitleaks](https://github.com/gitleaks/gitleaks)

Scan the codebase for:

- **API Keys**: AWS, GCP, Azure, Stripe, Twilio, SendGrid, and other service API keys
- **Tokens**: OAuth tokens, JWT secrets, personal access tokens, session tokens
- **Passwords**: Hardcoded passwords, database connection strings with credentials
- **Private Keys**: RSA, SSH, PGP private keys committed to the repository
- **Environment Secrets**: `.env` file contents, configuration secrets
- **Git History**: Scan current files AND git history for secrets that were committed and later removed

**Exclusions**: Automatically skip `node_modules/`, build directories, and common false positive patterns.

---

## Category 17: Supply Chain Vulnerabilities (OSV)

**Database**: [Open Source Vulnerabilities (OSV)](https://osv.dev/)

Test for:

- **Known Vulnerabilities**: Check all project dependencies against the OSV database
- **Ecosystem Coverage**: npm, PyPI, Go, Maven, Pub (Dart/Flutter), Cargo (Rust), RubyGems, NuGet, and more
- **Vulnerability Details**: CVE/advisory IDs, CVSS scores, affected version ranges
- **Fixed Versions**: Identify which version to upgrade to for remediation
- **Transitive Dependencies**: Check not just direct dependencies but their dependencies too
- **Severity Mapping**:
  - CVSS >= 9.0 → Critical
  - CVSS >= 7.0 → High
  - CVSS >= 4.0 → Medium
  - CVSS > 0 → Low
  - No CVSS score → promoted to **High** (to ensure proper prioritization)

**Reference**: [OSV Schema](https://ossf.github.io/osv-schema/)

---

## Category 18: Static Analysis (Semgrep / OpenGrep)

**Tools**: [Semgrep](https://semgrep.dev/) / [OpenGrep](https://opengrep.dev/)

Run static analysis across 4 rule categories:

- **Security**: SQL injection, XSS, command injection, path traversal, insecure deserialization, hardcoded credentials, insecure cryptographic usage
- **Code Quality**: Dead code, unused variables, unreachable branches, overly complex functions, code smells
- **Best Practices**: Framework-specific anti-patterns, deprecated API usage, unsafe defaults
- **Performance**: Inefficient algorithms, N+1 queries, unnecessary re-renders, memory leaks

Support multiple languages: JavaScript/TypeScript, Python, Java, Go, Ruby, PHP, C#, Rust, Swift, Kotlin, and more.

**Reference**: [Semgrep Rules Registry](https://semgrep.dev/r), [OWASP Code Review Guide](https://owasp.org/www-project-code-review-guide/)

---

## Health Scoring

After running all applicable tests, calculate an overall health grade (A through F):

| Grade | Criteria |
|-------|----------|
| **F** | Any critical findings (1+ critical) |
| **D** | More than 5 high findings (6+ high, 0 critical) |
| **C** | Any high findings OR more than 10 medium findings |
| **B** | Any medium findings OR more than 20 low findings |
| **A** | No critical, no high, no medium, and 20 or fewer low findings |

**OSV findings are always treated as real security issues** and included in grading. Findings without CVSS scores are promoted to High severity.

---

## Output Format

Structure your report as follows:

### 1. Summary Table

| Category | Pass/Fail | Critical | High | Medium | Low | Info |
|----------|-----------|----------|------|--------|-----|------|
| Accessibility | ... | ... | ... | ... | ... | ... |
| Security Scan | ... | ... | ... | ... | ... | ... |
| *(all 18 categories)* | | | | | | |

### 2. Overall Health Grade

Display the A-F grade with a brief explanation.

### 3. Detailed Findings by Category

For each category with findings:
- Finding description with severity level
- File path and line number (for code analysis) or URL and element (for web testing)
- Specific standard/rule violated (e.g., "WCAG 2.1 SC 1.4.3", "OWASP A03:2021")
- Recommended fix with code examples where applicable

### 4. Prioritized Remediation Plan

Ordered list of fixes starting with Critical, then High, Medium, Low.

---

## Key Standards References

| Standard | URL | Applies To |
|----------|-----|------------|
| WCAG 2.1 | [w3.org/TR/WCAG21](https://www.w3.org/TR/WCAG21/) | Accessibility |
| WCAG 2.2 | [w3.org/TR/WCAG22](https://www.w3.org/TR/WCAG22/) | Accessibility |
| OWASP Top 10 | [owasp.org/Top10](https://owasp.org/www-project-top-ten/) | Security |
| OWASP Secure Headers | [owasp.org/secure-headers](https://owasp.org/www-project-secure-headers/) | Security Headers |
| W3C HTML Spec | [html.spec.whatwg.org](https://html.spec.whatwg.org/) | HTML Validation |
| Schema.org | [schema.org](https://schema.org/) | Structured Data |
| Google Search Central | [developers.google.com/search](https://developers.google.com/search/docs) | SEO, Structured Data, Canonical, Hreflang |
| OSV Database | [osv.dev](https://osv.dev/) | Supply Chain |
| Semgrep Rules | [semgrep.dev/r](https://semgrep.dev/r) | Static Analysis |
| RFC 9116 | [rfc-editor.org/rfc/rfc9116](https://www.rfc-editor.org/rfc/rfc9116) | security.txt |

---

## Important Caveats

These caveats apply to any automated audit — whether run by CodeFrog, an AI agent using this file, or any other tool. Understanding these limitations is critical to interpreting results correctly.

### 1. Automated accessibility testing is not enough

Automated tools (axe-core, Pa11y, etc.) catch approximately **57% of WCAG issues** in controlled audits and often only **20-30% in real-world testing**. After fixing all automated findings, you **must** also perform manual testing:

- **Screen reader testing**: Navigate the entire site with VoiceOver (macOS/iOS), NVDA or JAWS (Windows), or TalkBack (Android). Verify all content is announced correctly, interactive elements are operable, and the reading order makes sense.
- **Keyboard-only testing**: Tab through every page. Confirm all interactive elements are reachable, focus indicators are visible, and there are no keyboard traps.
- **Zoom and reflow testing**: Zoom to 200% and 400%. Verify no content is lost, truncated, or overlapping. Test with browser text-only zoom as well.
- **Color and contrast**: Check beyond what automated tools measure — verify meaning is not conveyed by color alone, and that custom components (tooltips, modals, date pickers) meet contrast requirements.
- **Cognitive and content review**: Ensure error messages are clear, form labels are descriptive, and instructions make sense without visual context.

Automated results are a starting point, not a finish line.

### 2. Automated security scanning has blind spots

Automated security scans check for headers, exposed files, TLS configuration, and known vulnerability patterns — but they **cannot** catch:

- **Business logic vulnerabilities**: Authentication bypasses, privilege escalation, insecure direct object references that depend on application logic.
- **Code-level issues not covered by static rules**: Custom encryption implementations, race conditions, time-of-check/time-of-use bugs.
- **Configuration and infrastructure**: Misconfigured cloud IAM roles, overly permissive S3 buckets, database access controls, API rate limiting.
- **Secrets in private channels**: Credentials shared in Slack, email, or internal wikis that aren't in the codebase.

After automated scanning, you should:

- Have your code reviewed by a human or AI code review tool (e.g., [CodeRabbit](https://coderabbit.ai/)) to catch logic-level security issues.
- Conduct a manual penetration test or threat model for production applications.
- Verify that nothing is publicly accessible that shouldn't be (admin panels, staging environments, debug endpoints, internal APIs).

### 3. Single-page vs. full-site testing

A single-page audit (testing only the homepage or one URL) will **not** catch issues that exist on other pages. Common things missed:

- **Page-specific bugs**: A contact form with XSS, a blog post missing alt text, a checkout page with broken ARIA.
- **Template variations**: Different page templates may have different accessibility or security issues.
- **Dynamic content**: Pages rendered based on user state (logged in/out, different roles) may behave differently.

For comprehensive coverage:

- Use **sitemap mode** to test all pages (CodeFrog supports this natively).
- At minimum, test one representative page from each template/layout type.
- Test pages with forms, authentication flows, and dynamic content separately.

### 4. Desktop-only testing misses mobile issues

Testing only the desktop viewport will miss issues specific to mobile and responsive layouts:

- **Touch target sizes**: Interactive elements should be at least 44x44 CSS pixels per [WCAG 2.5.8](https://www.w3.org/TR/WCAG22/#target-size-minimum) (Level AA in WCAG 2.2).
- **Responsive layout breakage**: Content that overflows, overlaps, or becomes unreachable at narrow viewports.
- **Mobile-specific navigation**: Hamburger menus, drawers, and mobile nav patterns may have keyboard/screen reader issues not present in the desktop nav.
- **Viewport meta tag**: Missing or misconfigured `<meta name="viewport">` can break mobile rendering entirely.
- **Hover-dependent interactions**: Tooltips, dropdowns, or content that only appears on hover is inaccessible on touch devices.

Test at multiple viewport widths (320px, 375px, 768px, 1024px, 1440px) and on actual mobile devices when possible.

### 5. Point-in-time snapshot

An audit reflects the state of the code and site **at the moment it was run**. It does not account for:

- **Future deployments** that may introduce regressions.
- **Third-party script changes**: Analytics, chat widgets, ad scripts, and CDN-hosted libraries can change without your deployment.
- **Content updates**: CMS-managed content, user-generated content, or API-driven content may introduce new issues after the audit.

Run audits regularly — ideally as part of your CI/CD pipeline — not just once before launch.

### 6. Findings require context

Not every finding requires immediate action. Use severity levels to prioritize, but also consider:

- **False positives**: Automated tools can flag correct code as problematic (e.g., a decorative image with intentionally empty alt text).
- **Accepted risk**: Some low-severity findings may be acceptable trade-offs for your use case.
- **Iterative discovery**: Fixing accessibility issues often reveals new ones that were previously hidden by the original violations (e.g., fixing a missing landmark may expose a heading hierarchy issue within it).

Review findings with your team and make informed decisions rather than blindly fixing everything.

---

## Continuous Testing in CI/CD

A one-time audit is useful. Continuous testing is what actually prevents regressions. The goal is to catch issues **before they reach production** by integrating quality checks into your pull request and deployment pipeline.

### What to run on every PR

Set up your CI to run these checks automatically on every pull request that touches relevant code:

#### Accessibility (Pa11y CI + axe-core)

[Pa11y CI](https://github.com/pa11y/pa11y-ci) runs axe-core against a list of URLs and fails the build if WCAG violations are found. Example `.pa11yci` config:

```json
{
  "defaults": {
    "standard": "WCAG2AA",
    "runners": ["axe"],
    "timeout": 30000,
    "wait": 1000,
    "chromeLaunchConfig": {
      "args": ["--no-sandbox", "--disable-setuid-sandbox"]
    }
  },
  "urls": [
    "http://localhost:8000/",
    "http://localhost:8000/about",
    "http://localhost:8000/contact"
  ]
}
```

Add every page and template variation to the URL list. When you add a new page, add it to the list — otherwise it ships untested.

#### Console error checking

Use a headless browser (Puppeteer) to load each page and capture runtime errors:

- JavaScript exceptions and `console.error` output
- Failed network requests (broken scripts, images, API calls)
- CORS errors and CSP violations
- Mixed content warnings (HTTP resources on HTTPS pages)
- Deprecated API warnings

This catches issues that static analysis and linting miss — things that only break at runtime in a real browser. A page can pass HTML validation and accessibility checks and still throw JavaScript errors that break functionality.

#### HTML validation

Run the [Nu HTML Checker (vnu)](https://validator.github.io/validator/) against your pages to catch markup errors, duplicate IDs, invalid nesting, and deprecated elements. Invalid HTML can cause unpredictable behavior in screen readers and browsers.

#### Static analysis and linting

Run your language-specific linters and static analysis tools (ESLint, Semgrep, etc.) on every PR. These catch code quality and security issues at the source level before they ever reach a browser.

### Example CI workflow (GitHub Actions)

Here's a simplified example of how to wire this up:

```yaml
name: Quality Checks

on:
  pull_request:
    branches: [main]
    paths:
      - 'your-site/**'

jobs:
  accessibility:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP (or your server)
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.2'

      - name: Start local server
        run: |
          php -S localhost:8000 -t your-site/ &
          sleep 3

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install Pa11y CI
        run: npm install -g pa11y-ci puppeteer

      - name: Run console error checks
        run: node scripts/check-console-errors.js

      - name: Run accessibility tests
        run: pa11y-ci
```

### What to run on a schedule

Some checks are too slow or too broad for every PR but should still run regularly:

- **Full sitemap crawl**: Test every URL on the site weekly or after major deployments.
- **Dependency vulnerability scan (OSV/npm audit)**: Run daily — new CVEs are published constantly.
- **Secrets detection (Gitleaks)**: Run on the full git history periodically, not just the diff.
- **Broken link checking**: External links break without any change on your end. Check weekly.

### AI code review on PRs

Tools like [CodeRabbit](https://coderabbit.ai/) can review every pull request automatically for security issues, code quality, accessibility patterns, and best practices. This complements automated testing by catching logic-level issues that linters and scanners miss — things like insecure authentication flows, missing input validation, or accessibility anti-patterns in component structure.

### The principle

**If it's not in CI, it will regress.** Manual audits find issues. Continuous testing prevents them from coming back. Every check in this document that can be automated should be automated and run on every pull request.

---

## Tone

Direct, actionable, developer-friendly. No fluff. Like a senior dev doing a code review who actually cares — but one who has actually read the specs.

---

*This document is maintained by [CodeFrog](https://codefrog.app). For the real thing with automated parallel testing, health scoring, report history, and export — download CodeFrog.*
