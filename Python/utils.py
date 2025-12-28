"""
Utility functions for the Trading Analyzer system
"""
import asyncio
import aiofiles
import subprocess
import shutil
import json
import os
from pathlib import Path
from typing import Dict, List, Any, Optional
from datetime import datetime, timedelta

from loguru import logger


async def install_playwright_browsers():
    """Install Playwright browsers"""
    try:
        logger.info("Installing Playwright browsers...")

        result = subprocess.run(
            ["python", "-m", "playwright", "install", "chromium"],
            capture_output=True,
            text=True
        )

        if result.returncode == 0:
            logger.info("Playwright browsers installed successfully")
            return True
        else:
            logger.error(f"Playwright installation failed: {result.stderr}")
            return False

    except Exception as e:
        logger.error(f"Error installing Playwright browsers: {e}")
        return False


async def check_imagemagick():
    """Check if ImageMagick is installed"""
    try:
        result = subprocess.run(
            ["convert", "-version"],
            capture_output=True,
            text=True
        )

        if result.returncode == 0:
            logger.info("ImageMagick is available")
            return True
        else:
            logger.warning("ImageMagick not found - image optimization will be limited")
            return False

    except Exception as e:
        logger.warning(f"ImageMagick check failed: {e}")
        return False


async def install_imagemagick():
    """Try to install ImageMagick on different systems"""
    try:
        import platform
        system = platform.system().lower()

        if system == "linux":
            # Try apt-get
            result = subprocess.run(
                ["sudo", "apt-get", "update", "&&", "sudo", "apt-get", "install", "-y", "imagemagick"],
                shell=True,
                capture_output=True,
                text=True
            )

            if result.returncode == 0:
                logger.info("ImageMagick installed via apt-get")
                return True

        elif system == "darwin":  # macOS
            # Try brew
            result = subprocess.run(
                ["brew", "install", "imagemagick"],
                capture_output=True,
                text=True
            )

            if result.returncode == 0:
                logger.info("ImageMagick installed via brew")
                return True

        logger.warning("Could not install ImageMagick automatically")
        return False

    except Exception as e:
        logger.error(f"ImageMagick installation failed: {e}")
        return False


def create_directory_structure():
    """Create necessary directory structure"""
    try:
        from config import OUTPUT_DIR, SCREENSHOTS_DIR, RESPONSES_DIR, LOGS_DIR

        directories = [
            OUTPUT_DIR,
            SCREENSHOTS_DIR,
            RESPONSES_DIR,
            LOGS_DIR,
            Path("browser_profiles"),
            Path("temp")
        ]

        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)
            logger.debug(f"Created directory: {directory}")

        logger.info("Directory structure created successfully")
        return True

    except Exception as e:
        logger.error(f"Failed to create directory structure: {e}")
        return False


async def validate_urls():
    """Validate that target URLs are accessible"""
    try:
        import httpx

        urls_to_check = [
            "https://www.tradingview.com",
            "https://lmarena.ai"
        ]

        async with httpx.AsyncClient(
            headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"},
            timeout=30.0
        ) as client:

            for url in urls_to_check:
                try:
                    response = await client.get(url)
                    if response.status_code == 200:
                        logger.info(f"✅ {url} is accessible")
                    else:
                        logger.warning(f"⚠️ {url} returned status {response.status_code}")

                except Exception as e:
                    logger.error(f"❌ {url} is not accessible: {e}")

        return True

    except Exception as e:
        logger.error(f"URL validation failed: {e}")
        return False


def check_system_resources():
    """Check available system resources"""
    try:
        import psutil

        # Check available memory
        memory = psutil.virtual_memory()
        available_gb = memory.available / (1024**3)

        # Check available disk space
        disk = psutil.disk_usage('/')
        available_disk_gb = disk.free / (1024**3)

        # Check CPU count
        cpu_count = psutil.cpu_count()

        logger.info(f"System Resources:")
        logger.info(f"  Available RAM: {available_gb:.1f} GB")
        logger.info(f"  Available Disk: {available_disk_gb:.1f} GB")
        logger.info(f"  CPU Cores: {cpu_count}")

        # Warn if resources are low
        if available_gb < 2.0:
            logger.warning("Low memory available - consider closing other applications")

        if available_disk_gb < 5.0:
            logger.warning("Low disk space available - consider cleaning up files")

        return {
            "memory_gb": available_gb,
            "disk_gb": available_disk_gb,
            "cpu_cores": cpu_count,
            "sufficient": available_gb >= 1.0 and available_disk_gb >= 2.0
        }

    except Exception as e:
        logger.error(f"System resource check failed: {e}")
        return {"sufficient": True}  # Assume sufficient if check fails


async def test_browser_launch():
    """Test browser launch functionality"""
    try:
        from playwright.async_api import async_playwright

        logger.info("Testing browser launch...")

        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            page = await browser.new_page()

            # Test basic navigation
            await page.goto("https://httpbin.org/user-agent")
            content = await page.content()

            await browser.close()

            if "Mozilla" in content:
                logger.info("✅ Browser test successful")
                return True
            else:
                logger.error("❌ Browser test failed - unexpected content")
                return False

    except Exception as e:
        logger.error(f"❌ Browser test failed: {e}")
        return False


async def create_config_file(config_data: Dict[str, Any], config_path: str = "user_config.json"):
    """Create user configuration file"""
    try:
        config_path = Path(config_path)

        async with aiofiles.open(config_path, 'w') as f:
            await f.write(json.dumps(config_data, indent=2))

        logger.info(f"Configuration saved to: {config_path}")
        return True

    except Exception as e:
        logger.error(f"Failed to create config file: {e}")
        return False


async def load_config_file(config_path: str = "user_config.json") -> Dict[str, Any]:
    """Load user configuration file"""
    try:
        config_path = Path(config_path)

        if not config_path.exists():
            return {}

        async with aiofiles.open(config_path, 'r') as f:
            content = await f.read()
            return json.loads(content)

    except Exception as e:
        logger.error(f"Failed to load config file: {e}")
        return {}


def get_proxy_list() -> List[Dict[str, str]]:
    """Get list of proxy servers (placeholder - implement with real proxy service)"""
    # This is a placeholder - in real implementation, you would:
    # 1. Connect to a proxy service API
    # 2. Load from configuration file
    # 3. Rotate through different proxy providers

    return [
        # {"server": "http://proxy1.example.com:8080", "username": "user", "password": "pass"},
        # {"server": "http://proxy2.example.com:8080", "username": "user", "password": "pass"},
    ]


async def rotate_user_agent():
    """Get a random user agent"""
    try:
        from fake_useragent import UserAgent
        ua = UserAgent()
        return ua.random
    except Exception as e:
        logger.warning(f"Failed to get random user agent: {e}")
        return "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"


async def compress_image(image_path: str, quality: int = 85) -> Optional[str]:
    """Compress image using PIL"""
    try:
        from PIL import Image

        image_path = Path(image_path)
        if not image_path.exists():
            return None

        # Create compressed version
        compressed_path = image_path.with_suffix(f"_compressed{image_path.suffix}")

        with Image.open(image_path) as img:
            # Convert to RGB if necessary
            if img.mode != 'RGB':
                img = img.convert('RGB')

            # Resize if too large
            max_size = (1200, 800)
            if img.size[0] > max_size[0] or img.size[1] > max_size[1]:
                img.thumbnail(max_size, Image.Resampling.LANCZOS)

            # Save with compression
            img.save(compressed_path, "JPEG", quality=quality, optimize=True)

        logger.debug(f"Image compressed: {compressed_path}")
        return str(compressed_path)

    except Exception as e:
        logger.error(f"Image compression failed: {e}")
        return None


async def cleanup_temp_files(temp_dir: str = "temp", max_age_hours: int = 24):
    """Clean up temporary files older than specified hours"""
    try:
        temp_path = Path(temp_dir)
        if not temp_path.exists():
            return

        cutoff_time = datetime.now() - timedelta(hours=max_age_hours)

        files_removed = 0
        for file_path in temp_path.rglob("*"):
            if file_path.is_file():
                file_time = datetime.fromtimestamp(file_path.stat().st_mtime)
                if file_time < cutoff_time:
                    try:
                        file_path.unlink()
                        files_removed += 1
                    except Exception as e:
                        logger.warning(f"Failed to remove {file_path}: {e}")

        if files_removed > 0:
            logger.info(f"Cleaned up {files_removed} temporary files")

    except Exception as e:
        logger.error(f"Temp file cleanup failed: {e}")


async def get_system_info() -> Dict[str, Any]:
    """Get comprehensive system information"""
    try:
        import platform
        import sys

        info = {
            "platform": platform.platform(),
            "system": platform.system(),
            "machine": platform.machine(),
            "python_version": sys.version,
            "architecture": platform.architecture()[0],
            "timestamp": datetime.now().isoformat()
        }

        # Add resource info if available
        try:
            resources = check_system_resources()
            info.update(resources)
        except:
            pass

        return info

    except Exception as e:
        logger.error(f"Failed to get system info: {e}")
        return {}


async def generate_session_id() -> str:
    """Generate unique session ID"""
    import uuid
    return f"session_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{uuid.uuid4().hex[:8]}"


async def save_debug_info(data: Dict[str, Any], filename: Optional[str] = None):
    """Save debug information to file"""
    try:
        if filename is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"debug_info_{timestamp}.json"

        debug_path = Path("outputs") / "logs" / filename
        debug_path.parent.mkdir(parents=True, exist_ok=True)

        # Add system info
        debug_data = {
            "timestamp": datetime.now().isoformat(),
            "system_info": await get_system_info(),
            "data": data
        }

        async with aiofiles.open(debug_path, 'w') as f:
            await f.write(json.dumps(debug_data, indent=2, default=str))

        logger.debug(f"Debug info saved: {debug_path}")
        return str(debug_path)

    except Exception as e:
        logger.error(f"Failed to save debug info: {e}")
        return None


def setup_logging(log_level: str = "INFO", log_file: Optional[str] = None):
    """Setup logging configuration"""
    try:
        # Remove default logger
        logger.remove()

        # Add console logger
        logger.add(
            lambda msg: print(msg, end=""),
            level=log_level,
            format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan> | <level>{message}</level>",
            colorize=True
        )

        # Add file logger if specified
        if log_file:
            log_path = Path("outputs") / "logs" / log_file
            log_path.parent.mkdir(parents=True, exist_ok=True)

            logger.add(
                log_path,
                level=log_level,
                format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {name} | {message}",
                rotation="1 day",
                retention="7 days",
                compression="zip"
            )

        logger.info("Logging setup completed")
        return True

    except Exception as e:
        print(f"Failed to setup logging: {e}")
        return False


# Async context manager for temporary file handling
class TempFileManager:
    """Context manager for temporary file handling"""

    def __init__(self, base_dir: str = "temp"):
        self.base_dir = Path(base_dir)
        self.temp_files = []

    async def __aenter__(self):
        self.base_dir.mkdir(parents=True, exist_ok=True)
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        # Clean up temporary files
        for temp_file in self.temp_files:
            try:
                if temp_file.exists():
                    temp_file.unlink()
            except Exception as e:
                logger.warning(f"Failed to cleanup temp file {temp_file}: {e}")

    def create_temp_file(self, suffix: str = ".tmp") -> Path:
        """Create a temporary file"""
        import uuid
        temp_file = self.base_dir / f"temp_{uuid.uuid4().hex[:8]}{suffix}"
        self.temp_files.append(temp_file)
        return temp_file


# Performance monitoring
class PerformanceMonitor:
    """Simple performance monitoring"""

    def __init__(self, name: str):
        self.name = name
        self.start_time = None
        self.measurements = []

    def start(self):
        """Start timing"""
        self.start_time = datetime.now()

    def stop(self, operation: str = "operation"):
        """Stop timing and record measurement"""
        if self.start_time:
            duration = (datetime.now() - self.start_time).total_seconds()
            self.measurements.append({
                "operation": operation,
                "duration": duration,
                "timestamp": datetime.now().isoformat()
            })
            logger.debug(f"{self.name} - {operation}: {duration:.2f}s")
            return duration
        return 0

    def get_summary(self) -> Dict[str, Any]:
        """Get performance summary"""
        if not self.measurements:
            return {}

        durations = [m["duration"] for m in self.measurements]
        return {
            "total_operations": len(self.measurements),
            "total_time": sum(durations),
            "average_time": sum(durations) / len(durations),
            "min_time": min(durations),
            "max_time": max(durations),
            "measurements": self.measurements
        }
