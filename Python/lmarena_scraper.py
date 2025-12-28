"""
LMArena.ai Chat Scraper
Handles model selection, message sending, and response extraction
"""
import asyncio
import re
import time
from datetime import datetime
from pathlib import Path
from typing import Optional, List, Dict, Any
import json

from bs4 import BeautifulSoup
from loguru import logger

from anti_detect_browser import AntiDetectBrowser
from config import LMARENA_CONFIG, TRADING_PROMPT, RESPONSES_DIR


class LMArenaScaper:
    """
    LMArena.ai chat scraper with model selection and response extraction
    """

    def __init__(self, profile_name: str = "lmarena"):
        self.profile_name = profile_name
        self.browser: Optional[AntiDetectBrowser] = None
        self.current_model = None
        self.session_active = False
        self.conversation_history = []

        # Ensure responses directory exists
        RESPONSES_DIR.mkdir(parents=True, exist_ok=True)

        logger.info("LMArena scraper initialized")

    async def start(self):
        """Start the LMArena scraper"""
        try:
            self.browser = AntiDetectBrowser(self.profile_name)

            # Use mobile user agent for mobile version
            await self.browser.start_browser(
                mobile=True,
                proxy=None  # Add proxy configuration if needed
            )

            # Navigate to LMArena chat
            await self._navigate_to_chat()

            logger.info("LMArena scraper started successfully")

        except Exception as e:
            logger.error(f"Failed to start LMArena scraper: {e}")
            await self.cleanup()
            raise

    async def _navigate_to_chat(self):
        """Navigate to the LMArena chat interface"""
        try:
            logger.info("Navigating to LMArena chat...")

            # Navigate to the specific chat URL
            await self.browser.navigate_to(
                LMARENA_CONFIG["chat_url"],
                timeout=30000
            )

            # Wait for page to load
            await asyncio.sleep(3)

            # Try to dismiss any initial popups or modals
            await self._dismiss_popups()

            # Wait for chat interface to be ready
            await self._wait_for_chat_interface()

            self.session_active = True
            logger.info("Successfully navigated to LMArena chat")

        except Exception as e:
            logger.error(f"Failed to navigate to chat: {e}")
            raise

    async def _dismiss_popups(self):
        """Dismiss any popups or modal dialogs"""
        try:
            # Common popup dismissal patterns
            popup_patterns = [
                "button:has-text('Accept')",
                "button:has-text('Continue')",
                "button:has-text('OK')",
                "button:has-text('Close')",
                "[aria-label='Close']",
                ".modal-close",
                ".close-button",
                "[data-testid='close']"
            ]

            for pattern in popup_patterns:
                try:
                    element = await self.browser.page.query_selector(pattern)
                    if element and await element.is_visible():
                        await element.click()
                        await asyncio.sleep(1)
                        logger.debug(f"Dismissed popup with pattern: {pattern}")
                        break
                except:
                    continue

            # Press Escape as fallback
            await self.browser.page.keyboard.press("Escape")
            await asyncio.sleep(1)

        except Exception as e:
            logger.warning(f"Error dismissing popups: {e}")

    async def _wait_for_chat_interface(self):
        """Wait for chat interface elements to be ready"""
        try:
            # Wait for any of the expected selectors
            selectors_to_try = [
                LMARENA_CONFIG["selectors"]["chat_input"],
                "textarea",
                "input[type='text']",
                "[contenteditable='true']"
            ]

            element_found = False
            for selector in selectors_to_try:
                try:
                    await self.browser.page.wait_for_selector(
                        selector,
                        timeout=10000
                    )
                    element_found = True
                    logger.debug(f"Found chat interface with selector: {selector}")
                    break
                except:
                    continue

            if not element_found:
                raise Exception("Chat interface not found")

            # Additional wait for full page load
            await asyncio.sleep(2)

        except Exception as e:
            logger.error(f"Failed to find chat interface: {e}")
            raise

    async def get_available_models(self) -> List[str]:
        """Get list of available AI models"""
        try:
            models = []

            # Try to find model dropdown
            model_selectors = [
                LMARENA_CONFIG["selectors"]["model_dropdown"],
                "select",
                "button[aria-haspopup='listbox']",
                ".model-selector",
                "[data-testid*='model']"
            ]

            for selector in model_selectors:
                try:
                    dropdown = await self.browser.page.query_selector(selector)
                    if dropdown and await dropdown.is_visible():
                        # Click to open dropdown
                        await dropdown.click()
                        await asyncio.sleep(1)

                        # Get options
                        option_selectors = [
                            LMARENA_CONFIG["selectors"]["model_option"],
                            "option",
                            "[role='option']",
                            ".model-option"
                        ]

                        for opt_selector in option_selectors:
                            options = await self.browser.page.query_selector_all(opt_selector)
                            for option in options:
                                text = await option.inner_text()
                                if text and text.strip():
                                    models.append(text.strip())

                        if models:
                            break

                except Exception as e:
                    logger.debug(f"Error with selector {selector}: {e}")
                    continue

            # Fallback to configured models if dynamic detection fails
            if not models:
                models = LMARENA_CONFIG["models"]
                logger.info("Using configured model list as fallback")

            logger.info(f"Available models: {models}")
            return models

        except Exception as e:
            logger.error(f"Failed to get available models: {e}")
            return LMARENA_CONFIG["models"]

    async def select_model(self, model_name: str) -> bool:
        """Select a specific AI model"""
        try:
            logger.info(f"Selecting model: {model_name}")

            # Find model dropdown
            model_selectors = [
                LMARENA_CONFIG["selectors"]["model_dropdown"],
                "select",
                "button[aria-haspopup='listbox']",
                ".model-selector"
            ]

            dropdown_found = False
            for selector in model_selectors:
                try:
                    dropdown = await self.browser.page.query_selector(selector)
                    if dropdown and await dropdown.is_visible():
                        await dropdown.click()
                        await asyncio.sleep(1)
                        dropdown_found = True
                        break
                except:
                    continue

            if not dropdown_found:
                logger.warning("Model dropdown not found")
                return False

            # Find and click the specific model option
            option_found = False
            option_selectors = [
                f"[data-value='{model_name}']",
                f"option[value='{model_name}']",
                f"[role='option']:has-text('{model_name}')",
                f".model-option:has-text('{model_name}')"
            ]

            # Try exact match first
            for selector in option_selectors:
                try:
                    option = await self.browser.page.query_selector(selector)
                    if option:
                        await option.click()
                        await asyncio.sleep(1)
                        option_found = True
                        break
                except:
                    continue

            # If exact match fails, try partial text match
            if not option_found:
                try:
                    options = await self.browser.page.query_selector_all(
                        LMARENA_CONFIG["selectors"]["model_option"]
                    )

                    for option in options:
                        text = await option.inner_text()
                        if model_name.lower() in text.lower():
                            await option.click()
                            await asyncio.sleep(1)
                            option_found = True
                            break

                except Exception as e:
                    logger.error(f"Error finding model option: {e}")

            if option_found:
                self.current_model = model_name
                logger.info(f"Successfully selected model: {model_name}")
                return True
            else:
                logger.warning(f"Model {model_name} not found")
                return False

        except Exception as e:
            logger.error(f"Failed to select model {model_name}: {e}")
            return False

    async def send_message(self, message: str, image_path: Optional[str] = None) -> bool:
        """Send a message to the selected AI model"""
        try:
            logger.info(f"Sending message: {message[:100]}...")

            # Find chat input field
            input_selectors = [
                LMARENA_CONFIG["selectors"]["chat_input"],
                "textarea[placeholder*='Ask']",
                "textarea[placeholder*='follow']",
                "input[placeholder*='message']",
                "textarea",
                "[contenteditable='true']"
            ]

            input_found = False
            for selector in input_selectors:
                try:
                    input_element = await self.browser.page.query_selector(selector)
                    if input_element and await input_element.is_visible():
                        # Clear any existing text
                        await input_element.click()
                        await self.browser.page.keyboard.press("Control+a")
                        await asyncio.sleep(0.5)

                        # Type the message
                        await self.browser.type_text(selector, message, clear_first=False)
                        input_found = True
                        break
                except Exception as e:
                    logger.debug(f"Error with input selector {selector}: {e}")
                    continue

            if not input_found:
                logger.error("Chat input field not found")
                return False

            # Upload image if provided
            if image_path and Path(image_path).exists():
                await self._upload_image(image_path)

            # Find and click send button
            await asyncio.sleep(1)

            send_selectors = [
                LMARENA_CONFIG["selectors"]["send_button"],
                "button[type='submit']",
                "button:has-text('Send')",
                ".send-button",
                "[data-testid='send']"
            ]

            send_found = False
            for selector in send_selectors:
                try:
                    send_button = await self.browser.page.query_selector(selector)
                    if send_button and await send_button.is_visible():
                        await send_button.click()
                        send_found = True
                        break
                except:
                    continue

            # Fallback: try pressing Enter
            if not send_found:
                await self.browser.page.keyboard.press("Enter")
                logger.debug("Used Enter key as send fallback")

            await asyncio.sleep(2)
            logger.info("Message sent successfully")
            return True

        except Exception as e:
            logger.error(f"Failed to send message: {e}")
            return False

    async def _upload_image(self, image_path: str):
        """Upload an image to the chat"""
        try:
            # Look for file upload button or input
            upload_selectors = [
                "input[type='file']",
                "button[aria-label*='upload']",
                ".upload-button",
                "[data-testid='upload']"
            ]

            for selector in upload_selectors:
                try:
                    upload_element = await self.browser.page.query_selector(selector)
                    if upload_element:
                        if selector == "input[type='file']":
                            await upload_element.set_input_files(image_path)
                        else:
                            await upload_element.click()
                            # Handle file dialog
                            file_input = await self.browser.page.query_selector("input[type='file']")
                            if file_input:
                                await file_input.set_input_files(image_path)

                        logger.info(f"Uploaded image: {image_path}")
                        await asyncio.sleep(2)
                        return

                except Exception as e:
                    logger.debug(f"Error with upload selector {selector}: {e}")
                    continue

            logger.warning("Could not find image upload option")

        except Exception as e:
            logger.error(f"Failed to upload image: {e}")

    async def wait_for_response(self, timeout: int = None) -> Optional[str]:
        """Wait for and extract AI response"""
        try:
            if timeout is None:
                timeout = LMARENA_CONFIG["response_timeout"]

            logger.info("Waiting for AI response...")

            # Response selectors to try
            response_selectors = [
                LMARENA_CONFIG["selectors"]["response_area"],
                ".message-content",
                ".response-text",
                ".chat-message:last-child",
                ".ai-response",
                "[data-testid='response']"
            ]

            start_time = time.time()
            response_text = ""

            while time.time() - start_time < timeout / 1000:
                for selector in response_selectors:
                    try:
                        elements = await self.browser.page.query_selector_all(selector)
                        if elements:
                            # Get the last message (most recent)
                            last_element = elements[-1]
                            text = await last_element.inner_text()

                            if text and text.strip() and len(text.strip()) > 10:
                                response_text = text.strip()
                                logger.info(f"Response received: {response_text[:100]}...")
                                return response_text

                    except Exception as e:
                        logger.debug(f"Error checking response with {selector}: {e}")
                        continue

                # Wait before next check
                await asyncio.sleep(2)

            # If no response found, try BeautifulSoup parsing
            if not response_text:
                response_text = await self._extract_response_with_bs4()

            if response_text:
                return response_text
            else:
                logger.warning("No response received within timeout")
                return None

        except Exception as e:
            logger.error(f"Failed to wait for response: {e}")
            return None

    async def _extract_response_with_bs4(self) -> Optional[str]:
        """Extract response using BeautifulSoup as fallback"""
        try:
            # Get page HTML content
            html_content = await self.browser.page.content()
            soup = BeautifulSoup(html_content, 'html.parser')

            # Try various response patterns
            response_patterns = [
                {'class': re.compile(r'.*response.*', re.I)},
                {'class': re.compile(r'.*message.*', re.I)},
                {'class': re.compile(r'.*chat.*', re.I)},
                {'data-testid': re.compile(r'.*response.*', re.I)}
            ]

            for pattern in response_patterns:
                elements = soup.find_all('div', pattern)
                if elements:
                    # Get the last matching element
                    text = elements[-1].get_text(strip=True)
                    if text and len(text) > 10:
                        logger.debug("Extracted response with BeautifulSoup")
                        return text

            return None

        except Exception as e:
            logger.error(f"BeautifulSoup extraction failed: {e}")
            return None

    async def save_response(self, response: str, model_name: str = None, image_path: str = None) -> str:
        """Save response to output file"""
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            model_str = model_name or self.current_model or "unknown"

            # Create filename
            filename = f"trading_analysis_{model_str}_{timestamp}.txt"
            output_path = RESPONSES_DIR / filename

            # Prepare content
            content_lines = [
                f"Trading Analysis Response",
                f"=" * 50,
                f"Timestamp: {datetime.now().isoformat()}",
                f"Model: {model_str}",
                f"Image: {Path(image_path).name if image_path else 'None'}",
                f"=" * 50,
                "",
                response,
                "",
                f"Generated by LMArena Scraper"
            ]

            # Write to file
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write('\n'.join(content_lines))

            logger.info(f"Response saved to: {output_path}")

            # Also save as JSON for structured data
            json_data = {
                "timestamp": datetime.now().isoformat(),
                "model": model_str,
                "image_path": image_path,
                "response": response,
                "filename": filename
            }

            json_path = output_path.with_suffix('.json')
            with open(json_path, 'w', encoding='utf-8') as f:
                json.dump(json_data, f, indent=2, ensure_ascii=False)

            return str(output_path)

        except Exception as e:
            logger.error(f"Failed to save response: {e}")
            return ""

    async def analyze_chart(self, image_path: str, custom_prompt: str = None, model_name: str = None) -> Optional[Dict[str, Any]]:
        """Complete chart analysis workflow"""
        try:
            logger.info(f"Starting chart analysis with image: {image_path}")

            # Select model if specified
            if model_name and model_name != self.current_model:
                await self.select_model(model_name)

            # Use custom prompt or default trading prompt
            prompt = custom_prompt or TRADING_PROMPT

            # Send message with image
            success = await self.send_message(prompt, image_path)
            if not success:
                logger.error("Failed to send analysis message")
                return None

            # Wait for response
            response = await self.wait_for_response()
            if not response:
                logger.error("No response received")
                return None

            # Save response
            output_file = await self.save_response(
                response,
                self.current_model,
                image_path
            )

            # Prepare result
            result = {
                "success": True,
                "model": self.current_model,
                "image_path": image_path,
                "response": response,
                "output_file": output_file,
                "timestamp": datetime.now().isoformat()
            }

            # Add to conversation history
            self.conversation_history.append(result)

            logger.info("Chart analysis completed successfully")
            return result

        except Exception as e:
            logger.error(f"Chart analysis failed: {e}")
            return {
                "success": False,
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            }

    async def test_multiple_models(self, image_path: str, models: List[str] = None) -> List[Dict[str, Any]]:
        """Test chart analysis with multiple AI models"""
        try:
            if models is None:
                models = LMARENA_CONFIG["models"][:3]  # Test first 3 models

            results = []

            for model in models:
                logger.info(f"Testing model: {model}")

                try:
                    result = await self.analyze_chart(
                        image_path=image_path,
                        model_name=model
                    )

                    if result:
                        results.append(result)

                    # Wait between model switches
                    await asyncio.sleep(5)

                except Exception as e:
                    logger.error(f"Failed to test model {model}: {e}")
                    continue

            logger.info(f"Completed testing {len(results)} models")
            return results

        except Exception as e:
            logger.error(f"Multiple model testing failed: {e}")
            return []

    async def get_conversation_history(self) -> List[Dict[str, Any]]:
        """Get conversation history"""
        return self.conversation_history

    async def clear_conversation_history(self):
        """Clear conversation history"""
        self.conversation_history = []
        logger.info("Conversation history cleared")

    async def cleanup(self):
        """Clean up resources"""
        try:
            if self.browser:
                await self.browser.cleanup()
                self.browser = None

            self.session_active = False
            logger.info("LMArena scraper cleanup completed")

        except Exception as e:
            logger.error(f"Cleanup failed: {e}")

    async def __aenter__(self):
        """Async context manager entry"""
        await self.start()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit"""
        await self.cleanup()
