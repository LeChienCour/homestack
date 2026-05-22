# MCP Server — Vikunja

Servidor MCP en Python (FastMCP) para que Claude gestione tus tickets de Vikunja directamente desde el chat o desde Cowork.

## Herramientas expuestas

| Tool | Función |
|---|---|
| `list_projects` | Lista proyectos |
| `create_project` | Crea proyecto |
| `list_tasks` | Lista tareas de un proyecto |
| `create_task` | Crea ticket (con prioridad, fecha, descripción) |
| `update_task` | Edita ticket (título, estado, prioridad, etc.) |
| `move_task` | Mueve ticket entre proyectos |
| `complete_task` | Marca ticket como hecho |
| `list_labels` | Lista etiquetas |
| `add_label_to_task` | Asigna etiqueta a ticket |

Más un resource `vikunja://overview` con resumen de pendientes.

## Instalación

```bash
cd mcp-vikunja
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
```

## Obtener API token de Vikunja

1. Abre Vikunja → Settings → API Tokens → Create token
2. **Habilita TODOS los scopes** de tasks, projects y labels (read + write). Si no, dará 401 en algunos endpoints (bug conocido de Vikunja con scopes parciales).
3. Copia el token (empieza con `tk_`)

## Configurar variables

```bash
export VIKUNJA_URL="https://tasks.tudominio.com"
export VIKUNJA_TOKEN="tk_tu_token_aqui"
```

## Probar localmente

```bash
# Modo stdio (test rápido)
python -m src.server

# Modo HTTP (para connector remoto)
python -m src.server --http --port 8200
```

## Conectar a Claude Desktop / Cowork

Edita el archivo de config MCP de Claude Desktop:

**macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "vikunja": {
      "command": "/ruta/a/mcp-vikunja/.venv/bin/python",
      "args": ["-m", "src.server"],
      "cwd": "/ruta/a/mcp-vikunja",
      "env": {
        "VIKUNJA_URL": "https://tasks.tudominio.com",
        "VIKUNJA_TOKEN": "tk_tu_token_aqui"
      }
    }
  }
}
```

Reinicia Claude Desktop. Las herramientas `vikunja_*` aparecerán disponibles.

## Conectar como remote connector (HTTP)

Si prefieres correrlo como servicio HTTP (ej. expuesto vía el mismo Cloudflare Tunnel):

```bash
python -m src.server --http --host 0.0.0.0 --port 8200
```

Luego agrégalo como connector remoto en Claude apuntando a la URL del tunnel.

## Notas de seguridad

- El token de Vikunja da acceso completo a tus tareas. Trátalo como password.
- Guárdalo en Vaultwarden, no en texto plano.
- Si lo expones por HTTP, hazlo solo detrás del tunnel con autenticación.
