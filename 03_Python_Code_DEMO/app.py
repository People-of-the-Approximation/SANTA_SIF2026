import io
import uuid
import asyncio
import contextlib
import numpy as np
import torch
import matplotlib
import base64

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import colors as mcolors
from matplotlib.colors import LinearSegmentedColormap, ListedColormap, BoundaryNorm

from fastapi import FastAPI, Form, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse, StreamingResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles

import ui_main_page
import ui_gpt_page as ui_gpt
import ui_bert_page
from softmax_batch import open_serial, close_serial
from VerificationBERT import build_model_BERT, get_last_attention_matrix
from VerificationGPT2 import build_model_GPT2, get_last_gpt2_attention_matrix

SERIAL_PORT = "COM3"
BAUD_RATE = 115200
TIMEOUT = 1.0

models = {}
ATTN_STORE = {}
CACHE_STORE = {}
hardware_lock = asyncio.Lock()


@contextlib.asynccontextmanager
async def lifespan(app: FastAPI):
    print(f"[System] Attempting to open serial port {SERIAL_PORT}...")
    ser = None
    try:
        ser = open_serial(SERIAL_PORT, baud=BAUD_RATE, timeout=TIMEOUT)
        print(f"[System] Serial port {SERIAL_PORT} connected successfully.")
    except Exception as e:
        print(f"[Warning] Failed to open serial port: {e}")
        print("[System] Starting in SOFTWARE ONLY mode.")
        ser = None

    print("[System] Building BERT model...")
    tok_bert, base_bert, approx_bert, dev_bert = build_model_BERT(ser)

    print("[System] Building GPT-2 model...")
    tok_gpt2, base_gpt2, approx_gpt2, dev_gpt2 = build_model_GPT2(ser)

    models["ser"] = ser
    models["bert"] = (tok_bert, base_bert, approx_bert, dev_bert)
    models["gpt2"] = (tok_gpt2, base_gpt2, approx_gpt2, dev_gpt2)

    print("[System] All models loaded and ready!")
    yield
    if models.get("ser"):
        print("[System] Closing serial port...")
        close_serial(models["ser"])


app = FastAPI(lifespan=lifespan)
app.mount("/static", StaticFiles(directory="static"), name="static")


@app.get("/", response_class=HTMLResponse)
async def root():
    return RedirectResponse(url="/attention_ui")


@app.get("/attention_ui", response_class=HTMLResponse)
async def attention_ui(
    model: str = "gpt",
    port: str = SERIAL_PORT,
    mode: str = "hw",
):
    return HTMLResponse(ui_main_page.render_page1(model=model, port=port, mode=mode))


def plot_to_base64(matrix, layer, head):
    fig = plt.figure(figsize=(4, 4))
    ax = fig.add_subplot(111)
    ax.imshow(matrix, aspect="auto", cmap="viridis", interpolation="nearest")
    ax.axis("off")
    ax.set_title(f"Processing... L{layer} H{head}", fontsize=10)
    buf = io.BytesIO()
    fig.tight_layout(pad=0)
    fig.savefig(buf, format="png", dpi=80)
    plt.close(fig)
    buf.seek(0)
    return base64.b64encode(buf.getvalue()).decode("utf-8")


@app.websocket("/ws/generate")
async def websocket_generate(websocket: WebSocket):
    await websocket.accept()

    try:
        data = await websocket.receive_json()
        text = data.get("text", "")
        cache_id = data.get("cache_id", None)
        layer = int(data.get("layer", 0))
        head = int(data.get("head", 0))

        tokenizer, _, approx_model, device = models["gpt2"]
        loop = asyncio.get_event_loop()

        def sync_callback(matrix, layer_idx, head_idx):
            async def async_send():
                try:
                    b64_img = await asyncio.to_thread(
                        plot_to_base64, matrix, layer_idx, head_idx
                    )
                    await websocket.send_json({"type": "image", "data": b64_img})
                except Exception:
                    pass

            asyncio.run_coroutine_threadsafe(async_send(), loop)

        for module in approx_model.modules():
            if hasattr(module, "set_callback"):
                module.set_callback(sync_callback)

        await websocket.send_json({"type": "log", "data": "Hardware Initialized..."})

        def run_generation_task():
            input_ids = tokenizer.encode(text, return_tensors="pt").to(device)
            attention_mask = torch.ones_like(input_ids).to(device)

            output_tokens = approx_model.generate(
                input_ids,
                attention_mask=attention_mask,
                max_new_tokens=5,
                do_sample=False,
                pad_token_id=tokenizer.eos_token_id,
                use_cache=False,
            )

            hw_text = tokenizer.decode(output_tokens[0], skip_special_tokens=True)

            real_attn = get_last_gpt2_attention_matrix(
                approx_model, layer=layer, head=head
            )

            return hw_text, output_tokens[0], real_attn

        result = await asyncio.to_thread(run_generation_task)
        hw_text, tokens_tensor, real_attn = result

        if cache_id:
            CACHE_STORE[cache_id] = {
                "hw_text": hw_text,
                "tokens": [tokenizer.decode([t]).strip() for t in tokens_tensor],
                "real_attn": real_attn,
            }
            print(f"[Cache] Saved result for ID: {cache_id}")

        await websocket.send_json({"type": "done"})

    except WebSocketDisconnect:
        print("[WS] Client disconnected")
    except Exception as e:
        print(f"[WS] Error: {e}")
        await websocket.send_json({"type": "error", "msg": str(e)})
    finally:
        tokenizer, _, approx_model, device = models["gpt2"]
        for module in approx_model.modules():
            if hasattr(module, "set_callback"):
                module.set_callback(None)


@app.post("/attention_generate", response_class=HTMLResponse)
async def attention_generate(
    text: str = Form(...),
    model: str = Form("gpt"),
    mode: str = Form("hw"),
    layer: int = Form(0),
    head: int = Form(0),
    max_len: int = Form(128),
    cache_id: str = Form(None),
):
    if "bert" not in models and "gpt2" not in models:
        return HTMLResponse("<h1>Error: Models initialization failed.</h1>")

    async with hardware_lock:
        if model == "bert":
            return process_bert(text, mode, layer, head, max_len)
        elif model == "gpt":
            return process_gpt(text, mode, layer, head, cache_id)
        else:
            return HTMLResponse(f"<h1>Error: Unknown model '{model}'</h1>")


def process_bert(text, mode, layer, head, max_len):
    tokenizer, base_model, approx_model, device = models["bert"]
    inputs = tokenizer(
        text, return_tensors="pt", truncation=True, max_length=max_len
    ).to(device)

    try:
        with torch.no_grad():
            out_base = base_model(**inputs, output_attentions=True)
        sw_probs = torch.softmax(out_base.logits, dim=-1).tolist()[0]
        pred_sw_idx = out_base.logits.argmax().item()
    except Exception as e:
        return HTMLResponse(f"<h1>SW Error: {e}</h1>")

    hw_probs = [0.0, 0.0]
    pred_hw_idx = -1
    hw_error = None

    if mode in ["hw", "auto"]:
        try:
            with torch.no_grad():
                out_approx = approx_model(**inputs).logits
            hw_probs = torch.softmax(out_approx, dim=-1).tolist()[0]
            pred_hw_idx = out_approx.argmax().item()
        except Exception as e:
            hw_error = str(e)

    attn_matrix = None
    if mode in ["hw", "auto"] and hw_error is None:
        attn_matrix = get_last_attention_matrix(approx_model, layer=layer, head=head)

    if attn_matrix is None and out_base.attentions is not None:
        try:
            sw_attn_layer = out_base.attentions[int(layer)]
            attn_matrix = sw_attn_layer[0, int(head), :, :].cpu().numpy()
            if hw_error:
                hw_error += "\n(Displaying SW Heatmap)"
            else:
                hw_error = "(Mode: SW - Displaying Baseline Heatmap)"
        except IndexError:
            pass

    if attn_matrix is None:
        T = inputs["input_ids"].shape[-1]
        attn_matrix = np.zeros((T, T))

    attn_id = str(uuid.uuid4())
    token_ids = inputs["input_ids"][0]
    tokens = tokenizer.convert_ids_to_tokens(token_ids)

    ATTN_STORE[attn_id] = {
        "attn": attn_matrix,
        "tokens": tokens,
        "meta": {"mode": mode, "layer": layer, "head": head},
    }
    match_line = "MATCH" if pred_sw_idx == pred_hw_idx else "MISMATCH"
    if pred_hw_idx == -1:
        match_line = "N/A"

    return HTMLResponse(
        ui_bert_page.render_bert_result_page(
            used_mode=mode,
            layer=layer,
            head=head,
            T=len(tokens),
            attn_id=attn_id,
            hw_ppos=hw_probs[1],
            hw_pneg=hw_probs[0],
            sw_ppos=sw_probs[1],
            sw_pneg=sw_probs[0],
            match_line=match_line,
            err_blocks=hw_error if hw_error else "",
        )
    )


def process_gpt(text, mode, layer, head, cache_id=None):
    tokenizer, base_model, approx_model, device = models["gpt2"]

    input_ids = tokenizer.encode(text, return_tensors="pt").to(device)
    attention_mask = torch.ones_like(input_ids).to(device)

    out_base = base_model.generate(
        input_ids,
        attention_mask=attention_mask,
        max_new_tokens=5,
        do_sample=False,
        pad_token_id=tokenizer.eos_token_id,
        use_cache=False,
        output_attentions=True,
        return_dict_in_generate=True,
    )
    sw_text = tokenizer.decode(out_base.sequences[0], skip_special_tokens=True)

    hw_text = ""
    hw_error = None
    real_attn = None

    cached_data = None
    if cache_id and cache_id in CACHE_STORE:
        print(f"[Cache] Hit! Using cached result for {cache_id}")
        cached_data = CACHE_STORE.pop(cache_id)

        hw_text = cached_data["hw_text"]
        real_attn = cached_data["real_attn"]
        tokens = cached_data["tokens"]

    else:
        if mode in ["hw", "auto"]:
            try:
                out_approx = approx_model.generate(
                    input_ids,
                    attention_mask=attention_mask,
                    max_new_tokens=5,
                    do_sample=False,
                    pad_token_id=tokenizer.eos_token_id,
                    use_cache=False,
                )
                hw_text = tokenizer.decode(out_approx[0], skip_special_tokens=True)
                real_attn = get_last_gpt2_attention_matrix(
                    approx_model, layer=layer, head=head
                )
                tokens = [tokenizer.decode([t]).strip() for t in out_approx[0]]
            except Exception as e:
                hw_error = str(e)
                hw_text = "HW Generation Failed"
                tokens = ["Err"] * 10
        else:
            tokens = [tokenizer.decode([t]).strip() for t in out_base.sequences[0]]

    if real_attn is None and out_base.attentions is not None:
        try:
            last_step_layers = out_base.attentions[-1]
            target_layer_attn = last_step_layers[int(layer)]
            real_attn = target_layer_attn[0, int(head), :, :].cpu().numpy()
            if hw_error:
                hw_error += "\n(Displaying SW Heatmap)"
            else:
                hw_error = "(Mode: SW - Displaying Baseline Heatmap)"
        except Exception:
            pass

    if real_attn is None:
        real_attn = np.zeros((10, 10))

    if "tokens" not in locals():
        tokens = [tokenizer.decode([t]).strip() for t in out_base.sequences[0]]

    attn_id = str(uuid.uuid4())
    ATTN_STORE[attn_id] = {
        "attn": real_attn,
        "tokens": tokens,
        "meta": {"mode": mode, "layer": layer, "head": head, "model": "GPT"},
    }

    return HTMLResponse(
        ui_gpt.render_result_page(
            input_text=text,
            sw_text=sw_text,
            hw_text=hw_text,
            attn_id=attn_id,
            error_hw=hw_error,
        )
    )


@app.get("/attn_heatmap.png")
async def attn_heatmap_png(id: str):
    def error_image(msg):
        fig_err, ax_err = plt.subplots(figsize=(5, 1))
        ax_err.text(0.5, 0.5, msg, ha="center", va="center", color="red")
        ax_err.axis("off")
        buf_err = io.BytesIO()
        fig_err.savefig(buf_err, format="png")
        plt.close(fig_err)
        buf_err.seek(0)
        return StreamingResponse(buf_err, media_type="image/png")

    if id not in ATTN_STORE:
        return error_image("Image not found in STORE")

    try:
        data = ATTN_STORE[id]
        attn = data["attn"]
        tokens = data["tokens"]
        meta = data["meta"]

        T_rows, T_cols = attn.shape
        L = len(tokens)

        display_tokens = tokens
        if L != T_cols:
            if L > T_cols:
                display_tokens = tokens[:T_cols]
            else:
                display_tokens = tokens + [""] * (T_cols - L)

        fig = plt.figure(figsize=(8, 8))
        ax = fig.add_subplot(111)

        base_colors = [
            "#F6EAE8",
            "#F2CEBE",
            "#ECAE96",
            "#E7916F",
            "#E47950",
            "#E06338",
            "#D85D34",
            "#CB552E",
            "#BD4E2A",
            "#A84121",
        ]
        light_cmap = LinearSegmentedColormap.from_list("light_part", base_colors[:5])
        light_colors = [mcolors.to_hex(light_cmap(i / 6)) for i in range(7)]
        dark_colors = base_colors[5:]
        colors_12 = light_colors + dark_colors
        bounds = np.linspace(0.0, 1.0, len(colors_12) + 1)
        cmap = ListedColormap(colors_12)
        norm = BoundaryNorm(bounds, cmap.N)

        im = ax.imshow(attn, aspect="auto", cmap=cmap, norm=norm)
        model_name = meta.get("model", "Model")
        ax.set_title(f"{model_name} Attention (L{meta['layer']} H{meta['head']})")

        if T_cols <= 64:
            ax.set_xticks(range(len(display_tokens)))
            ax.set_xticklabels(display_tokens, rotation=90, fontsize=8)
            if T_rows == len(display_tokens):
                ax.set_yticks(range(len(display_tokens)))
                ax.set_yticklabels(display_tokens, fontsize=8)
        else:
            ax.set_xticks([])
            ax.set_yticks([])

        buf = io.BytesIO()
        fig.tight_layout()
        fig.savefig(buf, format="png", dpi=100)
        plt.close(fig)
        buf.seek(0)
        return StreamingResponse(buf, media_type="image/png")

    except Exception as e:
        print(f"[Heatmap Generation Error] {e}")
        return error_image(f"Plot Error: {str(e)[:50]}...")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=8000)
