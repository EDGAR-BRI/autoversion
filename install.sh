#!/usr/bin/env bash
set -e

# ==============================================================================
# AutoVersion Setup Script v1.3.0
# Soporte para Node.js (package.json) y Flutter / Dart (pubspec.yaml)
# Configuración jerárquica (.autoversion.json global y local)
# Generación atómica de CHANGELOG.md
# Compatible con Terminal CLI y GUIs (VS Code, Cursor, GitKraken, etc.)
# https://github.com/EDGAR-BRI/autoversion
# ==============================================================================

BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
RED="\033[0;31m"
NC="\033[0m"

echo -e "${BLUE}${BOLD}🚀 [AutoVersion] Configurando auto-versionamiento en el proyecto actual...${NC}\n"

AUTO_YES=false
for arg in "$@"; do
  case "$arg" in
    -y|--yes)
      AUTO_YES=true
      ;;
  esac
done

prompt_user() {
  local prompt_text="$1"
  local default_val="${2:-S}"
  local response=""

  if [ "$AUTO_YES" = true ]; then
    echo "$default_val"
    return 0
  fi

  if [ -c /dev/tty ]; then
    read -r -p "$prompt_text" response < /dev/tty
  elif [ -t 0 ]; then
    read -r -p "$prompt_text" response
  else
    response="$default_val"
  fi

  response="${response:-$default_val}"
  echo "$response"
}

# 1. Verificar Node.js
if ! command -v node >/dev/null 2>&1; then
  echo -e "${RED}❌ Error: Node.js no está instalado o no se encuentra en el PATH.${NC}"
  echo -e "   Node.js es requerido para ejecutar el script de análisis de commits."
  exit 1
fi

# 2. Verificar o inicializar Git
if [ ! -d ".git" ]; then
  echo -e "${YELLOW}⚠️  No se detectó repositorio Git en este directorio.${NC}"
  res=$(prompt_user "   ¿Deseas inicializarlo ahora con 'git init'? [S/n] " "S")
  if [[ "$res" =~ ^[sSyY]$ ]]; then
    git init
    echo -e "${GREEN}✓ Repositorio Git inicializado.${NC}"
  else
    echo -e "${RED}❌ Se requiere un repositorio Git para instalar los hooks.${NC}"
    exit 1
  fi
fi

# 3. Detectar tipo de proyecto (Node.js y/o Flutter)
HAS_PKG=false
HAS_PUBSPEC=false

if [ -f "package.json" ]; then
  HAS_PKG=true
fi

if [ -f "pubspec.yaml" ]; then
  HAS_PUBSPEC=true
fi

if [ "$HAS_PKG" = false ] && [ "$HAS_PUBSPEC" = false ]; then
  echo -e "${YELLOW}⚠️  No se detectó 'package.json' (Node) ni 'pubspec.yaml' (Flutter).\${NC}"
  res=$(prompt_user "   ¿Deseas crear un 'package.json' básico con npm init? [S/n] " "S")
  if [[ "$res" =~ ^[sSyY]$ ]]; then
    npm init -y >/dev/null
    HAS_PKG=true
    echo -e "${GREEN}✓ package.json creado.${NC}"
  else
    echo -e "${RED}❌ Se requiere package.json o pubspec.yaml para gestionar la versión.${NC}"
    exit 1
  fi
fi

# 4. Crear carpeta scripts/ si no existe
mkdir -p scripts

# 5. Generar .autoversion.json por defecto si no existe en el proyecto
if [ ! -f ".autoversion.json" ]; then
  cat << 'CONFIG_EOF' > .autoversion.json
{
  "changelog": true,
  "rules": {
    "major": ["breaking"],
    "minor": ["feat", "ui"],
    "patch": ["fix", "style", "perf", "refactor", "chore", "hotfix"]
  }
}
CONFIG_EOF
  echo -e "${GREEN}✓ Archivo de configuración local .autoversion.json creado.${NC}"
fi

# 6. Generar scripts/setup-git-hooks.mjs
cat << 'SETUP_HOOK_EOF' > scripts/setup-git-hooks.mjs
import fs from "node:fs";
import path from "node:path";

const hooksDir = path.resolve(".git/hooks");

const nodeEnvLoader = `# Cargar PATH común de Node (nvm, fnm, brew, volta, asdf) por si el entorno GUI no lo tiene
if ! command -v node >/dev/null 2>&1; then
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

if ! command -v node >/dev/null 2>&1; then
  for p in "$HOME/.nvm/versions/node"/*/"bin" "$HOME/.fnm/current/bin" "$HOME/.asdf/shims" "$HOME/.volta/bin" /usr/local/bin /usr/bin; do
    if [ -x "$p/node" ]; then
      export PATH="$p:$PATH"
      break
    fi
  done
fi
`;

const preCommitContent = `#!/usr/bin/env bash
${nodeEnvLoader}
if [ -f "scripts/auto-version-hook.mjs" ]; then
  exec node scripts/auto-version-hook.mjs --pre-commit
elif [ -f "scripts/auto-version-hook.js" ]; then
  exec node scripts/auto-version-hook.js --pre-commit
fi
`;

const postCommitContent = `#!/usr/bin/env bash
${nodeEnvLoader}
if [ -f "scripts/auto-version-hook.mjs" ]; then
  exec node scripts/auto-version-hook.mjs --post-commit
elif [ -f "scripts/auto-version-hook.js" ]; then
  exec node scripts/auto-version-hook.js --post-commit
fi
`;

try {
  if (fs.existsSync(hooksDir)) {
    fs.writeFileSync(path.resolve(hooksDir, "pre-commit"), preCommitContent, { mode: 0o755 });
    fs.writeFileSync(path.resolve(hooksDir, "post-commit"), postCommitContent, { mode: 0o755 });
    console.log("✓ [AutoVersion] Hooks pre-commit y post-commit instalados en .git/hooks/");
  }
} catch (e) {}
SETUP_HOOK_EOF

# 7. Generar scripts/auto-version-hook.mjs
cat << 'AUTO_VERSION_EOF' > scripts/auto-version-hook.mjs
import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";

const PKG_PATH = path.resolve("package.json");
const PUBSPEC_PATH = path.resolve("pubspec.yaml");

const DEFAULT_CONFIG = {
  changelog: true,
  changelogFile: "CHANGELOG.md",
  rules: {
    major: ["breaking"],
    minor: ["feat", "ui"],
    patch: ["fix", "style", "perf", "refactor", "chore", "hotfix"]
  }
};

/**
 * Carga jerarquía de configuración:
 * 1. Defaults de la herramienta
 * 2. Sobrescrito por ~/.autoversion.json (global) si existe
 * 3. Sobrescrito por ./.autoversion.json (local del proyecto) si existe
 */
function loadConfig() {
  const homeDir = process.env.HOME || process.env.USERPROFILE || "";
  const globalPath = path.resolve(homeDir, ".autoversion.json");
  const localPath = path.resolve(".autoversion.json");

  let config = JSON.parse(JSON.stringify(DEFAULT_CONFIG));

  if (homeDir && fs.existsSync(globalPath)) {
    try {
      const g = JSON.parse(fs.readFileSync(globalPath, "utf8"));
      if (g.changelog !== undefined) config.changelog = g.changelog;
      if (g.changelogFile) config.changelogFile = g.changelogFile;
      if (g.rules) {
        if (g.rules.major) config.rules.major = g.rules.major;
        if (g.rules.minor) config.rules.minor = g.rules.minor;
        if (g.rules.patch) config.rules.patch = g.rules.patch;
      }
    } catch {}
  }

  if (fs.existsSync(localPath)) {
    try {
      const l = JSON.parse(fs.readFileSync(localPath, "utf8"));
      if (l.changelog !== undefined) config.changelog = l.changelog;
      if (l.changelogFile) config.changelogFile = l.changelogFile;
      if (l.rules) {
        if (l.rules.major) config.rules.major = l.rules.major;
        if (l.rules.minor) config.rules.minor = l.rules.minor;
        if (l.rules.patch) config.rules.patch = l.rules.patch;
      }
    } catch {}
  }

  return config;
}

function findGitCommitCmdline() {
  try {
    let curr = process.ppid;
    while (curr && curr > 1) {
      if (fs.existsSync(`/proc/${curr}/cmdline`)) {
        const rawCmd = fs.readFileSync(`/proc/${curr}/cmdline`, "utf8");
        if (rawCmd) {
          const cmdline = rawCmd.split("\0").filter(Boolean);
          const isGit = cmdline.some(arg => arg === "git" || arg.endsWith("/git") || arg.endsWith("git.exe"));
          const isCommit = cmdline.includes("commit");
          if (isGit && isCommit) return cmdline;
        }
        const stat = fs.readFileSync(`/proc/${curr}/stat`, "utf8").split(" ");
        curr = parseInt(stat[3], 10);
      } else {
        break;
      }
    }
  } catch {}

  try {
    let curr = process.ppid;
    for (let i = 0; i < 6 && curr > 1; i++) {
      const out = execSync(`ps -p ${curr} -o ppid=,command=`, { encoding: "utf8" }).trim();
      if (!out) break;
      const parts = out.split(/\s+/);
      const parentPid = parseInt(parts[0], 10);
      const cmdStr = out.slice(parts[0].length).trim();
      if (/\bgit(\.exe)?\b.*commit/.test(cmdStr)) {
        return cmdStr.match(/(?:[^\s"'"]+|"[^"]*"|'[^']*')+/g) || cmdStr.split(" ");
      }
      curr = parentPid;
    }
  } catch {}

  if (process.platform === "win32") {
    try {
      const cmd = execSync(`powershell -NoProfile -Command "(Get-CimInstance Win32_Process -Filter \"ProcessId = ${process.ppid}\").CommandLine"`, { encoding: "utf8" });
      if (cmd && /\bgit(\.exe)?\b.*commit/.test(cmd)) {
        return cmd.match(/(?:[^\s"'"]+|"[^"]*"|'[^']*')+/g) || cmd.split(" ");
      }
    } catch {}
  }

  return null;
}

function extractCommitMessage(cmdline) {
  if (!cmdline || !Array.isArray(cmdline)) return "";
  const clean = str => (str ? str.replace(/^["'"]|["'"]$/g, "").trim() : "");

  for (let i = 0; i < cmdline.length; i++) {
    const arg = cmdline[i];
    if (arg === "-m" || arg === "--message") {
      if (cmdline[i + 1]) return clean(cmdline[i + 1]);
    } else if (arg.startsWith("--message=")) {
      return clean(arg.slice("--message=".length));
    } else if (arg.startsWith("-m=")) {
      return clean(arg.slice(3));
    } else if (arg === "-F" || arg === "--file") {
      const filePath = clean(cmdline[i + 1]);
      if (filePath && filePath !== "-" && fs.existsSync(filePath)) {
        return fs.readFileSync(filePath, "utf8").trim();
      }
    } else if (arg.startsWith("--file=") || arg.startsWith("-F=")) {
      const filePath = clean(arg.split("=")[1]);
      if (filePath && filePath !== "-" && fs.existsSync(filePath)) {
        return fs.readFileSync(filePath, "utf8").trim();
      }
    }
  }
  return "";
}

function calculateNextSemVer(currentVersion, bumpType) {
  const versionParts = currentVersion.split("-")[0].split(".").map(n => parseInt(n, 10) || 0);
  while (versionParts.length < 3) versionParts.push(0);
  let [maj, min, pat] = versionParts;

  if (bumpType === "major") return `${maj + 1}.0.0`;
  if (bumpType === "minor") return `${maj}.${min + 1}.0`;
  if (bumpType === "patch") return `${maj}.${min}.${pat + 1}`;
  return currentVersion;
}

function bumpFlutterPubspec(bumpType) {
  if (!fs.existsSync(PUBSPEC_PATH)) return null;
  const content = fs.readFileSync(PUBSPEC_PATH, "utf8");
  const match = content.match(/^[ \t]*version:[ \t]*([0-9]+)\.([0-9]+)\.([0-9]+)(?:\+([0-9]+))?/m);
  if (!match) return null;

  let [_, maj, min, pat, build] = match.map(n => (n !== undefined ? parseInt(n, 10) : 0));
  const nextBuild = (build || 0) + 1;

  if (bumpType === "major") { maj += 1; min = 0; pat = 0; }
  else if (bumpType === "minor") { min += 1; pat = 0; }
  else if (bumpType === "patch") { pat += 1; }

  const newVersion = `${maj}.${min}.${pat}+${nextBuild}`;
  const updated = content.replace(/^[ \t]*version:[ \t]*.*$/m, `version: ${newVersion}`);

  fs.writeFileSync(PUBSPEC_PATH, updated);
  execSync("git add pubspec.yaml");
  console.log(`📱 [AutoVersion] Flutter: versión actualizada a ${newVersion} (${bumpType.toUpperCase()}) en pubspec.yaml.`);
  return newVersion;
}

function bumpNodePackage(bumpType) {
  if (!fs.existsSync(PKG_PATH)) return null;
  const pkg = JSON.parse(fs.readFileSync(PKG_PATH, "utf8"));
  const current = pkg.version || "0.1.0";
  const newVersion = calculateNextSemVer(current, bumpType);

  pkg.version = newVersion;
  fs.writeFileSync(PKG_PATH, JSON.stringify(pkg, null, 2) + "\n");
  execSync("git add package.json");
  console.log(`📦 [AutoVersion] Node.js: versión actualizada a ${newVersion} (${bumpType.toUpperCase()}) en package.json.`);
  return newVersion;
}

function getBumpType(msg, config) {
  if (!msg) return null;
  msg = msg.trim();
  if (msg.startsWith("Merge ") || msg.startsWith("Revert ")) return null;

  const firstLine = msg.split("\n")[0].trim();

  // 1. Breaking change explícito con "!" antes de ":" o "BREAKING CHANGE"
  if (/^[a-z]+(\([^\)]+\))?!:/.test(firstLine) || /BREAKING CHANGE/i.test(msg)) {
    return "major";
  }

  // 2. Reglas MAJOR
  for (const prefix of config.rules.major || []) {
    const rx = new RegExp("^" + prefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "(\\([^\\)]+\\))?:", "i");
    if (rx.test(firstLine)) return "major";
  }

  // 3. Reglas MINOR
  for (const prefix of config.rules.minor || []) {
    const rx = new RegExp("^" + prefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "(\\([^\\)]+\\))?:", "i");
    if (rx.test(firstLine)) return "minor";
  }

  // 4. Reglas PATCH
  for (const prefix of config.rules.patch || []) {
    const rx = new RegExp("^" + prefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "(\\([^\\)]+\\))?:", "i");
    if (rx.test(firstLine)) return "patch";
  }

  return null;
}

function updateChangelog(newVersion, msg, bumpType, config) {
  if (!config.changelog || !newVersion) return false;
  const changelogPath = path.resolve(config.changelogFile || "CHANGELOG.md");
  const now = new Date();
  const dateStr = now.toISOString().split("T")[0];
  const firstLine = msg.split("\n")[0].trim();

  let icon = "•";
  if (bumpType === "major") icon = "💥";
  else if (firstLine.startsWith("feat")) icon = "🚀";
  else if (firstLine.startsWith("fix")) icon = "🐛";
  else if (firstLine.startsWith("perf")) icon = "⚡";
  else if (firstLine.startsWith("refactor")) icon = "🛠️";
  else if (firstLine.startsWith("chore")) icon = "🧹";
  else if (firstLine.startsWith("hotfix")) icon = "🔥";
  else if (firstLine.startsWith("ui")) icon = "🎨";

  const entry = `- ${icon} ${firstLine}`;
  const versionHeader = `## [${newVersion}] - ${dateStr}`;

  let content = "";
  if (fs.existsSync(changelogPath)) {
    content = fs.readFileSync(changelogPath, "utf8");
  } else {
    content = "# 📋 Historial de Cambios (Changelog)\n\nTodos los cambios notables de este proyecto serán documentados en este archivo.\n\n";
  }

  if (content.includes(`## [${newVersion}]`)) {
    if (!content.includes(firstLine)) {
      content = content.replace(`## [${newVersion}]`, `${versionHeader}\n${entry}`);
    }
  } else {
    const titleMatch = content.match(/^# [^\n]+\n+/);
    if (titleMatch) {
      const title = titleMatch[0];
      const rest = content.slice(title.length);
      content = `${title}${versionHeader}\n${entry}\n\n${rest.trimStart()}`;
    } else {
      content = `# 📋 Historial de Cambios (Changelog)\n\n${versionHeader}\n${entry}\n\n${content}`;
    }
  }

  fs.writeFileSync(changelogPath, content.trim() + "\n");
  try {
    execSync(`git add "${path.basename(changelogPath)}"`);
    console.log(`📝 [AutoVersion] Changelog actualizado en ${path.basename(changelogPath)}.`);
    return true;
  } catch {
    return false;
  }
}

function handlePreCommit() {
  const config = loadConfig();
  const cmdline = findGitCommitCmdline();
  const msg = extractCommitMessage(cmdline);
  const bumpType = getBumpType(msg, config);

  if (!bumpType) {
    if (msg) {
      const firstLine = msg.split("\n")[0].trim();
      const ignored = firstLine.match(/^([a-z]+)(\([^\)]+\))?:/i);
      if (ignored) {
        console.log(`\nℹ️ [AutoVersion] Mensaje detectado: "${firstLine}"`);
        console.log(`ℹ️ [AutoVersion] El tipo "${ignored[1]}" no incrementa versión según las reglas activas.`);
        console.log(`ℹ️ [AutoVersion] Puedes añadirlo en .autoversion.json o usar "fix:" / "feat:".\n`);
      }
    }
    return;
  }

  const hasNode = fs.existsSync(PKG_PATH);
  const hasFlutter = fs.existsSync(PUBSPEC_PATH);

  if (hasFlutter) {
    try {
      const diff = execSync("git diff --cached pubspec.yaml", { encoding: "utf8" });
      if (/^\+[ \t]*version:/m.test(diff)) return;
    } catch {}
  }
  if (hasNode) {
    try {
      const diff = execSync("git diff --cached package.json", { encoding: "utf8" });
      if (diff.includes('"version":')) return;
    } catch {}
  }

  console.log(`\n🚀 [AutoVersion] Mensaje detectado (CLI): "${msg.split("\n")[0]}"`);
  let newV = null;
  if (hasFlutter) newV = bumpFlutterPubspec(bumpType) || newV;
  if (hasNode) newV = bumpNodePackage(bumpType) || newV;

  if (newV) {
    updateChangelog(newV, msg, bumpType, config);
  }
  console.log("");
}

function handlePostCommit() {
  if (process.env.AUTOVERSION_AMENDING === "1") return;

  const config = loadConfig();
  const hasNode = fs.existsSync(PKG_PATH);
  const hasFlutter = fs.existsSync(PUBSPEC_PATH);
  if (!hasNode && !hasFlutter) return;

  let committedFiles = "";
  try {
    committedFiles = execSync("git diff-tree --no-commit-id --name-only -r --root HEAD", { encoding: "utf8" });
  } catch {
    return;
  }

  const alreadyBumped = (hasFlutter && committedFiles.includes("pubspec.yaml")) ||
                        (hasNode && committedFiles.includes("package.json"));
  if (alreadyBumped) return;

  let lastMsg = "";
  try {
    lastMsg = execSync("git log -1 --pretty=%B", { encoding: "utf8" }).trim();
  } catch {
    return;
  }

  const bumpType = getBumpType(lastMsg, config);
  if (!bumpType) {
    const firstLine = lastMsg.split("\n")[0].trim();
    const ignored = firstLine.match(/^([a-z]+)(\([^\)]+\))?:/i);
    if (ignored) {
      console.log(`\nℹ️ [AutoVersion] Mensaje detectado: "${firstLine}"`);
      console.log(`ℹ️ [AutoVersion] El tipo "${ignored[1]}" no incrementa versión según las reglas activas.`);
      console.log(`ℹ️ [AutoVersion] Puedes añadirlo en .autoversion.json o usar "fix:" / "feat:".\n`);
    }
    return;
  }

  console.log(`\n🚀 [AutoVersion] Mensaje detectado (GUI / stdin): "${lastMsg.split("\n")[0]}"`);
  let newV = null;
  if (hasFlutter) newV = bumpFlutterPubspec(bumpType) || newV;
  if (hasNode) newV = bumpNodePackage(bumpType) || newV;

  if (newV) {
    updateChangelog(newV, lastMsg, bumpType, config);
    try {
      execSync("git commit --amend --no-edit", {
        env: { ...process.env, AUTOVERSION_AMENDING: "1" },
        stdio: "pipe"
      });
      console.log("✓ [AutoVersion] Versión y Changelog enmendados exitosamente en el commit.\n");
    } catch (e) {
      console.error("Error en post-commit amend:", e.message);
    }
  }
}

function main() {
  try {
    const isPostCommit = process.argv.includes("--post-commit");
    if (isPostCommit) {
      handlePostCommit();
    } else {
      handlePreCommit();
    }
  } catch (err) {}
}

main();
AUTO_VERSION_EOF

# 8. Si existe package.json, registrar el script prepare
if [ "$HAS_PKG" = true ]; then
  node -e '
  const fs = require("node:fs");
  const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
  pkg.scripts = pkg.scripts || {};
  const prepareCmd = "node scripts/setup-git-hooks.mjs";

  if (!pkg.scripts.prepare) {
    pkg.scripts.prepare = prepareCmd;
  } else if (!pkg.scripts.prepare.includes("setup-git-hooks")) {
    pkg.scripts.prepare = `${pkg.scripts.prepare} && ${prepareCmd}`;
  }

  if (!pkg.version) {
    pkg.version = "1.0.0";
  }

  fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
  console.log("✓ [AutoVersion] Script prepare registrado en package.json");
  '
fi

# 9. Ejecutar configuración inicial de los hooks
node scripts/setup-git-hooks.mjs

echo -e "\n${GREEN}${BOLD}🎉 ¡Auto-versionamiento configurado con éxito!${NC}"
if [ "$HAS_PUBSPEC" = true ]; then
  echo -e "${CYAN}📱 Proyecto Flutter detectado: se actualizará 'pubspec.yaml' (SemVer + BuildNumber).\${NC}"
fi
if [ "$HAS_PKG" = true ]; then
  echo -e "${CYAN}📦 Proyecto Node.js detectado: se actualizará 'package.json'.\${NC}"
fi

echo -e "\n${BOLD}Funcionalidades activadas:${NC}"
echo -e "  • ⚙️  Reglas configurables en .autoversion.json (global en ~/.autoversion.json)"
echo -e "  • 📋 Generación automática y atómica de CHANGELOG.md"
echo -e "  • 🖥️  Compatibilidad total: Terminal CLI y VS Code / GUIs\n"
