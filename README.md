# 🚀 AutoVersion

> Auto-versionamiento semántico automático para proyectos **Node.js** (`package.json`) y **Flutter / Dart** (`pubspec.yaml`) basado en **Conventional Commits**.  
> Cero dependencias externas pesadas, sin necesidad de CI y 100% compatible con Linux, macOS y Windows.

---

## ⚡ Instalación en 1 Comando (Sin Clonar)

Ejecuta cualquiera de estos comandos en la **raíz de tu proyecto** (sea Node.js o Flutter):

### Opción 1: curl (Instantáneo, recomendada para cualquier proyecto)
```bash
curl -fsSL https://raw.githubusercontent.com/EDGAR-BRI/autoversion/main/install.sh | bash
```

### Opción 2: npx (Ecosistema Node.js)
```bash
npx github:EDGAR-BRI/autoversion
```

*(Añade el flag `-y` si deseas ejecutarlo de forma 100% desatendida en scripts).*

---

## 🎯 ¿Qué hace?

El script detecta automáticamente el stack de tu proyecto:
1. **Node.js / JS / TS** (`package.json`): Actualiza el campo `"version"` según SemVer.
2. **Flutter / Dart** (`pubspec.yaml`): Actualiza tanto la versión semántica como el **Build Number** (`X.Y.Z+Build`), obligatorio para publicar en Google Play Store y Apple App Store.
3. Si el proyecto tiene ambos (híbrido), mantiene ambos archivos sincronizados.
4. Configura el hook `.git/hooks/pre-commit` de forma atómica: la nueva versión entra en el mismo commit que tus cambios.

---

## 📋 Mapeo de Conventional Commits a SemVer

| Prefijo del Commit | Tipo | Resultado Node (`package.json`) | Resultado Flutter (`pubspec.yaml`) | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| `feat:` | **MINOR** | `1.0.0` ➔ `1.1.0` | `1.0.0+1` ➔ `1.1.0+2` | Nuevas funcionalidades o pantallas |
| `fix:`, `refactor:`, `perf:`, `style:` | **PATCH** | `1.1.0` ➔ `1.1.1` | `1.1.0+2` ➔ `1.1.1+3` | Corrección de errores u optimizaciones |
| `feat!:`, `fix!:`, `BREAKING CHANGE:` | **MAJOR** | `1.1.1` ➔ `2.0.0` | `1.1.1+3` ➔ `2.0.0+4` | Cambios que rompen compatibilidad |
| `chore:`, `docs:`, `test:`, `ci:`, `build:` | *Ninguno* | `1.0.0` ➔ `1.0.0` | `1.0.0+1` ➔ `1.0.0+1` | Documentación, tests o mantenimiento |

---

## 🛠️ Características Principales

- **Multi-ecosistema**: Detecta automáticamente Node.js y Flutter sin necesidad de configuración adicional.
- **Formato Store Ready**: En Flutter incrementa automáticamente el `versionCode` / `CFBundleVersion` (`+1`, `+2`, etc.), previniendo errores de rechazo en las tiendas móviles.
- **Cero dependencias npm**: No requiere instalar Husky, Commitlint ni Semantic-Release.
- **Agnóstico al formato de módulos**: Funciona tanto en proyectos ESM (`"type": "module"`) como CommonJS.
- **Multiplataforma**: Compatible con Linux (`/proc` y `ps`), macOS (`ps`) y Windows (PowerShell / Git Bash).

---

## 📄 Licencia

MIT © [EDGAR-BRI](https://github.com/EDGAR-BRI)
