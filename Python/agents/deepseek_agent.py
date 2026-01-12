import torch
from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig
import logging

class DeepSeekAgent:
    def __init__(self, model_name="deepseek-ai/DeepSeek-V3", load_in_4bit=True):
        self.logger = logging.getLogger("DeepSeekAgent")
        self.model_name = model_name
        self.tokenizer = None
        self.model = None
        self.device = "cuda" if torch.cuda.is_available() else "cpu"

        self._load_model(load_in_4bit)

    def _load_model(self, load_in_4bit):
        try:
            self.logger.info(f"Loading tokenizer for {self.model_name}...")
            self.tokenizer = AutoTokenizer.from_pretrained(self.model_name, trust_remote_code=True)

            self.logger.info(f"Loading model {self.model_name} on {self.device}...")

            quantization_config = None
            if load_in_4bit and self.device == "cuda":
                quantization_config = BitsAndBytesConfig(
                    load_in_4bit=True,
                    bnb_4bit_compute_dtype=torch.float16
                )

            self.model = AutoModelForCausalLM.from_pretrained(
                self.model_name,
                trust_remote_code=True,
                device_map="auto" if self.device == "cuda" else None,
                quantization_config=quantization_config,
                torch_dtype=torch.float16 if self.device == "cuda" else torch.float32
            )
            self.logger.info("Model loaded successfully.")

        except Exception as e:
            self.logger.error(f"Failed to load DeepSeek model: {e}")
            raise e

    def generate_response(self, prompt, max_new_tokens=512, temperature=0.7):
        if not self.model or not self.tokenizer:
            return "Error: Model not loaded."

        try:
            inputs = self.tokenizer(prompt, return_tensors="pt").to(self.device)

            with torch.no_grad():
                outputs = self.model.generate(
                    inputs.input_ids,
                    max_new_tokens=max_new_tokens,
                    temperature=temperature,
                    do_sample=True,
                    pad_token_id=self.tokenizer.eos_token_id
                )

            response = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
            # Remove the prompt from the response if desired, though usually decode includes it.
            # Simple slice if needed, but often user wants full context.
            return response

        except Exception as e:
            self.logger.error(f"Generation failed: {e}")
            return f"Error during generation: {e}"

    def analyze_sentiment(self, text):
        prompt = f"""
        Analyze the sentiment of the following financial news text.
        Determine if it is Bullish, Bearish, or Neutral.
        Provide a confidence score (0-100%).

        Text: "{text}"

        Format: Sentiment: [TYPE] | Confidence: [SCORE]%
        """
        return self.generate_response(prompt, max_new_tokens=100)
