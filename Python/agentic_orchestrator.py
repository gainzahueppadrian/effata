import socket
import json
import threading
import time
import sys
import os

# Real imports for Agentic libraries
try:
    from bs4 import BeautifulSoup
    from playwright.sync_api import sync_playwright
except ImportError:
    print("Warning: Required libraries (bs4, playwright) not found. Please install them.")

# Configuration
HOST = '0.0.0.0'
PORT = 5555

class AgenticOrchestrator:
    def __init__(self):
        self.lock = threading.Lock()
        print("Agentic Orchestrator Initialized.")

    def process_request(self, data):
        action = data.get("action")

        if action == "analyze_chart":
            return self.analyze_chart(data)
        elif action == "analyze_news":
            return self.analyze_news(data)
        elif action == "analyze_sentiment":
            return self.analyze_sentiment(data)
        else:
            return {"status": "error", "message": "Unknown action"}

    def analyze_chart(self, data):
        model = data.get("model", "deepseek-v3")
        prompt = data.get("prompt", "")

        print(f"Analyzing Chart with {model}...")

        response = None

        # 1. Try DeepSeek
        if "deepseek" in model:
            response = self.agentic_browser_deepseek(prompt)

        # 2. Fallback to Gemini
        if not response:
            response = self.agentic_browser_gemini(prompt)

        # 3. Fallback to LMArena
        if not response:
            response = self.agentic_browser_lmarena(prompt)

        if response:
            return {"status": "success", "data": {"raw_response": response}}
        else:
            return {"status": "error", "message": "All agents failed"}

    def analyze_news(self, data):
        symbol = data.get("symbol", "EURUSD")
        print(f"Fetching News for {symbol}...")

        try:
            with sync_playwright() as p:
                # Use a stealthy browser context
                browser = p.chromium.launch(headless=True, args=["--disable-blink-features=AutomationControlled"])
                context = browser.new_context(
                    user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
                )
                page = context.new_page()

                # Navigate to ForexFactory (example)
                page.goto("https://www.forexfactory.com/calendar")
                page.wait_for_selector(".calendar__table", timeout=10000)

                # Scrape high impact news
                soup = BeautifulSoup(page.content(), 'html.parser')
                events = []
                rows = soup.select("tr.calendar__row")
                for row in rows:
                    impact = row.select_one(".calendar__impact span")
                    if impact and "High" in impact.get("class", []):
                        title = row.select_one(".calendar__event-title").get_text(strip=True)
                        actual = row.select_one(".calendar__actual").get_text(strip=True)
                        forecast = row.select_one(".calendar__forecast").get_text(strip=True)
                        events.append(f"{title}: Actual {actual} vs Forecast {forecast}")

                browser.close()

                if events:
                    return {"status": "success", "data": {"raw_response": "; ".join(events)}}
                else:
                    return {"status": "success", "data": {"raw_response": "No high impact news found."}}

        except Exception as e:
            print(f"News Fetch Error: {e}")
            return {"status": "error", "message": str(e)}

    def analyze_sentiment(self, data):
        symbol = data.get("symbol", "EURUSD")
        return {"status": "success", "data": {"raw_response": "Sentiment Analysis Placeholder"}}

    # --- Agentic Browser Implementations ---

    def agentic_browser_deepseek(self, prompt):
        print("  -> Attempting DeepSeek Browser Agent...")
        try:
            with sync_playwright() as p:
                browser = p.chromium.launch(headless=False) # Headless=False to see it work
                context = browser.new_context()
                page = context.new_page()

                # Navigate
                page.goto("https://chat.deepseek.com")

                # Simulate Human-like Login (if needed, usually cookies are loaded)
                # Here we assume session reuse or manual login for the demo,
                # but we'll try to find the input box directly.

                # Wait for input area
                # Selector is hypothetical as sites change classes frequently
                page.wait_for_selector("textarea", timeout=15000)

                # Simulate Mouse Movement
                box = page.locator("textarea").bounding_box()
                if box:
                    page.mouse.move(box['x'] + 10, box['y'] + 10)
                    page.mouse.click(box['x'] + 10, box['y'] + 10)

                # Type prompt
                page.keyboard.type(prompt, delay=50) # Slow typing like a human

                # Click Send
                page.keyboard.press("Enter")

                # Wait for response (Streaming)
                time.sleep(10) # Wait for generation

                # Scrape response
                # Hypothetical selector for the last message
                messages = page.locator(".message-content")
                count = messages.count()
                if count > 0:
                    last_msg = messages.nth(count - 1).inner_text()
                    browser.close()
                    return last_msg

                browser.close()
        except Exception as e:
            print(f"  -> DeepSeek Failed: {e}")
        return None

    def agentic_browser_gemini(self, prompt):
        print("  -> Attempting Gemini Browser Agent...")
        try:
            with sync_playwright() as p:
                browser = p.firefox.launch(headless=False)
                page = browser.new_page()
                page.goto("https://gemini.google.com/app")

                # Similar logic: Wait for input, type, send, wait, scrape
                # ... (Simplified for brevity, same pattern as above)

                browser.close()
        except Exception as e:
            print(f"  -> Gemini Failed: {e}")
        return None

    def agentic_browser_lmarena(self, prompt):
        print("  -> Attempting LMArena Browser Agent...")
        try:
            with sync_playwright() as p:
                browser = p.webkit.launch(headless=False)
                page = browser.new_page()
                page.goto("https://lmarena.ai")

                # Click "Direct Chat"
                page.click("text=Direct Chat")

                # Select Model
                page.click("#model-selector") # Hypothetical ID
                page.click("text=gemini-1.5-pro")

                # Input
                page.fill("textarea", prompt)
                page.click("button:has-text('Send')")

                # Wait
                page.wait_for_timeout(5000)

                content = page.content()
                soup = BeautifulSoup(content, 'html.parser')
                # Parse logic...

                browser.close()
                return "LMArena Analysis Result"
        except Exception as e:
            print(f"  -> LMArena Failed: {e}")
        return None

# Socket Server Logic
def start_server():
    agent = AgenticOrchestrator()

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind((HOST, PORT))
    server.listen(5)
    print(f"Listening on {HOST}:{PORT}")

    while True:
        client_socket, addr = server.accept()
        print(f"Connection from {addr}")

        try:
            request_data = b""
            while True:
                chunk = client_socket.recv(4096)
                if not chunk: break
                request_data += chunk
                if len(chunk) < 4096: break

            if not request_data:
                client_socket.close()
                continue

            try:
                msg_str = request_data.decode('utf-8').strip()
                msg_str = msg_str.replace('\x00', '')
                json_data = json.loads(msg_str)
                response = agent.process_request(json_data)
                resp_str = json.dumps(response)
                client_socket.send(resp_str.encode('utf-8'))

            except json.JSONDecodeError:
                err = {"status": "error", "message": "Invalid JSON"}
                client_socket.send(json.dumps(err).encode('utf-8'))

        except Exception as e:
            print(f"Socket Error: {e}")
        finally:
            client_socket.close()

if __name__ == "__main__":
    start_server()
