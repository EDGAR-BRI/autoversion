# 🚀 AutoVersion: Guía Definitiva y Documentación Técnica

> **Auto-versionamiento semántico (SemVer) automático y atómico para proyectos Flutter / Dart y Node.js basado en Conventional Commits.**  
> Compatible al 100% con **Terminal CLI** y entornos visuales (**VS Code, Cursor, GitKraken, GitHub Desktop**), sin dependencias externas pesadas y multiplataforma (Linux, macOS, Windows).

---

## 📑 Tabla de Contenidos

1. [Visión General y Filosofía](#1-visión-general-y-filosofía)
2. [Instalación y Actualización en 1 Paso](#2-instalación-y-actualización-en-1-paso)
3. [Arquitectura del Sistema y Flujo de Git](#3-arquitectura-del-sistema-y-flujo-de-git)
   - [El Desafío: Terminal vs. Interfaces Gráficas (VS Code)](#el-desafío-terminal-vs-interfaces-gráficas-vs-code)
   - [La Solución: Estrategia Cooperativa Dual (pre-commit + post-commit)](#la-solución-estrategia-cooperativa-dual-pre-commit--post-commit)
   - [Diagrama de Flujo Completo](#diagrama-de-flujo-completo)
4. [Especificación SemVer y Mapeo de Commits](#4-especificación-semver-y-mapeo-de-commits)
   - [Tabla Maestra de Incrementos](#tabla-maestra-de-incrementos)
   - [Reglas para Proyectos Node.js (`package.json`)](#reglas-para-proyectos-nodejs-packagejson)
   - [Reglas para Proyectos Flutter / Dart (`pubspec.yaml`)](#reglas-para-proyectos-flutter--dart-pubspecyaml)
5. [Particularidades de Flutter: Play Store y App Store](#5-particularidades-de-flutter-play-store-y-app-store)
6. [Flujo de Trabajo del Día a Día (Ejemplos Reales)](#6-flujo-de-trabajo-del-día-a-día-ejemplos-reales)
7. [Colaboración en Equipo y Nuevos Clones](#7-colaboración-en-equipo-y-nuevos-clones)
8. [Mecanismos de Seguridad y Resiliencia](#8-mecanismos-de-seguridad-y-resiliencia)
9. [Resolución de Problemas (Troubleshooting & FAQs)](#9-resolución-de-problemas-troubleshooting--faqs)
10. [Desinstalación Limpia](#10-desinstalación-limpia)

---

## 1. Visión General y Filosofía

Mantener versiones consistentes siguiendo [Semantic Versioning (SemVer 2.0.0)](https://semver.org) suele requerir uno de dos extremos:
1. **Edición manual propensa a errores:** El desarrollador olvida cambiar el número en `package.json` o `pubspec.yaml`, o confunde si el cambio era *minor* o *patch*.
2. **Tooling sobrecargado:** Herramientas como Husky, Semantic-Release o Changesets que instalan cientos de megabytes en `node_modules`, requieren tokens de CI/CD y complican proyectos móviles o ligeros.

### Los 5 Principios de AutoVersion:
* 🪶 **Cero dependencias:** No instala librerías npm ni paquetes externos. Utiliza exclusivamente las APIs nativas del sistema operativo y de Node.js.
* ⚛️ **Atómico:** La versión se actualiza dentro del **mismo commit** que contiene el código. Nunca genera commits extras innecesarios tipo *"chore: bump version"* ensuciando el historial.
* 🌐 **Políglota nativo:** Reconoce y gestiona automáticamente proyectos **Node.js** (`package.json`) y **Flutter / Dart** (`pubspec.yaml`), así como repositorios híbridos.
* 🖥️ **Agnóstico al entorno:** Funciona de manera transparente tanto si eres un usuario de terminal pura (`git commit -m "..."`) como si prefieres el botón de commit visual de **VS Code**, **Cursor** o **GitKraken**.
* 🛡️ **Seguridad primero:** Si el desarrollador ya modificó la versión manualmente, o si ocurre una condición imprevista, el script **nunca** bloquea ni interrumpe el commit.

---

## 2. Instalación y Actualización en 1 Paso

El instalador es completamente **idempotente**: puedes ejecutarlo en repositorios nuevos para instalarlo o en repositorios existentes para **actualizar a la última versión**.

### Opción A: Mediante `curl` (Recomendado para cualquier proyecto)
Ejecútalo desde la **raíz de tu proyecto** (Flutter o Node):
```bash
curl -fsSL https://raw.githubusercontent.com/EDGAR-BRI/autoversion/main/install.sh | bash
```

### Opción B: Mediante `npx` (Ecosistema Node.js)
```bash
npx github:EDGAR-BRI/autoversion
```

> [!TIP]
> **Modo desatendido (Scripts y CI):**  
> Puedes pasar la bandera `-y` o `--yes` para omitir cualquier confirmación interactiva:
> ```bash
> curl -fsSL https://raw.githubusercontent.com/EDGAR-BRI/autoversion/main/install.sh | bash -s -- -y
> ```

---

## 3. Arquitectura del Sistema y Flujo de Git

### El Desafío: Terminal vs. Interfaces Gráficas (VS Code)

El ciclo de vida estándar de Git tiene una limitación técnica histórica:
1. **En la Terminal CLI:** Cuando ejecutas `git commit -m "feat: nueva pantalla"`, el mensaje viaja como un argumento visible del proceso del sistema operativo (`-m`). Un script en el hook `pre-commit` puede inspeccionar el proceso padre, leer el mensaje, actualizar el archivo y agregarlo al commit con `git add`.
2. **En la Interfaz de VS Code / GUIs:** Cuando escribes el mensaje en el panel de *Control de código fuente* y haces clic en **✓ Commit**, VS Code **no** usa `-m`. En su lugar, envía el mensaje a través de la entrada estándar (*stdin*) ejecutando `git commit --quiet --file -`.  
   En la fase `pre-commit`:
   - Git **no** ha creado aún el archivo `.git/COMMIT_EDITMSG`.
   - Git **no** reenvía el flujo de *stdin* al hook.
   - En consecuencia, en `pre-commit` es físicamente imposible conocer el mensaje antes de que se cree el commit.
3. **¿Por qué no usar `commit-msg`?**  
   En el hook `commit-msg` el mensaje ya está disponible, pero el árbol de *staging* de Git ya está congelado. Cualquier cambio en disco o ejecución de `git add` allí es ignorado para el commit en curso.

### La Solución: Estrategia Cooperativa Dual (`pre-commit` + `post-commit`)

`AutoVersion` resuelve este desafío implementando una arquitectura de dos hooks sincronizados que se complementan sin solaparse:

1. **Fase `pre-commit` (Optimización para Terminal):**
   - Rastrea el comando original en el árbol de procesos del sistema operativo.
   - Si detecta `-m`, `--message` o `-F <archivo>`, extrae el mensaje, sube la versión y ejecuta `git add`.
   - Si el commit proviene de una GUI (sin argumentos `-m`), sale silenciosamente sin tocar nada y delega la tarea a la fase siguiente.

2. **Fase `post-commit` (Garantía para VS Code y Clientes GUI):**
   - Se ejecuta inmediatamente después de que el commit ha sido creado en Git.
   - Inspecciona los archivos confirmados en `HEAD` (`git diff-tree --no-commit-id --name-only -r --root HEAD`).
   - Si la versión ya fue actualizada por `pre-commit` (o manualmente por el usuario), sale de inmediato en 0 milisegundos.
   - Si no fue modificada y el mensaje cumple con Conventional Commits, actualiza el archivo en disco y ejecuta `git commit --amend --no-edit` de forma atómica y transparente.
   - Cuenta con una variable de protección (`AUTOVERSION_AMENDING=1`) para evitar recursión infinita.

### Diagrama de Flujo Completo

```text
                                ¿Desde dónde se ejecuta el commit?
                                                 │
                      ┌──────────────────────────┴──────────────────────────┐
                      ▼                                                     ▼
         [ RUTA A: TERMINAL CLI ]                               [ RUTA B: VS CODE / GUI ]
          git commit -m "feat: ..."                            Botón Commit en Source Control
                      │                                                     │
                      ▼                                                     ▼
            .git/hooks/pre-commit                                 .git/hooks/pre-commit
                      │                                                     │
            Detecta flag -m en CLI                              Mensaje enviado por stdin
                      │                                        (Argumentos CLI vacíos)
                      ▼                                                     │
          ¿Cumple Conventional Commit?                                     ▼
           ├── NO  ──▶ Sale sin cambios                           Sale limpio sin tocar nada
           └── SÍ  ──┐                                                      │
                     ▼                                                      ▼
           Actualiza archivo en disco                            Git crea el commit inicial
           (package.json / pubspec.yaml)                                    │
                     │                                                      ▼
           git add package / pubspec                              .git/hooks/post-commit
                     │                                                      │
                     ▼                                           Inspecciona archivos en HEAD
           Git crea el commit atómico                                       │
         (Código + Versión en un solo paso)                     ¿Archivo de versión ya modificado?
                     │                                           ├── SÍ ──▶ Termina (ya atendido)
                     ▼                                           └── NO ──┐
            .git/hooks/post-commit                                        ▼
                     │                                           Lee mensaje desde HEAD
           Detecta archivo ya modificado                                  │
                     │                                           ¿Cumple Conventional Commit?
                     ▼                                            ├── NO  ──▶ Termina
               Sale de inmediato                                  └── SÍ  ──┐
                                                                            ▼
                                                                 Actualiza archivo en disco
                                                                            │
                                                                 git add package / pubspec
                                                                            │
                                                                 git commit --amend --no-edit
                                                                            │
                                                                            ▼
                                                                 Commit enmendado atómicamente
```

---

## 4. Especificación SemVer y Mapeo de Commits

El analizador examina la primera línea del mensaje de commit según el estándar **Conventional Commits 1.0.0**:

### Tabla Maestra de Incrementos

| Prefijo en el Commit | Nivel SemVer | Node.js (`package.json`) | Flutter (`pubspec.yaml`) | Propósito y Ejemplo |
| :--- | :---: | :---: | :---: | :--- |
| `feat:` o `feat(modulo):` | **MINOR** | `1.0.0` ➔ `1.1.0` | `1.0.0+1` ➔ `1.1.0+2` | Nuevas funcionalidades retrocompatibles.<br>*Ej:* `feat: login con biometría` |
| `fix:` o `fix(modulo):` | **PATCH** | `1.1.0` ➔ `1.1.1` | `1.1.0+2` ➔ `1.1.1+3` | Corrección de errores que no rompen nada.<br>*Ej:* `fix: corregir validación de email` |
| `refactor:` | **PATCH** | `1.1.0` ➔ `1.1.1` | `1.1.0+2` ➔ `1.1.1+3` | Refactorización interna de código.<br>*Ej:* `refactor: migrar cliente http a dio` |
| `perf:` | **PATCH** | `1.1.0` ➔ `1.1.1` | `1.1.0+2` ➔ `1.1.1+3` | Mejoras de rendimiento y optimización.<br>*Ej:* `perf: optimizar renderizado de lista` |
| `style:` | **PATCH** | `1.1.0` ➔ `1.1.1` | `1.1.0+2` ➔ `1.1.1+3` | Ajustes estéticos, formato de código.<br>*Ej:* `style: corregir padding en botones` |
| `feat!:` o `fix!:` | **MAJOR** | `1.1.1` ➔ `2.0.0` | `1.1.1+3` ➔ `2.0.0+4` | Cambios que rompen compatibilidad (Breaking Changes).<br>*Ej:* `feat!: cambiar api de autenticación` |
| `BREAKING CHANGE:` | **MAJOR** | `1.1.1` ➔ `2.0.0` | `1.1.1+3` ➔ `2.0.0+4` | Declaración de rotura de API en el cuerpo del mensaje. |
| `chore:`, `docs:`, `test:`, `ci:`, `build:` | *Ninguno* | *Sin cambios* | *Sin cambios* | Tareas auxiliares, documentación, pruebas o CI.<br>*Ej:* `docs: actualizar readme` |

### Reglas para Proyectos Node.js (`package.json`)
* Lee la propiedad `"version"` (por defecto `1.0.0` si no existe).
* Realiza el incremento numérico estricto `MAJOR.MINOR.PATCH`.
* Guarda el archivo respetando el formato JSON estándar con salto de línea final.

### Reglas para Proyectos Flutter / Dart (`pubspec.yaml`)
* Localiza la línea `version: X.Y.Z+Build` mediante expresión regular.
* Incrementa la parte semántica `X.Y.Z` según el commit.
* **Incrementa siempre el Build Number en +1** (ej. de `+2` a `+3`).

---

## 5. Particularidades de Flutter: Play Store y App Store

En el desarrollo de aplicaciones móviles, las tiendas de aplicaciones imponen reglas estrictas sobre el versionado:

```yaml
# pubspec.yaml
version: 1.2.0+15
#        └──┬──┘ └──┬──┘
#           │       └── Build Number (versionCode en Android, CFBundleVersion en iOS)
#           └────────── Version Name (versionName en Android, CFBundleShortVersionString en iOS)
```

1. **Google Play Store:** Rechazará cualquier nuevo APK o Android App Bundle (`.aab`) si su `versionCode` no es estrictamente mayor al de la versión publicada anteriormente.
2. **Apple App Store (TestFlight & App Store):** Exige que cada nueva subida tenga un `CFBundleVersion` numérico superior dentro de la misma versión visible.

> [!IMPORTANT]
> **Ventaja Automática de AutoVersion en Flutter:**  
> Cada vez que realizas un commit que califica para un incremento (`MAJOR`, `MINOR` o `PATCH`), el script **garantiza automáticamente que el Build Number aumente en 1 unidad**. Ya nunca tendrás un rechazo de compilación en CI/CD por olvidar subir el `+1`.

---

## 6. Flujo de Trabajo del Día a Día (Ejemplos Reales)

### Escenario 1: Commit desde la Terminal
1. Modificas un archivo de tu aplicación:
   ```bash
   git add lib/screens/home.dart
   ```
2. Realizas el commit:
   ```bash
   git commit -m "feat: agregar buscador en tiempo real"
   ```
3. Salida en consola:
   ```text
   🚀 [AutoVersion] Mensaje detectado (CLI): "feat: agregar buscador en tiempo real"
   📱 [AutoVersion] Flutter: versión actualizada a 1.2.0+4 (MINOR) en pubspec.yaml.
   [main a1b2c3d] feat: agregar buscador en tiempo real
    2 files changed, 45 insertions(+), 2 deletions(-)
   ```
4. El commit final contiene tu código **y** el `pubspec.yaml` actualizado en un único paso atómico.

### Escenario 2: Commit desde la Interfaz Visual de VS Code
1. Modificas tus archivos y abres el panel lateral de **Source Control** (Ctrl+Shift+G).
2. Escribes el mensaje en el cuadro de texto:
   ```text
   fix: corregir error de cálculo en totales
   ```
3. Haces clic en el botón azul **Commit** (o presionas `Ctrl+Enter`).
4. `AutoVersion` intercepta el commit recién generado:
   ```text
   🚀 [AutoVersion] Mensaje detectado (GUI / stdin): "fix: corregir error de cálculo en totales"
   📱 [AutoVersion] Flutter: versión actualizada a 1.2.1+5 (PATCH) en pubspec.yaml.
   ✓ [AutoVersion] Versión enmendada exitosamente en el commit.
   ```
5. En tu pestaña de Git verás que el commit final ya contiene la nueva versión incluida.

### Escenario 3: Tarea de Documentación (Sin Incremento)
```bash
git commit -m "docs: corregir comentarios en el servicio de api"
```
* `AutoVersion` detecta el prefijo `docs:` y no realiza ningún cambio en el archivo de versión.

### Escenario 4: Commit Manual (Tú decides la versión)
Si editas manualmente `pubspec.yaml` o `package.json` para fijar una versión específica (por ejemplo, saltar directamente a `2.0.0+10`):
* `AutoVersion` analiza el `git diff` de staging.
* Al detectar que el archivo de versión ya tiene cambios hechos por ti, **no interfiere ni duplica el incremento**. Respeta tu decisión al 100%.

---

## 7. Colaboración en Equipo y Nuevos Clones

¿Qué ocurre cuando otro desarrollador clona el repositorio o tú mismo descargas el proyecto en otra computadora?

```text
mi-proyecto/
├── .git/
│   └── hooks/
│       ├── pre-commit           # Script Bash local
│       └── post-commit          # Script Bash local
├── scripts/
│   ├── auto-version-hook.mjs    # Versionado en el repo (compartido)
│   └── setup-git-hooks.mjs      # Instalador de hooks (compartido)
├── package.json (o pubspec.yaml)
```

1. **La carpeta `.git/hooks/` no se sube a Git:** Esto es una regla inherente de Git por motivos de seguridad.
2. **Cómo se activan los hooks en nuevos clones:**
   - **En proyectos Node.js:** El instalador agrega automáticamente el script `"prepare": "node scripts/setup-git-hooks.mjs"` a `package.json`. Cuando cualquier desarrollador corre `npm install` o `pnpm install`, los hooks se instalan automáticamente.
   - **En proyectos Flutter:** En cualquier momento puedes ejecutar:
     ```bash
     node scripts/setup-git-hooks.mjs
     ```
     O volver a correr el instalador de 1 comando:
     ```bash
     curl -fsSL https://raw.githubusercontent.com/EDGAR-BRI/autoversion/main/install.sh | bash
     ```

---

## 8. Mecanismos de Seguridad y Resiliencia

El diseño de `AutoVersion` prioriza que **nada detenga el flujo de trabajo del desarrollador**:

* 🔒 **Anti-Bucles Infinitos:** En la fase `post-commit`, el comando `git commit --amend` dispara nuevamente los hooks. `AutoVersion` detecta tanto la variable `AUTOVERSION_AMENDING=1` como la presencia del archivo de versión en `HEAD`, abortando la segunda ejecución en 0 ms.
* 🌿 **Ignora Commits de Sistema:** Los commits generados por Git al resolver fusiones (`Merge branch...`) o reversiones (`Revert "..."`) son ignorados automáticamente para no distorsionar las versiones.
* 🔍 **Auto-detección de Node en Entornos GUI:** En Linux y macOS, aplicaciones de escritorio como VS Code a menudo no cargan variables de entorno interactivas como NVM o FNM. Los scripts bash de los hooks incluyen un cargador inteligente que busca Node en:
  - `$HOME/.nvm/versions/node/*/bin`
  - `$HOME/.fnm/current/bin`
  - `$HOME/.asdf/shims`
  - `$HOME/.volta/bin`
  - `/usr/local/bin` y `/usr/bin`
* 🛡️ **Tolerancia Total a Fallos:** Todo el bloque de lógica se encuentra envuelto en bloques `try/catch`. En caso de cualquier error imprevisto (sintaxis corrupta, disco lleno), el script falla de forma silenciosa y permite que el commit de tu código se guarde intacto.

---

## 9. Resolución de Problemas (Troubleshooting & FAQs)

### ¿Por qué mi commit no incrementó la versión?
Verifica las tres causas más comunes:
1. **Prefijo no convencional:** Commits como `"actualizado"`, `"cambios varios"` o `"subiendo avances"` no siguen Conventional Commits. Usa siempre `feat:`, `fix:`, `refactor:`, `perf:` o `style:`.
2. **Prefijo de mantenimiento:** Commits con `chore:`, `docs:`, `test:`, `ci:` o `build:` están diseñados intencionalmente para **no** alterar la versión.
3. **El archivo ya estaba en staging:** Si modificaste manualmente `pubspec.yaml` o `package.json` en ese mismo commit, el script lo respeta y no lo vuelve a incrementar.

### ¿Qué pasa si hago `git commit --amend` a mano?
Si enmiendas un commit que ya fue incrementado, el script detecta que `pubspec.yaml` ya forma parte del commit y no vuelve a subir la versión una segunda vez.

### ¿Puedo usar emojis en mis commits? (Gitmoji)
Sí, siempre que el tipo convencional esté presente en la primera línea. Por ejemplo:
* `feat: :sparkles: agregar nuevo reproductor de audio` ➜ **MINOR**
* `fix: :bug: corregir error al guardar` ➜ **PATCH**

---

## 10. Desinstalación Limpia

Si por alguna razón deseas desinstalar `AutoVersion` de un proyecto, solo debes eliminar los hooks y los dos scripts auxiliares:

```bash
# 1. Eliminar hooks locales
rm -f .git/hooks/pre-commit .git/hooks/post-commit

# 2. Eliminar scripts auxiliares
rm -f scripts/auto-version-hook.mjs scripts/setup-git-hooks.mjs
```

Y en caso de proyectos Node.js, remover la línea `"prepare"` de `package.json`.

---

<p align="center">
  <b>AutoVersion</b> es un proyecto de código abierto mantenido por <a href="https://github.com/EDGAR-BRI">EDGAR-BRI</a>.<br>
  Distribuido bajo licencia MIT.
</p>
