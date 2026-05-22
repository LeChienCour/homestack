# 04 — Umami: tracking de FOTOGRAMIA

## ¿Qué es Umami?

Alternativa self-hosted a Google Analytics:
- **Privacidad**: no usa cookies, no comparte datos con terceros
- **Ligero**: el script `<script>` pesa ~2KB (vs ~50KB de GA)
- **No bloqueado por ad-blockers**: porque corre en TU dominio
- **GDPR/CCPA compliant** sin banner de cookies

## Setup inicial

### 1. Acceder a Umami

Después de levantar el stack:
```
https://stats.tudominio.com
```

Login default:
- Username: `admin`
- Password: `umami`

**Cámbialo inmediatamente**: Settings → Users → admin → Change password.

### 2. Crear website para FOTOGRAMIA

1. Dashboard → Websites → Add website
2. Llenar:
   - **Name**: FOTOGRAMIA
   - **Domain**: `fotogramia.com` (sin `https://` ni `www.`)
3. Click Save
4. Click sobre el website creado → Edit → **Tracking code**

Te muestra algo así:

```html
<script defer
  src="https://stats.tudominio.com/script.js"
  data-website-id="abc123-def456-ghi789">
</script>
```

### 3. Agregar a tu sitio FOTOGRAMIA

Depende de cómo está hecho tu sitio:

#### Si es HTML estático

Pega el snippet **antes del cierre de `</head>`** en cada página, o mejor en un layout compartido.

#### Si es WordPress

- Plugin **Insert Headers and Footers** → pegar en "Scripts in header"
- O editar el theme: `header.php` antes de `</head>`

#### Si es Wix / Squarespace / Webflow

Cada uno tiene un campo de "Custom HTML in Head" en settings del sitio.

#### Si es Next.js / React

```jsx
// pages/_document.js o app/layout.tsx
<Script
  src="https://stats.tudominio.com/script.js"
  data-website-id="abc123-def456-ghi789"
  strategy="afterInteractive"
/>
```

## Ver estadísticas

Después de 5-10 minutos de tener el script puesto, deberías ver tráfico en:
```
https://stats.tudominio.com
```

Métricas que ves:
- Visitors únicos por día/semana/mes
- Páginas más visitadas
- Países y ciudades
- Devices (mobile/desktop)
- Referrers (de dónde vienen: Instagram, Google, directo)
- Eventos custom (si los configuras)

## Eventos custom (opcional, avanzado)

Para trackear clicks en botones específicos (ej. "Reservar photobooth"):

```html
<button onclick="umami.track('reservar-click')">Reservar</button>
```

O con datos:
```javascript
umami.track('reservar-click', { plan: 'premium', source: 'homepage' });
```

Aparecen como eventos en el dashboard de Umami.

## Privacidad y compliance

Umami **no necesita banner de cookies** porque:
- No usa cookies persistentes
- No identifica usuarios individualmente
- Solo guarda agregados anónimos

Esto es muy ventajoso vs Google Analytics, que sí requiere consent banner por GDPR.

Aún así, agrega en tu privacy policy:
> "Usamos Umami Analytics (self-hosted) para entender el tráfico del sitio. No usamos cookies de tracking ni compartimos datos con terceros."

## Goals y conversiones

Configura "goals" en Umami para medir conversiones:
1. Website → Goals → Create
2. Tipo: "URL visited" o "Event"
3. Ejemplo: URL = `/gracias-reserva` → cuenta cada reserva completada

## Performance

El script de Umami es asíncrono y no bloquea el render. No impacta el SEO ni el PageSpeed score.

## Backups

Los datos viven en la DB Postgres compartida. El script de backup ya incluye Umami automáticamente.

## Trackeando múltiples sitios

Puedes agregar más websites en el mismo Umami (no cuesta extra):
1. Dashboard → Websites → Add website
2. Cada uno tiene su propio `data-website-id`
3. Usa el mismo dominio `stats.tudominio.com`

Útil si en el futuro quieres trackear:
- Sitio principal de FOTOGRAMIA
- Landing pages de campañas
- Blog personal
- Etc.
