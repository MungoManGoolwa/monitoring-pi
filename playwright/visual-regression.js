const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const PAGES = [
  { name: 'home', url: 'https://musick.com.au/' },
  { name: 'gigs', url: 'https://musick.com.au/gigs/' },
  { name: 'whats-on', url: 'https://musick.com.au/whats-on/' },
  { name: 'this-weekend', url: 'https://musick.com.au/this-weekend/' },
  { name: 'tonight', url: 'https://musick.com.au/tonight/' },
  { name: 'artists', url: 'https://musick.com.au/artists/' },
  { name: 'venues', url: 'https://musick.com.au/venues/' },
  { name: 'trending', url: 'https://musick.com.au/trending/' },
  { name: 'festivals', url: 'https://musick.com.au/festivals/' },
  { name: 'charts', url: 'https://musick.com.au/charts/' },
  { name: 'playlists', url: 'https://musick.com.au/playlists/' },
  { name: 'awards', url: 'https://musick.com.au/awards/' },
  { name: 'lists', url: 'https://musick.com.au/lists/' },
];

const SCREENSHOT_DIR = '/app/screenshots';
const BASELINE_DIR = path.join(SCREENSHOT_DIR, 'baseline');
const CURRENT_DIR = path.join(SCREENSHOT_DIR, 'current');
const DIFF_DIR = path.join(SCREENSHOT_DIR, 'diff');
const VM_URL = process.env.VM_IMPORT_URL || 'http://victoria-metrics:8428/api/v1/import/prometheus';

async function takeScreenshots() {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const context = await browser.newContext({
    viewport: { width: 1920, height: 1080 },
    userAgent: 'Mozilla/5.0 (monitoring-pi visual-regression)',
  });

  const results = [];

  for (const page of PAGES) {
    const tab = await context.newPage();
    const startTime = Date.now();
    let status = 'ok';
    let httpStatus = 0;

    try {
      const response = await tab.goto(page.url, {
        waitUntil: 'networkidle',
        timeout: 60000,
      });
      httpStatus = response ? response.status() : 0;

      // Wait for any lazy-loaded content
      await tab.waitForTimeout(2000);

      const screenshotPath = path.join(CURRENT_DIR, `${page.name}.png`);
      await tab.screenshot({ path: screenshotPath, fullPage: true });

      const loadTime = Date.now() - startTime;

      // Check if baseline exists
      const baselinePath = path.join(BASELINE_DIR, `${page.name}.png`);
      let diffPercent = 0;

      if (fs.existsSync(baselinePath)) {
        // Use ImageMagick compare if available
        try {
          const result = execSync(
            `compare -metric AE "${baselinePath}" "${screenshotPath}" "${path.join(DIFF_DIR, page.name + '-diff.png')}" 2>&1 || true`,
            { encoding: 'utf8' }
          );
          const diffPixels = parseInt(result.trim()) || 0;
          // Rough percentage (based on 1920x1080 viewport)
          diffPercent = diffPixels / (1920 * 1080);
          if (diffPercent > 0.05) {
            status = 'visual_change';
          }
        } catch (e) {
          // ImageMagick not available, skip diff
          diffPercent = -1;
        }
      } else {
        // First run — save as baseline
        fs.copyFileSync(screenshotPath, baselinePath);
        status = 'baseline_created';
      }

      results.push({
        name: page.name,
        url: page.url,
        status,
        httpStatus,
        loadTime,
        diffPercent,
      });

      console.log(`${page.name}: HTTP ${httpStatus}, ${loadTime}ms, ${status}${diffPercent >= 0 ? `, diff: ${(diffPercent * 100).toFixed(2)}%` : ''}`);
    } catch (e) {
      results.push({
        name: page.name,
        url: page.url,
        status: 'error',
        httpStatus: 0,
        loadTime: Date.now() - startTime,
        diffPercent: 0,
        error: e.message,
      });
      console.error(`${page.name}: ERROR - ${e.message}`);
    }

    await tab.close();
  }

  await browser.close();

  // Push metrics to VictoriaMetrics
  const metrics = results.flatMap((r) => [
    `visual_regression_http_status{page="${r.name}",url="${r.url}"} ${r.httpStatus}`,
    `visual_regression_load_time_ms{page="${r.name}",url="${r.url}"} ${r.loadTime}`,
    `visual_regression_diff_percent{page="${r.name}",url="${r.url}"} ${Math.max(0, r.diffPercent)}`,
    `visual_regression_success{page="${r.name}",url="${r.url}"} ${r.status === 'ok' || r.status === 'baseline_created' ? 1 : 0}`,
  ]);

  try {
    const data = metrics.join('\n') + '\n';
    const http = require('http');
    const url = new URL(VM_URL);
    const req = http.request({ hostname: url.hostname, port: url.port, path: url.pathname, method: 'POST', headers: { 'Content-Type': 'text/plain' } });
    req.write(data);
    req.end();
    console.log(`\nPushed ${metrics.length} metrics to VictoriaMetrics`);
  } catch (e) {
    console.error(`Failed to push metrics: ${e.message}`);
  }

  // Summary
  const errors = results.filter((r) => r.status === 'error');
  const changes = results.filter((r) => r.status === 'visual_change');
  console.log(`\n=== Summary ===`);
  console.log(`Total: ${results.length}, OK: ${results.length - errors.length - changes.length}, Changes: ${changes.length}, Errors: ${errors.length}`);

  if (errors.length > 0) process.exit(1);
}

takeScreenshots();
