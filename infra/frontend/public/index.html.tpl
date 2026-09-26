<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Discovery Drill</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    :root {
      --ink: #1a1a1a;
      --muted: #666;
      --line: #e6e6e6;
      --accent: #111;
      --bg-soft: #f7f7f8;
    }
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      max-width: 720px;
      margin: 0 auto;
      padding: 48px 24px 80px;
      color: var(--ink);
      line-height: 1.55;
    }
    h1 { font-size: 28px; margin: 0 0 4px; letter-spacing: -0.02em; }
    .tagline { color: var(--muted); font-size: 15px; margin: 0 0 32px; }
    button {
      background: var(--accent);
      color: white;
      border: none;
      padding: 12px 24px;
      border-radius: 8px;
      font-size: 16px;
      cursor: pointer;
    }
    button:hover { opacity: 0.9; }
    #loading, #login-prompt { margin-top: 120px; text-align: center; }
    #welcome {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding-bottom: 16px;
      border-bottom: 1px solid var(--line);
      margin-bottom: 28px;
    }
    #welcome-text { color: var(--muted); font-size: 14px; }
    #logout {
      background: transparent;
      color: var(--muted);
      border: 1px solid var(--line);
      font-size: 13px;
      padding: 6px 14px;
    }
    .card {
      background: var(--bg-soft);
      border: 1px solid var(--line);
      border-radius: 12px;
      padding: 20px 22px;
      margin-bottom: 20px;
    }
    .card h2 { font-size: 15px; margin: 0 0 10px; text-transform: uppercase; letter-spacing: 0.04em; color: var(--muted); }
    .card p { margin: 0 0 8px; font-size: 15px; }
    .card p:last-child { margin-bottom: 0; }
    .steps { margin: 0; padding-left: 18px; font-size: 15px; }
    .steps li { margin-bottom: 6px; }
    .personas { display: flex; gap: 16px; flex-wrap: wrap; }
    .persona { flex: 1; min-width: 220px; }
    .persona strong { display: block; margin-bottom: 4px; }
    .persona span { color: var(--muted); font-size: 14px; }
    #convai-widget-container { margin-top: 8px; }
    .why { font-size: 15px; }
    .why strong { color: var(--ink); }
  </style>
</head>
<body>

  <div id="loading">Checking your session...</div>

  <div id="login-prompt" style="display:none">
    <h1>Discovery Drill</h1>
    <p class="tagline">Practice customer discovery calls with an AI stakeholder, then get coached on how you did.</p>
    <button onclick="redirectToLogin()">Sign in to start</button>
  </div>

  <div id="app" style="display:none">
    <div id="welcome">
      <div>
        <h1 style="font-size:22px;">Discovery Drill</h1>
        <div id="welcome-text"></div>
      </div>
      <button id="logout" onclick="logout()">Sign out</button>
    </div>

    <div class="card">
      <h2>Why this matters</h2>
      <p class="why">In technical sales, the deals that stall are rarely lost on the demo — they're lost in discovery. Jumping to a pitch before understanding a customer's real constraints leads to POCs that solve the wrong problem, security reviews that blow past deadlines, and stakeholders who were never bought in. <strong>Strong discovery is the highest-leverage skill a field engineer has</strong>, and it's a skill you can only build by doing it.</p>
    </div>

    <div class="card">
      <h2>How it works</h2>
      <ol class="steps">
        <li>Pick a stakeholder persona to practice with.</li>
        <li>Run a real discovery conversation — ask questions, listen, dig into what matters.</li>
        <li>The persona reveals information only as deep as your questions go, and pushes back if you pitch too early.</li>
        <li>At the end, step out of the roleplay for a coaching debrief and a report card sent to your inbox.</li>
      </ol>
    </div>

    <div class="card">
      <h2>Who you'll talk to</h2>
      <div class="personas">
        <div class="persona">
          <strong>The Developer</strong>
          <span>Pragmatic, tech-literate, cautious about adding tools. Cares about integration, maintenance, and edge cases.</span>
        </div>
        <div class="persona">
          <strong>The CTO / VP</strong>
          <span>Decisive, time-pressed, outcome-driven. Cares about ROI, risk, and business impact — not code.</span>
        </div>
      </div>
    </div>

    <div class="card">
      <h2>Your session</h2>
      <p style="color:var(--muted); margin-bottom:14px;">Click the widget below to begin. Speak naturally, like a real call.</p>
      <!-- ElevenLabs Web Widget mounts here -->
      <div id="convai-widget-container"></div>
    </div>
  </div>

  <script src="https://unpkg.com/@elevenlabs/convai-widget-embed" async></script>

  <script>
    // ---------- CONFIG — filled in by Terraform's templatefile() ----------
    const COGNITO_DOMAIN = "${cognito_domain}";
    const COGNITO_CLIENT_ID = "${cognito_client_id}";
    const REDIRECT_URI = window.location.origin; // must exactly match the callback URL configured in Cognito
    const ELEVENLABS_AGENT_ID = "${elevenlabs_agent_id}";
    // ---------------------------------------------

    const STORAGE_KEY = "readycheck_id_token";

    function redirectToLogin() {
      const loginUrl =
        `$${COGNITO_DOMAIN}/login?client_id=$${COGNITO_CLIENT_ID}` +
        `&response_type=token&scope=openid+email+profile` +
        `&redirect_uri=$${encodeURIComponent(REDIRECT_URI)}`;
      window.location.href = loginUrl;
    }

    function logout() {
      sessionStorage.removeItem(STORAGE_KEY);
      const logoutUrl =
        `$${COGNITO_DOMAIN}/logout?client_id=$${COGNITO_CLIENT_ID}` +
        `&logout_uri=$${encodeURIComponent(REDIRECT_URI)}`;
      window.location.href = logoutUrl;
    }

    // Decode a JWT payload (no signature verification here — this is a
    // client-side convenience read only; Cognito itself already verified
    // the token during the Hosted UI redirect. Anything security-critical
    // server-side must still verify the token properly.)
    function decodeJwt(token) {
      const payload = token.split(".")[1];
      const json = atob(payload.replace(/-/g, "+").replace(/_/g, "/"));
      return JSON.parse(json);
    }

    function getTokenFromUrlHash() {
      const hash = window.location.hash.substring(1);
      const params = new URLSearchParams(hash);
      return params.get("id_token");
    }

    function initWidget(claims) {
      const container = document.getElementById("convai-widget-container");
      const widget = document.createElement("elevenlabs-convai");
      widget.setAttribute("agent-id", ELEVENLABS_AGENT_ID);

      // The frontend already required a real Cognito login before this
      // widget is ever mounted at all, so these claims are trusted here —
      // the Lambda does not re-verify them. See the comment at the top
      // of lambda_function.py for why that's a deliberate, reasonable
      // scope decision for this tool.
      //
      // NOTE: the exact attribute/API for passing dynamic variables into
      // the ElevenLabs web widget needs to be verified against their
      // current widget documentation — this is a reasonable guess at the
      // shape, not a confirmed API.
      widget.setAttribute(
        "dynamic-variables",
        JSON.stringify({
          trainee_name: claims.given_name || claims.name || claims.email,
          trainee_email: claims.email,
        })
      );

      container.appendChild(widget);
    }

    function showApp(claims) {
      document.getElementById("loading").style.display = "none";
      document.getElementById("login-prompt").style.display = "none";
      document.getElementById("app").style.display = "block";
      document.getElementById("welcome-text").textContent =
        `Signed in as $${claims.given_name || claims.email}`;
      initWidget(claims);
    }

    function showLogin() {
      document.getElementById("loading").style.display = "none";
      document.getElementById("login-prompt").style.display = "block";
    }

    (function main() {
      // Case 1: just redirected back from Cognito with a fresh token in the URL
      const tokenFromHash = getTokenFromUrlHash();
      if (tokenFromHash) {
        sessionStorage.setItem(STORAGE_KEY, tokenFromHash);
        // clean the token out of the visible URL
        window.history.replaceState({}, document.title, window.location.pathname);
        showApp(decodeJwt(tokenFromHash));
        return;
      }

      // Case 2: already have a token from earlier this session
      const existingToken = sessionStorage.getItem(STORAGE_KEY);
      if (existingToken) {
        try {
          const claims = decodeJwt(existingToken);
          // Basic expiry check — exp is in seconds
          if (claims.exp && claims.exp * 1000 > Date.now()) {
            showApp(claims);
            return;
          }
        } catch (e) {
          // fall through to login
        }
      }

      // Case 3: no valid session — gate access, show login
      showLogin();
    })();
  </script>
</body>
</html>
