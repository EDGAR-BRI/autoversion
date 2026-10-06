# 🚀 AutoVersion

<p align="center">
  <img src="https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white" alt="Node.js" />
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Conventional%20Commits-FE5196?style=for-the-badge&logo=conventionalcommits&logoColor=white" alt="Conventional Commits" />
  <img src="https://img.shields.io/badge/SemVer-2.0.0-blue?style=for-the-badge" alt="SemVer" />
  <img src="https://img.shields.io/badge/Dependencies-0-brightgreen?style=for-the-badge" alt="Zero Dependencies" />
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge" alt="License" />
</p>

> **Auto-versionamiento semántico (SemVer) automático y atómico para proyectos Flutter / Dart (`pubspec.yaml`) y Node.js (`package.json`) basado en Conventional Commits.**  
> Compatible al 100% con **Terminal CLI** y entornos visuales (**VS Code, Cursor, GitKraken, GitHub Desktop**), sin dependencias externas pesadas y multiplataforma (Linux, macOS, Windows).

---

## ⚡ Instalación en 1 Comando (Sin Clonar)

Ejecuta cualquiera de estos comandos en la **raíz de tu proyecto** (sea Flutter o Node.js):

### Opción 1: curl (Instantáneo, universal)
```bash
curl -fsSL https://raw.githubusercontent.com/EDGAR-BRI/autoversion/main/install.sh | bash
```

### Opción 2: npx (Ecosistema Node.js)
```bash
npx github:EDGAR-BRI/autoversion
```

> **¿Quieres actualizarlo?**  
> El instalador es **100% idempotente**. Puedes volver a ejecutarlo en cualquier momento para actualizar los hooks y scripts de tu proyecto a la versión más reciente sin alterar tus archivos ni reiniciar tus versiones existentes.

---

## 🎯 ¿Qué hace?

`AutoVersion` analiza el mensaje de tus commits y actualiza la versión de forma atómica en el mismo commit:

1. **📱 Flutter / Dart (`pubspec.yaml`):**
   - Actualiza la versión visible (`versionName`) según SemVer (`MAJOR.MINOR.PATCH`).
   - **Incrementa obligatoriamente el Build Number (`+1`)** (ej. de `1.0.0+1` a `1.1.0+2`), garantizando que los binarios para **Google Play Store** y **Apple App Store** siempre cumplan con los requisitos de publicación.
2. **📦 Node.js / TypeScript (`package.json`):**
   - Actualiza el campo `"version"` respetando el estándar SemVer.
3. **🔄 Proyectos Híbridos / Fullstack:**
   - Si tu proyecto contiene tanto `package.json` como `pubspec.yaml`, actualiza y sincroniza ambos al unísono.
4. **🖥️ Compatibilidad Universal (CLI + GUIs):**
   - Funciona sin configuración adicional tanto en terminal (`git commit -m "..."`) como haciendo clic en el botón de commit de **VS Code**, **Cursor**, **GitKraken** o editores interactivos.

---

## 📋 Mapeo de Conventional Commits a SemVer

| Prefijo del Commit | Tipo SemVer | Node.js (`package.json`) | Flutter (`pubspec.yaml`) | Propósito y Ejemplo |
| :--- | :---: | :---: | :---: | :--- |
| `feat:` | **MINOR** | `1.0.0` ➔ `1.1.0` | `1.0.0+1` ➔ `1.1.0+2` | Nuevas funcionalidades.<br>`feat: login con huella` |
| `fix:`, `refactor:`, `perf:`, `style:` | **PATCH** | `1.1.0` ➔ `1.1.1` | `1.1.0+2` ➔ `1.1.1+3` | Corrección de errores o mejoras internas.<br>`fix: corregir validacion de rfc` |
| `feat!:`, `fix!:`, `BREAKING CHANGE:` | **MAJOR** | `1.1.1` ➔ `2.0.0` | `1.1.1+3` ➔ `2.0.0+4` | Cambios que rompen compatibilidad.<br>`feat!: nueva estructura de payload` |
| `chore:`, `docs:`, `test:`, `ci:`, `build:` | *Ninguno* | *Sin cambios* | *Sin cambios* | Mantenimiento, docs o pruebas.<br>`docs: actualizar guia de api` |

---

## 🆚 Comparativa con Otras Herramientas

| Característica | AutoVersion | Semantic-Release | Husky + Commitlint |
| :--- | :---: | :---: | :---: |
| **Dependencias externas** | **0** | Decenas de paquetes | Múltiples paquetes npm |
| **Soporte Flutter / Dart nativo** | **✅ Sí (`+BuildNumber`)** | ❌ Requiere plugins | ❌ Requiere scripts custom |
| **Soporte Node.js nativo** | **✅ Sí** | ✅ Sí | ✅ Sí |
| **Commit atómico local (sin commits extra)** | **✅ Sí** | ❌ Crea commits en CI | ❌ Solo valida |
| **Compatible con VS Code / GUIs** | **✅ Sí** | ❌ Solo CLI / CI | ⚠️ Requiere PATH manual |
| **Instalación sin clonar repositorio** | **✅ 1 comando** | ❌ Requiere setup en CI | ❌ Requiere npm install |

---

## 📘 Guía Técnica Detallada

¿Quieres comprender el funcionamiento interno, el diagrama de ciclo de vida de los hooks o resolver casos borde?  
👉 Consulta la **[Guía Técnica Completa (HOW_IT_WORKS.md)](./HOW_IT_WORKS.md)**.

---

## 📄 Licencia

Distribuido bajo la licencia MIT. Consulta el archivo [LICENSE](./LICENSE) para más detalles.
