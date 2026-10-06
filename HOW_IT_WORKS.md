# 📘 Guía Técnica: Cómo Funciona el Versionamiento Automático

Esta guía documenta la arquitectura, el funcionamiento interno y el flujo de ejecución del sistema de auto-versionamiento semántico implementado en este ecosistema (y empaquetado en [`EDGAR-BRI/autoversion`](https://github.com/EDGAR-BRI/autoversion)).

---

## 1. El Objetivo

Tradicionalmente, para mantener las versiones de un proyecto según [SemVer (Semantic Versioning)](https://semver.org) existen dos caminos:
1. **Manual:** El desarrollador edita a mano `"version"` en `package.json` o `pubspec.yaml` antes de cada commit. Es propenso a olvidos e inconsistencias.
2. **Herramientas de CI/CD pesadas:** Usar Semantic-Release, Changesets o Husky, que requieren decenas de dependencias npm, tokens de GitHub Actions y configuración compleja.

**Este sistema resuelve ambos problemas:**
- **0 dependencias externas** (solo módulos nativos del sistema y de Node.js).
- **Atómico:** La versión se actualiza y entra en el **mismo commit** que tus cambios de código.
- **Políglota:** Funciona en proyectos **Node.js** (`package.json`) y **Flutter / Dart** (`pubspec.yaml`).
- **Multiplataforma:** Compatible con Linux, macOS y Windows.
- **Compatible con Terminal y GUIs:** Funciona tanto ejecutando `git commit -m "..."` en consola como haciendo click en el botón de commit de **VS Code**, **Cursor**, **GitKraken** o editores interactivos.

---

## 2. Flujo de Ejecución Dual (CLI y VS Code / GUIs)

Para garantizar compatibilidad universal, el sistema implementa una **estrategia de hook dual** (`pre-commit` y `post-commit`):

```text
                                ¿Desde dónde se hace el commit?
                                              │
                      ┌───────────────────────┴───────────────────────┐
                      ▼                                               ▼
         [ RUTA A: TERMINAL CLI ]                        [ RUTA B: VS CODE / GUI ]
          git commit -m "feat: ..."                     Botón Commit en Source Control
                      │                                               │
                      ▼                                               ▼
             .git/hooks/pre-commit                           .git/hooks/pre-commit
                      │                                               │
             Detecta flag -m en CLI                       Mensaje enviado por stdin (vacío en CLI)
                      │                                               │
        Actualiza versión en disco                      Pasa limpio sin tocar nada
                      │                                               │
         git add package / pubspec                                    ▼
                      │                                  Git crea el commit de usuario
                      ▼                                               │
        Git crea el commit atómico                                    ▼
     (Código + Versión en un solo paso)                     .git/hooks/post-commit
                      │                                               │
                      ▼                                  Lee mensaje del commit desde HEAD
             .git/hooks/post-commit                                   │
                      │                                 ¿Es Conventional Commit y no fue bumped?
         Verifica si ya fue bumped                                    │
           (Sí -> Termina de inmediato)                  Actualiza versión en disco
                                                                      │
                                                         git add package / pubspec
                                                                      │
                                                         git commit --amend --no-edit
                                                                      │
                                                                      ▼
                                                         Commit enmendado atómicamente
```

---

## 3. El Desafío Técnico de las GUIs y su Solución

En Git, el ciclo de vida de los hooks presenta diferencias críticas dependiendo de cómo se ejecute el commit:

### El Problema de VS Code y GUIs
1. **En Terminal CLI (`git commit -m "..."`):**  
   El mensaje de commit se pasa como argumento de línea de comandos (`-m` o `--message`). El script puede inspeccionar el proceso padre (`/proc/<pid>/cmdline` o `ps`) y extraer el mensaje en fase `pre-commit`, antes de que el commit se escriba en el historial.
2. **En VS Code / GitKraken / GUIs:**  
   VS Code **no pasa** el mensaje como argumento `-m`. En su lugar, escribe el mensaje en standard input (stdin) mediante `git commit --quiet --file -` o archivos temporales.  
   En fase `pre-commit`, Git aún no ha creado `.git/COMMIT_EDITMSG` ni redirige stdin al hook. Por ende, ningún script en `pre-commit` puede conocer el mensaje por adelantado.
3. **¿Por qué no usar únicamente `commit-msg`?**  
   En el hook `commit-msg`, el árbol de staging de Git ya está congelado. Modificar archivos y hacer `git add` allí es ignorado por Git para el commit en curso.

### La Solución: Arquitectura Cooperativa Dual
- **Fase `pre-commit`:** Se encarga de capturar commits rápidos por CLI de terminal. Si detecta el mensaje con `-m`, sube la versión y hace `git add`. Si no detecta argumentos (como en VS Code), no hace nada y delega la tarea a `post-commit`.
- **Fase `post-commit`:** Se dispara inmediatamente después de que el commit ha sido creado.  
  1. Inspecciona los archivos modificados en `HEAD` con `git diff-tree --no-commit-id --name-only -r --root HEAD`.  
  2. Si `pubspec.yaml` o `package.json` ya fueron modificados en ese commit (porque `pre-commit` ya actuó o el usuario los editó), finaliza inmediatamente.  
  3. Si la versión no fue modificada y el commit cumple con Conventional Commits (`feat:`, `fix:`, etc.), incrementa la versión y ejecuta `git commit --amend --no-edit`.  
  4. Protegido contra bucles infinitos mediante la variable de entorno `AUTOVERSION_AMENDING=1` y la validación de archivos modificados.

---

## 4. Reglas de Clasificación SemVer

El script analiza la primera línea del mensaje siguiendo la especificación de **Conventional Commits**:

| Prefijo en el Commit | Regla SemVer | Node.js (`package.json`) | Flutter (`pubspec.yaml`) | Razón / Caso de Uso |
| :--- | :--- | :--- | :--- | :--- |
| `feat:` | **MINOR** | `1.0.0` ➔ `1.1.0` | `1.0.0+1` ➔ `1.1.0+2` | Nuevas características o pantallas |
| `fix:`, `refactor:`, `perf:`, `style:` | **PATCH** | `1.1.0` ➔ `1.1.1` | `1.1.0+2` ➔ `1.1.1+3` | Arreglo de bugs, optimización o estilo |
| `feat!:`, `fix!:`, `BREAKING CHANGE:` | **MAJOR** | `1.1.1` ➔ `2.0.0` | `1.1.1+3` ➔ `2.0.0+4` | Cambios que rompen compatibilidad |
| `chore:`, `docs:`, `test:`, `ci:`, `build:` | *Ninguno* | *Sin cambios* | *Sin cambios* | Mantenimiento interno o documentación |

---

## 5. Particularidad de Flutter: Gestión del Build Number

En Flutter, las tiendas de aplicaciones (**Google Play Store** y **Apple App Store**) exigen dos identificadores:
- **`versionName` / `CFBundleShortVersionString`**: La versión visible para el usuario (ej. `1.1.0`).
- **`versionCode` / `CFBundleVersion`**: El número entero incremental de compilación (ej. `+2`).

En `pubspec.yaml` ambos se configuran en una sola línea:
```yaml
version: 1.1.0+2
```

El script de auto-versionado:
1. Detecta la expresión regular `version: (\d+)\.(\d+)\.(\d+)(?:\+(\d+))?`.
2. Calcula el incremento SemVer (`MAJOR`, `MINOR` o `PATCH`).
3. **Incrementa obligatoriamente el `Build Number` (`+1`)** en cada cambio de versión, asegurando que el APK / Bundle generado sea siempre aceptado por Google Play y App Store sin rechazos.

---

## 6. Mecanismos de Seguridad y Resiliencia

1. **Evita incrementos dobles o bucles:**  
   - En `pre-commit`: Valida `git diff --cached` antes de tocar archivos.
   - En `post-commit`: Valida `git diff-tree --name-only HEAD` y el guard `AUTOVERSION_AMENDING=1`. Si la versión ya fue tocada, sale inmediatamente.
2. **Ignora commits automáticos:**  
   Si el commit empieza con `Merge ` o `Revert `, el script se cancela para no alterar la versión por operaciones de ramas.
3. **Detección inteligente de Node en entornos GUI:**  
   Los hooks incluyen un cargador de entorno que localiza el binario de Node.js (incluso bajo NVM, FNM, Volta, ASDF o Homebrew) cuando se ejecutan dentro de VS Code u otros entornos de escritorio que no heredan el `.bashrc` completo.
4. **Tolerancia a fallos:**  
   Todo el proceso está protegido en un bloque `try/catch`. Si ocurre un escenario imprevisto, el script nunca abortará el commit del desarrollador.

---

## 7. Estructura de Archivos en el Proyecto

Al instalarlo en un proyecto, se generan únicamente los siguientes archivos:

```text
mi-proyecto/
├── .git/
│   └── hooks/
│       ├── pre-commit           # Intercepta commits desde terminal CLI (-m)
│       └── post-commit          # Intercepta commits desde VS Code / GUIs (stdin)
├── scripts/
│   ├── auto-version-hook.mjs    # Lógica de detección de commit y bumping
│   └── setup-git-hooks.mjs      # Instalador de hooks para nuevos clones
├── package.json (o pubspec.yaml)
```

- **¿Por qué `.mjs`?**  
  Usar la extensión `.mjs` le indica a Node.js que ejecute el archivo con sintaxis moderna de módulos ES (`import`), garantizando compatibilidad tanto en proyectos `"type": "module"` como en proyectos CommonJS.
- **¿Cómo se mantiene al clonar el repositorio?**  
  En proyectos Node, `package.json` incluye `"prepare": "node scripts/setup-git-hooks.mjs"`. Cuando cualquier persona (o tú en otra máquina) clona el repo y corre `npm install` o `pnpm install`, los hooks se configuran automáticamente sin intervención manual.
