#!/usr/bin/bash

# https://huggingface.co/unsloth/gemma-4-31B-it-GGUF?show_file_info=gemma-4-31B-it-Q5_K_M.gguf
# NOTE: some issues on reddit; not ready yet?
#MODEL=hf.co/unsloth/gemma-4-31B-it-GGUF

# Based on https://www.reddit.com/r/ollama/comments/1s3vkfl/which_ollama_model_runs_best_for_coding/
MODEL=unsloth/Qwen3.5-35B-A3B-GGUF:UD-Q4_K_XL

ollama launch claude \
  --model $MODEL

