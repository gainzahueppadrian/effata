"""
Advanced Anti-Detection Browser Class
Provides stealth browsing capabilities with fingerprint spoofing and proxy support
"""
import asyncio
import random
import json
import time
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass

from playwright.async_api import async_playwright, Browser, BrowserContext, Page
from fake_useragent import UserAgent
from loguru import logger

from config import BROWSER_CONFIG, ANTI_DETECT_CONFIG


@dataclass
class BrowserFingerprint:
    """Browser fingerprint configuration"""
    user_agent: str
    viewport: Dict[str, int]
    locale: str
    timezone: str
    platform: str
    languages: List[str]
    plugins: List[str]
    webgl_vendor: str
    webgl_renderer: str
    screen_resolution: Dict[str, int]
    color_depth: int
    pixel_ratio: float


class AntiDetectBrowser:
    """
    Advanced anti-detection browser with spoofed fingerprints and proxy support
    """

    def __init__(self, profile_name: str = "default"):
        self.profile_name = profile_name
        self.playwright = None
        self.browser: Optional[Browser] = None
        self.context: Optional[BrowserContext] = None
        self.page: Optional[Page] = None
        self.ua = UserAgent()
        self.current_fingerprint: Optional[BrowserFingerprint] = None
        self.session_cookies: Dict[str, Any] = {}

        # Profile directory
        self.profile_dir = Path(BROWSER_CONFIG["user_data_dir"]) / profile_name
        self.profile_dir.mkdir(parents=True, exist_ok=True)

        logger.info(f"Initialized AntiDetectBrowser with profile: {profile_name}")

    def generate_fingerprint(self, mobile: bool = False) -> BrowserFingerprint:
        """Generate a realistic browser fingerprint"""

        if mobile:
            user_agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
            viewport = {"width": 390, "height": 844}
            screen_resolution = {"width": 390, "height": 844}
            platform = "iPhone"
            pixel_ratio = 3.0
        else:
            user_agent = random.choice(ANTI_DETECT_CONFIG["user_agents"])
            viewport = {"width": random.randint(1366, 1920), "height": random.randint(768, 1080)}
            screen_resolution = {"width": viewport["width"], "height": viewport["height"]}
            platform = random.choice(["Win32", "MacIntel", "Linux x86_64"])
            pixel_ratio = random.choice([1.0, 1.25, 1.5, 2.0])

        languages = random.choice([
            ["en-US", "en"],
            ["en-GB", "en"],
            ["en-CA", "en", "fr"],
            ["en-AU", "en"]
        ])

        timezone = random.choice([
            "America/New_York",
            "America/Los_Angeles",
            "America/Chicago",
            "Europe/London",
            "Europe/Berlin"
        ])

        webgl_vendors = ["Google Inc.", "NVIDIA Corporation", "AMD", "Intel Inc."]
        webgl_renderers = [
            "ANGLE (NVIDIA GeForce GTX 1060 Direct3D11 vs_5_0 ps_5_0)",
            "ANGLE (AMD Radeon RX 580 Direct3D11 vs_5_0 ps_5_0)",
            "Intel(R) UHD Graphics 620"
        ]

        fingerprint = BrowserFingerprint(
            user_agent=user_agent,
            viewport=viewport,
            locale=random.choice(["en-US", "en-GB", "en-CA"]),
            timezone=timezone,
            platform=platform,
            languages=languages,
            plugins=["Chrome PDF Plugin", "Chrome PDF Viewer", "Native Client"],
            webgl_vendor=random.choice(webgl_vendors),
            webgl_renderer=random.choice(webgl_renderers),
            screen_resolution=screen_resolution,
            color_depth=random.choice([24, 32]),
            pixel_ratio=pixel_ratio
        )

        logger.debug(f"Generated fingerprint: {fingerprint.user_agent[:50]}...")
        return fingerprint

    async def start_browser(self, mobile: bool = False, proxy: Optional[Dict] = None):
        """Start browser with anti-detection measures"""
        try:
            self.playwright = await async_playwright().start()

            # Generate fingerprint
            self.current_fingerprint = self.generate_fingerprint(mobile=mobile)

            # Browser launch arguments
            launch_args = [
                "--no-sandbox",
                "--disable-blink-features=AutomationControlled",
                "--disable-features=VizDisplayCompositor",
                "--disable-dev-shm-usage",
                "--disable-extensions-except=/path/to/extension",
                "--disable-plugins-discovery",
                "--disable-gpu",
                "--no-first-run",
                "--no-default-browser-check",
                "--disable-default-apps",
                "--disable-popup-blocking",
                "--disable-translate",
                "--disable-background-timer-throttling",
                "--disable-renderer-backgrounding",
                "--disable-device-discovery-notifications",
                "--disable-web-security",
                "--disable-features=TranslateUI",
                "--disable-ipc-flooding-protection",
                "--user-agent=" + self.current_fingerprint.user_agent
            ]

            if BROWSER_CONFIG["headless"]:
                launch_args.append("--headless=new")

            # Launch browser
            self.browser = await self.playwright.chromium.launch(
                headless=BROWSER_CONFIG["headless"],
                args=launch_args,
                ignore_default_args=["--enable-automation"]
            )

            # Create context with stealth settings
            context_options = {
                "viewport": self.current_fingerprint.viewport,
                "user_agent": self.current_fingerprint.user_agent,
                "locale": self.current_fingerprint.locale,
                "timezone_id": self.current_fingerprint.timezone,
                "permissions": BROWSER_CONFIG["permissions"],
                "geolocation": BROWSER_CONFIG["geolocation"],
                "extra_http_headers": BROWSER_CONFIG["extra_http_headers"],
                "ignore_https_errors": True,
                "java_script_enabled": True,
                "bypass_csp": True
            }

            if proxy:
                context_options["proxy"] = proxy
                logger.info(f"Using proxy: {proxy['server']}")

            self.context = await self.browser.new_context(**context_options)

            # Add stealth scripts
            await self._add_stealth_scripts()

            # Create page
            self.page = await self.context.new_page()

            # Additional stealth measures
            await self._apply_stealth_measures()

            logger.info("Anti-detect browser started successfully")

        except Exception as e:
            logger.error(f"Failed to start browser: {e}")
            await self.cleanup()
            raise

    async def _add_stealth_scripts(self):
        """Add stealth JavaScript to context"""
        stealth_script = """
        // Override webdriver property
        Object.defineProperty(navigator, 'webdriver', {
            get: () => undefined,
        });

        // Override plugins
        Object.defineProperty(navigator, 'plugins', {
            get: () => [1, 2, 3, 4, 5],
        });

        // Override languages
        Object.defineProperty(navigator, 'languages', {
            get: () => %s,
        });

        // Override platform
        Object.defineProperty(navigator, 'platform', {
            get: () => '%s',
        });

        // Override permissions
        const originalQuery = window.navigator.permissions.query;
        window.navigator.permissions.query = (parameters) => (
            parameters.name === 'notifications' ?
                Promise.resolve({ state: Notification.permission }) :
                originalQuery(parameters)
        );

        // Override chrome runtime
        Object.defineProperty(window, 'chrome', {
            writable: true,
            enumerable: true,
            configurable: false,
            value: {
                runtime: {}
            }
        });

        // Screen resolution spoofing
        Object.defineProperty(screen, 'width', {
            get: () => %d,
        });
        Object.defineProperty(screen, 'height', {
            get: () => %d,
        });
        Object.defineProperty(screen, 'colorDepth', {
            get: () => %d,
        });

        // WebGL fingerprint spoofing
        const getParameter = WebGLRenderingContext.prototype.getParameter;
        WebGLRenderingContext.prototype.getParameter = function(parameter) {
            if (parameter === 37445) {
                return '%s';
            }
            if (parameter === 37446) {
                return '%s';
            }
            return getParameter(parameter);
        };
        """ % (
            json.dumps(self.current_fingerprint.languages),
            self.current_fingerprint.platform,
            self.current_fingerprint.screen_resolution["width"],
            self.current_fingerprint.screen_resolution["height"],
            self.current_fingerprint.color_depth,
            self.current_fingerprint.webgl_vendor,
            self.current_fingerprint.webgl_renderer
        )

        await self.context.add_init_script(stealth_script)
        logger.debug("Added stealth scripts to context")

    async def _apply_stealth_measures(self):
        """Apply additional stealth measures to the page"""
        # Block automation detection
        await self.page.evaluate("""
            delete window.cdc_adoQpoasnfa76pfcZLmcfl_Array;
            delete window.cdc_adoQpoasnfa76pfcZLmcfl_Promise;
            delete window.cdc_adoQpoasnfa76pfcZLmcfl_Symbol;
        """)

        # Random mouse movements
        await self._random_mouse_movement()

        logger.debug("Applied stealth measures to page")

    async def _random_mouse_movement(self):
        """Simulate random mouse movements"""
        if self.page:
            try:
                viewport = self.current_fingerprint.viewport
                x = random.randint(100, viewport["width"] - 100)
                y = random.randint(100, viewport["height"] - 100)
                await self.page.mouse.move(x, y)
                await asyncio.sleep(random.uniform(0.1, 0.3))
            except Exception as e:
                logger.warning(f"Mouse movement failed: {e}")

    async def navigate_to(self, url: str, wait_for: Optional[str] = None, timeout: int = 30000):
        """Navigate to URL with anti-detection measures"""
        try:
            # Random delay before navigation
            if ANTI_DETECT_CONFIG["random_delays"]:
                delay = random.uniform(*ANTI_DETECT_CONFIG["delay_range"])
                await asyncio.sleep(delay)

            # Navigate
            await self.page.goto(url, wait_until="domcontentloaded", timeout=timeout)

            # Wait for specific element if provided
            if wait_for:
                await self.page.wait_for_selector(wait_for, timeout=timeout)

            # Random mouse movement after load
            await self._random_mouse_movement()

            logger.info(f"Successfully navigated to: {url}")

        except Exception as e:
            logger.error(f"Navigation failed: {e}")
            raise

    async def click_element(self, selector: str, timeout: int = 10000):
        """Click element with human-like behavior"""
        try:
            element = await self.page.wait_for_selector(selector, timeout=timeout)

            # Scroll into view
            await element.scroll_into_view_if_needed()

            # Random delay
            await asyncio.sleep(random.uniform(0.5, 1.5))

            # Human-like click
            await element.click()

            # Small delay after click
            await asyncio.sleep(random.uniform(0.2, 0.8))

            logger.debug(f"Clicked element: {selector}")

        except Exception as e:
            logger.error(f"Failed to click element {selector}: {e}")
            raise

    async def type_text(self, selector: str, text: str, clear_first: bool = True, timeout: int = 10000):
        """Type text with human-like behavior"""
        try:
            element = await self.page.wait_for_selector(selector, timeout=timeout)

            # Clear field if requested
            if clear_first:
                await element.click()
                await self.page.keyboard.press("Control+a")
                await asyncio.sleep(0.1)

            # Type with random delays between characters
            for char in text:
                await self.page.keyboard.type(char)
                await asyncio.sleep(random.uniform(0.05, 0.15))

            logger.debug(f"Typed text into {selector}: {text[:50]}...")

        except Exception as e:
            logger.error(f"Failed to type text into {selector}: {e}")
            raise

    async def take_screenshot(self, path: str, selector: Optional[str] = None, quality: int = 95):
        """Take screenshot with optional element selection"""
        try:
            screenshot_options = {
                "path": path,
                "quality": quality,
                "type": "jpeg"
            }

            if selector:
                element = await self.page.wait_for_selector(selector)
                await element.screenshot(**screenshot_options)
            else:
                await self.page.screenshot(**screenshot_options)

            logger.info(f"Screenshot saved: {path}")
            return path

        except Exception as e:
            logger.error(f"Screenshot failed: {e}")
            raise

    async def wait_for_response(self, selector: str, timeout: int = 60000) -> str:
        """Wait for and extract response text"""
        try:
            await self.page.wait_for_selector(selector, timeout=timeout)

            # Wait a bit more for content to load
            await asyncio.sleep(2)

            element = await self.page.query_selector(selector)
            if element:
                text = await element.inner_text()
                logger.info(f"Extracted response: {text[:100]}...")
                return text.strip()

            return ""

        except Exception as e:
            logger.error(f"Failed to wait for response: {e}")
            return ""

    async def get_cookies(self) -> List[Dict]:
        """Get current session cookies"""
        if self.context:
            return await self.context.cookies()
        return []

    async def set_cookies(self, cookies: List[Dict]):
        """Set session cookies"""
        if self.context:
            await self.context.add_cookies(cookies)
            logger.debug("Set session cookies")

    async def cleanup(self):
        """Clean up browser resources"""
        try:
            if self.page:
                await self.page.close()
                self.page = None

            if self.context:
                await self.context.close()
                self.context = None

            if self.browser:
                await self.browser.close()
                self.browser = None

            if self.playwright:
                await self.playwright.stop()
                self.playwright = None

            logger.info("Browser cleanup completed")

        except Exception as e:
            logger.error(f"Cleanup failed: {e}")

    async def __aenter__(self):
        """Async context manager entry"""
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit"""
        await self.cleanup()
