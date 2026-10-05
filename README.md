# 🚀 AutoVersion

> Auto-versionamiento semántico automático para cualquier proyecto Node.js / JavaScript / TypeScript basado en **Conventional Commits**.  
> Cero dependencias externas pesadas, sin necesidad de CI y 100% compatible con Linux, macOS y Windows.

---

## ⚡ Instalación en 1 Comando (Sin Clonar)

Ejecuta cualquiera de estos comandos en la **raíz de cualquier proyecto**:

### Opción 1: curl (Instantáneo, recomendada)
```bash
curl -fsSL https://raw.githubusercontent.com/EDGAR-BRI/autoversion/main/install.sh | bash
```

### Opción 2: npx (Ecosistema Node.js)
```bash
npx github:EDGAR-BRI/autoversion
```

*(Puedes añadir el flag `-y` si deseas ejecutarlo de forma 100% desatendida en scripts).*

---

## 🎯 ¿Qué hace?

Al ejecutarse en tu proyecto:
1. Verifica o inicializa el repositorio Git y `package.json`.
2. Genera los scripts autónomos en `scripts/auto-version-hook.mjs` y `scripts/setup-git-hooks.mjs`.
3. Registra el hook `"prepare": "node scripts/setup-git-hooks.mjs"` en tu `package.json` (respetando los scripts que ya tengas).
4. Configura el hook ejecutable `.git/hooks/pre-commit`.
5. A partir de ese momento, cada `git commit` inspecciona tu mensaje y actualiza la versión de `package.json` **en el mismo commit de forma atómica**.

---

## 📋 Mapeo de Conventional Commits a SemVer

| Prefijo del Commit | Tipo de Incremento | Ejemplo de Cambio | Descripción |
| :--- | :--- | :--- | :--- |
| `feat:` | **MINOR** | `1.0.0` ➔ `1.1.0` | Nuevas funcionalidades, páginas o características |
| `fix:`, `refactor:`, `perf:`, `style:` | **PATCH** | `1.1.0` ➔ `1.1.1` | Corrección de errores, optimizaciones o refactorizaciones |
| `feat!:`, `fix!:`, `BREAKING CHANGE:` | **MAJOR** | `1.1.1` ➔ `2.0.0` | Cambios que rompen compatibilidad hacia atrás |
| `chore:`, `docs:`, `test:`, `ci:`, `build:` | *Ninguno* | `1.0.0` ➔ `1.0.0` | Tareas de mantenimiento, documentación o pruebas |

---

## 🛠️ Características Principales

- **Cero dependencias npm**: No requiere instalar Husky, Commitlint ni Semantic-Release. Usa únicamente módulos estándar de Node.js (`fs`, `child_process`, `path`).
- **Agnóstico al formato de módulos**: Funciona tanto en proyectos con `"type": "module"` (ESM) como `"type": "commonjs"`.
- **Multiplataforma**: Compatible con Linux (`/proc` y `ps`), macOS (`ps`) y Windows (PowerShell / Git Bash).
- **Auto-instalable en equipos**: Al clonar tu proyecto en otra máquina, `npm install` o `pnpm install` activará el hook automáticamente gracias al ciclo de vida `prepare`.

---

## 📄 Licencia

MIT © [EDGAR-BRI](https://github.com/EDGAR-BRI)
