"""
TradingView Chart Scraper
Captures screenshots of XAUUSD charts with image optimization
"""
import asyncio
import time
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Optional, Tuple
import os

from PIL import Image, ImageEnhance, ImageFilter
from loguru import logger

from anti_detect_browser import AntiDetectBrowser
from config import TRADINGVIEW_CONFIG, IMAGE_CONFIG, SCREENSHOTS_DIR


class TradingViewScraper:
    """
    TradingView chart scraper with screenshot and image processing capabilities
    """

    def __init__(self, profile_name: str = "tradingview"):
        self.profile_name = profile_name
        self.browser: Optional[AntiDetectBrowser] = None
        self.chart_loaded = False
        self.last_screenshot_time = 0

        # Ensure screenshots directory exists
        SCREENSHOTS_DIR.mkdir(parents=True, exist_ok=True)

        logger.info("TradingView scraper initialized")

    async def start(self):
        """Start the TradingView scraper"""
        try:
            self.browser = AntiDetectBrowser(self.profile_name)
            await self.browser.start_browser(mobile=False)

            # Navigate to TradingView chart
            await self._load_chart()

            logger.info("TradingView scraper started successfully")

        except Exception as e:
            logger.error(f"Failed to start TradingView scraper: {e}")
            await self.cleanup()
            raise

    async def _load_chart(self):
        """Load and prepare the TradingView chart"""
        try:
            logger.info("Loading TradingView chart...")

            # Navigate to chart page
            await self.browser.navigate_to(
                TRADINGVIEW_CONFIG["url"],
                timeout=30000
            )

            # Wait for chart to load
            await asyncio.sleep(TRADINGVIEW_CONFIG["wait_for_chart"] / 1000)

            # Try to dismiss any popups or login prompts
            await self._dismiss_popups()

            # Wait for chart container to be visible
            try:
                await self.browser.page.wait_for_selector(
                    TRADINGVIEW_CONFIG["chart_selector"],
                    timeout=15000
                )
                self.chart_loaded = True
                logger.info("Chart loaded successfully")
            except:
                # Try alternative selector
                await self.browser.page.wait_for_selector(
                    TRADINGVIEW_CONFIG["chart_area_selector"],
                    timeout=10000
                )
                self.chart_loaded = True
                logger.info("Chart loaded with alternative selector")

            # Optimize chart view
            await self._optimize_chart_view()

        except Exception as e:
            logger.error(f"Failed to load chart: {e}")
            raise

    async def _dismiss_popups(self):
        """Dismiss any popups or modal dialogs"""
        try:
            # Common popup selectors
            popup_selectors = [
                "[data-name='close']",
                ".close-button",
                ".modal-close",
                "[aria-label='Close']",
                ".tv-dialog__close",
                ".js-dialog__close",
                ".close",
                "[data-role='button'][aria-label*='close']"
            ]

            for selector in popup_selectors:
                try:
                    element = await self.browser.page.query_selector(selector)
                    if element and await element.is_visible():
                        await element.click()
                        await asyncio.sleep(0.5)
                        logger.debug(f"Dismissed popup with selector: {selector}")
                except:
                    continue

            # Press Escape key to close any remaining popups
            await self.browser.page.keyboard.press("Escape")
            await asyncio.sleep(1)

        except Exception as e:
            logger.warning(f"Error dismissing popups: {e}")

    async def _optimize_chart_view(self):
        """Optimize chart view for better screenshots"""
        try:
            # Try to maximize chart area
            await self.browser.page.evaluate("""
                // Hide unnecessary UI elements
                const elementsToHide = [
                    '.tv-header',
                    '.tv-footer',
                    '.tv-chart-toolbar',
                    '.tv-floating-toolbar',
                    '.tv-alerts-button',
                    '.tv-toast-logger'
                ];

                elementsToHide.forEach(selector => {
                    const elements = document.querySelectorAll(selector);
                    elements.forEach(el => {
                        if (el) el.style.display = 'none';
                    });
                });

                // Ensure chart is fully visible
                const chartContainer = document.querySelector('.chart-container, .layout__area--center');
                if (chartContainer) {
                    chartContainer.scrollIntoView();
                }
            """)

            await asyncio.sleep(2)
            logger.debug("Optimized chart view")

        except Exception as e:
            logger.warning(f"Failed to optimize chart view: {e}")

    async def capture_chart_screenshot(self, filename: Optional[str] = None) -> Optional[str]:
        """Capture a screenshot of the chart"""
        try:
            if not self.chart_loaded:
                logger.error("Chart not loaded, cannot take screenshot")
                return None

            # Generate filename if not provided
            if not filename:
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f"xauusd_chart_{timestamp}.jpg"

            screenshot_path = SCREENSHOTS_DIR / filename

            # Take screenshot of chart area
            try:
                # Try chart-specific selector first
                await self.browser.take_screenshot(
                    str(screenshot_path),
                    selector=TRADINGVIEW_CONFIG["chart_selector"],
                    quality=TRADINGVIEW_CONFIG["chart_quality"]
                )
            except:
                # Fallback to full page screenshot
                await self.browser.take_screenshot(
                    str(screenshot_path),
                    quality=TRADINGVIEW_CONFIG["chart_quality"]
                )

            # Process the image
            processed_path = await self._process_image(screenshot_path)

            self.last_screenshot_time = time.time()
            logger.info(f"Chart screenshot captured: {processed_path}")

            return str(processed_path)

        except Exception as e:
            logger.error(f"Failed to capture screenshot: {e}")
            return None

    async def _process_image(self, image_path: Path) -> Path:
        """Process and optimize the screenshot image"""
        try:
            # Load image with Pillow
            with Image.open(image_path) as img:
                # Convert to RGB if necessary
                if img.mode != 'RGB':
                    img = img.convert('RGB')

                # Resize if too large
                max_size = IMAGE_CONFIG["max_size"]
                if img.size[0] > max_size[0] or img.size[1] > max_size[1]:
                    img.thumbnail(max_size, Image.Resampling.LANCZOS)
                    logger.debug(f"Resized image to: {img.size}")

                # Enhance image quality
                img = self._enhance_image(img)

                # Save optimized image
                optimized_path = image_path.with_suffix(f"_optimized{image_path.suffix}")
                img.save(
                    optimized_path,
                    format=IMAGE_CONFIG["format"],
                    quality=IMAGE_CONFIG["quality"],
                    optimize=True
                )

            # Use ImageMagick for additional optimization if available
            magick_path = await self._imagemagick_optimize(optimized_path)
            if magick_path:
                # Remove intermediate file
                if optimized_path.exists():
                    optimized_path.unlink()
                return magick_path

            # Remove original unoptimized file
            if image_path.exists() and image_path != optimized_path:
                image_path.unlink()

            return optimized_path

        except Exception as e:
            logger.error(f"Image processing failed: {e}")
            return image_path

    def _enhance_image(self, img: Image.Image) -> Image.Image:
        """Enhance image quality for better analysis"""
        try:
            # Adjust contrast slightly
            enhancer = ImageEnhance.Contrast(img)
            img = enhancer.enhance(1.1)

            # Adjust sharpness slightly
            enhancer = ImageEnhance.Sharpness(img)
            img = enhancer.enhance(1.1)

            # Apply subtle noise reduction
            img = img.filter(ImageFilter.SMOOTH_MORE)

            return img

        except Exception as e:
            logger.warning(f"Image enhancement failed: {e}")
            return img

    async def _imagemagick_optimize(self, image_path: Path) -> Optional[Path]:
        """Optimize image using ImageMagick if available"""
        try:
            # Check if ImageMagick is available
            result = subprocess.run(["convert", "-version"],
                                  capture_output=True, text=True)
            if result.returncode != 0:
                logger.debug("ImageMagick not available, skipping")
                return None

            # Create optimized version
            magick_path = image_path.with_suffix(f"_magick{image_path.suffix}")

            # Build ImageMagick command
            cmd = [
                "convert",
                str(image_path)
            ] + IMAGE_CONFIG["imagemagick_options"] + [str(magick_path)]

            # Run ImageMagick optimization
            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode == 0 and magick_path.exists():
                logger.debug("ImageMagick optimization successful")
                return magick_path
            else:
                logger.warning(f"ImageMagick failed: {result.stderr}")
                return None

        except Exception as e:
            logger.warning(f"ImageMagick optimization failed: {e}")
            return None

    async def is_chart_updated(self) -> bool:
        """Check if chart has been updated since last screenshot"""
        try:
            # Simple time-based check for now
            current_time = time.time()
            return (current_time - self.last_screenshot_time) >= TRADINGVIEW_CONFIG["screenshot_interval"]

        except Exception as e:
            logger.error(f"Failed to check chart update: {e}")
            return True

    async def refresh_chart(self):
        """Refresh the chart data"""
        try:
            # Refresh the page
            await self.browser.page.reload(wait_until="domcontentloaded")

            # Wait for chart to reload
            await asyncio.sleep(TRADINGVIEW_CONFIG["wait_for_chart"] / 1000)

            # Dismiss any new popups
            await self._dismiss_popups()

            # Re-optimize view
            await self._optimize_chart_view()

            logger.info("Chart refreshed successfully")

        except Exception as e:
            logger.error(f"Failed to refresh chart: {e}")
            raise

    async def get_latest_screenshot(self) -> Optional[str]:
        """Get the most recent chart screenshot"""
        try:
            screenshots = list(SCREENSHOTS_DIR.glob("xauusd_chart_*.jpg"))
            if not screenshots:
                return None

            # Sort by modification time and get latest
            latest = max(screenshots, key=lambda p: p.stat().st_mtime)
            return str(latest)

        except Exception as e:
            logger.error(f"Failed to get latest screenshot: {e}")
            return None

    async def cleanup_old_screenshots(self, max_files: int = 50):
        """Clean up old screenshot files"""
        try:
            screenshots = list(SCREENSHOTS_DIR.glob("xauusd_chart_*.jpg"))

            if len(screenshots) > max_files:
                # Sort by modification time
                screenshots.sort(key=lambda p: p.stat().st_mtime)

                # Remove oldest files
                files_to_remove = screenshots[:-max_files]
                for file_path in files_to_remove:
                    file_path.unlink()
                    logger.debug(f"Removed old screenshot: {file_path.name}")

                logger.info(f"Cleaned up {len(files_to_remove)} old screenshots")

        except Exception as e:
            logger.error(f"Failed to cleanup screenshots: {e}")

    async def run_continuous_capture(self, interval: int = None):
        """Run continuous chart capture at specified interval"""
        if interval is None:
            interval = TRADINGVIEW_CONFIG["screenshot_interval"]

        logger.info(f"Starting continuous capture every {interval} seconds")

        try:
            while True:
                # Take screenshot
                screenshot_path = await self.capture_chart_screenshot()

                if screenshot_path:
                    logger.info(f"Captured chart: {screenshot_path}")
                else:
                    logger.warning("Failed to capture chart screenshot")

                # Clean up old files periodically
                if time.time() % 3600 < interval:  # Once per hour
                    await self.cleanup_old_screenshots()

                # Wait for next interval
                await asyncio.sleep(interval)

        except KeyboardInterrupt:
            logger.info("Continuous capture interrupted by user")
        except Exception as e:
            logger.error(f"Continuous capture failed: {e}")
            raise

    async def cleanup(self):
        """Clean up resources"""
        try:
            if self.browser:
                await self.browser.cleanup()
                self.browser = None

            logger.info("TradingView scraper cleanup completed")

        except Exception as e:
            logger.error(f"Cleanup failed: {e}")

    async def __aenter__(self):
        """Async context manager entry"""
        await self.start()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit"""
        await self.cleanup()
