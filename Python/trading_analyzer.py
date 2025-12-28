"""
Main Trading Analyzer Orchestrator
Combines TradingView scraping with LMArena AI analysis
"""
import asyncio
import schedule
import time
import json
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Any
import threading

from loguru import logger

from tradingview_scraper import TradingViewScraper
from lmarena_scraper import LMArenaScaper
from config import (
    SCHEDULE_CONFIG, TRADINGVIEW_CONFIG, LMARENA_CONFIG,
    OUTPUT_DIR, SCREENSHOTS_DIR, RESPONSES_DIR
)


class TradingAnalyzer:
    """
    Main orchestrator for automated trading analysis
    Combines chart scraping with AI analysis
    """

    def __init__(self):
        self.tv_scraper: Optional[TradingViewScraper] = None
        self.lm_scraper: Optional[LMArenaScaper] = None
        self.running = False
        self.analysis_results = []
        self.scheduler_thread = None

        # Setup logging
        log_file = OUTPUT_DIR / "logs" / f"trading_analyzer_{datetime.now().strftime('%Y%m%d')}.log"
        logger.add(
            log_file,
            rotation="1 day",
            retention="7 days",
            level="INFO",
            format="{time:YYYY-MM-DD HH:mm:ss} | {level} | {name} | {message}"
        )

        logger.info("Trading Analyzer initialized")

    async def initialize(self):
        """Initialize both scrapers"""
        try:
            logger.info("Initializing Trading Analyzer...")

            # Initialize TradingView scraper
            self.tv_scraper = TradingViewScraper("tradingview_main")
            await self.tv_scraper.start()

            # Initialize LMArena scraper
            self.lm_scraper = LMArenaScaper("lmarena_main")
            await self.lm_scraper.start()

            logger.info("Trading Analyzer initialized successfully")

        except Exception as e:
            logger.error(f"Failed to initialize Trading Analyzer: {e}")
            await self.cleanup()
            raise

    async def capture_and_analyze(self, models: List[str] = None, custom_prompt: str = None) -> Dict[str, Any]:
        """Capture chart and perform AI analysis"""
        try:
            logger.info("Starting capture and analysis cycle")

            # Capture chart screenshot
            screenshot_path = await self.tv_scraper.capture_chart_screenshot()
            if not screenshot_path:
                logger.error("Failed to capture chart screenshot")
                return {"success": False, "error": "Screenshot failed"}

            # Get models to test
            if models is None:
                models = [LMARENA_CONFIG["default_model"]]

            analysis_results = []

            # Analyze with each model
            for model in models:
                try:
                    logger.info(f"Analyzing with model: {model}")

                    result = await self.lm_scraper.analyze_chart(
                        image_path=screenshot_path,
                        custom_prompt=custom_prompt,
                        model_name=model
                    )

                    if result and result.get("success"):
                        analysis_results.append(result)
                        logger.info(f"Analysis completed with {model}")
                    else:
                        logger.warning(f"Analysis failed with {model}")

                    # Wait between models to avoid rate limiting
                    await asyncio.sleep(10)

                except Exception as e:
                    logger.error(f"Analysis failed with model {model}: {e}")
                    continue

            # Compile final result
            final_result = {
                "success": len(analysis_results) > 0,
                "timestamp": datetime.now().isoformat(),
                "screenshot_path": screenshot_path,
                "analyses": analysis_results,
                "models_tested": len(analysis_results),
                "total_models": len(models)
            }

            # Save consolidated result
            await self._save_analysis_session(final_result)

            # Add to results history
            self.analysis_results.append(final_result)

            logger.info(f"Analysis cycle completed: {len(analysis_results)}/{len(models)} models successful")
            return final_result

        except Exception as e:
            logger.error(f"Capture and analysis failed: {e}")
            return {
                "success": False,
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            }

    async def _save_analysis_session(self, result: Dict[str, Any]):
        """Save analysis session results"""
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            session_file = OUTPUT_DIR / f"analysis_session_{timestamp}.json"

            with open(session_file, 'w', encoding='utf-8') as f:
                json.dump(result, f, indent=2, ensure_ascii=False)

            logger.debug(f"Analysis session saved: {session_file}")

        except Exception as e:
            logger.error(f"Failed to save analysis session: {e}")

    async def run_continuous_analysis(self, interval_minutes: int = 15, models: List[str] = None):
        """Run continuous analysis at specified intervals"""
        try:
            logger.info(f"Starting continuous analysis every {interval_minutes} minutes")
            self.running = True

            while self.running:
                try:
                    # Perform analysis
                    result = await self.capture_and_analyze(models)

                    if result["success"]:
                        logger.info(f"Analysis completed successfully: {result['models_tested']} models")
                    else:
                        logger.warning("Analysis cycle failed")

                    # Cleanup old files periodically
                    if len(self.analysis_results) % 4 == 0:  # Every 4 cycles
                        await self._cleanup_old_files()

                    # Wait for next cycle
                    await asyncio.sleep(interval_minutes * 60)

                except KeyboardInterrupt:
                    logger.info("Continuous analysis interrupted by user")
                    break
                except Exception as e:
                    logger.error(f"Analysis cycle error: {e}")
                    await asyncio.sleep(60)  # Wait 1 minute before retry
                    continue

        except Exception as e:
            logger.error(f"Continuous analysis failed: {e}")
        finally:
            self.running = False

    async def test_single_analysis(self, model_name: str = None) -> Dict[str, Any]:
        """Test single analysis with specified model"""
        try:
            logger.info("Running single analysis test")

            model = model_name or LMARENA_CONFIG["default_model"]
            result = await self.capture_and_analyze([model])

            if result["success"]:
                logger.info("Single analysis test completed successfully")
                return result
            else:
                logger.error("Single analysis test failed")
                return result

        except Exception as e:
            logger.error(f"Single analysis test failed: {e}")
            return {
                "success": False,
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            }

    async def test_multiple_models(self, models: List[str] = None) -> Dict[str, Any]:
        """Test analysis with multiple models"""
        try:
            if models is None:
                models = LMARENA_CONFIG["models"][:3]  # Test first 3 models

            logger.info(f"Testing multiple models: {models}")

            result = await self.capture_and_analyze(models)

            logger.info(f"Multiple model test completed: {result['models_tested']}/{result['total_models']} successful")
            return result

        except Exception as e:
            logger.error(f"Multiple model test failed: {e}")
            return {
                "success": False,
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            }

    def setup_scheduled_analysis(self, interval_minutes: int = 15):
        """Setup scheduled analysis using the schedule library"""
        try:
            # Clear existing schedule
            schedule.clear()

            # Schedule regular analysis
            schedule.every(interval_minutes).minutes.do(self._run_scheduled_analysis)

            # Schedule hourly cleanup
            schedule.every().hour.do(self._run_cleanup)

            # Start scheduler in separate thread
            self.scheduler_thread = threading.Thread(target=self._run_scheduler, daemon=True)
            self.scheduler_thread.start()

            logger.info(f"Scheduled analysis setup: every {interval_minutes} minutes")

        except Exception as e:
            logger.error(f"Failed to setup scheduled analysis: {e}")

    def _run_scheduler(self):
        """Run the scheduler in a separate thread"""
        try:
            while self.running:
                schedule.run_pending()
                time.sleep(30)  # Check every 30 seconds
        except Exception as e:
            logger.error(f"Scheduler error: {e}")

    def _run_scheduled_analysis(self):
        """Run scheduled analysis (wrapper for async function)"""
        try:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)

            # Run single model analysis for scheduled runs
            result = loop.run_until_complete(
                self.capture_and_analyze([LMARENA_CONFIG["default_model"]])
            )

            if result["success"]:
                logger.info("Scheduled analysis completed")
            else:
                logger.warning("Scheduled analysis failed")

        except Exception as e:
            logger.error(f"Scheduled analysis error: {e}")

    def _run_cleanup(self):
        """Run cleanup (wrapper for async function)"""
        try:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)

            loop.run_until_complete(self._cleanup_old_files())

        except Exception as e:
            logger.error(f"Scheduled cleanup error: {e}")

    async def _cleanup_old_files(self):
        """Clean up old files to manage disk space"""
        try:
            logger.info("Running cleanup of old files...")

            # Clean up old screenshots
            if self.tv_scraper:
                await self.tv_scraper.cleanup_old_screenshots(
                    max_files=SCHEDULE_CONFIG.get("max_screenshots", 100)
                )

            # Clean up old response files
            response_files = list(RESPONSES_DIR.glob("*.txt"))
            max_responses = SCHEDULE_CONFIG.get("max_responses", 50)

            if len(response_files) > max_responses:
                # Sort by modification time and remove oldest
                response_files.sort(key=lambda p: p.stat().st_mtime)
                files_to_remove = response_files[:-max_responses]

                for file_path in files_to_remove:
                    try:
                        file_path.unlink()
                        # Also remove corresponding JSON file
                        json_file = file_path.with_suffix('.json')
                        if json_file.exists():
                            json_file.unlink()
                    except Exception as e:
                        logger.warning(f"Failed to remove {file_path}: {e}")

                logger.info(f"Cleaned up {len(files_to_remove)} old response files")

            # Clean up old analysis session files
            session_files = list(OUTPUT_DIR.glob("analysis_session_*.json"))
            if len(session_files) > 20:
                session_files.sort(key=lambda p: p.stat().st_mtime)
                old_sessions = session_files[:-20]

                for session_file in old_sessions:
                    try:
                        session_file.unlink()
                    except Exception as e:
                        logger.warning(f"Failed to remove {session_file}: {e}")

                logger.info(f"Cleaned up {len(old_sessions)} old session files")

        except Exception as e:
            logger.error(f"Cleanup failed: {e}")

    async def get_analysis_summary(self, hours: int = 24) -> Dict[str, Any]:
        """Get analysis summary for the last N hours"""
        try:
            cutoff_time = datetime.now() - timedelta(hours=hours)

            recent_results = [
                result for result in self.analysis_results
                if datetime.fromisoformat(result["timestamp"]) > cutoff_time
            ]

            successful_analyses = [r for r in recent_results if r["success"]]

            summary = {
                "period_hours": hours,
                "total_analyses": len(recent_results),
                "successful_analyses": len(successful_analyses),
                "success_rate": len(successful_analyses) / len(recent_results) if recent_results else 0,
                "models_used": set(),
                "latest_analysis": recent_results[-1] if recent_results else None
            }

            # Collect unique models used
            for result in successful_analyses:
                for analysis in result.get("analyses", []):
                    summary["models_used"].add(analysis.get("model", "unknown"))

            summary["models_used"] = list(summary["models_used"])

            return summary

        except Exception as e:
            logger.error(f"Failed to get analysis summary: {e}")
            return {}

    async def export_results(self, output_file: Optional[str] = None) -> str:
        """Export all analysis results to JSON file"""
        try:
            if output_file is None:
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                output_file = str(OUTPUT_DIR / f"trading_analysis_export_{timestamp}.json")

            export_data = {
                "export_timestamp": datetime.now().isoformat(),
                "total_results": len(self.analysis_results),
                "results": self.analysis_results
            }

            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(export_data, f, indent=2, ensure_ascii=False)

            logger.info(f"Results exported to: {output_file}")
            return output_file

        except Exception as e:
            logger.error(f"Failed to export results: {e}")
            return ""

    async def stop(self):
        """Stop all operations"""
        try:
            logger.info("Stopping Trading Analyzer...")

            self.running = False

            # Clear schedule
            schedule.clear()

            # Wait for scheduler thread to finish
            if self.scheduler_thread and self.scheduler_thread.is_alive():
                self.scheduler_thread.join(timeout=5)

            logger.info("Trading Analyzer stopped")

        except Exception as e:
            logger.error(f"Error stopping Trading Analyzer: {e}")

    async def cleanup(self):
        """Clean up all resources"""
        try:
            await self.stop()

            if self.tv_scraper:
                await self.tv_scraper.cleanup()
                self.tv_scraper = None

            if self.lm_scraper:
                await self.lm_scraper.cleanup()
                self.lm_scraper = None

            logger.info("Trading Analyzer cleanup completed")

        except Exception as e:
            logger.error(f"Cleanup failed: {e}")

    async def __aenter__(self):
        """Async context manager entry"""
        await self.initialize()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit"""
        await self.cleanup()
