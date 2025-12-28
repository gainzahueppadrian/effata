#!/usr/bin/env python3
"""
Trading Analyzer CLI - Main Entry Point
Advanced TradingView and LMArena.ai scraper with anti-detection
"""
import asyncio
import argparse
import sys
from pathlib import Path

from loguru import logger
from utils import setup_logging
from trading_analyzer import TradingAnalyzer
from socket_server import start_socket_server


async def run_setup():
    """Run setup process"""
    try:
        from setup import main as setup_main
        await setup_main()
    except Exception as e:
        logger.error(f"Setup failed: {e}")
        return False


async def run_single_test(model: str = None):
    """Run single analysis test"""
    try:
        logger.info("🧪 Running single analysis test...")

        async with TradingAnalyzer() as analyzer:
            result = await analyzer.test_single_analysis(model)

            if result["success"]:
                logger.info("✅ Single test completed successfully")
                logger.info(f"📊 Analysis result saved")

                # Show summary
                analyses = result.get("analyses", [])
                if analyses:
                    analysis = analyses[0]
                    logger.info(f"🤖 Model: {analysis.get('model', 'unknown')}")
                    logger.info(f"📝 Response length: {len(analysis.get('response', ''))} characters")
                    logger.info(f"💾 Output file: {analysis.get('output_file', 'N/A')}")

                return True
            else:
                logger.error("❌ Single test failed")
                return False

    except Exception as e:
        logger.error(f"Single test error: {e}")
        return False


async def run_multi_model_test(models: list = None):
    """Run multi-model analysis test"""
    try:
        logger.info("🧪 Running multi-model analysis test...")

        async with TradingAnalyzer() as analyzer:
            result = await analyzer.test_multiple_models(models)

            success_count = result.get("models_tested", 0)
            total_count = result.get("total_models", 0)

            logger.info(f"📊 Multi-model test: {success_count}/{total_count} models successful")

            if result["success"]:
                logger.info("✅ Multi-model test completed")

                # Show results summary
                for i, analysis in enumerate(result.get("analyses", []), 1):
                    logger.info(f"  {i}. {analysis.get('model', 'unknown')} - ✅")

                return True
            else:
                logger.error("❌ Multi-model test failed")
                return False

    except Exception as e:
        logger.error(f"Multi-model test error: {e}")
        return False


async def run_continuous(interval: int = 15, models: list = None):
    """Run continuous analysis"""
    try:
        logger.info(f"🔄 Starting continuous analysis (every {interval} minutes)")
        logger.info("Press Ctrl+C to stop")

        async with TradingAnalyzer() as analyzer:
            await analyzer.run_continuous_analysis(interval, models)

    except KeyboardInterrupt:
        logger.info("🛑 Continuous analysis stopped by user")
    except Exception as e:
        logger.error(f"Continuous analysis error: {e}")


async def run_scheduled(interval: int = 15):
    """Run scheduled analysis"""
    try:
        logger.info(f"⏰ Starting scheduled analysis (every {interval} minutes)")
        logger.info("Press Ctrl+C to stop")

        async with TradingAnalyzer() as analyzer:
            analyzer.setup_scheduled_analysis(interval)

            # Keep running
            while True:
                await asyncio.sleep(60)

    except KeyboardInterrupt:
        logger.info("🛑 Scheduled analysis stopped by user")
    except Exception as e:
        logger.error(f"Scheduled analysis error: {e}")


async def show_status():
    """Show system status"""
    try:
        from utils import get_system_info, check_system_resources
        from config import OUTPUT_DIR, SCREENSHOTS_DIR, RESPONSES_DIR

        logger.info("📊 Trading Analyzer Status")
        logger.info("=" * 40)

        # System info
        system_info = await get_system_info()
        logger.info(f"🖥️  Platform: {system_info.get('platform', 'Unknown')}")
        logger.info(f"🐍 Python: {system_info.get('python_version', 'Unknown')[:10]}")

        # Resources
        resources = check_system_resources()
        logger.info(f"💾 RAM: {resources.get('memory_gb', 0):.1f} GB available")
        logger.info(f"💿 Disk: {resources.get('disk_gb', 0):.1f} GB available")

        # File counts
        screenshots = len(list(SCREENSHOTS_DIR.glob("*.jpg"))) if SCREENSHOTS_DIR.exists() else 0
        responses = len(list(RESPONSES_DIR.glob("*.txt"))) if RESPONSES_DIR.exists() else 0

        logger.info(f"📸 Screenshots: {screenshots}")
        logger.info(f"📝 Responses: {responses}")

        # Check dependencies
        try:
            from playwright.async_api import async_playwright
            logger.info("✅ Playwright available")
        except ImportError:
            logger.warning("❌ Playwright not available")

        try:
            import subprocess
            result = subprocess.run(["convert", "-version"], capture_output=True)
            if result.returncode == 0:
                logger.info("✅ ImageMagick available")
            else:
                logger.warning("⚠️ ImageMagick not available")
        except:
            logger.warning("⚠️ ImageMagick not available")

        return True

    except Exception as e:
        logger.error(f"Status check failed: {e}")
        return False


async def export_results(output_file: str = None):
    """Export analysis results"""
    try:
        logger.info("📤 Exporting analysis results...")

        async with TradingAnalyzer() as analyzer:
            export_path = await analyzer.export_results(output_file)

            if export_path:
                logger.info(f"✅ Results exported to: {export_path}")
                return True
            else:
                logger.error("❌ Export failed")
                return False

    except Exception as e:
        logger.error(f"Export failed: {e}")
        return False


async def cleanup_files():
    """Clean up old files"""
    try:
        from utils import cleanup_temp_files
        from config import SCHEDULE_CONFIG

        logger.info("🧹 Cleaning up old files...")

        async with TradingAnalyzer() as analyzer:
            await analyzer._cleanup_old_files()

        # Clean temp files
        await cleanup_temp_files()

        logger.info("✅ Cleanup completed")
        return True

    except Exception as e:
        logger.error(f"Cleanup failed: {e}")
        return False


def create_parser():
    """Create command line argument parser"""
    parser = argparse.ArgumentParser(
        description="Trading Analyzer - TradingView & LMArena.ai Scraper",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python main.py setup                    # Run initial setup
  python main.py test                     # Run single test
  python main.py test --model gpt-4       # Test specific model
  python main.py multi-test               # Test multiple models
  python main.py continuous --interval 10 # Run every 10 minutes
  python main.py scheduled --interval 15  # Scheduled analysis
  python main.py status                   # Show system status
  python main.py export                   # Export results
  python main.py cleanup                  # Clean up old files
  python main.py server                   # Start socket server for MQL5

Available Models:
  - chatgpt-4o-latest-20250326
  - gpt-4.1-2-25-04-14
  - o3-2025-04-16
  - claude-opus
  - claude-sonnet
  - minimax
        """
    )

    parser.add_argument(
        "command",
        choices=[
            "setup", "test", "multi-test", "continuous",
            "scheduled", "status", "export", "cleanup", "server"
        ],
        help="Command to run"
    )

    parser.add_argument(
        "--model",
        type=str,
        help="AI model to use for analysis"
    )

    parser.add_argument(
        "--models",
        type=str,
        nargs="+",
        help="Multiple AI models to test"
    )

    parser.add_argument(
        "--interval",
        type=int,
        default=15,
        help="Analysis interval in minutes (default: 15)"
    )

    parser.add_argument(
        "--output",
        type=str,
        help="Output file path for export"
    )

    parser.add_argument(
        "--headless",
        action="store_true",
        default=True,
        help="Run browser in headless mode"
    )

    parser.add_argument(
        "--log-level",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        default="INFO",
        help="Logging level (default: INFO)"
    )

    parser.add_argument(
        "--log-file",
        type=str,
        help="Log file path"
    )

    return parser


async def main():
    """Main entry point"""
    parser = create_parser()
    args = parser.parse_args()

    # Setup logging
    log_file = args.log_file or f"trading_analyzer_{args.command}.log"
    setup_logging(args.log_level, log_file)

    logger.info(f"🚀 Trading Analyzer - {args.command.upper()}")

    try:
        if args.command == "setup":
            success = await run_setup()

        elif args.command == "test":
            success = await run_single_test(args.model)

        elif args.command == "multi-test":
            success = await run_multi_model_test(args.models)

        elif args.command == "continuous":
            await run_continuous(args.interval, args.models)
            success = True

        elif args.command == "scheduled":
            await run_scheduled(args.interval)
            success = True

        elif args.command == "status":
            success = await show_status()

        elif args.command == "export":
            success = await export_results(args.output)

        elif args.command == "cleanup":
            success = await cleanup_files()

        elif args.command == "server":
            await start_socket_server()
            success = True

        else:
            logger.error(f"Unknown command: {args.command}")
            success = False

        if success:
            logger.info("✅ Command completed successfully")
            sys.exit(0)
        else:
            logger.error("❌ Command failed")
            sys.exit(1)

    except KeyboardInterrupt:
        logger.info("🛑 Operation interrupted by user")
        sys.exit(0)
    except Exception as e:
        logger.error(f"💥 Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    # Ensure we're using the right event loop policy on Windows
    if sys.platform == "win32":
        asyncio.set_event_loop_policy(asyncio.WindowsProactorEventLoopPolicy())

    asyncio.run(main())
