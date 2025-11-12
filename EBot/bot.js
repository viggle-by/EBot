const mineflayer = require('mineflayer');
const fs = require('fs');
const path = require('path');

const bot = mineflayer.createBot({
  host: '168.100.225.224',
  port: 25565,
  username: 'EBot'
});

// ----- Load filter.json safely -----
let filter = [];
try {
  const rawFilter = JSON.parse(fs.readFileSync(path.join(__dirname, 'filter.json'), 'utf8'));
  filter = Array.isArray(rawFilter) ? rawFilter.filter(f => f && typeof f.id === 'string') : [];
} catch (e) {
  console.log('No valid filter.json found.');
}

// ----- Load mute.json safely -----
let mutes = [];
try {
  const rawMutes = JSON.parse(fs.readFileSync(path.join(__dirname, 'mute.json'), 'utf8'));
  mutes = Array.isArray(rawMutes) ? rawMutes.filter(m => m && typeof m.id === 'string') : [];
} catch (e) {
  console.log('No valid mute.json found.');
}

// ----- Helpers -----
function matchesFilter(username) {
  if (!username) return false;
  username = username.toLowerCase();
  return filter.some(f => {
    const id = f.id.toLowerCase().replace(/\*/g, '');
    if (f.id.startsWith('*') && f.id.endsWith('*')) return username.includes(id);
    if (f.id.startsWith('*')) return username.endsWith(id);
    if (f.id.endsWith('*')) return username.startsWith(id);
    return username === id;
  });
}

function isMuted(username) {
  if (!username) return false;
  username = username.toLowerCase();
  return mutes.some(m => {
    const id = m.id.toLowerCase().replace(/\*/g, '');
    if (m.id.startsWith('*') && m.id.endsWith('*')) return username.includes(id);
    if (m.id.startsWith('*')) return username.endsWith(id);
    if (m.id.endsWith('*')) return username.startsWith(id);
    return username === id;
  });
}

// ----- Commands registry -----
const commands = {};
function registerCommand(name, fn) { commands[name] = fn; }

// ----- Bot chat handler -----
bot.on('chat', (username, message) => {
  if (username === bot.username) return; // ignore self

  // Muted users
  if (isMuted(username)) {
    bot.chat(`/sudo ${username} c:You Are Silenced for 0y`);
    bot.chat(`/nick ${username} &r`);
    bot.chat(`/sudo ${username} rank &r`);
    return;
  }

  // Handle bot commands
  const parts = message.split(' ');
  const cmd = parts[0].toLowerCase();
  const args = parts.slice(1).join(' ');

  if (commands[cmd]) {
    commands[cmd](username, args);
    return;
  }

  // ----- Override default chat -----
  const tellrawJson = {
    color: "#FF99DD",
    translate: "[%s] %s › %s",
    with: [
      {
        color: "#FFCCEE",
        click_event: { action: "open_url", url: "https://code.chipmunk.land/7cc5c4f330d47060/chipmunkmod" },
        hover_event: { action: "show_text", value: { color: "white", text: "Click here to open the ChipmunkMod source code" } },
        text: "ChipmunkMod"
      },
      { color: "#FFCCEE", text: username },
      { color: "white", text: message }
    ]
  };

  bot.chat(`/minecraft:tellraw @a ${JSON.stringify(tellrawJson)}`);
});

// ----- Bot Commands -----

// HELP
registerCommand('help', (username) => {
  bot.chat(`/tell ${username} Available commands: help, facc <username>, chipmunkmodcustomchat <username>, core, ping, filter`);
});

// PING
registerCommand('ping', () => bot.chat('/ping'));

// CORE
registerCommand('core', (username, message) => {
  bot.chat('/fill -2160 0 -176 -2145 0 -161 minecraft:repeating_command_block{CustomName:{translate:block.minecraft.heavy_core,color:red}} replace');

  const tellrawJson = {
    color: "#FF99DD",
    translate: "[%s] %s › %s",
    with: [
      {
        color: "#FFCCEE",
        click_event: { action: "open_url", url: "https://code.chipmunk.land/7cc5c4f330d47060/chipmunkmod" },
        hover_event: { action: "show_text", value: { color: "white", text: "Click here to open the ChipmunkMod source code" } },
        text: "ChipmunkMod"
      },
      { color: "#FFCCEE", selector: "@s" },
      {
        color: "white",
        click_event: { action: "copy_to_clipboard", value: message || "" },
        hover_event: { action: "show_text", value: { color: "white", text: "Click here to copy the message" } },
        text: message || ""
      }
    ]
  };

  bot.chat(`/minecraft:tellraw @a ${JSON.stringify(tellrawJson)}`);
});

// FACCBOT
registerCommand('facc', (username, newUsername) => {
  if (!newUsername) return;
  mineflayer.createBot({ host: '168.100.225.224', port: 25565, username: newUsername });
  bot.chat(`/tell ${username} Spawned bot ${newUsername}`);
});

// CHIPMUNKMODCUSTOMCHAT
registerCommand('chipmunkmodcustomchat', (username, targetUsername) => {
  if (!targetUsername) return;
  if (matchesFilter(targetUsername)) {
    bot.chat(`/nick ${targetUsername} &d${targetUsername}`);
    bot.chat(`/sudo ${targetUsername} rank &d[ChipmunkMod]`);
  }
});

// FILTER (mute)
registerCommand('filter', (username, targetUsername) => {
  if (!targetUsername) return;
  mutes.push({ id: targetUsername, reason: 'Filtered by command' });
  fs.writeFileSync(path.join(__dirname, 'mute.json'), JSON.stringify(mutes, null, 2));
  bot.chat(`/sudo ${targetUsername} c:You Are Silenced for 0y`);
  bot.chat(`/nick ${targetUsername} &r`);
  bot.chat(`/sudo ${targetUsername} rank &r`);
});

// ----- Events -----
bot.on('login', () => console.log('EBot connected.'));
bot.on('error', (err) => console.log(err));
bot.on('end', () => console.log('Bot disconnected, reconnecting...'));
