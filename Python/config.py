"""
Configuration settings for TradingView and LMArena.ai scraper
"""
import os
from pathlib import Path

# Base Configuration
BASE_DIR = Path(__file__).parent
OUTPUT_DIR = BASE_DIR / "outputs"
SCREENSHOTS_DIR = OUTPUT_DIR / "screenshots"
RESPONSES_DIR = OUTPUT_DIR / "responses"
LOGS_DIR = OUTPUT_DIR / "logs"

# Create directories
for dir_path in [OUTPUT_DIR, SCREENSHOTS_DIR, RESPONSES_DIR, LOGS_DIR]:
    dir_path.mkdir(parents=True, exist_ok=True)

# TradingView Configuration
TRADINGVIEW_CONFIG = {
    "url": "https://www.tradingview.com/chart/?symbol=ICMARKETS%3AXAUUSD",
    "screenshot_interval": 300,  # 5 minutes in seconds
    "chart_selector": ".chart-container",
    "chart_area_selector": ".layout__area--center",
    "wait_for_chart": 10000,  # 10 seconds
    "chart_quality": 95,
    "max_image_size": (1920, 1080)
}

# LMArena.ai Configuration
LMARENA_CONFIG = {
    "base_url": "https://lmarena.ai",
    "chat_url": "https://lmarena.ai/c/552d5044-6d1f-408f-b688-f2fe498227a6",
    "mobile_user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
    "models": [
        "chatgpt-4o-latest-20250326",
        "gpt-4.1-2-25-04-14",
        "o3-2025-04-16",
        "claude-opus",
        "claude-sonnet",
        "minimax",
        "gemini-pro",
        "llama-3-70b"
    ],
    "default_model": "chatgpt-4o-latest-20250326",
    "selectors": {
        "model_dropdown": "button[aria-label*='chatgpt'], .model-selector, [data-testid='model-selector']",
        "model_option": "div[role='option'], .model-option, [data-value]",
        "chat_input": "textarea[placeholder*='Ask'], input[placeholder*='follow'], .chat-input, [data-testid='chat-input']",
        "send_button": "button[type='submit'], .send-button, [data-testid='send-button']",
        "response_area": ".response-text, .message-content, [data-testid='response'], .chat-message",
        "direct_chat_button": "button:has-text('Direct Chat'), [data-testid='direct-chat']"
    },
    "wait_timeout": 30000,
    "response_timeout": 60000
}

# Trading Analysis Prompt
TRADING_PROMPT = """What do you see in the chart? Analyze the chart for trading Forex Gold (XAUUSD) signals of entries and exits, seasonalities, confluence timeframes, daily biases, liquidity zones, retail stop hunts zones. You are my Forex Trading Assistant, could you identify key levels in the charts, recommend opportunities for entry and exit trades, support and resistance levels, trend analysis, momentum indicators, and potential reversal patterns. Please provide specific price levels and timeframes for optimal trade setups. Respond with a valid JSON object only."""

# Browser Configuration
BROWSER_CONFIG = {
    "headless": True,
    "user_data_dir": str(BASE_DIR / "browser_profiles"),
    "viewport": {"width": 1920, "height": 1080},
    "locale": "en-US",
    "timezone_id": "America/New_York",
    "permissions": ["geolocation", "notifications"],
    "geolocation": {"latitude": 40.7128, "longitude": -74.0060},  # New York
    "extra_http_headers": {
        "Accept-Language": "en-US,en;q=0.9",
        "Accept-Encoding": "gzip, deflate, br",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Cache-Control": "no-cache",
        "Pragma": "no-cache"
    }
}

# Anti-Detection Configuration
ANTI_DETECT_CONFIG = {
    "user_agents": [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    ],
    "proxy_rotation": True,
    "fingerprint_rotation": True,
    "random_delays": True,
    "delay_range": (1, 3),  # seconds
    "max_retries": 3,
    "retry_delay": 5
}

# Image Processing Configuration
IMAGE_CONFIG = {
    "max_size": (1200, 800),
    "quality": 85,
    "format": "JPEG",
    "compression": "JPEG",
    "imagemagick_options": [
        "-quality", "85",
        "-resize", "1200x800>",
        "-strip",
        "-interlace", "Plane",
        "-sampling-factor", "4:2:0"
    ]
}

# Logging Configuration
LOGGING_CONFIG = {
    "level": "INFO",
    "format": "{time:YYYY-MM-DD HH:mm:ss} | {level} | {name} | {message}",
    "rotation": "1 day",
    "retention": "7 days",
    "compression": "zip"
}

# Schedule Configuration
SCHEDULE_CONFIG = {
    "screenshot_interval": "5 minutes",
    "analysis_interval": "15 minutes",
    "cleanup_interval": "1 hour",
    "max_screenshots": 100,
    "max_responses": 50
}

# Socket Server Configuration
SOCKET_CONFIG = {
    "host": "127.0.0.1",
    "port": 5555,
    "buffer_size": 4096
}
