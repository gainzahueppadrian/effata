"""
Setup script for Trading Analyzer System
Installs dependencies and configures the environment
"""
import asyncio
import subprocess
import sys
import os
from pathlib import Path

from loguru import logger


async def install_python_packages():
    """Install Python packages from requirements.txt"""
    try:
        logger.info("Installing Python packages...")

        # Install packages
        result = subprocess.run([
            sys.executable, "-m", "pip", "install", "-r", "requirements.txt"
        ], capture_output=True, text=True)

        if result.returncode == 0:
            logger.info("✅ Python packages installed successfully")
            return True
        else:
            logger.error(f"❌ Package installation failed: {result.stderr}")
            return False

    except Exception as e:
        logger.error(f"❌ Error installing packages: {e}")
        return False


async def install_playwright():
    """Install Playwright and browsers"""
    try:
        logger.info("Installing Playwright browsers...")

        # Install Playwright browsers
        result = subprocess.run([
            sys.executable, "-m", "playwright", "install", "chromium"
        ], capture_output=True, text=True)

        if result.returncode == 0:
            logger.info("✅ Playwright browsers installed successfully")
            return True
        else:
            logger.error(f"❌ Playwright installation failed: {result.stderr}")
            return False

    except Exception as e:
        logger.error(f"❌ Error installing Playwright: {e}")
        return False


async def check_imagemagick():
    """Check if ImageMagick is available"""
    try:
        result = subprocess.run(["convert", "-version"], capture_output=True, text=True)
        if result.returncode == 0:
            logger.info("✅ ImageMagick is available")
            return True
        else:
            logger.warning("⚠️ ImageMagick not found")
            return False
    except FileNotFoundError:
        logger.warning("⚠️ ImageMagick not found")
        return False


async def install_imagemagick():
    """Try to install ImageMagick"""
    try:
        import platform
        system = platform.system().lower()

        if system == "linux":
            logger.info("Attempting to install ImageMagick on Linux...")
            result = subprocess.run([
                "sudo", "apt-get", "update", "&&",
                "sudo", "apt-get", "install", "-y", "imagemagick"
            ], shell=True, capture_output=True, text=True)

            if result.returncode == 0:
                logger.info("✅ ImageMagick installed via apt-get")
                return True

        elif system == "darwin":  # macOS
            logger.info("Attempting to install ImageMagick on macOS...")
            result = subprocess.run([
                "brew", "install", "imagemagick"
            ], capture_output=True, text=True)

            if result.returncode == 0:
                logger.info("✅ ImageMagick installed via brew")
                return True

        logger.warning("⚠️ Could not install ImageMagick automatically")
        logger.info("Please install ImageMagick manually:")
        logger.info("  Ubuntu/Debian: sudo apt-get install imagemagick")
        logger.info("  macOS: brew install imagemagick")
        logger.info("  Windows: Download from https://imagemagick.org/")
        return False

    except Exception as e:
        logger.error(f"❌ ImageMagick installation failed: {e}")
        return False


def create_directories():
    """Create necessary directories"""
    try:
        directories = [
            "outputs",
            "outputs/screenshots",
            "outputs/responses",
            "outputs/logs",
            "browser_profiles",
            "temp"
        ]

        for directory in directories:
            Path(directory).mkdir(parents=True, exist_ok=True)
            logger.debug(f"Created directory: {directory}")

        logger.info("✅ Directory structure created")
        return True

    except Exception as e:
        logger.error(f"❌ Failed to create directories: {e}")
        return False


async def test_installation():
    """Test the installation"""
    try:
        logger.info("Testing installation...")

        # Test imports
        try:
            from playwright.async_api import async_playwright
            from bs4 import BeautifulSoup
            from PIL import Image
            logger.info("✅ Core modules imported successfully")
        except ImportError as e:
            logger.error(f"❌ Import failed: {e}")
            return False

        # Test browser launch
        try:
            async with async_playwright() as p:
                browser = await p.chromium.launch(headless=True)
                page = await browser.new_page()
                await page.goto("data:text/html,<h1>Test</h1>")
                content = await page.content()
                await browser.close()

                if "Test" in content:
                    logger.info("✅ Browser test successful")
                else:
                    logger.error("❌ Browser test failed")
                    return False

        except Exception as e:
            logger.error(f"❌ Browser test failed: {e}")
            return False

        logger.info("✅ Installation test completed successfully")
        return True

    except Exception as e:
        logger.error(f"❌ Installation test failed: {e}")
        return False


async def create_example_config():
    """Create example configuration file"""
    try:
        config_content = '''# Trading Analyzer Configuration

# TradingView Settings
TRADINGVIEW_URL = "https://www.tradingview.com/chart/?symbol=ICMARKETS%3AXAUUSD"
SCREENSHOT_INTERVAL = 300  # 5 minutes

# LMArena Settings
LMARENA_URL = "https://lmarena.ai/c/552d5044-6d1f-408f-b688-f2fe498227a6"
DEFAULT_MODEL = "chatgpt-4o-latest-20250326"

# Models to test (uncomment to enable)
MODELS_TO_TEST = [
    "chatgpt-4o-latest-20250326",
    # "gpt-4.1-2-25-04-14",
    # "o3-2025-04-16",
    # "claude-opus",
    # "claude-sonnet",
    # "minimax"
]

# Analysis Settings
ANALYSIS_INTERVAL = 15  # minutes
ENABLE_CONTINUOUS = False  # Set to True for continuous operation

# Browser Settings
HEADLESS_MODE = True
USE_MOBILE_UA = True  # Use mobile user agent for LMArena

# Image Settings
MAX_IMAGE_SIZE = (1200, 800)
IMAGE_QUALITY = 85

# Proxy Settings (optional)
# PROXY_SERVER = "http://proxy.example.com:8080"
# PROXY_USERNAME = "username"
# PROXY_PASSWORD = "password"
'''

        config_path = Path("config.env")
        with open(config_path, 'w') as f:
            f.write(config_content)

        logger.info(f"✅ Example configuration created: {config_path}")
        return True

    except Exception as e:
        logger.error(f"❌ Failed to create config: {e}")
        return False


async def main():
    """Main setup function"""
    logger.info("🚀 Starting Trading Analyzer Setup")
    logger.info("=" * 50)

    # Check Python version
    if sys.version_info < (3, 8):
        logger.error("❌ Python 3.8 or higher is required")
        return False

    logger.info(f"✅ Python {sys.version_info.major}.{sys.version_info.minor} detected")

    # Create directories
    if not create_directories():
        return False

    # Install Python packages
    if not await install_python_packages():
        return False

    # Install Playwright
    if not await install_playwright():
        return False

    # Check/install ImageMagick
    if not await check_imagemagick():
        await install_imagemagick()

    # Test installation
    if not await test_installation():
        return False

    # Create example config
    await create_example_config()

    logger.info("=" * 50)
    logger.info("🎉 Setup completed successfully!")
    logger.info("")
    logger.info("Next steps:")
    logger.info("1. Review and edit config.env if needed")
    logger.info("2. Run a test: python trading_analyzer.py test")
    logger.info("3. Start continuous analysis: python trading_analyzer.py continuous")
    logger.info("")
    logger.info("For help: python trading_analyzer.py --help")

    return True


if __name__ == "__main__":
    asyncio.run(main())
