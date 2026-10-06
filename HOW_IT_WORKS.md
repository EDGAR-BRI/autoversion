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

---

## 2. Flujo de Ejecución (Paso a Paso)

Cuando ejecutas un comando de commit en tu terminal, ocurre la siguiente secuencia:

```text
┌──────────────────────────────────────────────────────────────────────────┐
│  1. Desarrollador ejecuta:                                               │
│     git commit -m "feat: login con google"                               │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     │
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  2. Git dispara el hook pre-commit:                                      │
│     .git/hooks/pre-commit  ───▶  node scripts/auto-version-hook.mjs      │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     │
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  3. Inspección del proceso ancestro en el SO:                            │
│     Rastrea el comando original y extrae el mensaje: "feat: ..."        │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     │
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  4. Clasificación Conventional Commit:                                  │
│     • feat:             ➜  MINOR  (+0.1.0)                               │
│     • fix / refactor:   ➜  PATCH  (+0.0.1)                               │
│     • feat! / BREAKING: ➜  MAJOR  (+1.0.0)                               │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     │
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  5. Actualización en disco:                                              │
│     • Node.js:  package.json (SemVer)                                    │
│     • Flutter:  pubspec.yaml (SemVer + BuildNumber)                      │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     │
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  6. Inclusión atómica en Git:                                            │
│     git add package.json / pubspec.yaml                                  │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     │
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  7. Commit completado con éxito:                                         │
│     El commit se crea con tu código Y la nueva versión en el mismo paso  │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 3. El Desafío Técnico y su Solución

En Git existen dos hooks principales relacionados con la creación de commits:
1. **`commit-msg`**: Se ejecuta cuando el mensaje ya está escrito en el archivo `.git/COMMIT_EDITMSG`, **pero** en este punto el índice de Git (los archivos en *staging*) ya está congelado. Modificar `package.json` aquí no lo incluye en el commit actual a menos que se fuerce un commit adicional.
2. **`pre-commit`**: Se ejecuta antes de congelar el índice, lo que permite hacer `git add` y meter cambios en el mismo commit. **Sin embargo**, en esta fase Git aún no ha creado el archivo `.git/COMMIT_EDITMSG`.

### La Solución: Inspección del Proceso Ancestro

Para capturar el mensaje en la fase `pre-commit`, el script rastrea hacia atrás el árbol de procesos de tu sistema operativo hasta encontrar el comando original `git commit`:

```text
Proceso C (Node.js: auto-version-hook.mjs) [Hijo]
      ▲
Proceso B (Bash: .git/hooks/pre-commit) [Padre]
      ▲
Proceso A (Git: git commit -m "feat: mi cambio") [Abuelo / Ancestro]
```

#### ¿Cómo lo hace en cada sistema operativo?
- **En Linux / WSL:** Lee el sistema de archivos virtual del kernel: `/proc/<pid>/cmdline` y recorre los PPID en `/proc/<pid>/stat`. Es instantáneo y directo.
- **En macOS / BSD:** Usa `ps -p <pid> -o ppid=,command=` para subir por los procesos padres.
- **En Windows:** Consulta las instancias de procesos mediante `PowerShell (Get-CimInstance Win32_Process)`.

Una vez ubicado el comando `git commit`, extrae el texto pasado en los argumentos `-m`, `--message`, `-F` o `--file`.

---

## 4. Reglas de Clasificación SemVer

El script analiza el prefijo del mensaje siguiendo la especificación de **Conventional Commits**:

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
1. Detecta la expresión regular `version: (\d+)\.(\d+)\.(\d+)\+(\d+)`.
2. Calcula el incremento SemVer (`MAJOR`, `MINOR` o `PATCH`).
3. **Incrementa obligatoriamente el `Build Number` (`+1`)** en cada cambio de versión, asegurando que el APK / Bundle generado sea siempre aceptado por Google Play y App Store sin rechazos.

---

## 6. Mecanismos de Seguridad y Casos Borde

1. **Evita incrementos dobles:**  
   Antes de modificar nada, ejecuta `git diff --cached package.json` (o `pubspec.yaml`). Si el desarrollador ya modificó la versión manualmente en ese commit, el script se detiene y no la vuelve a incrementar.
2. **Ignora commits automáticos:**  
   Si el commit empieza con `Merge ` o `Revert `, el script se cancela para no alterar la versión por operaciones de ramas.
3. **Tolerancia a fallos:**  
   Todo el proceso está protegido en un bloque `try/catch`. Si ocurre un escenario imprevisto (ej. sintaxis inusual), el script no interrumpe el commit del desarrollador.

---

## 7. Estructura de Archivos en el Proyecto

Al instalarlo en un proyecto, se generan únicamente dos archivos pequeños:

```text
mi-proyecto/
├── .git/
│   └── hooks/
│       └── pre-commit           # Script Bash ejecutable que invoca al hook
├── scripts/
│   ├── auto-version-hook.mjs    # Lógica de detección de commit y bumping
│   └── setup-git-hooks.mjs      # Auto-instalador para nuevos clones
├── package.json (o pubspec.yaml)
```

- **¿Por qué `.mjs`?**  
  Usar la extensión `.mjs` le indica a Node.js que ejecute el archivo con sintaxis moderna de módulos ES (`import`), evitando errores de incompatibilidad tanto en proyectos que usen `"type": "module"` como en proyectos `"type": "commonjs"`.
- **¿Cómo se mantiene al clonar el repositorio?**  
  En proyectos Node, `package.json` incluye `"prepare": "node scripts/setup-git-hooks.mjs"`. Cuando cualquier persona (o tú en otra máquina) clona el repo y corre `npm install` o `pnpm install`, el hook se activa automáticamente.
