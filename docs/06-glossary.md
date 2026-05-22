# 06 — Glosario de términos

Términos que aparecen en el proyecto, explicados de forma directa.

## Infraestructura / contenedores

**Container** — Una "caja" donde corre un servicio (n8n, Postgres, etc.) aislado del resto del sistema. Como una mini-computadora virtual ultraligera.

**Imagen** — La plantilla desde la que se crea un container. Ej: `postgres:16-alpine` es una imagen, y el container es la instancia corriendo de esa imagen.

**Volume** — Carpeta persistente donde un container guarda sus datos. Sobrevive aunque borres el container.

**Podman** — Alternativa a Docker. Mismo concepto, sin daemon central, más liviano. Compatible con todos los comandos Docker.

**Podman Machine** — La VM Linux mínima donde corren tus containers cuando estás en Mac (los containers son Linux nativo, macOS no puede correrlos directamente).

**docker-compose / podman-compose** — Herramienta para definir múltiples containers en un solo archivo YAML y levantarlos con un comando.

## Red

**Reverse proxy** — Software que recibe todo el tráfico web y lo redirige al container correcto según la URL. En este stack es **Traefik**.

**Ingress** — En el contexto de Cloudflare Tunnel: las reglas que dicen "el hostname X va al servicio Y".

**Tunnel** — Conexión cifrada saliente desde tu Mac mini hacia Cloudflare. Permite recibir tráfico sin abrir puertos.

**CNAME** — Tipo de registro DNS que apunta un dominio a otro dominio (en lugar de a una IP). Ej: `n8n.tudominio.com → tunnel-id.cfargotunnel.com`.

**TXT record** — Registro DNS que guarda texto arbitrario. Usado para verificación de dominio, SPF, DKIM, DMARC.

**Proxied (Cloudflare)** — Cuando un DNS pasa por Cloudflare (orange cloud). Oculta tu IP real, da SSL gratis, protección DDoS.

## Email

**SMTP** — Protocolo para enviar emails. Listmonk se conecta a SES vía SMTP.

**DKIM** — Firma criptográfica que prueba que un email viene de tu dominio. Sin DKIM, te marcan spam.

**SPF** — Lista de servidores autorizados a enviar emails con tu dominio.

**DMARC** — Política que dice qué hacer con emails que fallan SPF/DKIM.

**MAIL FROM domain** — Dominio que aparece en el "envelope" del email (técnico, no visible al usuario), distinto del "From" que ve el usuario. Tener uno propio mejora reputación.

**SES sandbox** — Modo restringido por defecto en AWS SES. Solo puedes enviar a emails verificados manualmente. Hay que pedir salida.

**Bounce rate** — % de emails que rebotan (dirección inválida). Debe ser <5%.

**Complaint rate** — % de destinatarios que te marcaron como spam. Debe ser <0.1%.

## Seguridad

**SOPS** — Herramienta de Mozilla para encriptar archivos secretos dentro de tu repositorio Git. Permite versionar secretos sin exponerlos.

**age** — Algoritmo de encriptación moderno. SOPS lo usa para encriptar.

**IAM user** — Usuario de AWS con permisos específicos. Buena práctica: crear uno por aplicación con permisos mínimos.

**Access Key / Secret Key** — Las credenciales de un IAM user. Como usuario y contraseña pero para APIs.

**WAF (Web Application Firewall)** — Cloudflare lo incluye gratis. Bloquea ataques conocidos (SQL injection, XSS, etc.).

**TLS / SSL** — Lo que hace que la URL diga `https://` y no `http://`. Cloudflare lo provee automáticamente.

## Bases de datos

**Postgres** — La base de datos relacional más popular open-source. Robusta, rápida, gratis.

**Redis** — Base de datos en memoria, ultra rápida. Usada para cache, colas de tareas. Postiz la necesita.

**Database compartida** — En lugar de instalar Postgres N veces (uno por app), instalamos uno solo con múltiples "schemas" o "databases" dentro. Ahorra ~2GB de RAM.

**Dump** — Exportación completa del contenido de la base de datos a un archivo. Es como hacer "Save As".

## Backups

**Restic** — Herramienta de backup encriptado, deduplicado e incremental. Solo guarda lo que cambió.

**Snapshot** — Versión específica del backup en un momento dado. Restic te permite restaurar cualquier snapshot.

**Retention policy** — Reglas de "cuántos backups guardar": ej. 7 diarios, 4 semanales, 12 mensuales. El resto se borra automáticamente.

## Terraform

**IaC (Infrastructure as Code)** — Definir infraestructura en archivos de texto versionables en Git, en vez de hacer click en consolas. Terraform es el estándar.

**Provider** — Plugin de Terraform para hablar con una plataforma específica (AWS, Cloudflare, etc.).

**Resource** — Cualquier "cosa" que Terraform crea: un usuario IAM, un DNS record, un tunnel.

**State file** — Archivo donde Terraform recuerda qué creó. Crítico: si lo pierdes, Terraform no sabe qué existe.

**Plan / Apply** — `terraform plan` muestra lo que va a hacer. `terraform apply` lo ejecuta. Siempre revisa el plan antes de aplicar.

## macOS

**launchd** — Sistema de jobs programados de macOS (equivalente a cron en Linux). Lo usamos para correr backups nocturnos.

**LaunchAgent** — Job que corre con tu usuario. Lo guardamos en `~/Library/LaunchAgents/`.

**pmset** — Comando para configurar power management (dormir, despertar, etc.).

## Aplicaciones del stack

**n8n** — Plataforma de automatización con UI visual. Conectas servicios con drag-and-drop. Alternativa open-source a Zapier.

**Listmonk** — Software para enviar newsletters/campañas. Listas, plantillas, métricas. Alternativa a Mailchimp.

**Docuseal** — Servicio para subir PDFs, agregar campos de firma, enviar a clientes para firmar electrónicamente. Alternativa a DocuSign.

**Postiz** — Programa publicaciones a Instagram, Twitter, LinkedIn, etc. desde un solo dashboard. Alternativa a Buffer.

**Vaultwarden** — Servidor compatible con clientes de Bitwarden (extensión browser, app móvil). Tus contraseñas en tu servidor, no en la nube de nadie.

**Umami** — Web analytics privado. Sin cookies, sin tracking invasivo, GDPR-compliant out of the box.

**Homepage** — Dashboard customizable que muestra todos tus servicios en una página.

**Beszel** — Monitor de host (CPU, RAM, disco) y containers. UI bonita, ligero.

**Dozzle** — Visualizador de logs de containers en tiempo real via web.
