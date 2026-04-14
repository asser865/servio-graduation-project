function el(tag, className) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  return node;
}

function addBubble(messagesEl, { role, label, text }) {
  const bubble = el("div", `chat-widget__bubble chat-widget__bubble--${role}`);
  const lbl = el("span", "chat-widget__label");
  lbl.textContent = label;
  lbl.setAttribute("aria-hidden", "true");

  const p = el("p");
  p.textContent = text;

  bubble.append(lbl, p);
  messagesEl.appendChild(bubble);
  messagesEl.scrollTop = messagesEl.scrollHeight;
}

export function initChatWidget() {
  const widget = document.querySelector("[data-chat-widget]");
  if (!widget) return;

  const overlay = widget.querySelector("[data-chat-overlay]");
  const fab = widget.querySelector("[data-chat-fab]");
  const panel = widget.querySelector("[data-chat-panel]");
  const closeBtn = widget.querySelector("[data-chat-close]");
  const form = widget.querySelector("[data-chat-form]");
  const input = widget.querySelector("[data-chat-input]");
  const messages = widget.querySelector("[data-chat-messages]");

  if (!overlay || !fab || !panel || !closeBtn || !form || !input || !messages) return;

  const open = () => {
    widget.classList.add("is-open");
    fab.setAttribute("aria-expanded", "true");
    panel.removeAttribute("hidden");
    overlay.removeAttribute("hidden");
    window.setTimeout(() => input.focus(), 0);
  };

  const close = () => {
    panel.classList.add("is-closing");
    widget.classList.remove("is-open");
    fab.setAttribute("aria-expanded", "false");
    overlay.setAttribute("hidden", "true");

    panel.addEventListener("animationend", function handler() {
      panel.removeEventListener("animationend", handler);
      panel.classList.remove("is-closing");
      panel.setAttribute("hidden", "true");
      fab.focus();
    });
  };

  fab.addEventListener("click", () => {
    const isOpen = widget.classList.contains("is-open");
    if (isOpen) close();
    else open();
  });

  closeBtn.addEventListener("click", close);
  overlay.addEventListener("click", close);

  document.addEventListener("keydown", (e) => {
    if (e.key !== "Escape") return;
    if (!widget.classList.contains("is-open")) return;
    close();
  });

  form.addEventListener("submit", (e) => {
    e.preventDefault();
    const value = input.value.trim();
    if (!value) return;

    addBubble(messages, { role: "user", label: "You", text: value });
    input.value = "";

    window.setTimeout(() => {
      addBubble(messages, {
        role: "ai",
        label: "SERVIO AI",
        text: "Got it. I’ll match you with verified technicians near you. Tell me your area and preferred time.",
      });
    }, 450);
  });
}


// .
