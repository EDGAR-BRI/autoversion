#!/usr/bin/env bash
set -e

# ==============================================================================
# AutoVersion Setup Script
# Configura versionamiento automático por Conventional Commits en cualquier
# proyecto Node.js / JavaScript / TypeScript.
# ==============================================================================

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}${BOLD}🚀 [AutoVersion] Configurando auto-versionamiento en el proyecto actual...${NC}\n"

AUTO_YES=false
for arg in "$@"; do
  case "$arg" in
    -y|--yes)
      AUTO_YES=true
      ;;
  esac
done

# 1. Verificar Node.js
if ! command -v node >/dev/null 2>&1; then
  echo -e "${RED}❌ Error: Node.js no está instalado o no se encuentra en el PATH.${NC}"
  exit 1
fi

# 2. Verificar o inicializar Git
if [ ! -d ".git" ]; then
  echo -e "${YELLOW}⚠️  No se detectó repositorio Git en este directorio.${NC}"
  if [ "$AUTO_YES" = true ] || [ ! -t 0 ]; then
    response="S"
  else
    read -r -p "   ¿Deseas inicializarlo ahora con 'git init'? [S/n] " response
    response=${response:-S}
  fi
  if [[ "$response" =~ ^[sSyY]$ ]]; then
    git init
    echo -e "${GREEN}✓ Repositorio Git inicializado.${NC}"
  else
    echo -e "${RED}❌ Se requiere un repositorio Git para instalar los hooks.${NC}"
    exit 1
  fi
fi

# 3. Verificar o inicializar package.json
if [ ! -f "package.json" ]; then
  echo -e "${YELLOW}⚠️  No se encontró package.json.${NC}"
  if [ "$AUTO_YES" = true ] || [ ! -t 0 ]; then
    response="S"
  else
    read -r -p "   ¿Deseas crearlo con 'npm init -y'? [S/n] " response
    response=${response:-S}
  fi
  if [[ "$response" =~ ^[sSyY]$ ]]; then
    npm init -y >/dev/null
    echo -e "${GREEN}✓ package.json creado.${NC}"
  else
    echo -e "${RED}❌ Se requiere package.json para gestionar la versión.${NC}"
    exit 1
  fi
fi

# 4. Crear carpeta scripts/ si no existe
mkdir -p scripts

# 5. Generar scripts/setup-git-hooks.mjs (compatible con ESM y CommonJS)
cat << 'EOF' > scripts/setup-git-hooks.mjs
import fs from 'node:fs';
import path from 'node:path';

const hookPath = path.resolve('.git/hooks/pre-commit');
const scriptContent = `#!/usr/bin/env bash

# Auto-versionador basado en Conventional Commits
if [ -f "scripts/auto-version-hook.mjs" ]; then
  exec node scripts/auto-version-hook.mjs
elif [ -f "scripts/auto-version-hook.js" ]; then
  exec node scripts/auto-version-hook.js
fi
`;

try {
  const hooksDir = path.resolve('.git/hooks');
  if (fs.existsSync(hooksDir)) {
    fs.writeFileSync(hookPath, scriptContent, { mode: 0o755 });
    console.log('✓ [AutoVersion] Hook pre-commit instalado en .git/hooks/pre-commit');
  }
} catch (e) {
  // Ignorar en entornos de despliegue donde no exista .git
}
EOF

# 6. Generar scripts/auto-version-hook.mjs (Multiplataforma Linux / macOS / Windows)
cat << 'EOF' > scripts/auto-version-hook.mjs
import fs from 'node:fs';
import path from 'node:path';
import { execSync } from 'node:child_process';

const PKG_PATH = path.resolve('package.json');

/**
 * Inspecciona el proceso ancestro de git commit
 * Compatible con Linux (/proc y ps), macOS (ps) y Windows (powershell)
 */
function findGitCommitCmdline() {
  // 1. Linux /proc (rápido y nativo en entornos Linux / WSL)
  try {
    let curr = process.ppid;
    while (curr && curr > 1) {
      if (fs.existsSync(`/proc/${curr}/cmdline`)) {
        const rawCmd = fs.readFileSync(`/proc/${curr}/cmdline`, 'utf8');
        if (rawCmd) {
          const cmdline = rawCmd.split('\0').filter(Boolean);
          const isGit = cmdline.some(arg => arg === 'git' || arg.endsWith('/git') || arg.endsWith('git.exe'));
          const isCommit = cmdline.includes('commit');
          if (isGit && isCommit) {
            return cmdline;
          }
        }
        const stat = fs.readFileSync(`/proc/${curr}/stat`, 'utf8').split(' ');
        curr = parseInt(stat[3], 10);
      } else {
        break;
      }
    }
  } catch {}

  // 2. macOS / BSD / POSIX fallback usando ps
  try {
    let curr = process.ppid;
    for (let i = 0; i < 6 && curr > 1; i++) {
      const out = execSync(`ps -p ${curr} -o ppid=,command=`, { encoding: 'utf8' }).trim();
      if (!out) break;
      const parts = out.split(/\s+/);
      const parentPid = parseInt(parts[0], 10);
      const cmdStr = out.slice(parts[0].length).trim();
      if (/\bgit(\.exe)?\b.*commit/.test(cmdStr)) {
        return cmdStr.match(/(?:[^\s"']+|"[^"]*"|'[^']*')+/g) || cmdStr.split(' ');
      }
      curr = parentPid;
    }
  } catch {}

  // 3. Windows nativo (PowerShell)
  if (process.platform === 'win32') {
    try {
      const cmd = execSync(`powershell -NoProfile -Command "(Get-CimInstance Win32_Process -Filter \\"ProcessId = ${process.ppid}\\").CommandLine"`, { encoding: 'utf8' });
      if (cmd && /\bgit(\.exe)?\b.*commit/.test(cmd)) {
        return cmd.match(/(?:[^\s"']+|"[^"]*"|'[^']*')+/g) || cmd.split(' ');
      }
    } catch {}
  }

  return null;
}

/**
 * Extrae el mensaje de commit desde los argumentos de git
 */
function extractCommitMessage(cmdline) {
  if (!cmdline || !Array.isArray(cmdline)) return '';
  const clean = str => (str ? str.replace(/^["']|["']$/g, '').trim() : '');

  // 1. Flags -m o --message
  for (let i = 0; i < cmdline.length; i++) {
    const arg = cmdline[i];
    if (arg === '-m' || arg === '--message') {
      if (cmdline[i + 1]) return clean(cmdline[i + 1]);
    } else if (arg.startsWith('--message=')) {
      return clean(arg.slice('--message='.length));
    } else if (arg.startsWith('-m=')) {
      return clean(arg.slice(3));
    }
  }

  // 2. Flags -F o --file
  for (let i = 0; i < cmdline.length; i++) {
    const arg = cmdline[i];
    if (arg === '-F' || arg === '--file') {
      const filePath = clean(cmdline[i + 1]);
      if (filePath && fs.existsSync(filePath)) {
        return fs.readFileSync(filePath, 'utf8').trim();
      }
    } else if (arg.startsWith('--file=') || arg.startsWith('-F=')) {
      const filePath = clean(arg.split('=')[1]);
      if (filePath && fs.existsSync(filePath)) {
        return fs.readFileSync(filePath, 'utf8').trim();
      }
    }
  }

  return '';
}

function main() {
  try {
    if (!fs.existsSync(PKG_PATH)) return;

    // Si la versión ya fue modificada manualmente en el staging actual, no duplicar el incremento
    try {
      const stagedDiff = execSync('git diff --cached package.json', { encoding: 'utf8' });
      if (stagedDiff.includes('"version":')) {
        return;
      }
    } catch {
      // Ignorar si git diff falla
    }

    const cmdline = findGitCommitCmdline();
    let msg = extractCommitMessage(cmdline);

    msg = msg.trim();
    if (!msg) return;

    // Omitir commits automáticos de merge o revert
    if (msg.startsWith('Merge ') || msg.startsWith('Revert ')) {
      return;
    }

    // Mapeo de Conventional Commits a SemVer
    let bumpType = null;
    if (/^[a-z]+(\([^\)]+\))?!:/.test(msg) || /BREAKING CHANGE/i.test(msg)) {
      bumpType = 'major';
    } else if (/^feat(\([^\)]+\))?:/i.test(msg)) {
      bumpType = 'minor';
    } else if (/^(fix|style|perf|refactor)(\([^\)]+\))?:/i.test(msg)) {
      bumpType = 'patch';
    }

    if (!bumpType) {
      // chore, docs, test, build, ci, etc. no incrementan versión
      return;
    }

    const pkg = JSON.parse(fs.readFileSync(PKG_PATH, 'utf8'));
    if (!pkg.version) {
      pkg.version = '0.1.0';
    }

    const versionParts = pkg.version.split('-')[0].split('.').map(n => parseInt(n, 10) || 0);
    while (versionParts.length < 3) versionParts.push(0);
    const [maj, min, pat] = versionParts;

    let newVersion = pkg.version;
    if (bumpType === 'major') newVersion = `${maj + 1}.0.0`;
    else if (bumpType === 'minor') newVersion = `${maj}.${min + 1}.0`;
    else if (bumpType === 'patch') newVersion = `${maj}.${min}.${pat + 1}`;

    pkg.version = newVersion;
    fs.writeFileSync(PKG_PATH, JSON.stringify(pkg, null, 2) + '\n');
    execSync('git add package.json');

    console.log(`\n🚀 [AutoVersion] Mensaje detectado: "${msg.split('\n')[0]}"`);
    console.log(`📦 [AutoVersion] Versión actualizada a ${newVersion} (${bumpType.toUpperCase()}) en package.json.\n`);
  } catch (err) {
    // No interrumpir el flujo si ocurre algún error imprevisto
  }
}

main();
EOF

# 7. Actualizar package.json con el script prepare
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

# 8. Ejecutar configuración inicial del hook
node scripts/setup-git-hooks.mjs

echo -e "\n${GREEN}${BOLD}🎉 ¡Auto-versionamiento configurado con éxito!${NC}"
echo -e "${CYAN}A partir de ahora, cada commit actualizará package.json según el prefijo:${NC}"
echo -e "  • ${BOLD}feat:...${NC}        → Minor (+0.1.0) ej. nueva funcionalidad"
echo -e "  • ${BOLD}fix:...${NC}         → Patch (+0.0.1) ej. refactor, perf, style, fix"
echo -e "  • ${BOLD}feat!:...${NC}       → Major (+1.0.0) o cualquier BREAKING CHANGE"
echo -e "  • ${BOLD}chore:...${NC}       → Sin incremento (docs, test, chore, build)\n"
