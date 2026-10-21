# 🦈 Shark Paint Battle (Splatoon 3 Style)

Juego multijugador en Roblox Studio al estilo *Splatoon 3*, pero temático de tiburones ("Shark Paint Battle"), desarrollado con arquitectura modular en Luau y sincronizado mediante [Rojo](https://rojo.space).

---

## 🚀 Características Implementadas (Fase 1)

1. **Gestión de Tinta (`src/shared/InkSystem.luau`)**:
   - Depósito de tinta de 0 a 100 con consumo por disparo.
   - Recargas pasivas y recarga ultrarrápida al nadar en tinta amiga.
   - Cálculo reactivo del porcentaje de tinta.

2. **Catálogo de Armas (`src/shared/WeaponData.luau`)**:
   - **Lanzatintas Escualo:** Cadencia media, consumo medio, alcance balanceado.
   - **Francotiburón Cargador:** Disparo cargado de alta presión, daño masivo y largo alcance.

3. **Modo Tiburón & Homúnculo de Tinta (`src/client/SharkController.client.luau`)**:
   - Detección de suelo y tinta de equipo mediante Raycasting.
   - Transformación completa a **Homúnculo de Tinta** al mantener [Shift Izquierdo] sobre tinta amiga.
   - Aumento de velocidad a 34 WalkSpeed y animación procedural de natación (coleo dinámico e inclinación).
   - Efectos de sonido y partículas acuáticas de inmersión y salida.
   - Restauración garantizada del personaje sin parpadeos ni pérdida de visibilidad.

4. **Arma de Prueba y Entorno de Desarrollo (`src/weapon/` y `src/server/init.server.luau`)**:
   - Herramienta de disparo con proyectiles neón, colores dinámicos y explosiones de impacto.
   - Pedestal central interactivo y plataforma de tinta de prueba en Workspace.

---

## 🛠️ Cómo iniciar el proyecto

1. Clona el repositorio:
   ```bash
   git clone https://github.com/Cardona-vk/splatoon.git
   cd splatoon
   ```

2. Inicia el servidor de Rojo:
   ```bash
   rojo serve
   ```

3. Abre el proyecto en Roblox Studio y conecta el plugin de Rojo (`34872`).
