# 🚌 Plataforma de Transporte - Frontend (Offline-First)

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![SQLite](https://img.shields.io/badge/sqlite-%2307405e.svg?style=for-the-badge&logo=sqlite&logoColor=white)
![Socket.io](https://img.shields.io/badge/Socket.io-black?style=for-the-badge&logo=socket.io&badgeColor=010101)

Aplicación móvil diseñada para la gestión y validación de pasajes de transporte público en entornos de baja conectividad. Utiliza una arquitectura **Offline-First** con validación criptográfica asimétrica (HMAC-SHA256) para garantizar el cobro sin necesidad de internet.

## ✨ Características Principales

* **Dos Perfiles de Usuario:** Módulos independientes para Pasajeros y Operadores (Choferes).
* **Generación Criptográfica Offline:** Creación de códigos QR mediante UUIDs y firmas HMAC, eliminando la dependencia del reloj del sistema (Anti-Clock Drift).
* **Bóveda de Transacciones (SQLite):** Almacenamiento seguro de viajes validados cuando el autobús no tiene señal.
* **Sincronización Reactiva:** Motor en segundo plano (`SyncWorkerService`) que detecta automáticamente la recuperación de red y envía lotes de datos al servidor optimizando el consumo de batería.
* **Actualizaciones en Tiempo Real:** Integración con WebSockets para reflejar cobros en la pantalla del pasajero de manera instantánea.
* **Prevención de Fraude Local:** Sistema de validación en puerta ("Cadenero") que impide el doble escaneo de boletos en modo offline.

## 🛠️ Tecnologías y Arquitectura

* **Framework:** Flutter (Dart)
* **Gestión de Estado:** `ChangeNotifier` + `ListenableBuilder` (Arquitectura Reactiva guiada por eventos).
* **Base de Datos Local:** `sqflite`
* **Lectura QR:** `mobile_scanner`
* **Conectividad:** `connectivity_plus`
* **Criptografía:** `crypto` (HMAC-SHA256) y `uuid`

## 🚀 Instalación y Configuración

1. **Clonar el repositorio:**
   ```bash
   git clone [https://github.com/tu-usuario/transporte-frontend.git](https://github.com/tu-usuario/transporte-frontend.git)
   cd transporte-frontend
