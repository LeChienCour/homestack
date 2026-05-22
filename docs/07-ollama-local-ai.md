# 07 — Ollama nativo + IA local

## Por qué nativo y no en container

Podman en Mac corre dentro de una VM Linux que **no tiene acceso al GPU (Metal) de tu Apple Silicon**. Si metes Ollama en container, corre solo en CPU = lento y se come la RAM de la VM. Nativo usa Metal, va mucho más rápido, y gestiona su memoria aparte del stack.

## Instalación

```bash
brew install ollama

# Iniciar el servicio (corre en background, escucha en localhost:11434)
brew services start ollama
```

## Modelo recomendado para tu Mac mini 16GB

Para 16GB de RAM, el consenso 2026 es qwen2.5:7b como modelo general. Para tareas de las que hablamos (clasificar notas, generar títulos de tickets, resumir):

```bash
# Opción equilibrada (recomendada): Qwen 2.5 7B
ollama pull qwen2.5:7b

# Opción ligera (más rápida, para clasificación simple): Llama 3.2 3B
ollama pull llama3.2:3b
```

**Mi sugerencia:** empieza con `llama3.2:3b` para el workflow de tickets (es rápido y suficiente para clasificar), y ten `qwen2.5:7b` para tareas que pidan algo más de calidad.

En 8GB se usa llama3.2:3b, en 16GB qwen2.5:7b — tú estás en el tier de 16GB pero compartes RAM con el stack, así que el 3B es el caballo de batalla seguro.

## Optimización en Mac (importante)

Configura las variables de entorno con `launchctl`, NO en `.zshrc` (Ollama corre como servicio del sistema):

```bash
# Mantener el modelo en memoria (evita recargas lentas)
launchctl setenv OLLAMA_KEEP_ALIVE -1

# Flash attention (más rápido, menos RAM)
launchctl setenv OLLAMA_FLASH_ATTENTION 1

# Reiniciar el servicio para aplicar
brew services restart ollama
```

Verifica que use GPU y no CPU:

```bash
ollama ps
# La columna "Processor" debe decir GPU, no CPU
```

## Probar

```bash
ollama run llama3.2:3b "Resume en una línea: necesito configurar backups para el stack"
```

## Cómo lo usa el stack

Los containers de Podman acceden a Ollama nativo vía `host.containers.internal:11434` (el equivalente Podman de `host.docker.internal`).

Ejemplo desde n8n (ya está en el workflow `nota-a-ticket.json`):

```
URL: http://host.containers.internal:11434/api/generate
Body: {
  "model": "llama3.2:3b",
  "prompt": "...",
  "stream": false,
  "format": "json"
}
```

## Gestión de RAM — la regla práctica

| Estado | RAM Ollama |
|---|---|
| Modelo descargado pero sin usar | ~0 (en disco) |
| Modelo 3B cargado e inferiendo | ~3-4 GB |
| Modelo 7B cargado e inferiendo | ~6 GB |

Con `OLLAMA_KEEP_ALIVE -1` el modelo se queda en RAM. Si tu Mac mini va justo de memoria con todo el stack arriba, usa el default (se descarga tras 5 min de inactividad) en vez de `-1`:

```bash
launchctl setenv OLLAMA_KEEP_ALIVE 5m
```

Así Ollama solo ocupa RAM cuando realmente lo usas.

## Cuándo usar Ollama vs API de Claude

| Tarea | Herramienta |
|---|---|
| Clasificar nota, generar título, etiquetar | Ollama local (gratis, privado, rápido) |
| Resumen corto de texto en el Mac | Ollama local |
| Razonamiento complejo, código, análisis profundo | API de Claude (mejor calidad) |
| Algo que requiera contexto largo | API de Claude (Ollama 3B/7B se queda corto) |

La división: Ollama para lo trivial y privado, Claude para lo que pide calidad real.

## Comandos útiles

```bash
ollama list              # Modelos descargados
ollama ps                # Modelos cargados ahora + procesador (GPU/CPU)
ollama rm <modelo>       # Borrar modelo
ollama pull <modelo>     # Descargar/actualizar
curl localhost:11434/api/tags   # Listar modelos vía API
```
