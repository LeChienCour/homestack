#!/usr/bin/env python3
"""
MCP Server para Vikunja
=======================
Expone la API de Vikunja como herramientas MCP para que Claude pueda
crear, listar, mover y organizar tickets directamente desde el chat.

Construido con FastMCP 3.x. Autenticación vía API token (tk_...).

Variables de entorno requeridas:
    VIKUNJA_URL    - Base URL de la instancia (ej. https://tasks.tudominio.com)
    VIKUNJA_TOKEN  - API token creado en Settings > API Tokens (empieza con tk_)

Uso:
    # stdio (para Claude Desktop / Cowork local)
    python -m src.server

    # HTTP (para conectar como remote connector)
    python -m src.server --http --port 8200
"""

import os
import sys
import argparse
from typing import Optional

import httpx
from fastmcp import FastMCP

# -----------------------------------------------------------------------------
# Configuración
# -----------------------------------------------------------------------------
VIKUNJA_URL = os.environ.get("VIKUNJA_URL", "").rstrip("/")
VIKUNJA_TOKEN = os.environ.get("VIKUNJA_TOKEN", "")

if not VIKUNJA_URL or not VIKUNJA_TOKEN:
    print(
        "ERROR: define VIKUNJA_URL y VIKUNJA_TOKEN en el entorno.",
        file=sys.stderr,
    )
    sys.exit(1)

API_BASE = f"{VIKUNJA_URL}/api/v1"
HEADERS = {
    "Authorization": f"Bearer {VIKUNJA_TOKEN}",
    "Content-Type": "application/json",
}

mcp = FastMCP(name="vikunja")


# -----------------------------------------------------------------------------
# Helper HTTP
# -----------------------------------------------------------------------------
def _request(method: str, path: str, json_body: Optional[dict] = None,
             params: Optional[dict] = None) -> dict | list:
    """Wrapper sobre la API de Vikunja con manejo de errores."""
    url = f"{API_BASE}{path}"
    with httpx.Client(timeout=30.0) as client:
        resp = client.request(
            method, url, headers=HEADERS, json=json_body, params=params
        )
        if resp.status_code == 401:
            raise RuntimeError(
                "401 de Vikunja: token invalido o sin scope para este endpoint. "
                "Revisa que el API token tenga permisos de tasks/projects."
            )
        resp.raise_for_status()
        if resp.content:
            return resp.json()
        return {}


# -----------------------------------------------------------------------------
# TOOLS — Proyectos
# -----------------------------------------------------------------------------
@mcp.tool
def list_projects() -> list:
    """Lista todos los proyectos del usuario en Vikunja.

    Returns:
        Lista de proyectos con id, title, description e identifier.
    """
    projects = _request("GET", "/projects")
    return [
        {
            "id": p.get("id"),
            "title": p.get("title"),
            "description": p.get("description", ""),
            "identifier": p.get("identifier", ""),
            "is_archived": p.get("is_archived", False),
        }
        for p in (projects or [])
    ]


@mcp.tool
def create_project(title: str, description: str = "") -> dict:
    """Crea un nuevo proyecto en Vikunja.

    Args:
        title: Nombre del proyecto.
        description: Descripcion opcional.

    Returns:
        El proyecto creado con su id.
    """
    body = {"title": title, "description": description}
    result = _request("PUT", "/projects", json_body=body)
    return {"id": result.get("id"), "title": result.get("title")}


# -----------------------------------------------------------------------------
# TOOLS — Tareas (tickets)
# -----------------------------------------------------------------------------
@mcp.tool
def list_tasks(project_id: int, include_done: bool = False) -> list:
    """Lista las tareas de un proyecto.

    Args:
        project_id: ID del proyecto (usa list_projects para encontrarlo).
        include_done: Si True, incluye tareas completadas.

    Returns:
        Lista de tareas con id, title, done, priority, due_date.
    """
    params = {} if include_done else {"filter": "done = false"}
    tasks = _request("GET", f"/projects/{project_id}/tasks", params=params)
    return [
        {
            "id": t.get("id"),
            "title": t.get("title"),
            "description": t.get("description", ""),
            "done": t.get("done", False),
            "priority": t.get("priority", 0),
            "due_date": t.get("due_date"),
            "labels": [l.get("title") for l in (t.get("labels") or [])],
        }
        for t in (tasks or [])
    ]


@mcp.tool
def create_task(
    project_id: int,
    title: str,
    description: str = "",
    priority: int = 0,
    due_date: Optional[str] = None,
) -> dict:
    """Crea una nueva tarea (ticket) en un proyecto.

    Args:
        project_id: ID del proyecto destino.
        title: Titulo del ticket.
        description: Descripcion / detalle (acepta markdown).
        priority: 0=sin prioridad, 1=baja, 2=media, 3=alta, 4=urgente, 5=DO NOW.
        due_date: Fecha limite en formato ISO 8601 (ej. 2026-06-01T00:00:00Z).

    Returns:
        El ticket creado con su id.
    """
    body: dict = {"title": title, "description": description, "priority": priority}
    if due_date:
        body["due_date"] = due_date
    result = _request("PUT", f"/projects/{project_id}/tasks", json_body=body)
    return {
        "id": result.get("id"),
        "title": result.get("title"),
        "project_id": project_id,
    }


@mcp.tool
def update_task(
    task_id: int,
    title: Optional[str] = None,
    description: Optional[str] = None,
    done: Optional[bool] = None,
    priority: Optional[int] = None,
    due_date: Optional[str] = None,
) -> dict:
    """Actualiza una tarea existente. Solo cambia los campos que pases.

    Args:
        task_id: ID de la tarea a modificar.
        title: Nuevo titulo (opcional).
        description: Nueva descripcion (opcional).
        done: Marcar como completada/no completada (opcional).
        priority: Nueva prioridad 0-5 (opcional).
        due_date: Nueva fecha ISO 8601 (opcional).

    Returns:
        La tarea actualizada.
    """
    # Vikunja requiere el objeto completo; primero leemos la tarea actual
    current = _request("GET", f"/tasks/{task_id}")
    if title is not None:
        current["title"] = title
    if description is not None:
        current["description"] = description
    if done is not None:
        current["done"] = done
    if priority is not None:
        current["priority"] = priority
    if due_date is not None:
        current["due_date"] = due_date
    result = _request("POST", f"/tasks/{task_id}", json_body=current)
    return {
        "id": result.get("id"),
        "title": result.get("title"),
        "done": result.get("done"),
        "priority": result.get("priority"),
    }


@mcp.tool
def move_task(task_id: int, target_project_id: int) -> dict:
    """Mueve una tarea a otro proyecto.

    Args:
        task_id: ID de la tarea a mover.
        target_project_id: ID del proyecto destino.

    Returns:
        Confirmacion del movimiento.
    """
    current = _request("GET", f"/tasks/{task_id}")
    current["project_id"] = target_project_id
    result = _request("POST", f"/tasks/{task_id}", json_body=current)
    return {
        "id": result.get("id"),
        "title": result.get("title"),
        "new_project_id": target_project_id,
    }


@mcp.tool
def complete_task(task_id: int) -> dict:
    """Marca una tarea como completada (atajo de update_task).

    Args:
        task_id: ID de la tarea.

    Returns:
        Confirmacion.
    """
    current = _request("GET", f"/tasks/{task_id}")
    current["done"] = True
    result = _request("POST", f"/tasks/{task_id}", json_body=current)
    return {"id": result.get("id"), "title": result.get("title"), "done": True}


# -----------------------------------------------------------------------------
# TOOLS — Labels
# -----------------------------------------------------------------------------
@mcp.tool
def list_labels() -> list:
    """Lista todas las etiquetas (labels) disponibles.

    Returns:
        Lista de labels con id y title.
    """
    labels = _request("GET", "/labels")
    return [{"id": l.get("id"), "title": l.get("title")} for l in (labels or [])]


@mcp.tool
def add_label_to_task(task_id: int, label_id: int) -> dict:
    """Asigna una etiqueta a una tarea.

    Args:
        task_id: ID de la tarea.
        label_id: ID del label (usa list_labels).

    Returns:
        Confirmacion.
    """
    body = {"label_id": label_id}
    _request("PUT", f"/tasks/{task_id}/labels", json_body=body)
    return {"task_id": task_id, "label_id": label_id, "added": True}


# -----------------------------------------------------------------------------
# RESOURCE — Vista rapida del estado
# -----------------------------------------------------------------------------
@mcp.resource("vikunja://overview")
def overview() -> str:
    """Resumen de todos los proyectos y conteo de tareas pendientes."""
    projects = _request("GET", "/projects")
    lines = ["# Vikunja — Overview\n"]
    for p in (projects or []):
        if p.get("is_archived"):
            continue
        pid = p.get("id")
        try:
            tasks = _request(
                "GET", f"/projects/{pid}/tasks", params={"filter": "done = false"}
            )
            count = len(tasks or [])
        except Exception:
            count = "?"
        lines.append(f"- **{p.get('title')}** (id={pid}): {count} tareas pendientes")
    return "\n".join(lines)


# -----------------------------------------------------------------------------
# Entrypoint
# -----------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="MCP server para Vikunja")
    parser.add_argument("--http", action="store_true", help="Usar transport HTTP")
    parser.add_argument("--port", type=int, default=8200, help="Puerto para HTTP")
    parser.add_argument("--host", default="127.0.0.1", help="Host para HTTP")
    args = parser.parse_args()

    if args.http:
        mcp.run(transport="http", host=args.host, port=args.port)
    else:
        mcp.run()  # stdio por defecto


if __name__ == "__main__":
    main()
