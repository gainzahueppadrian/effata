#!/usr/bin/env python3
"""
Installation Test Script
Validates that all components are working correctly
"""
import asyncio
import sys
import subprocess
from pathlib import Path

from loguru import logger


async def test_imports():
    """Test that all required modules can be imported"""
    logger.info("🔍 Testing imports...")

    try:
        # Core modules
        import asyncio
        import json
        import time
        from datetime import datetime
        from pathlib import Path
        logger.info("✅ Core Python modules")

        # Third-party modules
        from playwright.async_api import async_playwright
        logger.info("✅ Playwright")

        from bs4 import BeautifulSoup
        logger.info("✅ BeautifulSoup")

        from PIL import Image
        logger.info("✅ PIL (Pillow)")

        from fake_useragent import UserAgent
        logger.info("✅ Fake UserAgent")

        from loguru import logger as loguru_logger
        logger.info("✅ Loguru")

        # Project modules
        from config import TRADINGVIEW_CONFIG, LMARENA_CONFIG
        logger.info("✅ Configuration")

        from anti_detect_browser import AntiDetectBrowser
        logger.info("✅ Anti-Detect Browser")

        from tradingview_scraper import TradingViewScraper
        logger.info("✅ TradingView Scraper")

        from lmarena_scraper import LMArenaScaper
        logger.info("✅ LMArena Scraper")

        from trading_analyzer import TradingAnalyzer
        logger.info("✅ Trading Analyzer")

        from utils import setup_logging
        logger.info("✅ Utilities")

        logger.info("✅ All imports successful")
        return True

    except ImportError as e:
        logger.error(f"❌ Import failed: {e}")
        return False
    except Exception as e:
        logger.error(f"❌ Import error: {e}")
        return False


async def test_playwright():
    """Test Playwright browser functionality"""
    logger.info("🌐 Testing Playwright browser...")

    try:
        from playwright.async_api import async_playwright

        async with async_playwright() as p:
            # Launch browser
            browser = await p.chromium.launch(headless=True)
            logger.info("✅ Browser launched")

            # Create page
            page = await browser.new_page()
            logger.info("✅ Page created")

            # Navigate to test page
            await page.goto("data:text/html,<h1>Test Page</h1><p>Playwright is working!</p>")
            logger.info("✅ Navigation successful")

            # Get content
            content = await page.content()
            if "Test Page" in content:
                logger.info("✅ Content extraction successful")
            else:
                logger.error("❌ Content extraction failed")
                return False

            # Take screenshot
            temp_screenshot = Path("temp_test_screenshot.png")
            await page.screenshot(path=str(temp_screenshot))

            if temp_screenshot.exists():
                logger.info("✅ Screenshot capability working")
                temp_screenshot.unlink()  # Clean up
            else:
                logger.error("❌ Screenshot failed")
                return False

            # Close browser
            await browser.close()
            logger.info("✅ Browser closed successfully")

        logger.info("✅ Playwright test successful")
        return True

    except Exception as e:
        logger.error(f"❌ Playwright test failed: {e}")
        return False


async def test_anti_detect_browser():
    """Test anti-detection browser functionality"""
    logger.info("🕵️ Testing anti-detection browser...")

    try:
        from anti_detect_browser import AntiDetectBrowser

        # Test browser initialization
        browser = AntiDetectBrowser("test_profile")
        await browser.start_browser(mobile=False)
        logger.info("✅ Anti-detect browser started")

        # Test navigation
        await browser.navigate_to("data:text/html,<h1>Anti-Detection Test</h1>")
        logger.info("✅ Navigation successful")

        # Test fingerprint generation
        fingerprint = browser.current_fingerprint
        if fingerprint and fingerprint.user_agent:
            logger.info("✅ Fingerprint generation working")
            logger.info(f"   User Agent: {fingerprint.user_agent[:50]}...")
        else:
            logger.error("❌ Fingerprint generation failed")
            return False

        # Test screenshot
        temp_screenshot = Path("temp_antidetect_screenshot.jpg")
        await browser.take_screenshot(str(temp_screenshot))

        if temp_screenshot.exists():
            logger.info("✅ Screenshot capability working")
            temp_screenshot.unlink()  # Clean up
        else:
            logger.error("❌ Screenshot failed")
            return False

        # Cleanup
        await browser.cleanup()
        logger.info("✅ Browser cleanup successful")

        logger.info("✅ Anti-detection browser test successful")
        return True

    except Exception as e:
        logger.error(f"❌ Anti-detection browser test failed: {e}")
        return False


async def test_image_processing():
    """Test image processing capabilities"""
    logger.info("🖼️ Testing image processing...")

    try:
        from PIL import Image, ImageDraw
        import io

        # Create test image
        img = Image.new('RGB', (800, 600), color='blue')
        draw = ImageDraw.Draw(img)
        draw.text((10, 10), "Test Image", fill='white')

        # Save test image
        test_image_path = Path("temp_test_image.jpg")
        img.save(test_image_path, "JPEG", quality=85)
        logger.info("✅ Image creation successful")

        # Test image loading and processing
        with Image.open(test_image_path) as loaded_img:
            # Test resize
            loaded_img.thumbnail((400, 300))
            logger.info("✅ Image resize working")

            # Test format conversion
            if loaded_img.mode != 'RGB':
                loaded_img = loaded_img.convert('RGB')
            logger.info("✅ Image format conversion working")

        # Test ImageMagick if available
        try:
            result = subprocess.run(["convert", "-version"], capture_output=True, text=True)
            if result.returncode == 0:
                logger.info("✅ ImageMagick available")

                # Test ImageMagick operation
                magick_output = test_image_path.with_suffix("_magick.jpg")
                cmd = ["convert", str(test_image_path), "-quality", "70", str(magick_output)]
                result = subprocess.run(cmd, capture_output=True, text=True)

                if result.returncode == 0 and magick_output.exists():
                    logger.info("✅ ImageMagick processing working")
                    magick_output.unlink()  # Clean up
                else:
                    logger.warning("⚠️ ImageMagick processing failed")
            else:
                logger.warning("⚠️ ImageMagick not available")
        except FileNotFoundError:
            logger.warning("⚠️ ImageMagick not found")

        # Clean up
        test_image_path.unlink()

        logger.info("✅ Image processing test successful")
        return True

    except Exception as e:
        logger.error(f"❌ Image processing test failed: {e}")
        return False


async def test_web_access():
    """Test web access to target sites"""
    logger.info("🌐 Testing web access...")

    try:
        import httpx

        urls_to_test = [
            ("TradingView", "https://www.tradingview.com"),
            ("LMArena", "https://lmarena.ai"),
            ("Test Site", "https://httpbin.org/user-agent")
        ]

        async with httpx.AsyncClient(
            headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"},
            timeout=30.0,
            follow_redirects=True
        ) as client:

            for name, url in urls_to_test:
                try:
                    response = await client.get(url)

                    if response.status_code == 200:
                        logger.info(f"✅ {name} accessible (200)")
                    elif response.status_code in [301, 302, 307, 308]:
                        logger.info(f"✅ {name} redirected ({response.status_code})")
                    else:
                        logger.warning(f"⚠️ {name} returned {response.status_code}")

                except httpx.TimeoutException:
                    logger.warning(f"⚠️ {name} timeout")
                except Exception as e:
                    logger.warning(f"⚠️ {name} error: {e}")

        logger.info("✅ Web access test completed")
        return True

    except Exception as e:
        logger.error(f"❌ Web access test failed: {e}")
        return False


async def test_directory_structure():
    """Test directory structure creation"""
    logger.info("📁 Testing directory structure...")

    try:
        from config import OUTPUT_DIR, SCREENSHOTS_DIR, RESPONSES_DIR, LOGS_DIR

        # Test directory creation
        test_dirs = [OUTPUT_DIR, SCREENSHOTS_DIR, RESPONSES_DIR, LOGS_DIR]

        for directory in test_dirs:
            directory.mkdir(parents=True, exist_ok=True)

            if directory.exists() and directory.is_dir():
                logger.info(f"✅ {directory.name} directory ready")
            else:
                logger.error(f"❌ {directory.name} directory failed")
                return False

        # Test file creation
        test_file = OUTPUT_DIR / "test_file.txt"
        test_file.write_text("Test content")

        if test_file.exists():
            logger.info("✅ File creation working")
            test_file.unlink()  # Clean up
        else:
            logger.error("❌ File creation failed")
            return False

        logger.info("✅ Directory structure test successful")
        return True

    except Exception as e:
        logger.error(f"❌ Directory structure test failed: {e}")
        return False


async def test_configuration():
    """Test configuration loading"""
    logger.info("⚙️ Testing configuration...")

    try:
        from config import (
            TRADINGVIEW_CONFIG, LMARENA_CONFIG,
            BROWSER_CONFIG, ANTI_DETECT_CONFIG,
            IMAGE_CONFIG, TRADING_PROMPT
        )

        # Test TradingView config
        if TRADINGVIEW_CONFIG.get("url") and "tradingview.com" in TRADINGVIEW_CONFIG["url"]:
            logger.info("✅ TradingView configuration valid")
        else:
            logger.error("❌ TradingView configuration invalid")
            return False

        # Test LMArena config
        if LMARENA_CONFIG.get("chat_url") and "lmarena.ai" in LMARENA_CONFIG["chat_url"]:
            logger.info("✅ LMArena configuration valid")
        else:
            logger.error("❌ LMArena configuration invalid")
            return False

        # Test models list
        if LMARENA_CONFIG.get("models") and len(LMARENA_CONFIG["models"]) > 0:
            logger.info(f"✅ {len(LMARENA_CONFIG['models'])} AI models configured")
        else:
            logger.error("❌ No AI models configured")
            return False

        # Test trading prompt
        if TRADING_PROMPT and len(TRADING_PROMPT) > 50:
            logger.info("✅ Trading prompt configured")
        else:
            logger.error("❌ Trading prompt missing or too short")
            return False

        logger.info("✅ Configuration test successful")
        return True

    except Exception as e:
        logger.error(f"❌ Configuration test failed: {e}")
        return False


async def run_full_installation_test():
    """Run complete installation test"""
    logger.info("🚀 Running Full Installation Test")
    logger.info("=" * 50)

    tests = [
        ("Import Test", test_imports),
        ("Configuration Test", test_configuration),
        ("Directory Structure Test", test_directory_structure),
        ("Image Processing Test", test_image_processing),
        ("Playwright Test", test_playwright),
        ("Anti-Detection Browser Test", test_anti_detect_browser),
        ("Web Access Test", test_web_access),
    ]

    results = {}

    for test_name, test_func in tests:
        try:
            logger.info(f"\n🔍 Running: {test_name}")
            result = await test_func()
            results[test_name] = result

            if result:
                logger.info(f"✅ {test_name} PASSED")
            else:
                logger.error(f"❌ {test_name} FAILED")

        except Exception as e:
            logger.error(f"💥 {test_name} CRASHED: {e}")
            results[test_name] = False

    # Summary
    logger.info("\n📊 Test Results Summary:")
    logger.info("=" * 30)

    passed = sum(1 for result in results.values() if result)
    total = len(results)

    for test_name, result in results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        logger.info(f"{status} {test_name}")

    logger.info(f"\n🎯 Overall: {passed}/{total} tests passed ({passed/total*100:.1f}%)")

    if passed == total:
        logger.info("🎉 All tests passed! Installation is ready.")
        return True
    else:
        logger.error("⚠️ Some tests failed. Check logs and fix issues.")
        return False


async def main():
    """Main test runner"""
    # Setup basic logging
    logger.remove()
    logger.add(
        lambda msg: print(msg, end=""),
        level="INFO",
        format="<green>{time:HH:mm:ss}</green> | <level>{level: <8}</level> | <level>{message}</level>",
        colorize=True
    )

    if len(sys.argv) > 1:
        test_name = sys.argv[1].lower()

        test_functions = {
            "imports": test_imports,
            "playwright": test_playwright,
            "browser": test_anti_detect_browser,
            "image": test_image_processing,
            "web": test_web_access,
            "dirs": test_directory_structure,
            "config": test_configuration,
            "full": run_full_installation_test
        }

        if test_name in test_functions:
            success = await test_functions[test_name]()
            sys.exit(0 if success else 1)
        else:
            logger.error(f"Unknown test: {test_name}")
            logger.info("Available tests: " + ", ".join(test_functions.keys()))
            sys.exit(1)
    else:
        success = await run_full_installation_test()
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
