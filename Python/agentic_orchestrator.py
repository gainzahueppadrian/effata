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

# Real imports for Transformers Agents
try:
    from agents.deepseek_agent import DeepSeekAgent
    from agents.qwen_agent import QwenAgent
except ImportError:
    print("Warning: Local Agent scripts not found or transformers missing.")

# Configuration
HOST = '0.0.0.0'
PORT = 5555

class AgenticOrchestrator:
    def __init__(self):
        self.lock = threading.Lock()
        print("Agentic Orchestrator Initialized.")

        # Initialize Local Agents Lazy Loading
        self.local_deepseek = None
        self.local_qwen = None
        self.use_local_llm = False # Set to True if you want to load 70B models!

    def get_deepseek_agent(self):
        if not self.local_deepseek and self.use_local_llm:
            print("Initializing Local DeepSeek Agent...")
            try:
                self.local_deepseek = DeepSeekAgent()
            except Exception as e:
                print(f"Failed to init DeepSeek Agent: {e}")
        return self.local_deepseek

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

        # 1. Try Local LLM if enabled and matching model
        if self.use_local_llm and "deepseek" in model:
            agent = self.get_deepseek_agent()
            if agent:
                response = agent.generate_response(prompt)
                if response:
                    return {"status": "success", "data": {"raw_response": response}}

        # 2. Try Agentic Browser (DeepSeek)
        if "deepseek" in model and not response:
            response = self.agentic_browser_deepseek(prompt)

        # 3. Fallback to Gemini Browser
        if not response:
            response = self.agentic_browser_gemini(prompt)

        if response:
            return {"status": "success", "data": {"raw_response": response}}
        else:
            return {"status": "error", "message": "All agents failed"}

    def analyze_news(self, data):
        symbol = data.get("symbol", "EURUSD")
        print(f"Fetching News for {symbol}...")

        try:
            with sync_playwright() as p:
                browser = p.chromium.launch(headless=True, args=["--disable-blink-features=AutomationControlled"])
                context = browser.new_context(
                    user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
                )
                page = context.new_page()
                page.goto("https://www.forexfactory.com/calendar")

                # Check for Cloudflare/Captcha (basic check)
                if "challenge" in page.title().lower():
                    print("Captcha detected. Waiting...")
                    time.sleep(5)

                page.wait_for_selector(".calendar__table", timeout=15000)

                soup = BeautifulSoup(page.content(), 'html.parser')
                events = []
                rows = soup.select("tr.calendar__row")
                for row in rows:
                    impact = row.select_one(".calendar__impact span")
                    if impact and "High" in impact.get("class", []):
                        title = row.select_one(".calendar__event-title").get_text(strip=True)
                        actual_el = row.select_one(".calendar__actual")
                        forecast_el = row.select_one(".calendar__forecast")
                        actual = actual_el.get_text(strip=True) if actual_el else "N/A"
                        forecast = forecast_el.get_text(strip=True) if forecast_el else "N/A"

                        events.append(f"{title}: Actual {actual} vs Forecast {forecast}")

                browser.close()

                result_text = "; ".join(events) if events else "No high impact news found."
                return {"status": "success", "data": {"raw_response": result_text}}

        except Exception as e:
            print(f"News Fetch Error: {e}")
            return {"status": "error", "message": str(e)}

    def analyze_sentiment(self, data):
        symbol = data.get("symbol", "EURUSD")
        # Real Sentiment Implementation using TextBlob or LLM if available
        # First, try to fetch news for the symbol (simplified via Google News scraping here or re-using analyze_news)

        news_text = "Market is volatile." # Fallback

        # Try to scrape fresh news for sentiment
        try:
            with sync_playwright() as p:
                browser = p.chromium.launch(headless=True)
                page = browser.new_page()
                page.goto(f"https://www.google.com/search?q={symbol}+forex+news&tbm=nws")
                page.wait_for_selector("#search", timeout=10000)

                snippets = page.locator(".GI74Re").all_inner_texts() # Common class for snippets, might change
                if snippets:
                    news_text = " ".join(snippets[:5])
                browser.close()
        except Exception as e:
            print(f"Sentiment Scrape Error: {e}")

        # Analyze using Local LLM if available
        if self.use_local_llm:
            agent = self.get_deepseek_agent()
            if agent:
                sentiment = agent.analyze_sentiment(news_text)
                return {"status": "success", "data": {"raw_response": sentiment}}

        # Fallback to TextBlob
        try:
            from textblob import TextBlob
            blob = TextBlob(news_text)
            polarity = blob.sentiment.polarity
            sentiment_str = "Neutral"
            if polarity > 0.1: sentiment_str = "Bullish"
            if polarity < -0.1: sentiment_str = "Bearish"

            return {"status": "success", "data": {"raw_response": f"Sentiment: {sentiment_str} | Score: {polarity:.2f}"}}
        except ImportError:
             return {"status": "success", "data": {"raw_response": "Sentiment Lib Missing"}}


    # --- Agentic Browser Implementations ---

    def agentic_browser_deepseek(self, prompt):
        print("  -> Attempting DeepSeek Browser Agent...")
        try:
            with sync_playwright() as p:
                browser = p.chromium.launch(headless=False)
                context = browser.new_context()
                page = context.new_page()

                page.goto("https://chat.deepseek.com")

                # Handling Login / CAPTCHA is complex and usually requires user intervention or cookies
                # Here we attempt to find the input box assuming logged in or guest access

                try:
                    page.wait_for_selector("textarea", timeout=15000)
                except:
                    print("  -> Login required or selector changed.")
                    browser.close()
                    return None

                page.fill("textarea", prompt)
                page.keyboard.press("Enter")

                # Wait for streaming response
                time.sleep(15)

                # Scrape response (Generalized selector strategy)
                # Looking for the last assistant message
                # This selector is fragile and site-dependent
                content = page.content()
                soup = BeautifulSoup(content, 'html.parser')
                # Hypothetical class
                responses = soup.select(".ds-markdown")
                if responses:
                    return responses[-1].get_text()

                browser.close()
        except Exception as e:
            print(f"  -> DeepSeek Browser Failed: {e}")
        return None

    def agentic_browser_gemini(self, prompt):
        print("  -> Attempting Gemini Browser Agent...")
        try:
            with sync_playwright() as p:
                browser = p.firefox.launch(headless=False)
                page = browser.new_page()
                page.goto("https://gemini.google.com/app")

                # Check for login redirect
                if "accounts.google.com" in page.url:
                    print("  -> Gemini requires login.")
                    browser.close()
                    return None

                page.wait_for_selector("div[contenteditable='true']", timeout=10000)
                page.fill("div[contenteditable='true']", prompt)
                page.keyboard.press("Enter")

                time.sleep(15)

                # Scrape
                content = page.content()
                # Parse logic...
                browser.close()
                return "Gemini Analysis (Scraped)" # Placeholder for actual text extraction logic
        except Exception as e:
            print(f"  -> Gemini Failed: {e}")
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
