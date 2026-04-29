import { initThemeToggle } from "../components/theme-toggle.js";
import { getInitials } from '../utils/string.js';
import { sendMessage as apiSendMessage, getMessages, getUnreadCount, getConversations } from '../api/messages.js';

/**
 * messages.js — Refactored to be 100% API-driven.
 * Removed legacy AUTO_REPLIES and mock conversation data.
 */

const session = JSON.parse(localStorage.getItem('servio_session') || 'null');
if (!session) {
  const currentPath = window.location.pathname;
  const currentPage = currentPath.substring(currentPath.lastIndexOf('/') + 1) || 'index.html';
  const redirectParam = encodeURIComponent('./' + currentPage + window.location.search);
  window.location.href = './login.html?redirect=' + redirectParam;
}

let _activeChatBookingId  = '';
let _chatPollInterval     = null;
let _unreadPollInterval   = null;
let _convsPollInterval    = null;

// ── API-backed conversation loading ───────────────────────────────────────────
async function loadConversations() {
  const list = document.getElementById('conversationsList') || document.querySelector('.conversations-list, [data-conversations]');
  if (!list) return;
  try {
    const res = await getConversations();
    const convs = res.conversations || [];
    if (!convs.length) {
      list.innerHTML = `<div class="empty-state-small">
          <p data-i18n="messages_no_convs">No conversations yet.</p>
        </div>`;
      return;
    }
    list.innerHTML = convs.map(c => {
      const bookingId = c.booking?._id || '';
      const name = c.otherUser?.name || 'User';
      const preview = c.lastMessage?.content || '';
      const unread = c.unreadCount || 0;
      const date = c.lastMessage?.createdAt ? new Date(c.lastMessage.createdAt).toLocaleDateString() : '';
      const isActive = _activeChatBookingId === bookingId;

      return `<button class="conversation-item${unread ? ' is-unread' : ''}${isActive ? ' is-active' : ''}" data-booking-id="${bookingId}" type="button">
        <div class="conversation-item__top">
          <span class="conversation-item__name">${name}</span>
          ${unread ? `<span class="conversation-item__badge">${unread}</span>` : ''}
          <span class="conversation-item__date">${date}</span>
        </div>
        <p class="conversation-item__preview">${preview}</p>
      </button>`;
    }).join('');

    // Wire click to open chat
    list.querySelectorAll('[data-booking-id]').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.dataset.bookingId;
        const name = btn.querySelector('.conversation-item__name')?.textContent || 'Chat';
        openChat(id, name);
        // Refresh list to update active state
        list.querySelectorAll('.conversation-item').forEach(i => i.classList.remove('is-active'));
        btn.classList.add('is-active');
      });
    });
  } catch (err) {
    console.error('Failed to load conversations:', err);
  }
}

function openChat(bookingId, name) {
  _activeChatBookingId = bookingId;
  const chatPanel = document.getElementById('chatPanel') || document.querySelector('.chat-panel, [data-chat-panel]');
  const chatTitle = document.getElementById('chatRecipientName') || document.querySelector('[data-chat-title]');
  const emptyState = document.getElementById('selectConversation') || document.querySelector('.chat-empty-state');
  
  if (chatPanel)  chatPanel.hidden = false;
  if (emptyState) emptyState.hidden = true;
  if (chatTitle)  chatTitle.textContent = name;

  loadChatMessages(bookingId);

  // Start 5-second polling for new messages
  if (_chatPollInterval) clearInterval(_chatPollInterval);
  _chatPollInterval = setInterval(() => loadChatMessages(bookingId), 5000);
}

async function loadChatMessages(bookingId) {
  if (!bookingId) return;
  const msgList = document.getElementById('messagesList') || document.querySelector('.messages-list, [data-messages-list]');
  if (!msgList) return;

  try {
    const res = await getMessages(bookingId);
    const msgs = res.messages || [];
    const myId = session._id || '';

    const html = msgs.map((m, idx) => {
      const isMine = m.sender?._id === myId;
      const time = m.createdAt ? new Date(m.createdAt).toLocaleTimeString([], {hour:'2-digit', minute:'2-digit'}) : '';
      
      // Basic stacking logic
      const prev = msgs[idx-1];
      const isStacked = prev && prev.sender?._id === m.sender?._id;

      return `<div class="msg-bubble msg-bubble--${isMine ? 'mine' : 'theirs'} ${isStacked ? 'is-stacked' : ''}">
        <p class="msg-bubble__text">${m.content || ''}</p>
        <span class="msg-bubble__time">${time}</span>
      </div>`;
    }).join('');

    const wasAtBottom = msgList.scrollHeight - msgList.scrollTop <= msgList.clientHeight + 50;
    msgList.innerHTML = html;
    
    if (wasAtBottom) {
      msgList.scrollTop = msgList.scrollHeight;
    }
  } catch (err) {
    console.warn('Chat poll failed:', err);
  }
}

// ── Unread badge & list polling ────────────────────────────────────────────────
function refreshUnreadBadge() {
  getUnreadCount().then(res => {
    const count = res.count || 0;
    const badge = document.getElementById('topbar-notif-badge') || document.querySelector('[data-unread-badge]');
    if (badge) { 
      badge.textContent = count > 9 ? '9+' : String(count); 
      badge.hidden = count === 0; 
    }
  }).catch(() => {});
}

// ── UI Utilities ───────────────────────────────────────────────────────────────
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

// ── Initialization ─────────────────────────────────────────────────────────────
function initMessages() {
  const input = document.getElementById('messageInput');
  const sendBtn = document.getElementById('sendBtn');

  initThemeToggle();
  loadConversations();
  refreshUnreadBadge();

  // Periodic refreshes
  _unreadPollInterval = setInterval(refreshUnreadBadge, 15000);
  _convsPollInterval  = setInterval(loadConversations, 30000);

  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      clearInterval(_unreadPollInterval);
      clearInterval(_convsPollInterval);
      _unreadPollInterval = null;
      _convsPollInterval  = null;
    } else {
      if (!_unreadPollInterval) _unreadPollInterval = setInterval(refreshUnreadBadge, 15000);
      if (!_convsPollInterval)  _convsPollInterval  = setInterval(loadConversations, 30000);
      refreshUnreadBadge();
      loadConversations();
    }
  });

  attachQuickReplies(input, sendBtn);
  if (input) {
    resizeInput(input);
    updateComposerState(input, sendBtn);
  }

  async function handleSend() {
    if (!input || !_activeChatBookingId) return;
    const content = input.value.trim();
    if (!content) return;

    input.value = '';
    resizeInput(input);
    updateComposerState(input, sendBtn);

    try {
      await apiSendMessage(_activeChatBookingId, content);
      await loadChatMessages(_activeChatBookingId);
      loadConversations(); // refresh list to update previews
    } catch (err) {
      input.value = content; // restore on error
      resizeInput(input);
      updateComposerState(input, sendBtn);
      console.error('Send failed:', err.message);
    }
  }

  sendBtn?.addEventListener('click', handleSend);
  input?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  });

  input?.addEventListener('input', () => {
    resizeInput(input);
    updateComposerState(input, sendBtn);
  });
}

// Execute
document.addEventListener('DOMContentLoaded', initMessages);
