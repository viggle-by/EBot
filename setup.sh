#!/bin/bash

# Setup script for EBot
echo "Setting up EBot project..."

# Create project folder
mkdir -p EBot
cd EBot

# Create package.json
cat > package.json <<'EOL'
{
  "name": "ebot",
  "version": "1.0.0",
  "description": "Mineflayer bot with custom chat, commands, and web UI",
  "main": "bot.js",
  "scripts": {
    "start": "node bot.js"
  },
  "dependencies": {
    "mineflayer": "^4.10.0",
    "express": "^4.18.2",
    "body-parser": "^1.20.2",
    "minimatch": "^9.0.1"
  }
}
EOL

# Install dependencies
npm install

# Create filter.json
cat > filter.json <<EOL
[
  { "id": "mcrafter*" },
  { "id": "*Giggle" }
]
EOL

# Create mute.json
cat > mute.json <<EOL
[
    {},
    {
        "id": "SAYGEX",
        "reason": "swap the s and the g gay sex"
    },
    {
        "id": "caseoh*",
        "reason": "pussy"
    },
    {
        "id": "nigger*",
        "reason": "racist"
    }
]
EOL

# Create bot.js
cat > bot.js <<'EOL'
const mineflayer = require('mineflayer');
const fs = require('fs');
const minimatch = require('minimatch');
const path = require('path');
const express = require('express');
const bodyParser = require('body-parser');

// Files
const FILTER_FILE = path.join(__dirname, 'filter.json');
const MUTE_FILE = path.join(__dirname, 'mute.json');

let filter = [];
let mute = [];

// Load JSON
function loadFilter() {
  if (fs.existsSync(FILTER_FILE)) {
    filter = JSON.parse(fs.readFileSync(FILTER_FILE, 'utf8'));
  } else {
    filter = [];
    fs.writeFileSync(FILTER_FILE, JSON.stringify(filter, null, 2));
  }
}

function loadMute() {
  if (fs.existsSync(MUTE_FILE)) {
    mute = JSON.parse(fs.readFileSync(MUTE_FILE, 'utf8'));
  } else {
    mute = [];
    fs.writeFileSync(MUTE_FILE, JSON.stringify(mute, null, 2));
  }
}

function saveMute() {
  fs.writeFileSync(MUTE_FILE, JSON.stringify(mute, null, 2));
}

// Initial load
loadFilter();
loadMute();

// Create bot
const bot = mineflayer.createBot({
  host: '168.100.225.224',
  port: 25565,
  username: 'EBot'
});

// Command registry
const commands = {};
function registerCommand(name, callback, description) {
  commands[name.toLowerCase()] = { callback, description };
}

// --- Helper functions ---
function isMuted(username) {
  const now = Date.now();
  return mute.some(entry => entry.id && minimatch(username, entry.id) && entry.expires > now);
}

function sendCustomChat(username, message) {
  if (!filter.some(f => minimatch(username, f.id))) return;
  const formatted = `[${username}] [ChipmunkMod] › ${message}`;
  bot.chat(formatted);
}

// --- Commands ---
registerCommand('fillcore', () => {
  bot.chat('/fill -2160 0 -176 -2145 0 -161 minecraft:repeating_command_block{CustomName:{translate:block.minecraft.heavy_core,color:red}} replace');
}, "Fill core area");

registerCommand('ping', () => {
  bot.chat('/ping');
}, "Run /ping command");

registerCommand('mute', (username, message) => {
  const args = message.split(' ');
  if (args.length < 3) {
    bot.chat('Usage: !mute <username/pattern> <duration> (e.g., 3d, 5h, 0y)');
    return;
  }

  const target = args[1];
  const durationArg = args[2].toLowerCase();

  if (durationArg === '0y') return; // immediate expiry

  const number = parseInt(durationArg.slice(0, -1));
  const unit = durationArg.slice(-1);

  if (isNaN(number) || !['d','h'].includes(unit)) {
    bot.chat('Invalid duration! Use Xd for days or Xh for hours.');
    return;
  }

  let expires = Date.now();
  if (unit === 'd') expires += number*24*60*60*1000;
  if (unit === 'h') expires += number*60*60*1000;

  mute.push({ id: target, expires });
  saveMute();
  bot.chat(`Muted ${target} for ${durationArg}`);
});

registerCommand('unmute', (username, message) => {
  const args = message.split(' ');
  if (args.length < 2) { bot.chat('Usage: !unmute <username/pattern>'); return; }
  const target = args[1];
  mute = mute.filter(entry => !minimatch(entry.id, target));
  saveMute();
  bot.chat(`Unmuted entries matching ${target}`);
});

// --- Cleanup expired mutes ---
function cleanExpiredMutes() {
  const now = Date.now();
  const before = mute.length;
  mute = mute.filter(entry => !entry.id || entry.expires > now);
  if (mute.length < before) saveMute();
}
setInterval(cleanExpiredMutes, 5*60*1000);

// --- Chat listener ---
bot.on('chat', (username, message) => {
  if (username === bot.username) return;
  if (isMuted(username)) return;

  if (message.startsWith('!')) {
    const cmdName = message.slice(1).split(' ')[0].toLowerCase();
    if (commands[cmdName]) commands[cmdName].callback(username, message);
  } else {
    sendCustomChat(username, message);
  }
});

// --- Web UI ---
const app = express();
app.use(bodyParser.json());
const PORT = 3000;

app.get('/', (req,res) => {
  res.send(`
  <html>
    <head><title>EBot Mutes</title></head>
    <body>
      <h1>Mute Management</h1>
      <ul id="mutes"></ul>
      <script>
        async function loadMutes() {
          const res = await fetch('/mutes');
          const data = await res.json();
          const list = document.getElementById('mutes');
          list.innerHTML = '';
          data.forEach(m => {
            const li = document.createElement('li');
            li.textContent = (m.id||'') + ' - ' + (m.reason||'No reason');
            list.appendChild(li);
          });
        }
        loadMutes();
      </script>
    </body>
  </html>`);
});

app.get('/mutes', (req,res) => res.json(mute));

app.post('/mutes', (req,res) => {
  const { id, reason, duration } = req.body;
  if (!id || !duration) return res.status(400).json({ error: 'Missing id or duration' });

  let expires = Date.now();
  const num = parseInt(duration.slice(0,-1));
  const unit = duration.slice(-1);
  if (unit==='d') expires += num*24*60*60*1000;
  if (unit==='h') expires += num*60*60*1000;

  mute.push({ id, reason, expires });
  saveMute();
  res.json({ success:true });
});

app.delete('/mutes/:id', (req,res) => {
  const target = req.params.id;
  mute = mute.filter(entry => entry.id !== target);
  saveMute();
  res.json({ success:true });
});

app.listen(PORT,()=>console.log(`Web UI running at http://localhost:${PORT}`));

bot.on('spawn', ()=>console.log(`EBot spawned as ${bot.username}`));
EOL

echo "Setup complete. Run 'npm start' to launch the bot."

