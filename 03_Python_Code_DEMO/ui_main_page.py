def render_page1(
    *,
    model: str = "gpt",
    port: str = "COM3",
    mode: str = "hw",
):
    model = (model or "gpt").lower()
    mode = (mode or "hw").lower()

    return f"""
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Main UI</title>
        <link rel="stylesheet" href="/static/style.css" />
        <style>
            .live-preview {{
                display: none;
                flex-direction: column;
                align-items: center;
                margin-top: 24px;
                padding: 20px;
                background: #f9fafb;
                border: 1px solid #e5e7eb;
                border-radius: 12px;
                box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
            }}
            .live-title {{
                font-size: 20px;
                font-weight: 600;
                color: #374151;
                margin-bottom: 12px;
            }}
            .live-img {{
                width: 600px;
                height: 600px;
                object-fit: contain;
                border: 1px solid #d1d5db;
                border-radius: 8px;
                background: #fff;
            }}
            .live-log {{
                font-size: 16px;
                color: #6b7280;
                margin-top: 10px;
                font-family: monospace;
            }}
        </style>
      </head>

      <body>
        <div id="loading-overlay" class="loading-overlay">
            <div class="spinner"></div>
            <div class="loading-text">Generating...</div>
        </div>

        <div class="page">
          <div class="hero-title">SIF2026 SANTA</div>

          <form id="run-form" class="input-wrap" method="post" action="/attention_generate">

            <div class="input-frame">
              <div class="input-left">
                <textarea
                  class="textarea"
                  name="text"
                  rows="1"
                  spellcheck="false"
                  placeholder="영어 문장을 입력하시오"
                ></textarea>

                <input type="hidden" name="layer" value="0" />
                <input type="hidden" name="head" value="0" />
                <input type="hidden" name="max_len" value="768" />
                <input type="hidden" name="baud" value="115200" />
                
                <input type="hidden" name="cache_id" id="cache_id" value="" />
              </div>

              <div class="input-divider"></div>

              <div class="input-right">
                <button type="submit" class="icon-btn" aria-label="Run">
                  <img
                    class="chip-icon"
                    src="/static/images/chip_icon.png"
                    alt="run"
                  />
                </button>
              </div>
            </div>

          <div class="control-group">
            <div class="control-title">Model</div>
            <div class="segmented">
              <input type="radio" id="model-gpt" name="model" value="gpt" checked>
              <label for="model-gpt">GPT</label>

              <input type="radio" id="model-bert" name="model" value="bert">
              <label for="model-bert">BERT</label>
            </div>
          </div>

          </form>
          <div id="live-area" class="live-preview">
             <div class="live-title">Real-time HW Execution</div>
             <img id="live-img" class="live-img" src="" alt="Realtime Attention" />
             <div class="live-log" id="status-text">Connecting to HW...</div>
          </div>

        </div>

        <script>
          const form = document.getElementById('run-form');
          const overlay = document.getElementById('loading-overlay');
          const liveArea = document.getElementById('live-area');
          const liveImg = document.getElementById('live-img');
          const statusText = document.getElementById('status-text');
          const cacheInput = document.getElementById('cache_id');

          function generateUUID() {{
              return 'xxxx-xxxx-xxxx-xxxx'.replace(/[x]/g, function(c) {{
                  var r = Math.random() * 16 | 0;
                  return r.toString(16);
              }});
          }}

          if (form) {{
              form.addEventListener('submit', function(e) {{
                const model = document.querySelector('input[name="model"]:checked')?.value;
                const mode = 'hw'; 
                  const newCacheId = generateUUID();
                  cacheInput.value = newCacheId;
                  
                  if ((mode === 'hw' || mode === 'auto') && model === 'gpt') {{
                      e.preventDefault(); 
                      
                      liveArea.style.display = 'flex';
                      statusText.innerText = "Initializing WebSocket...";

                      const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
                      const ws = new WebSocket(proto + "//" + location.host + "/ws/generate");

                      ws.onopen = function() {{
                          statusText.innerText = "Connected! Sending Prompt...";
                          const formData = new FormData(form);
                          const json = {{}};
                          formData.forEach((value, key) => json[key] = value);

                          json['cache_id'] = newCacheId;
                          ws.send(JSON.stringify(json));
                      }};

                      ws.onmessage = function(event) {{
                          const msg = JSON.parse(event.data);
                          
                          if (msg.type === 'image') {{
                              liveImg.src = "data:image/png;base64," + msg.data;
                              statusText.innerText = "Processing Layer/Head...";
                          }} else if (msg.type === 'log') {{
                              statusText.innerText = msg.data;
                          }} else if (msg.type === 'done') {{
                              statusText.innerText = "Done! Redirecting...";
                              form.submit(); 
                          }} else if (msg.type === 'error') {{
                              alert("Error: " + msg.msg);
                              ws.close();
                              liveArea.style.display = 'none';
                          }}
                      }};
                      
                      ws.onclose = function() {{ console.log("WS Closed"); }};
                      
                  }} else {{
                      overlay.style.display = 'flex';
                  }}
              }});
          }}
        </script>
      </body>
    </html>
    """
