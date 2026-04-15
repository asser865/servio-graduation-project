import { initThemeToggle } from "../components/theme-toggle.js";
import { getInitials } from '../utils/string.js';

// Messaging workspace logic

const session = JSON.parse(localStorage.getItem('servio_session') || 'null');
if (!session) {
  const currentPath = window.location.pathname;
  const currentPage = currentPath.substring(currentPath.lastIndexOf('/') + 1) || 'index.html';
  const redirectParam = encodeURIComponent('./' + currentPage + window.location.search);
  window.location.href = './login.html?redirect=' + redirectParam;
}

const CONVERSATIONS = [
  {
    id: 1,
    person: 'Khaled Mohamed',
    initials: 'KM',
    status: 'Active now',
    listStatus: '',
    presence: 'online',
    unreadCount: 0,
    context: 'Plumbing | Booking #S-2847',
    href: { customer: './customer-dashboard.html', technician: './technician-dashboard.html' },
    messages: [
      { sent: false, text: "Salam, I've reviewed the job. Can come tomorrow 9am?", time: '09:15' },
      { sent: true, text: 'Yes, 9am works. The pipe under the sink is leaking.', time: '09:20' },
      { sent: false, text: "Got it, I'll bring replacement parts.", time: '09:22' },
      { sent: false, text: "Got it, I'll be there on time (thumbs up)", time: '10:30' },
    ],
  },
  {
    id: 2,
    person: 'Hassan Ali',
    initials: 'HA',
    status: 'Waiting on your reply',
    listStatus: '',
    presence: 'idle',
    unreadCount: 1,
    context: 'HVAC | Booking #S-2848',
    href: { customer: './customer-dashboard.html', technician: './technician-dashboard.html' },
    messages: [
      { sent: false, text: 'AC unit needs a refrigerant refill. I will assess on arrival.', time: '11:00' },
      { sent: true, text: "Perfect, please call when you're 10 minutes away.", time: '11:05' },
    ],
  },
  {
    id: 3,
    person: 'Mahmoud Ibrahim',
    initials: 'MI',
    status: 'Scheduled for today',
    listStatus: '',
    presence: 'away',
    unreadCount: 0,
    context: 'Electrical | Booking #S-2849',
    href: { customer: './customer-dashboard.html', technician: './technician-dashboard.html' },
    messages: [
      { sent: true, text: 'The circuit breaker keeps tripping. Is this dangerous?', time: '14:00' },
      { sent: false, text: 'Could be overload or a faulty breaker. I will test everything.', time: '14:08' },
      { sent: true, text: "Thank you, I'll make sure the main switch is off beforehand.", time: '14:10' },
    ],
  },
];

const AUTO_REPLIES = [
  'Thanks, noted.',
  "On it. I'll share an ETA soon.",
  'Understood. I will bring the necessary tools.',
  'Appreciate the heads-up. See you shortly.',
  'Will do. Let me know if anything changes.',
];

const presenceClassMap = {
  online: 'is-online',
  away: 'is-away',
};

let activeConvId = CONVERSATIONS[0].id;

function nowTime() {
  return new Date().toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
}

function getSelfInitials() {
  return getInitials(session?.name || session?.email || session?.role || 'Me');
}

function getConversationById(id) {
  return CONVERSATIONS.find((conversation) => conversation.id === id);
}

function getConversationItem(id) {
  return document.querySelector(`.conv-item[data-conv="${id}"]`);
}

function truncatePreview(text, maxLength = 58) {
  if (!text) return '';
  if (text.length <= maxLength) return text;
  return `${text.slice(0, maxLength - 1).trimEnd()}...`;
}

function setStatus(presence, statusText) {
  const dot = document.querySelector('.status-dot');
  const statusEl = document.getElementById('threadStatus');

  if (dot) {
    dot.className = 'status-dot';
    if (presenceClassMap[presence]) dot.classList.add(presenceClassMap[presence]);
  }

  if (statusEl) {
    const key = presence === 'online' ? 'messages_active' : 'messages_away';
    statusEl.textContent = typeof window.t === 'function' ? window.t(key) : (statusText || 'Active now');
    statusEl.setAttribute('data-i18n', key);
  }
}

function updateWorkspaceLink() {
  const homeLink = document.getElementById('workspaceHomeLink');
  if (!homeLink) return;

  const roleHomeMap = {
    customer: './customer-dashboard.html',
    technician: './technician-dashboard.html',
    admin: './admin-dashboard.html',
  };

  homeLink.href = roleHomeMap[session?.role] || './customer-dashboard.html';
}

function updateConversationListItem(conv) {
  const item = getConversationItem(conv.id);
  if (!item) return;

  const lastMessage = conv.messages[conv.messages.length - 1];
  const nameEl = item.querySelector('.conv-item__name');
  const timeEl = item.querySelector('.conv-item__time');
  const statusEl = item.querySelector('.conv-item__status');
  const previewEl = item.querySelector('.conv-item__preview');
  const avatarEl = item.querySelector('.conv-item__avatar');
  const metaRowEl = item.querySelector('.conv-item__row--meta');

  if (nameEl) nameEl.textContent = conv.person;
  if (timeEl && lastMessage) timeEl.textContent = lastMessage.time;
  if (previewEl && lastMessage) previewEl.textContent = truncatePreview(lastMessage.text);
  if (avatarEl) avatarEl.textContent = conv.initials;

  if (metaRowEl) {
    metaRowEl.classList.toggle('conv-item__row--statusless', !conv.listStatus);
  }

  if (conv.listStatus) {
    const nextStatusEl = statusEl || document.createElement('span');
    nextStatusEl.textContent = conv.listStatus;
    nextStatusEl.className = 'conv-item__status';
    if (conv.presence === 'away') {
      nextStatusEl.classList.add(presenceClassMap[conv.presence]);
    }

    if (!statusEl && metaRowEl) {
      metaRowEl.prepend(nextStatusEl);
    }
  } else if (statusEl) {
    statusEl.remove();
  }

  item.classList.toggle('is-active', conv.id === activeConvId);
  item.classList.toggle('is-unread', conv.unreadCount > 0);
  item.setAttribute('aria-selected', String(conv.id === activeConvId));

  /* Badges removed for cleaner UI */
}

function syncConversationList() {
  CONVERSATIONS.forEach((conversation) => updateConversationListItem(conversation));
}

function makeBubble(message, isGroupStart, isGroupEnd) {
  const bubble = document.createElement('article');
  bubble.className = `msg-bubble msg-bubble--${message.sent ? 'sent' : 'received'}`;
  if (!isGroupStart) bubble.classList.add('is-stack-top');
  if (!isGroupEnd) bubble.classList.add('is-stack-bottom');

  const textEl = document.createElement('p');
  textEl.className = 'msg-bubble__text';
  textEl.textContent = message.text;

  const meta = document.createElement('div');
  meta.className = 'msg-meta';

  const ts = document.createElement('time');
  ts.className = 'msg-timestamp';
  ts.textContent = message.time;

  meta.appendChild(ts);
  bubble.append(textEl, meta);
  return bubble;
}

function makeMessageRow(conv, message, index) {
  const previousMessage = conv.messages[index - 1];
  const nextMessage = conv.messages[index + 1];
  const isGroupStart = !previousMessage || previousMessage.sent !== message.sent;
  const isGroupEnd = !nextMessage || nextMessage.sent !== message.sent;

  const row = document.createElement('div');
  row.className = `message-row message-row--${message.sent ? 'sent' : 'received'}`;
  if (!isGroupStart) row.classList.add('is-stacked');
  if (isGroupEnd) row.classList.add('is-group-end');

  const leadingAside = document.createElement('div');
  leadingAside.className = 'message-row__aside message-row__aside--leading';

  const trailingAside = document.createElement('div');
  trailingAside.className = 'message-row__aside message-row__aside--trailing';

  const avatar = document.createElement('div');
  avatar.className = 'message-row__avatar';
  if (message.sent) avatar.classList.add('message-row__avatar--self');
  if (!isGroupEnd) avatar.classList.add('is-placeholder');
  avatar.textContent = message.sent ? getSelfInitials() : conv.initials;

  if (message.sent) {
    trailingAside.appendChild(avatar);
  } else {
    leadingAside.appendChild(avatar);
  }

  row.append(leadingAside, makeBubble(message, isGroupStart, isGroupEnd), trailingAside);
  return row;
}

function scrollThreadToBottom(behavior = 'auto') {
  const body = document.getElementById('threadBody');
  if (!body) return;
  body.scrollTo({ top: body.scrollHeight, behavior });
}

function renderThread(conv) {
  const body = document.getElementById('threadBody');
  if (!body) return;

  body.innerHTML = '';
  conv.messages.forEach((message, index) => {
    body.appendChild(makeMessageRow(conv, message, index));
  });
  scrollThreadToBottom();

  const nameEl = document.getElementById('threadName');
  const avatarEl = document.getElementById('threadAvatar');
  const ctxLink = document.getElementById('contextLink');

  if (nameEl) nameEl.textContent = conv.person;
  if (avatarEl) avatarEl.textContent = conv.initials;
  if (ctxLink) {
    ctxLink.textContent = conv.context;
    ctxLink.href = session?.role === 'technician' ? conv.href.technician : conv.href.customer;
  }

  setStatus(conv.presence, conv.status);
}

function appendMessage(convId, message) {
  const conv = getConversationById(convId);
  if (!conv) return;

  conv.messages.push(message);
  updateConversationListItem(conv);

  if (convId !== activeConvId) return;

  const body = document.getElementById('threadBody');
  if (!body) return;

  const previousRow = body.lastElementChild;
  const previousBubble = previousRow?.querySelector('.msg-bubble');
  const previousWasSent = previousBubble?.classList.contains('msg-bubble--sent');
  const isGroupStart = previousWasSent !== message.sent;

  if (!isGroupStart && previousRow) {
    previousRow.classList.remove('is-group-end');
    const previousAvatar = previousRow.querySelector('.message-row__avatar');
    if (previousAvatar) previousAvatar.classList.add('is-placeholder');
    previousBubble?.classList.add('is-stack-bottom');
  }

  const row = makeMessageRow(conv, message, conv.messages.length - 1);
  row.classList.add('is-new');
  body.appendChild(row);
  scrollThreadToBottom('smooth');
}

function resizeInput(inputEl) {
  if (!inputEl) return;
  inputEl.style.height = 'auto';
  inputEl.style.height = `${Math.min(inputEl.scrollHeight, 160)}px`;
}

function updateComposerState(inputEl, sendBtn) {
  if (!inputEl || !sendBtn) return;
  const hasValue = inputEl.value.trim().length > 0;
  sendBtn.disabled = !hasValue;
  sendBtn.classList.toggle('is-ready', hasValue);
}

function attachQuickReplies(inputEl, sendBtn) {
  const chips = document.querySelectorAll('.chip[data-reply]');
  chips.forEach((chip) => {
    chip.addEventListener('click', () => {
      if (!inputEl) return;
      inputEl.value = chip.dataset.reply || '';
      resizeInput(inputEl);
      updateComposerState(inputEl, sendBtn);
      inputEl.focus();
    });
  });
}

function scheduleAutoReply(convId) {
  const delay = 1000 + Math.random() * 1200;
  window.setTimeout(() => {
    const conv = getConversationById(convId);
    if (!conv) return;

    const reply = AUTO_REPLIES[Math.floor(Math.random() * AUTO_REPLIES.length)];
    const replyMessage = { sent: false, text: reply, time: nowTime() };

    if (convId !== activeConvId) {
      conv.unreadCount += 1;
    }

    appendMessage(convId, replyMessage);
  }, delay);
}

function setActiveConversation(nextId) {
  const conv = getConversationById(nextId);
  if (!conv) return;

  activeConvId = nextId;
  conv.unreadCount = 0;
  syncConversationList();
  renderThread(conv);
}

function initMessages() {
  const items = document.querySelectorAll('.conv-item');
  const input = document.getElementById('messageInput');
  const sendBtn = document.getElementById('sendBtn');

  initThemeToggle();
  updateWorkspaceLink();
  syncConversationList();
  renderThread(CONVERSATIONS[0]);
  attachQuickReplies(input, sendBtn);
  resizeInput(input);
  updateComposerState(input, sendBtn);

  items.forEach((item) => {
    item.addEventListener('click', () => {
      const nextId = Number.parseInt(item.dataset.conv || '', 10);
      if (!Number.isNaN(nextId)) setActiveConversation(nextId);
    });
  });

  function sendMessage() {
    if (!input) return;
    const text = input.value.trim();
    if (!text) return;

    const conv = getConversationById(activeConvId);
    if (!conv) return;

    const message = { sent: true, text, time: nowTime() };
    conv.unreadCount = 0;
    appendMessage(activeConvId, message);

    input.value = '';
    resizeInput(input);
    updateComposerState(input, sendBtn);

    sendBtn?.classList.add('sent-pulse');
    window.setTimeout(() => sendBtn?.classList.remove('sent-pulse'), 260);

    scheduleAutoReply(activeConvId);
  }

  sendBtn?.addEventListener('click', sendMessage);
  input?.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      sendMessage();
    }
  });

  input?.addEventListener('input', () => {
    resizeInput(input);
    updateComposerState(input, sendBtn);
  });
}

initMessages();

// .
