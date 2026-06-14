# ManaHelper v2.0

**ManaHelper** es un addon ligero y altamente optimizado de monitoreo y asistencia de maná para sanadores en **World of Warcraft 3.3.5a (WotLK)**, optimizado para el servidor **NaerZone**. Permite comprobar en tiempo real el maná de los healers del grupo o banda, utilizando un motor de alertas inteligente por escalones y sincronización de banda jerárquica para evitar el spam en el chat.

---

## 🚀 Funcionalidades y Módulos

| Característica / Módulo | Descripción |
|---|---|
| **Alertas por Escalones** | Motor de alertas inteligente con cooldown. Se disparan al cruzar el umbral y luego solo si el maná cae un paso adicional configurable (ej: cada 10%). |
| **Sincronización Inteligente** | Comunicación invisible mediante canal de addon (`SendAddonMessage`). Elige automáticamente un único emisor para el chat basándose en la jerarquía del grupo (Líder > Ayudante > Miembro). |
| **Modo Silencio** | Opción en tiempo real que te excluye de la lista de emisores de alertas de chat si desmarcas la casilla "Chat" en tu interfaz. |
| **Marco Visual Arrastrable** | Ventana de aviso visual en pantalla que se puede mover fuera de combate. En combate, cuenta con *Click-Through* garantizado para no entorpecer los clics en el entorno 3D. |
| **Interfaz Estilo Details** | Panel minimalista y limpio con barras de progreso y colores correspondientes a cada clase de sanador (Sacerdote, Paladín, Chamán, Druida). |

> **Optimización en Combate**: Durante el combate, el marco visual del addon bloquea la entrada del ratón (*Click-Through*) para evitar clics accidentales mientras curas o te mueves.

---

## 🛠️ Instalación

1. Copia la carpeta `Manahelper` en `World of Warcraft\Interface\Addons\`
2. Asegúrate de que la carpeta se llame exactamente `Manahelper`
3. Actívalo en el menú de Addons al iniciar el juego o recarga la interfaz con `/reload`

---

## 📖 Uso Rápido

- **Comando `/mh` o `/manahelper`**: Abre o cierra la ventana principal de sanadores.
- **Comando `/mh help` o `/mh ayuda`**: Muestra el menú de ayuda interactivo en la consola del chat.
- **Comando `/mh test`**: Lanza una alerta visual y un sonido de prueba para configurar la interfaz.
- **Ventana Movible**: Haz clic en el icono del engranaje en la cabecera para mover el marco visual a cualquier posición.

---

## 💻 Desarrollo

Desarrollado por **Zorrorojo/Miabuelita** hermandad **<Sedentarios>** para el servidor NaerZone.
